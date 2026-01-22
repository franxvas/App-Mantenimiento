import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import ExcelJS from "exceljs";
import { promises as fs } from "fs";
import path from "path";
import { graphClientSecret } from "./config";
import {
  deleteRowByIndex,
  ensureWorksheetAndTable,
  findRowIndexById,
  resolveOrCreateWorkbook,
  upsertRow
} from "./graph/excel";

initializeApp();

const getPisoValue = (data: Record<string, unknown> | undefined): string => {
  if (!data) {
    return "";
  }

  const piso = data.piso;
  if (typeof piso === "string" || typeof piso === "number") {
    return String(piso);
  }

  const ubicacion = data.ubicacion as { nivel?: string | number } | undefined;
  if (ubicacion?.nivel !== undefined) {
    return String(ubicacion.nivel);
  }

  return "";
};

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

const hasRelevantChange = (
  beforeData: Record<string, unknown>,
  afterData: Record<string, unknown>
): boolean => {
  const beforePiso = getPisoValue(beforeData);
  const afterPiso = getPisoValue(afterData);

  return (
    normalizeValue(beforeData.nombre) !== normalizeValue(afterData.nombre) ||
    normalizeValue(beforeData.estado) !== normalizeValue(afterData.estado) ||
    beforePiso !== afterPiso ||
    normalizeValue(beforeData.updatedAt) !== normalizeValue(afterData.updatedAt)
  );
};

const normalizeKeySegment = (value: string): string =>
  value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .replace(/[^a-zA-Z0-9]+/g, " ")
    .trim()
    .toLowerCase();

const toCamelCase = (value: string): string => {
  const normalized = normalizeKeySegment(value);
  if (!normalized) {
    return "";
  }
  const parts = normalized.split(/\s+/g);
  return parts[0] + parts.slice(1).map((part) => part[0].toUpperCase() + part.slice(1)).join("");
};

const toDisciplineKey = (value: string): string => normalizeKeySegment(value).replace(/\s+/g, "");

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

    if (operation === "update" && beforeData && afterData && !hasRelevantChange(beforeData, afterData)) {
      console.log({
        correlationId,
        productId,
        status: "skipped",
        operation,
        reason: "no_relevant_changes"
      });
      return;
    }

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

    const nombre = normalizeValue(sourceData.nombre);
    const estado = normalizeValue(sourceData.estado);
    const piso = getPisoValue(sourceData);
    const updatedAt = getUpdatedAtIso(sourceData, event.time ?? new Date().toISOString());

    const values = [productId, nombre, piso, estado, updatedAt];

    try {
      const workbookId = await resolveOrCreateWorkbook();
      await ensureWorksheetAndTable(workbookId);

      const rowIndex = await findRowIndexById(workbookId, productId);

      if (operation === "delete") {
        if (rowIndex !== null) {
          await deleteRowByIndex(workbookId, rowIndex);
        }
        console.log({
          correlationId,
          productId,
          status: "success",
          operation,
          deleted: rowIndex !== null
        });
        return;
      }

      await upsertRow(workbookId, rowIndex, values);

      console.log({
        correlationId,
        productId,
        status: "success",
        operation,
        updated: rowIndex !== null
      });
    } catch (error) {
      console.error({
        correlationId,
        productId,
        status: "error",
        operation,
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
