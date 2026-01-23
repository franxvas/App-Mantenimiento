# appmantflutter

A new Flutter project.

## Parámetros (Firestore + Flutter, sin Functions ni Storage)

Este repo implementa la experiencia de Parámetros **solo con Flutter + Firestore**:

- **No** se usa Cloud Functions.
- **No** se usa Firebase Storage.
- **No** se usa Microsoft Graph/OneDrive.

El Excel se genera localmente en el dispositivo usando Flutter.

## Flujo general
- Firestore (`productos`) es la fuente de verdad.
- La app **siembra esquemas** en `parametros_schemas` si no existen.
- La app **mantiene datasets** en `parametros_datasets/<disciplina>_<tipo>/rows` en cada alta/edición/borrado.
- El visor lee `parametros_schemas` y el subcollection `rows` para mostrar la tabla.
- El Excel se genera en el dispositivo y se guarda en documentos locales.

## Colecciones en Firestore

### parametros_schemas
Doc ID: `<disciplina>_<tipo>` (ej: `electricas_base`)

```json
{
  "disciplina": "electricas",
  "tipo": "base",
  "filenameDefault": "Electricas_Base_ES.xlsx",
  "columns": [
    { "key": "id", "displayName": "ID", "order": 0, "type": "text", "required": true },
    { "key": "nombre", "displayName": "Nombre", "order": 1, "type": "text", "required": true },
    { "key": "piso", "displayName": "Piso", "order": 2, "type": "text" },
    { "key": "estado", "displayName": "Estado", "order": 3, "type": "text" }
  ],
  "aliases": { "nivel": "piso" },
  "updatedAt": "<timestamp>"
}
```

### parametros_datasets
Doc ID: `<disciplina>_<tipo>` (ej: `electricas_base`)

```json
{
  "disciplina": "electricas",
  "tipo": "base",
  "schemaRef": "parametros_schemas/electricas_base",
  "rowCount": 12,
  "updatedAt": "<timestamp>"
}
```

Subcollection de filas:
`parametros_datasets/<disciplina>_<tipo>/rows/<rowId>`

```json
{
  "id": "<rowId>",
  "nombre": "...",
  "piso": "...",
  "estado": "...",
  "values": { "<key>": "<stringValue>" },
  "updatedAt": "<timestamp>"
}
```

## Sembrado de esquemas
La app siembra automáticamente los 8 esquemas requeridos (4 disciplinas x base/reportes) si la colección está vacía.

## Mapeo de columnas (producto → fila)
- `id`: ID del documento de `productos`.
- `nombre`: `producto.nombre`.
- `piso`: `producto.piso` o `producto.ubicacion.nivel` o `producto.nivel`.
- `estado`: `producto.estado`.
- Otras columnas: `producto.attrs[key]` → `producto[key]` → vacío.

## Generación de Excel (en dispositivo)
Desde el visor, el botón **Generar Excel** crea el archivo `.xlsx` con:
- Nombre exacto `filenameDefault` (por disciplina y tipo).
- Hoja "Parametros".
- Header con `columns.displayName`.
- Filas con los valores del dataset.

El archivo se guarda en el directorio de documentos local y se abre con `open_filex`.

## Nota importante
Como no hay Functions ni triggers, los datasets se actualizan **solo** cuando la app crea/edita/borra productos usando los servicios locales.
Si se editan documentos directamente en Firestore fuera de la app, el dataset no se sincroniza automáticamente.
