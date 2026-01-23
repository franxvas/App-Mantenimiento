# appmantflutter

A new Flutter project.

## Parámetros Excel (Firebase Storage)

Este repo genera archivos Excel de parámetros a partir de plantillas locales (`functions/assets/excel_templates`) y datos en Firestore (`productos`). El flujo es 100% Firebase (Firestore + Storage), sin Microsoft Graph ni OneDrive.

### Flujo general
- Firestore (`productos`) es la fuente de verdad.
- Cloud Functions genera archivos Excel por disciplina y tipo.
- Los archivos se suben a Firebase Storage en `parametros/<filename>`.
- La app Flutter descarga los archivos desde Storage.

### Endpoints HTTP
Todos los endpoints son Cloud Functions **1st gen** (compatibles con Spark).

#### Inicializar catálogo de parámetros
Crea los documentos base en `parametros_excels` para los 8 archivos esperados.

```bash
curl -X GET https://<region>-<project-id>.cloudfunctions.net/initParametrosCatalog
```

#### Generar archivos
Genera un archivo puntual o todos si no se envían filtros.

```bash
# Generar todo
curl -X GET https://<region>-<project-id>.cloudfunctions.net/generateParametros

# Generar solo una disciplina + tipo
curl -X GET "https://<region>-<project-id>.cloudfunctions.net/generateParametros?disciplina=electricas&tipo=base"
```

### Datos que se escriben en Firestore
Colección: `parametros_excels`

```json
{
  "key": "electricas_base",
  "disciplina": "electricas",
  "tipo": "base",
  "filename": "Electricas_Base_ES.xlsx",
  "storagePath": "parametros/Electricas_Base_ES.xlsx",
  "generatedAt": null
}
```

### Mapeo de columnas (Excel → Firestore)
- Se usa la fila 1 del template como headers.
- Si no existe una columna `id`, se agrega como primera columna.
- Para cada fila:
  - `id`: ID del documento de `productos`.
  - `nombre`: `doc.nombre`.
  - `piso`: `doc.piso` o fallback `doc.ubicacion.nivel`.
  - `estado`: `doc.estado`.
  - Otras columnas: `doc.attrs[key]` → `doc[key]` → vacío.

### Reglas recomendadas de Storage (ajustar a tus roles)
```js
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /parametros/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.token.admin == true;
    }

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

### Migración `nivel` → `piso`
Si existen documentos con `ubicacion.nivel`, puedes migrarlos a `piso` con tu propio script (Admin SDK) o mantener el fallback en la generación del Excel.

Ejemplo de script con Admin SDK (Node):

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
