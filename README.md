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
- El visor lee `parametros_schemas` y consulta Firestore directamente para `productos` (Base) y `productos/{id}/reportes` (Reportes).
- El Excel se genera en el dispositivo y se guarda en documentos locales.

## Colecciones en Firestore

### parametros_schemas
Doc ID: `<disciplina>_<tipo>` (ej: `electricas_base`)

```json
{
  "disciplina": "Electricas",
  "disciplinaKey": "electricas",
  "tipo": "base",
  "filenameDefault": "Electricas_Base_ES.xlsx",
  "columns": [
    { "key": "idActivo", "displayName": "ID_Activo", "order": 0, "type": "text" },
    { "key": "disciplina", "displayName": "Disciplina", "order": 1, "type": "text" },
    { "key": "categoriaActivo", "displayName": "Categoria_Activo", "order": 2, "type": "text" }
  ],
  "aliases": { "nivel": "piso" },
  "updatedAt": "<timestamp>"
}
```

### productos/{id}/reportes
Subcolección de reportes por activo (se usa para el visor de Reportes).

## Sembrado de esquemas
La app siembra automáticamente los 8 esquemas requeridos (4 disciplinas x base/reportes) si la colección está vacía.

## Mapeo de columnas (Excel → Firestore)
El campo canónico de ubicación es **`nivel`**. Al leer, se hace fallback en este orden:
1. `nivel`
2. `piso`
3. `ubicacion.nivel`
4. `ubicacion.piso`

### Base (Electricas)
- `ID_Activo`: `doc.id`
- `Disciplina`: `producto.disciplina`
- `Categoria_Activo`: `producto.categoriaActivo`
- `Tipo_Activo`: `producto.tipoActivo`
- `Bloque`: `producto.bloque`
- `Nivel`: `producto.nivel` (fallback según orden anterior)
- `Espacio`: `producto.espacio`
- `Estado_Operativo`: `producto.estadoOperativo`
- `Condicion_Fisica`: `producto.condicionFisica`
- `Fecha_Ultima_Inspeccion`: `producto.fechaUltimaInspeccion`
- `Nivel_Criticidad`: `producto.nivelCriticidad`
- `Impacto_Falla`: `producto.impactoFalla`
- `Riesgo_Normativo`: `producto.riesgoNormativo`
- `Frecuencia_Mantenimiento_Meses`: `producto.frecuenciaMantenimientoMeses`
- `Fecha_Proximo_Mantenimiento`: `producto.fechaProximoMantenimiento`
- `Costo_Mantenimiento`: `producto.costoMantenimiento`
- `Costo_Reemplazo`: `producto.costoReemplazo`
- `Observaciones`: `producto.observaciones`

### Reportes (Electricas)
- `ID_Reporte`: `reporte.id`
- `ID_Activo`: `producto.id`
- `Disciplina`: `Electricas`
- `Fecha_Inspeccion`: `reporte.fechaInspeccion`
- `Estado_Detectado`: `reporte.estadoDetectado`
- `Riesgo_Electrico`: `reporte.riesgoElectrico`
- `Accion_Recomendada`: `reporte.accionRecomendada`
- `Costo_Estimado`: `reporte.costoEstimado`
- `Responsable`: `reporte.responsable`

## Generación de Excel (en dispositivo)
Desde el visor, el botón **Generar Excel** crea el archivo `.xlsx` con:
- Nombre con formato `Electricas_Base_yyyyMMdd.xlsx` o `Electricas_Reportes_yyyyMMdd.xlsx`.
- Hoja "Parametros".
- Header con `columns.displayName`.
- Filas con los valores del dataset.

El archivo se guarda en el directorio de documentos local y se abre con `open_filex`.

## Nota importante
Como no hay Functions ni triggers, los cambios se reflejan solo cuando la app crea/edita productos y reportes.
Si se editan documentos directamente en Firestore fuera de la app, el visor no recalcula datos adicionales automáticamente.
