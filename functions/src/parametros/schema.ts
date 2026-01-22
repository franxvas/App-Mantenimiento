import ExcelJS from "exceljs";
import path from "path";
import { Timestamp, FieldValue, Firestore } from "firebase-admin/firestore";

type TemplateDefinition = {
  disciplina: string;
  tipo: "base" | "reportes";
  filename: string;
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
  const templatePath = path.join(__dirname, "../../..", "assets/excel_templates", filename);
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

const buildFields = (headers: string[]) => {
  const seen = new Map<string, number>();
  return headers.map((header, index) => {
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
      type: key === "estado" ? "enum" : "string",
      required: key === "nombre",
      order: index
    };
  });
};

export const initSchemasFromTemplates = async (firestore: Firestore) => {
  const batch = firestore.batch();
  const updatedAt = FieldValue.serverTimestamp();

  const grouped = TEMPLATE_DEFINITIONS.filter((template) => template.tipo === "base");
  for (const template of grouped) {
    const headers = await resolveHeaders(template.filename);
    const fields = buildFields(headers);
    const docRef = firestore.collection("parametros_schemas").doc(template.disciplina);
    batch.set(
      docRef,
      {
        disciplina: template.disciplina,
        fields,
        aliases: {
          nivel: "piso"
        },
        updatedAt
      },
      { merge: true }
    );
  }

  for (const template of TEMPLATE_DEFINITIONS) {
    const key = `${template.disciplina}_${template.tipo}`;
    const docRef = firestore.collection("parametros_excels").doc(key);
    batch.set(
      docRef,
      {
        key,
        filename: template.filename,
        disciplina: template.disciplina,
        tipo: template.tipo,
        storagePath: `parametros/${template.filename}`,
        generatedAt: null,
        lastSourceUpdateAt: null,
        updatedAt: Timestamp.now()
      },
      { merge: true }
    );
  }

  await batch.commit();
};

export const getTemplateDefinitions = () => TEMPLATE_DEFINITIONS;
