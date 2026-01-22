import axios, { AxiosError } from "axios";
import ExcelJS from "exceljs";
import fs from "fs";
import path from "path";
import { GRAPH_TABLE_NAME, GRAPH_WORKSHEET_NAME, getGraphConfig } from "../config";
import { getAccessToken } from "./auth";

const GRAPH_BASE_URL = "https://graph.microsoft.com/v1.0";
const MAX_RETRIES = 5;

const workbookCache = new Map<string, string>();
const tableCache = new Set<string>();

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

const graphGetBuffer = async (url: string): Promise<Buffer> => {
  const token = await getAccessToken();
  const response = await axios.request<ArrayBuffer>({
    method: "GET",
    url: `${GRAPH_BASE_URL}${url}`,
    responseType: "arraybuffer",
    headers: {
      Authorization: `Bearer ${token}`
    }
  });
  return Buffer.from(response.data);
};

const buildWorkbookBuffer = async (): Promise<Buffer> => {
  const workbook = new ExcelJS.Workbook();
  workbook.addWorksheet(GRAPH_WORKSHEET_NAME);
  return Buffer.from(await workbook.xlsx.writeBuffer());
};

const buildTemplateBuffer = async (templateFilename: string): Promise<Buffer> => {
  const templatePath = path.join(__dirname, "../../..", "assets/excel_templates", templateFilename);
  return fs.readFileSync(templatePath);
};

const normalizeDrivePath = (folder: string, filename: string): string => {
  const normalizedFolder = folder.endsWith("/") ? folder.slice(0, -1) : folder;
  return path.posix.join(normalizedFolder, filename);
};

const columnLetter = (index: number): string => {
  let column = "";
  let dividend = index + 1;
  while (dividend > 0) {
    let modulo = (dividend - 1) % 26;
    column = String.fromCharCode(65 + modulo) + column;
    dividend = Math.floor((dividend - modulo) / 26);
  }
  return column;
};

export const resolveOrCreateWorkbook = async (): Promise<string> => {
  const { workbookPath } = getGraphConfig();
  return resolveOrCreateWorkbookByPath(workbookPath);
};

export const resolveOrCreateWorkbookByPath = async (
  itemPath: string,
  templateFilename?: string,
  useParametrosFolder = true
): Promise<string> => {
  const { userId, parametrosFolder } = getGraphConfig();
  const drivePath = useParametrosFolder ? normalizeDrivePath(parametrosFolder, itemPath) : itemPath;

  if (workbookCache.has(drivePath)) {
    return workbookCache.get(drivePath) as string;
  }

  try {
    const item = await graphRequest<{ id: string }>(
      "GET",
      `/users/${userId}/drive/root:${drivePath}`
    );
    workbookCache.set(drivePath, item.id);
    return item.id;
  } catch (error) {
    const axiosError = error as AxiosError;
    if (axiosError.response?.status !== 404) {
      throw axiosError;
    }
  }

  const buffer = templateFilename ? await buildTemplateBuffer(templateFilename) : await buildWorkbookBuffer();
  const created = await graphPut<{ id: string }>(
    `/users/${userId}/drive/root:${drivePath}:/content`,
    buffer,
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  );
  workbookCache.set(drivePath, created.id);
  return created.id;
};

export const ensureWorksheetAndTable = async (
  itemId: string,
  worksheetName = GRAPH_WORKSHEET_NAME,
  tableName = GRAPH_TABLE_NAME,
  headers: string[] = ["id", "nombre", "piso", "estado", "updatedAt"]
): Promise<void> => {
  const tableKey = `${itemId}:${tableName}`;
  if (tableCache.has(tableKey)) {
    return;
  }

  const { userId } = getGraphConfig();

  const worksheets = await graphRequest<{ value: Array<{ name: string }> }>(
    "GET",
    `/users/${userId}/drive/items/${itemId}/workbook/worksheets`
  );

  const hasWorksheet = worksheets.value.some((sheet) => sheet.name === worksheetName);
  if (!hasWorksheet) {
    await graphRequest(
      "POST",
      `/users/${userId}/drive/items/${itemId}/workbook/worksheets/add`,
      { name: worksheetName }
    );
  }

  const tables = await graphRequest<{ value: Array<{ id: string; name: string }> }>(
    "GET",
    `/users/${userId}/drive/items/${itemId}/workbook/tables`
  );

  const existing = tables.value.find((table) => table.name === tableName);
  if (!existing) {
    const lastColumn = columnLetter(headers.length - 1);
    await graphRequest(
      "PATCH",
      `/users/${userId}/drive/items/${itemId}/workbook/worksheets/${worksheetName}/range(address='A1:${lastColumn}1')`,
      {
        values: [headers]
      }
    );

    const created = await graphRequest<{ id: string }>(
      "POST",
      `/users/${userId}/drive/items/${itemId}/workbook/tables/add`,
      {
        address: `${worksheetName}!A1:${lastColumn}1`,
        hasHeaders: true
      }
    );

    await graphRequest(
      "PATCH",
      `/users/${userId}/drive/items/${itemId}/workbook/tables/${created.id}`,
      { name: tableName }
    );
  }

  tableCache.add(tableKey);
};

export const getWorksheetNames = async (itemId: string): Promise<string[]> => {
  const { userId } = getGraphConfig();
  const worksheets = await graphRequest<{ value: Array<{ name: string }> }>(
    "GET",
    `/users/${userId}/drive/items/${itemId}/workbook/worksheets`
  );
  return worksheets.value.map((sheet) => sheet.name);
};

export const findRowIndexById = async (
  itemId: string,
  productId: string,
  tableName = GRAPH_TABLE_NAME
): Promise<number | null> => {
  const { userId } = getGraphConfig();

  const rows = await graphRequest<{ value: Array<{ index: number; values: string[][] }> }>(
    "GET",
    `/users/${userId}/drive/items/${itemId}/workbook/tables/${tableName}/rows`
  );

  const match = rows.value.find((row) => row.values?.[0]?.[0] === productId);
  return match ? match.index : null;
};

export const upsertRow = async (
  itemId: string,
  rowIndex: number | null,
  values: Array<string>,
  tableName = GRAPH_TABLE_NAME
): Promise<void> => {
  const { userId } = getGraphConfig();

  if (rowIndex === null) {
    await graphRequest(
      "POST",
      `/users/${userId}/drive/items/${itemId}/workbook/tables/${tableName}/rows/add`,
      { values: [values] }
    );
    return;
  }

  await graphRequest(
    "PATCH",
    `/users/${userId}/drive/items/${itemId}/workbook/tables/${tableName}/rows/${rowIndex}`,
    { values: [values] }
  );
};

export const deleteRowByIndex = async (
  itemId: string,
  rowIndex: number,
  tableName = GRAPH_TABLE_NAME
): Promise<void> => {
  const { userId } = getGraphConfig();

  await graphRequest(
    "POST",
    `/users/${userId}/drive/items/${itemId}/workbook/tables/${tableName}/rows/${rowIndex}/delete`
  );
};

export const downloadWorkbook = async (itemId: string): Promise<Buffer> => {
  const { userId } = getGraphConfig();
  return graphGetBuffer(`/users/${userId}/drive/items/${itemId}/content`);
};
