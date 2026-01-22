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
  GRAPH_WORKBOOK_PATH="/Apps/InteriorMaintenance/Productos.xlsx" \\
  GRAPH_PARAMETROS_FOLDER="/Apps/InteriorMaintenance/Parametros"

firebase functions:secrets:set GRAPH_CLIENT_SECRET
```

> También puedes usar `functions/.env.example` como guía local.

#### Detalle de variables Graph
| Variable | Descripción | Ejemplo |
| --- | --- | --- |
| `GRAPH_TENANT_ID` | ID del tenant de Entra ID (Azure AD). | `00000000-0000-0000-0000-000000000000` |
| `GRAPH_CLIENT_ID` | Client ID de la App Registration. | `00000000-0000-0000-0000-000000000000` |
| `GRAPH_CLIENT_SECRET` | Client secret (se gestiona como **secret**). | _(secrets:set)_ |
| `GRAPH_USER_ID` | UPN o ID del usuario propietario del OneDrive. | `owner@contoso.com` |
| `GRAPH_WORKBOOK_PATH` | Ruta del Excel en OneDrive. | `/Apps/InteriorMaintenance/Productos.xlsx` |
| `GRAPH_PARAMETROS_FOLDER` | Carpeta en OneDrive donde se almacenan los archivos de parámetros/plantillas consumidos por Graph. | `/Apps/InteriorMaintenance/Parametros` |

### Ejecutar `initSchemasFromTemplates`
`initSchemasFromTemplates` es una función administrativa pensada para inicializar esquemas desde las plantillas en Storage/Graph. Para ejecutarla manualmente con la CLI:

```bash
firebase functions:shell
# En la consola interactiva:
initSchemasFromTemplates()
```

Si necesitas ejecutarla en un entorno específico, asegúrate de usar el proyecto correcto con `firebase use <project-id>` antes de abrir el shell.

### Migración `nivel` → `piso`
Actualmente los documentos pueden traer el valor de ubicación como `ubicacion.nivel`, pero la salida hacia Excel utiliza `piso`. Para migrar datos existentes:

1. **Actualiza los clientes** para escribir `piso` (string/number) en el documento de `productos`.
2. **Migra documentos existentes** copiando `ubicacion.nivel` → `piso`.
3. **Depura el campo antiguo** (`ubicacion.nivel`) cuando todos los clientes ya lean/escriban `piso`.

Ejemplo de script con Admin SDK (Node) para la migración:

```ts
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

initializeApp();
const db = getFirestore();

const snapshot = await db.collection("productos").get();
const batch = db.batch();

snapshot.docs.forEach((doc) => {
  const data = doc.data();
  const nivel = data?.ubicacion?.nivel;
  if (nivel !== undefined && data.piso === undefined) {
    batch.update(doc.ref, { piso: String(nivel) });
  }
});

await batch.commit();
```

### Despliegue de Functions
```bash
firebase deploy --only functions
```

Si también necesitas publicar reglas de Storage:

```bash
firebase deploy --only storage
```

### Reglas recomendadas de Storage (ajustar a tus roles)
Ejemplo de reglas que requieren usuarios autenticados para lectura/escritura y permiten lectura pública opcional de plantillas:

```js
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Plantillas/parametros (opcionalmente solo lectura autenticada)
    match /parametros/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.token.admin == true;
    }

    // Por defecto: restringir a usuarios autenticados
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

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
