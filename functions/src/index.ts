import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import * as functions from "firebase-functions";
import { SchemaColumn, initSchemasFromTemplates } from "./parametros/schema";

initializeApp();

const firestore = getFirestore();

const DISCIPLINAS = new Set(["electricas", "arquitectura", "sanitarias", "estructuras"]);
const MAX_ROWS_IN_DOC = 500;

type DatasetRow = {
  id: string;
  values: Record<string, unknown>;
  updatedAt?: unknown;
};

type DatasetOperation = "upsert" | "delete";

const normalizeValue = (value: unknown): unknown => {
  if (value === undefined || value === null) {
    return "";
  }
  return value;
};

const buildRowValues = (columns: SchemaColumn[], data: Record<string, unknown>, productId: string) => {
  const values: Record<string, unknown> = {};
  const attrs = (data.attrs as Record<string, unknown>) ?? {};
  const ubicacion = (data.ubicacion as { nivel?: string | number } | undefined) ?? undefined;

  columns.forEach((column) => {
    if (column.key === "id") {
      values[column.key] = productId;
      return;
    }

    if (column.key === "nombre") {
      values[column.key] = normalizeValue(data.nombre ?? data["nombre"]);
      return;
    }

    if (column.key === "piso") {
      const pisoValue = data.piso ?? ubicacion?.nivel ?? data.nivel;
      values[column.key] = normalizeValue(pisoValue);
      return;
    }

    if (column.key === "estado") {
      values[column.key] = normalizeValue(data.estado);
      return;
    }

    const directValue = attrs[column.key] ?? data[column.key];
    values[column.key] = normalizeValue(directValue);
  });

  return values;
};

const migrateRowsToSubcollection = async (datasetRef: FirebaseFirestore.DocumentReference) => {
  const snapshot = await datasetRef.get();
  if (!snapshot.exists) {
    return;
  }

  const data = snapshot.data() ?? {};
  const rowsById = (data.rowsById ?? {}) as Record<string, DatasetRow>;
  const rowEntries = Object.entries(rowsById);
  if (rowEntries.length === 0) {
    await datasetRef.set({ storageMode: "subcollection", rowsById: FieldValue.delete() }, { merge: true });
    return;
  }

  const chunkSize = 400;
  for (let i = 0; i < rowEntries.length; i += chunkSize) {
    const chunk = rowEntries.slice(i, i + chunkSize);
    const batch = firestore.batch();
    chunk.forEach(([rowId, rowData]) => {
      const rowRef = datasetRef.collection("rows").doc(rowId);
      batch.set(rowRef, rowData, { merge: true });
    });
    await batch.commit();
  }

  await datasetRef.set(
    {
      storageMode: "subcollection",
      rowsById: FieldValue.delete()
    },
    { merge: true }
  );
};

const applyDatasetUpdate = async (
  disciplina: string,
  productId: string,
  operation: DatasetOperation,
  sourceData?: Record<string, unknown>
) => {
  if (!DISCIPLINAS.has(disciplina)) {
    return;
  }

  const schemaId = `${disciplina}_base`;
  const schemaSnap = await firestore.collection("parametros_schemas").doc(schemaId).get();
  if (!schemaSnap.exists) {
    return;
  }

  const schemaData = schemaSnap.data() ?? {};
  const columns = (schemaData.columns ?? []) as SchemaColumn[];
  const datasetRef = firestore.collection("parametros_datasets").doc(schemaId);

  const datasetSnapshot = await datasetRef.get();
  const datasetData = datasetSnapshot.data() ?? {};
  const storageMode = (datasetData.storageMode as string | undefined) ?? "document";

  if (storageMode === "subcollection") {
    const rowRef = datasetRef.collection("rows").doc(productId);
    await firestore.runTransaction(async (transaction) => {
      const current = await transaction.get(datasetRef);
      const currentData = current.data() ?? {};
      const currentCount = (currentData.rowCount as number | undefined) ?? 0;
      const rowSnapshot = await transaction.get(rowRef);
      const exists = rowSnapshot.exists;
      let nextCount = currentCount;

      if (operation === "delete" && exists) {
        nextCount = Math.max(0, currentCount - 1);
      } else if (operation === "upsert" && !exists) {
        nextCount = currentCount + 1;
      }

      if (operation === "delete") {
        transaction.delete(rowRef);
      } else if (sourceData) {
        const values = buildRowValues(columns, sourceData, productId);
        transaction.set(
          rowRef,
          {
            id: productId,
            values,
            updatedAt: FieldValue.serverTimestamp()
          },
          { merge: true }
        );
      }

      transaction.set(
        datasetRef,
        {
          disciplina,
          tipo: "base",
          columns,
          rowCount: nextCount,
          generatedAt: FieldValue.serverTimestamp(),
          storageMode: "subcollection"
        },
        { merge: true }
      );
    });
    return;
  }

  let nextCount = (datasetData.rowCount as number | undefined) ?? 0;
  const rowsById = { ...(datasetData.rowsById as Record<string, DatasetRow> | undefined) };
  const hadRow = Boolean(rowsById[productId]);

  if (operation === "delete") {
    if (hadRow) {
      rowsById[productId] = FieldValue.delete() as unknown as DatasetRow;
      nextCount = Math.max(0, nextCount - 1);
    }
  } else if (sourceData) {
    rowsById[productId] = {
      id: productId,
      values: buildRowValues(columns, sourceData, productId),
      updatedAt: FieldValue.serverTimestamp()
    };
    if (!hadRow) {
      nextCount += 1;
    }
  }

  await datasetRef.set(
    {
      disciplina,
      tipo: "base",
      columns,
      rowsById,
      rowCount: nextCount,
      generatedAt: FieldValue.serverTimestamp(),
      storageMode: "document"
    },
    { merge: true }
  );

  if (nextCount > MAX_ROWS_IN_DOC) {
    await migrateRowsToSubcollection(datasetRef);
  }
};

export const initParametrosSchemas = functions.https.onRequest(async (_req, res) => {
  try {
    await initSchemasFromTemplates(firestore);
    res.status(200).json({ status: "ok" });
  } catch (error) {
    console.error("initParametrosSchemas failed", error);
    res.status(500).json({ error: (error as Error).message });
  }
});

export const syncParametrosBase = functions.firestore
  .document("productos/{productId}")
  .onWrite(async (change, context) => {
    const productId = context.params.productId as string;
    const beforeData = change.before.exists
      ? (change.before.data() as Record<string, unknown>)
      : undefined;
    const afterData = change.after.exists
      ? (change.after.data() as Record<string, unknown>)
      : undefined;
    const beforeDisciplina = beforeData?.disciplina as string | undefined;
    const afterDisciplina = afterData?.disciplina as string | undefined;

    if (!beforeData && !afterData) {
      return;
    }

    if (beforeDisciplina && beforeDisciplina !== afterDisciplina) {
      await applyDatasetUpdate(beforeDisciplina, productId, "delete");
    }

    if (afterDisciplina) {
      await applyDatasetUpdate(afterDisciplina, productId, afterData ? "upsert" : "delete", afterData);
    }
  });
