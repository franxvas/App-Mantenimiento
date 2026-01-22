import { initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore, QueryDocumentSnapshot } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { graphClientSecret } from "./config";
import {
  deleteRowByIndex,
  downloadWorkbook,
  ensureWorksheetAndTable,
  findRowIndexById,
  getWorksheetNames,
  resolveOrCreateWorkbookByPath,
  upsertRow
} from "./graph/excel";
import { getTemplateDefinitions, initSchemasFromTemplates } from "./parametros/schema";

initializeApp();

const firestore = getFirestore();
const storage = getStorage();

type SchemaField = {
  key: string;
  displayName: string;
  type: string;
  required: boolean;
  order: number;
};

type SchemaData = {
  fields: SchemaField[];
  aliases: Record<string, string>;
};

const schemaCache = new Map<string, SchemaData>();

const normalizeValue = (value: unknown): string => {
  if (value === null || value === undefined) {
    return "";
  }
  return String(value);
};

const getUpdatedAtIso = (data: Record<string, unknown> | undefined, fallback: string): string => {
  const updatedAt = data?.updatedAt as { toDate?: () => Date } | undefined;
  if (updatedAt?.toDate) {
    return updatedAt.toDate().toISOString();
  }
  return fallback;
};

const getSchemaForDisciplina = async (disciplina: string): Promise<SchemaData | null> => {
  if (schemaCache.has(disciplina)) {
    return schemaCache.get(disciplina) as SchemaData;
  }

  const doc = await firestore.collection("parametros_schemas").doc(disciplina).get();
  if (!doc.exists) {
    return null;
  }

  const data = doc.data() ?? {};
  const fields = (data.fields ?? []) as SchemaField[];
  const aliases = (data.aliases ?? {}) as Record<string, string>;
  const schema = { fields, aliases };
  schemaCache.set(disciplina, schema);
  return schema;
};

const getFieldValue = (
  data: Record<string, unknown>,
  attrs: Record<string, unknown>,
  fieldKey: string,
  aliases: Record<string, string>,
  fallbackUpdatedAt: string
): string => {
  if (fieldKey === "id") {
    return "";
  }

  if (fieldKey === "updatedAt") {
    return getUpdatedAtIso(data, fallbackUpdatedAt);
  }

  const directValue = data[fieldKey] ?? attrs[fieldKey];
  if (directValue !== undefined && directValue !== null) {
    return normalizeValue(directValue);
  }

  if (fieldKey === "piso") {
    const ubicacion = data.ubicacion as { piso?: string | number; nivel?: string | number } | undefined;
    if (ubicacion?.piso !== undefined) {
      return normalizeValue(ubicacion.piso);
    }
    if (ubicacion?.nivel !== undefined) {
      return normalizeValue(ubicacion.nivel);
    }
  }

  for (const [alias, canonical] of Object.entries(aliases)) {
    if (canonical !== fieldKey) {
      continue;
    }
    const aliasValue = data[alias] ?? attrs[alias];
    if (aliasValue !== undefined && aliasValue !== null) {
      return normalizeValue(aliasValue);
    }
  }

  return "";
};

const hasRelevantChange = (
  beforeData: Record<string, unknown>,
  afterData: Record<string, unknown>,
  schema: SchemaData
): boolean => {
  const beforeAttrs = (beforeData.attrs as Record<string, unknown>) ?? {};
  const afterAttrs = (afterData.attrs as Record<string, unknown>) ?? {};
  const fallback = new Date().toISOString();

  return schema.fields.some((field) => {
    const beforeValue = getFieldValue(beforeData, beforeAttrs, field.key, schema.aliases, fallback);
    const afterValue = getFieldValue(afterData, afterAttrs, field.key, schema.aliases, fallback);
    return beforeValue !== afterValue;
  });
};

const buildColumns = (fields: SchemaField[]) => {
  const columns = fields.map((field) => ({ key: field.key, displayName: field.displayName }));
  if (!columns.some((column) => column.key === "id")) {
    columns.unshift({ key: "id", displayName: "id" });
  }
  return columns;
};

export const initSchemas = onRequest(async (_req, res) => {
  try {
    await initSchemasFromTemplates(firestore);
    res.status(200).json({ status: "ok" });
  } catch (error) {
    console.error("initSchemasFromTemplates failed", error);
    res.status(500).json({ error: (error as Error).message });
  }
});

export const migrateNivelToPiso = onRequest(async (req, res) => {
  const removeNivel = req.query.removeNivel === "true";
  const batchSize = 300;
  let lastDoc: QueryDocumentSnapshot | undefined;
  let total = 0;

  try {
    while (true) {
      let query = firestore.collection("productos").orderBy("updatedAt").limit(batchSize);
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }
      const snapshot = await query.get();
      if (snapshot.empty) {
        break;
      }

      const batch = firestore.batch();
      snapshot.docs.forEach((doc) => {
        const data = doc.data() as Record<string, unknown>;
        const piso = data.piso ?? (data.ubicacion as { piso?: string } | undefined)?.piso;
        const nivel = data.nivel ?? (data.ubicacion as { nivel?: string } | undefined)?.nivel;
        if (!piso && nivel) {
          const ubicacion = (data.ubicacion as Record<string, unknown>) ?? {};
          batch.update(doc.ref, {
            piso: nivel,
            ubicacion: {
              ...ubicacion,
              piso: nivel,
              ...(removeNivel ? { nivel: FieldValue.delete() } : {})
            },
            ...(removeNivel ? { nivel: FieldValue.delete() } : {}),
            updatedAt: FieldValue.serverTimestamp()
          });
          total += 1;
        }
      });

      await batch.commit();
      lastDoc = snapshot.docs[snapshot.docs.length - 1];
    }

    res.status(200).json({ migrated: total });
  } catch (error) {
    console.error("migrateNivelToPiso failed", error);
    res.status(500).json({ error: (error as Error).message });
  }
});

export const syncProductsToExcel = onDocumentWritten(
  {
    document: "productos/{productId}",
    secrets: [graphClientSecret]
  },
  async (event) => {
    const correlationId = event.id ?? `products-${Date.now()}`;
    const productId = event.params.productId as string;
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;

    if (!beforeSnap || !afterSnap) {
      console.log({
        correlationId,
        productId,
        status: "skipped",
        reason: "missing_snapshot"
      });
      return;
    }

    const beforeExists = beforeSnap.exists;
    const afterExists = afterSnap.exists;

    let operation: "create" | "update" | "delete";
    if (!beforeExists && afterExists) {
      operation = "create";
    } else if (beforeExists && !afterExists) {
      operation = "delete";
    } else {
      operation = "update";
    }

    const beforeData = beforeSnap.data() as Record<string, unknown> | undefined;
    const afterData = afterSnap.data() as Record<string, unknown> | undefined;
    const sourceData = operation === "delete" ? beforeData : afterData;
    if (!sourceData) {
      console.log({
        correlationId,
        productId,
        status: "skipped",
        operation,
        reason: "missing_data"
      });
      return;
    }

    const disciplina = sourceData.disciplina as string | undefined;
    if (!disciplina) {
      console.log({
        correlationId,
        productId,
        status: "skipped",
        operation,
        reason: "missing_disciplina"
      });
      return;
    }

    const schema = await getSchemaForDisciplina(disciplina);
    if (!schema) {
      console.log({
        correlationId,
        productId,
        status: "skipped",
        operation,
        reason: "schema_not_found",
        disciplina
      });
      return;
    }

    if (operation === "update" && beforeData && afterData && !hasRelevantChange(beforeData, afterData, schema)) {
      console.log({
        correlationId,
        productId,
        status: "skipped",
        operation,
        reason: "no_relevant_changes"
      });
      return;
    }

    const template = getTemplateDefinitions().find(
      (item) => item.disciplina === disciplina && item.tipo === "base"
    );
    if (!template) {
      console.log({
        correlationId,
        productId,
        status: "skipped",
        operation,
        reason: "template_not_found"
      });
      return;
    }

    const columns = buildColumns(schema.fields);
    const attrs = (sourceData.attrs as Record<string, unknown>) ?? {};
    const updatedAtFallback = event.time ?? new Date().toISOString();
    const values = columns.map((column) => {
      if (column.key === "id") {
        return productId;
      }
      return getFieldValue(sourceData, attrs, column.key, schema.aliases, updatedAtFallback);
    });

    try {
      const workbookId = await resolveOrCreateWorkbookByPath(template.filename, template.filename);
      const worksheetNames = await getWorksheetNames(workbookId);
      const worksheetName = worksheetNames[0] ?? "Productos";
      const headers = columns.map((column) => column.displayName);
      const tableName = `Tabla_${disciplina}_base`;
      await ensureWorksheetAndTable(workbookId, worksheetName, tableName, headers);

      const rowIndex = await findRowIndexById(workbookId, productId, tableName);

      if (operation === "delete") {
        if (rowIndex !== null) {
          await deleteRowByIndex(workbookId, rowIndex, tableName);
        }
      } else {
        await upsertRow(workbookId, rowIndex, values, tableName);
      }

      const workbookBuffer = await downloadWorkbook(workbookId);
      const bucket = storage.bucket();
      const storagePath = `parametros/${template.filename}`;
      await bucket.file(storagePath).save(workbookBuffer, {
        contentType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      });

      await firestore.collection("parametros_excels").doc(`${disciplina}_base`).set(
        {
          key: `${disciplina}_base`,
          filename: template.filename,
          disciplina,
          tipo: "base",
          storagePath,
          generatedAt: Timestamp.now(),
          lastSourceUpdateAt: Timestamp.now()
        },
        { merge: true }
      );

      console.log({
        correlationId,
        productId,
        status: "success",
        operation,
        disciplina
      });
    } catch (error) {
      console.error({
        correlationId,
        productId,
        status: "error",
        operation,
        disciplina,
        error: (error as Error).message
      });
      throw error;
    }
  }
);

export const initSchemasFromTemplates = onRequest(async (_req, res) => {
  const templatesDir = path.resolve(__dirname, "../assets/excel_templates");
  const files = await fs.readdir(templatesDir);
  const db = getFirestore();
  const aliases = {
    nivel: "piso"
  };

  const schemaResults: Array<{ disciplina: string; fields: number }> = [];
  const excelResults: Array<{ key: string; type: string }> = [];

  for (const file of files) {
    const match = file.match(/^(.*)_(Base|Reportes)_ES\.xlsx$/i);
    if (!match) {
      continue;
    }

    const [, disciplineLabel, templateType] = match;
    const disciplina = toDisciplineKey(disciplineLabel);
    const key = path.basename(file, ".xlsx");

    await db
      .collection("parametros_excels")
      .doc(key)
      .set(
        {
          key,
          disciplina,
          templateType: templateType.toLowerCase(),
          fileName: file,
          path: `assets/excel_templates/${file}`,
          updatedAt: FieldValue.serverTimestamp()
        },
        { merge: true }
      );
    excelResults.push({ key, type: templateType.toLowerCase() });

    if (templateType.toLowerCase() !== "base") {
      continue;
    }

    const workbook = new ExcelJS.Workbook();
    const filePath = path.join(templatesDir, file);
    await workbook.xlsx.readFile(filePath);
    const worksheet = workbook.worksheets[0];
    const headerRow = worksheet?.getRow(1);
    const fields: Array<{ key: string; displayName: string }> = [];

    if (headerRow) {
      headerRow.eachCell({ includeEmpty: false }, (cell) => {
        const displayName = String(cell.text ?? cell.value ?? "").trim();
        if (!displayName) {
          return;
        }
        const keyName = toCamelCase(displayName);
        if (!keyName) {
          return;
        }
        fields.push({ key: keyName, displayName });
      });
    }

    await db
      .collection("parametros_schemas")
      .doc(disciplina)
      .set(
        {
          fields,
          aliases,
          updatedAt: FieldValue.serverTimestamp()
        },
        { merge: true }
      );

    schemaResults.push({ disciplina, fields: fields.length });
  }

  res.json({
    status: "ok",
    schemas: schemaResults,
    excels: excelResults
  });
});
