import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import * as functions from "firebase-functions";
import ExcelJS from "exceljs";
import fs from "fs/promises";
import path from "path";
import { getTemplateDefinitions, initSchemasFromTemplates } from "./parametros/schema";

initializeApp();

const firestore = getFirestore();
const storage = getStorage();

const TEMPLATE_DIR = path.join(__dirname, "..", "assets", "excel_templates");
const EXCEL_CONTENT_TYPE =
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

const resolveTemplatePath = (filename: string) => path.join(TEMPLATE_DIR, filename);

const getHeaderValues = (worksheet: ExcelJS.Worksheet): string[] => {
  const headerRow = worksheet.getRow(1);
  const values = headerRow.values as Array<string | number | null | undefined>;
  return values
    .slice(1)
    .map((value) => String(value ?? "").trim())
    .filter((value) => value.length > 0);
};

const ensureIdHeader = (headers: string[]) => {
  const hasId = headers.some((header) => header.trim().toLowerCase() === "id");
  if (hasId) {
    return headers;
  }
  return ["id", ...headers];
};

const resolveCellValue = (data: Record<string, unknown>, header: string): string => {
  const normalized = header.trim().toLowerCase();

  if (normalized === "id") {
    return "";
  }

  if (normalized === "nombre") {
    return String(data.nombre ?? data["nombre"] ?? "");
  }

  if (normalized === "piso") {
    const ubicacion = (data.ubicacion as { nivel?: string | number } | undefined) ?? undefined;
    const pisoValue = data.piso ?? ubicacion?.nivel;
    return pisoValue !== undefined && pisoValue !== null ? String(pisoValue) : "";
  }

  if (normalized === "estado") {
    return String(data.estado ?? "");
  }

  const attrs = (data.attrs as Record<string, unknown>) ?? {};
  const directValue = attrs[header] ?? attrs[normalized] ?? data[header] ?? data[normalized];
  if (directValue === undefined || directValue === null) {
    return "";
  }
  return String(directValue);
};

const buildBaseWorkbookBuffer = async (disciplina: string, filename: string): Promise<Buffer> => {
  const templatePath = resolveTemplatePath(filename);
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.readFile(templatePath);

  const worksheet = workbook.worksheets[0] ?? workbook.addWorksheet("Datos");
  const rawHeaders = getHeaderValues(worksheet);
  const headers = ensureIdHeader(rawHeaders);

  const headerRow = worksheet.getRow(1);
  headerRow.values = [null, ...headers];
  headerRow.commit();

  if (worksheet.rowCount > 1) {
    worksheet.spliceRows(2, worksheet.rowCount - 1);
  }

  const snapshot = await firestore
    .collection("productos")
    .where("disciplina", "==", disciplina)
    .get();

  snapshot.docs.forEach((doc) => {
    const data = doc.data() as Record<string, unknown>;
    const row = headers.map((header) => {
      if (header.trim().toLowerCase() === "id") {
        return doc.id;
      }
      return resolveCellValue(data, header);
    });
    worksheet.addRow(row);
  });

  const buffer = await workbook.xlsx.writeBuffer();
  return Buffer.isBuffer(buffer) ? buffer : Buffer.from(buffer);
};

const buildReportesWorkbookBuffer = async (filename: string): Promise<Buffer> => {
  const templatePath = resolveTemplatePath(filename);
  const fileBuffer = await fs.readFile(templatePath);
  return Buffer.from(fileBuffer);
};

const uploadWorkbook = async (filename: string, buffer: Buffer) => {
  const storagePath = `parametros/${filename}`;
  const bucket = storage.bucket();
  await bucket.file(storagePath).save(buffer, { contentType: EXCEL_CONTENT_TYPE });
  return storagePath;
};

export const initSchemas = functions.https.onRequest(async (_req, res) => {
  try {
    await initSchemasFromTemplates(firestore);
    res.status(200).json({ status: "ok" });
  } catch (error) {
    console.error("initSchemasFromTemplates failed", error);
    res.status(500).json({ error: (error as Error).message });
  }
});

export const initParametrosCatalog = functions.https.onRequest(async (_req, res) => {
  try {
    const batch = firestore.batch();
    const updatedAt = FieldValue.serverTimestamp();

    getTemplateDefinitions().forEach((template) => {
      const key = `${template.disciplina}_${template.tipo}`;
      const docRef = firestore.collection("parametros_excels").doc(key);
      batch.set(
        docRef,
        {
          key,
          disciplina: template.disciplina,
          tipo: template.tipo,
          filename: template.filename,
          storagePath: `parametros/${template.filename}`,
          generatedAt: null,
          updatedAt
        },
        { merge: true }
      );
    });

    await batch.commit();

    res.status(200).json({ status: "ok" });
  } catch (error) {
    console.error("initParametrosCatalog failed", error);
    res.status(500).json({ error: (error as Error).message });
  }
});

export const generateParametros = functions.https.onRequest(async (req, res) => {
  if (req.method !== "GET") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const disciplina = (req.query.disciplina as string | undefined)?.toLowerCase();
  const tipo = (req.query.tipo as string | undefined)?.toLowerCase();

  const templates = getTemplateDefinitions().filter((template) => {
    if (disciplina && template.disciplina !== disciplina) {
      return false;
    }
    if (tipo && template.tipo !== tipo) {
      return false;
    }
    return true;
  });

  if (templates.length === 0) {
    res.status(400).json({ error: "No templates matched the request." });
    return;
  }

  try {
    const results: Array<{ key: string; filename: string }> = [];

    for (const template of templates) {
      const buffer =
        template.tipo === "base"
          ? await buildBaseWorkbookBuffer(template.disciplina, template.filename)
          : await buildReportesWorkbookBuffer(template.filename);

      const storagePath = await uploadWorkbook(template.filename, buffer);

      await firestore.collection("parametros_excels").doc(`${template.disciplina}_${template.tipo}`).set(
        {
          key: `${template.disciplina}_${template.tipo}`,
          disciplina: template.disciplina,
          tipo: template.tipo,
          filename: template.filename,
          storagePath,
          generatedAt: FieldValue.serverTimestamp()
        },
        { merge: true }
      );

      results.push({ key: `${template.disciplina}_${template.tipo}`, filename: template.filename });
    }

    res.status(200).json({ status: "ok", generated: results });
  } catch (error) {
    console.error("generateParametros failed", error);
    res.status(500).json({ error: (error as Error).message });
  }
});
