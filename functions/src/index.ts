import { initializeApp } from "firebase-admin/app";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
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
