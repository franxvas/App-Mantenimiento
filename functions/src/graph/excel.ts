import axios, { AxiosError } from "axios";
import ExcelJS from "exceljs";
import { GRAPH_TABLE_NAME, GRAPH_WORKSHEET_NAME, getGraphConfig } from "../config";
import { getAccessToken } from "./auth";

const GRAPH_BASE_URL = "https://graph.microsoft.com/v1.0";
const MAX_RETRIES = 5;

let cachedWorkbookId: string | null = null;
let cachedTableReady = false;

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const isRetryable = (error: AxiosError) => {
  if (!error.response) {
    return true;
  }
  const status = error.response.status;
  return status === 429 || status >= 500;
};

const getRetryDelay = (error: AxiosError, attempt: number) => {
  const retryAfter = error.response?.headers?.["retry-after"];
  if (retryAfter) {
    const seconds = Number(retryAfter);
    if (!Number.isNaN(seconds) && seconds > 0) {
      return seconds * 1000;
    }
  }
  return Math.min(1000 * 2 ** (attempt - 1), 8000);
};

const graphRequest = async <T>(
  method: "GET" | "POST" | "PUT" | "PATCH",
  url: string,
  data?: unknown
): Promise<T> => {
  const token = await getAccessToken();

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt += 1) {
    try {
      const response = await axios.request<T>({
        method,
        url: `${GRAPH_BASE_URL}${url}`,
        data,
        headers: {
          Authorization: `Bearer ${token}`
        }
      });
      return response.data;
    } catch (error) {
      const axiosError = error as AxiosError;
      if (!isRetryable(axiosError) || attempt === MAX_RETRIES) {
        throw axiosError;
      }
      const delay = getRetryDelay(axiosError, attempt);
      await sleep(delay);
    }
  }

  throw new Error("Graph request failed after retries.");
};

const graphPut = async <T>(url: string, data: unknown, contentType: string): Promise<T> => {
  const token = await getAccessToken();
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt += 1) {
    try {
      const response = await axios.request<T>({
        method: "PUT",
        url: `${GRAPH_BASE_URL}${url}`,
        data,
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": contentType
        }
      });
      return response.data;
    } catch (error) {
      const axiosError = error as AxiosError;
      if (!isRetryable(axiosError) || attempt === MAX_RETRIES) {
        throw axiosError;
      }
      const delay = getRetryDelay(axiosError, attempt);
      await sleep(delay);
    }
  }

  throw new Error("Graph request failed after retries.");
};

const buildWorkbookBuffer = async (): Promise<Buffer> => {
  const workbook = new ExcelJS.Workbook();
  workbook.addWorksheet(GRAPH_WORKSHEET_NAME);
  return Buffer.from(await workbook.xlsx.writeBuffer());
};

export const resolveOrCreateWorkbook = async (): Promise<string> => {
  if (cachedWorkbookId) {
    return cachedWorkbookId;
  }

  const { userId, workbookPath } = getGraphConfig();

  try {
    const item = await graphRequest<{ id: string }>(
      "GET",
      `/users/${userId}/drive/root:${workbookPath}`
    );
    cachedWorkbookId = item.id;
    return item.id;
  } catch (error) {
    const axiosError = error as AxiosError;
    if (axiosError.response?.status !== 404) {
      throw axiosError;
    }
  }

  const buffer = await buildWorkbookBuffer();
  const created = await graphPut<{ id: string }>(
    `/users/${userId}/drive/root:${workbookPath}:/content`,
    buffer,
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  );
  cachedWorkbookId = created.id;
  return created.id;
};

export const ensureWorksheetAndTable = async (itemId: string): Promise<void> => {
  if (cachedTableReady) {
    return;
  }

  const { userId } = getGraphConfig();

  const worksheets = await graphRequest<{ value: Array<{ name: string }> }>(
    "GET",
    `/users/${userId}/drive/items/${itemId}/workbook/worksheets`
  );

  const hasWorksheet = worksheets.value.some((sheet) => sheet.name === GRAPH_WORKSHEET_NAME);
  if (!hasWorksheet) {
    await graphRequest(
      "POST",
      `/users/${userId}/drive/items/${itemId}/workbook/worksheets/add`,
      { name: GRAPH_WORKSHEET_NAME }
    );
  }

  await graphRequest(
    "PATCH",
    `/users/${userId}/drive/items/${itemId}/workbook/worksheets/${GRAPH_WORKSHEET_NAME}/range(address='A1:E1')`,
    {
      values: [["id", "nombre", "piso", "estado", "updatedAt"]]
    }
  );

  const tables = await graphRequest<{ value: Array<{ id: string; name: string }> }>(
    "GET",
    `/users/${userId}/drive/items/${itemId}/workbook/tables`
  );

  const existing = tables.value.find((table) => table.name === GRAPH_TABLE_NAME);
  if (!existing) {
    const created = await graphRequest<{ id: string }>(
      "POST",
      `/users/${userId}/drive/items/${itemId}/workbook/tables/add`,
      {
        address: `${GRAPH_WORKSHEET_NAME}!A1:E1`,
        hasHeaders: true
      }
    );

    await graphRequest(
      "PATCH",
      `/users/${userId}/drive/items/${itemId}/workbook/tables/${created.id}`,
      { name: GRAPH_TABLE_NAME }
    );
  }

  cachedTableReady = true;
};

export const findRowIndexById = async (
  itemId: string,
  productId: string
): Promise<number | null> => {
  const { userId } = getGraphConfig();

  const rows = await graphRequest<{ value: Array<{ index: number; values: string[][] }> }>(
    "GET",
    `/users/${userId}/drive/items/${itemId}/workbook/tables/${GRAPH_TABLE_NAME}/rows`
  );

  const match = rows.value.find((row) => row.values?.[0]?.[0] === productId);
  return match ? match.index : null;
};

export const upsertRow = async (
  itemId: string,
  rowIndex: number | null,
  values: Array<string>
): Promise<void> => {
  const { userId } = getGraphConfig();

  if (rowIndex === null) {
    await graphRequest(
      "POST",
      `/users/${userId}/drive/items/${itemId}/workbook/tables/${GRAPH_TABLE_NAME}/rows/add`,
      { values: [values] }
    );
    return;
  }

  await graphRequest(
    "PATCH",
    `/users/${userId}/drive/items/${itemId}/workbook/tables/${GRAPH_TABLE_NAME}/rows/${rowIndex}`,
    { values: [values] }
  );
};

export const deleteRowByIndex = async (itemId: string, rowIndex: number): Promise<void> => {
  const { userId } = getGraphConfig();

  await graphRequest(
    "POST",
    `/users/${userId}/drive/items/${itemId}/workbook/tables/${GRAPH_TABLE_NAME}/rows/${rowIndex}/delete`
  );
};
