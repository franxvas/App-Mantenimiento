import ExcelJS from "exceljs";
import path from "path";
import { FieldValue, Firestore } from "firebase-admin/firestore";

export type TemplateDefinition = {
  disciplina: "electricas" | "sanitarias" | "estructuras" | "arquitectura";
  tipo: "base" | "reportes";
  filename: string;
};

export type SchemaColumn = {
  key: string;
  displayName: string;
  order: number;
  type: "text" | "number" | "date" | "bool" | "enum";
  required?: boolean;
};

const TEMPLATE_DEFINITIONS: TemplateDefinition[] = [
  { disciplina: "electricas", tipo: "base", filename: "Electricas_Base_ES.xlsx" },
  { disciplina: "electricas", tipo: "reportes", filename: "Electricas_Reportes_ES.xlsx" },
  { disciplina: "sanitarias", tipo: "base", filename: "Sanitarias_Base_ES.xlsx" },
  { disciplina: "sanitarias", tipo: "reportes", filename: "Sanitarias_Reportes_ES.xlsx" },
  { disciplina: "estructuras", tipo: "base", filename: "Estructuras_Base_ES.xlsx" },
  { disciplina: "estructuras", tipo: "reportes", filename: "Estructuras_Reportes_ES.xlsx" },
  { disciplina: "arquitectura", tipo: "base", filename: "Arquitectura_Base_ES.xlsx" },
  { disciplina: "arquitectura", tipo: "reportes", filename: "Arquitectura_Reportes_ES.xlsx" }
];

const TEMPLATE_DIR = path.join(__dirname, "..", "..", "assets", "excel_templates");

const normalizeHeader = (header: string): string => {
  const clean = header
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-zA-Z0-9]+/g, " ")
    .trim()
    .toLowerCase();
  if (!clean) {
    return "";
  }
  const parts = clean.split(/\s+/);
  return parts
    .map((part, index) => (index === 0 ? part : part.charAt(0).toUpperCase() + part.slice(1)))
    .join("");
};

const resolveHeaders = async (filename: string): Promise<string[]> => {
  const templatePath = path.join(TEMPLATE_DIR, filename);
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.readFile(templatePath);
  const worksheet = workbook.worksheets[0];
  if (!worksheet) {
    return [];
  }

  let headerRow: ExcelJS.Row | undefined;
  worksheet.eachRow((row) => {
    if (headerRow) {
      return;
    }
    const values = row.values as Array<string | number | undefined>;
    const hasText = values.some((value) => typeof value === "string" && value.trim().length > 0);
    if (hasText) {
      headerRow = row;
    }
  });

  if (!headerRow) {
    return [];
  }

  const values = headerRow.values as Array<string | number | undefined>;
  return values
    .slice(1)
    .map((value) => (typeof value === "string" ? value.trim() : String(value ?? "").trim()))
    .filter((value) => value.length > 0);
};

const guessColumnType = (key: string): SchemaColumn["type"] => {
  if (key === "estado") {
    return "enum";
  }
  if (key.includes("fecha")) {
    return "date";
  }
  return "text";
};

const buildColumns = (headers: string[]): SchemaColumn[] => {
  const seen = new Map<string, number>();
  const columns = headers.map((header, index) => {
    let key = normalizeHeader(header);
    if (!key) {
      key = `field${index + 1}`;
    }
    const count = seen.get(key) ?? 0;
    if (count > 0) {
      key = `${key}${count + 1}`;
    }
    seen.set(key, count + 1);
    return {
      key,
      displayName: header,
      type: guessColumnType(key),
      required: key === "nombre",
      order: index + 1
    };
  });

  if (!columns.some((column) => column.key === "id")) {
    columns.unshift({
      key: "id",
      displayName: "id",
      order: 0,
      type: "text",
      required: true
    });
  } else {
    columns.sort((a, b) => a.order - b.order);
  }

  return columns;
};

export const initSchemasFromTemplates = async (firestore: Firestore) => {
  const batch = firestore.batch();
  const updatedAt = FieldValue.serverTimestamp();
  const aliases = {
    nivel: "piso"
  };

  for (const template of TEMPLATE_DEFINITIONS) {
    const headers = await resolveHeaders(template.filename);
    const columns = buildColumns(headers);
    const schemaId = `${template.disciplina}_${template.tipo}`;
    const schemaRef = firestore.collection("parametros_schemas").doc(schemaId);
    batch.set(
      schemaRef,
      {
        disciplina: template.disciplina,
        tipo: template.tipo,
        filenameDefault: template.filename,
        columns,
        aliases,
        updatedAt
      },
      { merge: true }
    );

    const datasetRef = firestore.collection("parametros_datasets").doc(schemaId);
    batch.set(
      datasetRef,
      {
        disciplina: template.disciplina,
        tipo: template.tipo,
        columns,
        rowsById: {},
        generatedAt: null,
        rowCount: 0,
        storageMode: "document",
        updatedAt
      },
      { merge: true }
    );
  }

  await batch.commit();
};

export const getTemplateDefinitions = () => TEMPLATE_DEFINITIONS;
