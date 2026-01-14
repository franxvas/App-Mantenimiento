# appmantflutter

A new Flutter project.

## Sincronización automática de productos a Excel (OneDrive)

Este repo incluye una integración **backend-only** para reflejar cambios en Firestore hacia un Excel en OneDrive usando Microsoft Graph + Firebase Cloud Functions.

### Arquitectura
- Firestore (fuente de verdad) → Cloud Functions (TypeScript) → Microsoft Graph → Excel (tabla).
- El cliente Flutter **no** accede a Graph ni guarda secretos.

### Requisitos en Azure
1. **Azure App Registration** (cuenta propietaria del OneDrive).
2. Permisos de Microsoft Graph (Application permissions):
   - `Files.ReadWrite.All`
   - `Sites.ReadWrite.All`
   - `User.Read.All` (para acceso al drive del usuario, si usas UPN)
3. Otorgar **Admin consent**.

### Variables y secretos (Firebase Functions)
Configura estas variables en Functions (NO en Flutter):

```bash
firebase functions:config:set \\
  GRAPH_TENANT_ID="your-tenant-id" \\
  GRAPH_CLIENT_ID="your-client-id" \\
  GRAPH_USER_ID="owner@contoso.com" \\
  GRAPH_WORKBOOK_PATH="/Apps/InteriorMaintenance/Productos.xlsx"

firebase functions:secrets:set GRAPH_CLIENT_SECRET
```

> También puedes usar `functions/.env.example` como guía local.

### Despliegue

```bash
firebase deploy --only functions
```

### Ruta del Excel
El archivo se crea/usa en:

```
/Apps/InteriorMaintenance/Productos.xlsx
```

La tabla creada dentro del Excel es **TablaProductos** con columnas:
`id, nombre, piso, estado, updatedAt`.
