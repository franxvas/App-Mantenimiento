import { defineSecret, defineString } from "firebase-functions/params";

export const graphTenantId = defineString("GRAPH_TENANT_ID");
export const graphClientId = defineString("GRAPH_CLIENT_ID");
export const graphClientSecret = defineSecret("GRAPH_CLIENT_SECRET");
export const graphUserId = defineString("GRAPH_USER_ID");
export const graphWorkbookPath = defineString("GRAPH_WORKBOOK_PATH");

export const GRAPH_WORKSHEET_NAME = "Productos";
export const GRAPH_TABLE_NAME = "TablaProductos";
const DEFAULT_WORKBOOK_PATH = "/Apps/InteriorMaintenance/Productos.xlsx";

export const getGraphConfig = () => {
  const tenantId = graphTenantId.value();
  const clientId = graphClientId.value();
  const clientSecret = graphClientSecret.value();
  const userId = graphUserId.value();
  const workbookPath = graphWorkbookPath.value() || DEFAULT_WORKBOOK_PATH;

  if (!tenantId || !clientId || !clientSecret || !userId) {
    throw new Error("Missing Graph configuration (tenant/client/secret/user). Check environment settings.");
  }

  return {
    tenantId,
    clientId,
    clientSecret,
    userId,
    workbookPath
  };
};
