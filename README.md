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
- La app **siembra esquemas** en `parametros_schemas` para formularios dinámicos, pero el visor usa **directamente** los headers de las plantillas Excel.
- El visor consulta `productos` (Base) y `productos/{id}/reportes` (Reportes) directamente.
- El Excel se genera en el dispositivo y se guarda en documentos locales (Web descarga archivo).

## Colecciones en Firestore

### productos/{id}/reportes
Subcolección de reportes por activo (se usa para el visor de Reportes).

## Sembrado de esquemas
La app siembra automáticamente los 8 esquemas requeridos (4 disciplinas x base/reportes) si la colección está vacía. Esto solo afecta formularios dinámicos y validaciones, no el visor Excel.

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
Desde el visor, el botón **Generar Excel** crea el archivo `.xlsx` usando la **plantilla real** de `assets/excel_templates/`:
- Nombre con formato `Electricas_Base_yyyyMMdd.xlsx` o `Electricas_Reportes_yyyyMMdd.xlsx`.
- Encabezados tomados de la primera fila de la plantilla.
- Filas nuevas reemplazando los datos existentes en el template.

El archivo se guarda en el directorio de documentos local y se abre con `open_filex` (Web descarga archivo).

## Añadir nuevas disciplinas o plantillas
1. Agrega las plantillas en `assets/excel_templates/` con el formato:
   - `<Disciplina>_Base_ES.xlsx`
   - `<Disciplina>_Reportes_ES.xlsx`
2. Asegura que `pubspec.yaml` incluya `assets/excel_templates/`.
3. Registra la disciplina en `lib/parametros/parametros_screen.dart` con su `disciplinaKey` (lowercase) y `disciplinaLabel`.
4. Los headers se leen de la plantilla; si agregas nuevas columnas, mapea los headers en `lib/services/excel_row_mapper.dart`.

## Nota importante
Como no hay Functions ni triggers, los cambios se reflejan solo cuando la app crea/edita productos y reportes.
Si se editan documentos directamente en Firestore fuera de la app, el visor no recalcula datos adicionales automáticamente.
