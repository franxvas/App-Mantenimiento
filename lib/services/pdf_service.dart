import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appmantflutter/services/usuarios_cache_service.dart';
import 'package:flutter/services.dart';
import 'package:appmantflutter/services/categorias_service.dart';
import 'package:appmantflutter/services/file_save_service.dart';
import 'package:appmantflutter/shared/text_formatters.dart';

class PdfService {
  
  static Future<void> generarFichaTecnica({
    required Map<String, dynamic> producto,
    required String productId,
    required List<Map<String, dynamic>> ultimosReportes,
  }) async {
    
    final String? imageUrl = producto['imagenUrl'];
    Uint8List? imageBytes;
    
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
        }
      } catch (e) {
        print("ADVERTENCIA: Fallo al descargar imagen para PDF ($e).");
      }
    }

    final fonts = await _loadFonts();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.bold,
        italic: fonts.italic,
        boldItalic: fonts.boldItalic,
      ),
    );

    try {
      final disciplinaKey = producto['disciplina']?.toString().toLowerCase() ?? '';
      final bool isMobiliarios = disciplinaKey == 'mobiliarios';
      final categoriaLabel =
          await _resolveCategoriaLabel(disciplinaKey, producto['categoria']?.toString());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              _buildHeader(producto, productId, categoriaLabel),
              pw.SizedBox(height: 20),
              _buildPdfSection(
                "Resumen del Activo",
                _buildResumenActivo(producto, imageBytes, isMobiliarios, productId),
              ),
              if (isMobiliarios) ...[
                pw.SizedBox(height: 10),
                _buildPdfSection("Especificaciones (Mobiliario)", _buildMobiliarioSpecs(producto)),
              ],
              pw.SizedBox(height: 20),
              _buildPdfSection("Ubicación", _buildLocationInfo(producto)),
              pw.SizedBox(height: 10),
              _buildPdfSection("Historial de reportes (últimos 3)", _buildReportsTable(ultimosReportes)),
              pw.SizedBox(height: 30),
              _buildFooter(),
            ];
          },
        ),
      );

      final filename = 'FichaTecnica_$productId.pdf';
      await saveFileBytes(
        bytes: await pdf.save(),
        filename: filename,
        mimeType: 'application/pdf',
      );
      
    } catch (e) {
        print("ERROR GENERANDO FICHA TÉCNICA: $e");
    }
  }

  
  static Future<void> generarReporte({
    required Map<String, dynamic> reporte,
    required String reportId,
  }) async {
    await UsuariosCacheService.instance.preload();
    final fonts = await _loadFonts();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.bold,
        italic: fonts.italic,
        boldItalic: fonts.boldItalic,
      ),
    );
    
    final String nro = reporte['nro'] ?? '0000';
    final DateTime? fechaEmision = _resolveFechaEmision(reporte);
    final String fecha = fechaEmision == null ? '--/--/----' : formatDateTimeDMYHM(fechaEmision);
    final String nombreEquipo = reporte['activo_nombre'] ?? reporte['activoNombre'] ?? 'N/A';
    final String estadoNuevo =
        (reporte['estadoNuevo'] ?? reporte['estado_nuevo'] ?? reporte['estado'])
            ?.toString() ??
        'N/A';
    final Map<String, dynamic> ubicacion = reporte['ubicacion'] ?? {};
    final String responsable = UsuariosCacheService.instance.resolveResponsableName(reporte);
    final String? firmaUrl = UsuariosCacheService.instance.resolveResponsableFirmaUrl(reporte);
    final Uint8List? firmaBytes = await _loadNetworkImageBytes(firmaUrl);
    final String tipoReporte = reporte['tipoReporte'] ?? reporte['tipo_reporte'] ?? 'General';
    final String tipoReporteLabel = _formatTitleCase(tipoReporte);
    final String estadoFinalLabel = _formatTitleCase(estadoNuevo);
    final String estadoAnteriorLabel = _formatTitleCase(reporte['estadoAnterior']?.toString() ?? '');
    final String estadoDetectadoLabel = _formatTitleCase(reporte['estadoDetectado']?.toString() ?? '');
    final String estadoNuevoLabel = _formatTitleCase(
      reporte['estadoNuevo']?.toString() ??
          reporte['estado_nuevo']?.toString() ??
          reporte['estado']?.toString() ??
          '',
    );
    final String disciplinaLabel = _formatTitleCase(reporte['disciplina']?.toString() ?? '');
    final String condicionFisicaLabel = _formatTitleCase(reporte['condicionFisica']?.toString() ?? '');
    final String tipoMantenimientoLabel = _formatTitleCase(reporte['tipoMantenimiento']?.toString() ?? '');
    final String nivelCriticidadLabel = _formatTitleCase(reporte['nivelCriticidad']?.toString() ?? '');
    final String impactoFallaLabel = _formatTitleCase(reporte['impactoFalla']?.toString() ?? '');
    final String riesgoNormativoLabel = _formatTitleCase(reporte['riesgoNormativo']?.toString() ?? '');
    final String riesgoElectricoLabel = _formatTitleCase(reporte['riesgoElectrico']?.toString() ?? '');
    final String accionRecomendadaLabel = _formatTitleCase(reporte['accionRecomendada']?.toString() ?? '');
    final bool esReemplazo = _normalizeKey(tipoReporte) == 'reemplazo';
    final String requiereReemplazo = reporte['requiereReemplazo'] == null
        ? ''
        : (reporte['requiereReemplazo'] == true ? 'Sí' : 'No');
    final String costoEstimado = _formatNumber(reporte['costoEstimado'] ?? reporte['costo']);
    final String disciplinaKey = reporte['disciplina']?.toString().toLowerCase() ?? '';
    final String? categoriaLabel = await _resolveCategoriaLabel(disciplinaKey, reporte['categoria']?.toString());
    final List<String> fotosReporteUrls = (reporte['fotosReporte'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString().trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    final List<Uint8List> fotosReporteBytes = [];
    for (final url in fotosReporteUrls) {
      final bytes = await _loadNetworkImageBytes(url);
      if (bytes != null) {
        fotosReporteBytes.add(bytes);
      }
    }

    try {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              _buildPdfHeader("REPORTE TÉCNICO N° $nro"),
              pw.Divider(height: 20, thickness: 2, color: PdfColors.red800),
              
              _buildPdfSection(
                "Información General",
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow("Fecha y Hora de Emision:", fecha),
                    _infoRow("Responsable:", responsable),
                    _infoRow("Tipo de Reporte:", tipoReporteLabel),
                    _infoRow("Estado Final del Equipo:", estadoFinalLabel),
                  ],
                ),
              ),
              
              _buildPdfSection(
                "Datos del Equipo",
                _buildPills(
                  [
                    _PillData(label: 'Equipo', value: nombreEquipo),
                    _PillData(
                      label: 'Categoria',
                      value: _formatTitleCase(categoriaLabel ?? reporte['categoria']?.toString() ?? ''),
                    ),
                    _PillData(label: 'ID Sistema', value: reporte['productId']),
                  ],
                ),
              ),

              _buildPdfSection(
                "Ubicación del Equipo",
                _buildPills(
                  [
                    _PillData(label: 'Bloque', value: ubicacion['bloque']),
                    _PillData(label: 'Nivel', value: ubicacion['nivel'] ?? ubicacion['piso']),
                    _PillData(label: 'Area', value: ubicacion['area']),
                  ],
                ),
              ),

              _buildPdfSection(
                "Detalles del Reporte",
                _buildPills(
                  [
                    _PillData(label: 'Disciplina', value: disciplinaLabel),
                    _PillData(label: 'Estado detectado', value: estadoDetectadoLabel),
                    _PillData(label: 'Estado anterior', value: estadoAnteriorLabel),
                    _PillData(label: 'Estado nuevo', value: estadoNuevoLabel),
                    _PillData(label: 'Condición física', value: condicionFisicaLabel),
                    _PillData(label: 'Tipo mantenimiento', value: tipoMantenimientoLabel),
                    _PillData(label: 'Nivel criticidad', value: nivelCriticidadLabel),
                    _PillData(label: 'Impacto falla', value: impactoFallaLabel),
                    _PillData(label: 'Riesgo normativo', value: riesgoNormativoLabel),
                    _PillData(label: 'Riesgo eléctrico', value: riesgoElectricoLabel),
                    _PillData(label: 'Nivel desgaste', value: _formatTitleCase(reporte['nivelDesgaste']?.toString() ?? '')),
                    _PillData(label: 'Riesgo usuario', value: _formatTitleCase(reporte['riesgoUsuario']?.toString() ?? '')),
                    _PillData(label: 'Acción recomendada', value: accionRecomendadaLabel),
                    _PillData(label: 'Costo estimado', value: costoEstimado),
                    if (!esReemplazo) _PillData(label: 'Requiere reemplazo', value: requiereReemplazo),
                  ],
                ),
              ),

              _buildPdfSection(
                "Descripción del Problema / Motivo", 
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4)
                  ),
                  child: pw.Text(
                    reporte['descripcion'] ??
                        reporte['estadoDetectado'] ??
                        'Sin descripción detallada.',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                )
              ),
              
              _buildPdfSection(
                "Acciones Tomadas / Comentarios", 
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4)
                  ),
                  child: pw.Text(
                    reporte['comentarios'] ??
                        reporte['accionRecomendada'] ??
                        'No se registraron comentarios adicionales.',
                    style: const pw.TextStyle(fontSize: 11),
                  )
                )
              ),

              if (fotosReporteBytes.isNotEmpty)
                _buildPdfSection(
                  "Evidencia Fotográfica",
                  _buildReportPhotosGrid(fotosReporteBytes),
                ),
              
              pw.SizedBox(height: 40),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    children: [
                      if (firmaBytes != null)
                        pw.Container(
                          width: 150,
                          height: 60,
                          alignment: pw.Alignment.center,
                          child: pw.Image(pw.MemoryImage(firmaBytes), fit: pw.BoxFit.contain),
                        )
                      else
                        pw.SizedBox(height: 60),
                      pw.Container(width: 150, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 5),
                      pw.Text("Firma del Encargado", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(responsable, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ]
                  )
                ]
              ),
              
              pw.Spacer(),
              _buildFooter(),
            ];
          },
        ),
      );

      final filename = 'ReporteTecnico_$reportId.pdf';
      await saveFileBytes(
        bytes: await pdf.save(),
        filename: filename,
        mimeType: 'application/pdf',
      );
      
    } catch (e) {
      print("ERROR GENERANDO REPORTE PDF: $e");
    }
  }


  static pw.Widget _buildPdfHeader(String title) {
    return pw.Text(title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900));
  }

  static pw.Widget _buildPdfSection(String title, pw.Widget content) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.Divider(height: 5, thickness: 0.5, color: PdfColors.grey400),
          pw.SizedBox(height: 5),
          content,
        ],
      ),
    );
  }

  static Future<Uint8List?> _loadNetworkImageBytes(String? url) async {
    if (url == null || url.trim().isEmpty) {
      return null;
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print("ADVERTENCIA: Fallo al descargar firma para PDF ($e).");
    }
    return null;
  }

  static pw.Widget _buildPills(List<_PillData> items) {
    final visible = items
        .where((item) => item.value != null && item.value!.toString().trim().isNotEmpty)
        .toList();
    if (visible.isEmpty) {
      return pw.Text("Sin detalles adicionales.", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600));
    }
    return pw.Wrap(
      spacing: 6,
      runSpacing: 6,
      children: visible.map(_buildPill).toList(),
    );
  }

  static pw.Widget _buildPill(_PillData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey800),
          children: [
            pw.TextSpan(text: '${data.label}: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: data.value.toString()),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildHeader(Map<String, dynamic> data, String id, String? categoriaLabel) {
    final idActivo = id;
    final disciplina = _formatTitleCase(data['disciplina']?.toString() ?? '');
    final categoria = _formatTitleCase(categoriaLabel ?? data['categoria']?.toString() ?? '');
    final subcategoria = _formatTitleCase(data['subcategoria']?.toString() ?? '');
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "FICHA TECNICA DE EQUIPO",
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
              ),
              pw.Text("ID Sistema: $id", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              pw.SizedBox(height: 6),
              pw.Text("ID Activo: $idActivo", style: const pw.TextStyle(fontSize: 10)),
              if (disciplina.isNotEmpty) pw.Text("Disciplina: $disciplina", style: const pw.TextStyle(fontSize: 10)),
              if (categoria.isNotEmpty) pw.Text("Categoria: $categoria", style: const pw.TextStyle(fontSize: 10)),
              if (subcategoria.isNotEmpty) pw.Text("Subcategoria: $subcategoria", style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue900), borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Text(
            _formatTitleCase((data['estado'] ?? 'N/A')?.toString() ?? 'N/A'),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildResumenActivo(
    Map<String, dynamic> data,
    Uint8List? imageBytes,
    bool isMobiliarios,
    String id,
  ) {
    final List<pw.Widget> leftColumn = [];
    void addInfo(String label, dynamic value, {bool formatTitle = false}) {
      final text = value?.toString() ?? '';
      if (text.trim().isEmpty) {
        return;
      }
      leftColumn.add(_infoRow(label, formatTitle ? _formatTitleCase(text) : text));
    }

    addInfo("Equipo:", data['nombre'] ?? data['nombreProducto']);
    addInfo("Marca:", data['marca']);
    addInfo("Serie:", data['serie']);
    addInfo("Codigo QR:", id);
    addInfo("Proveedor:", data['proveedor']);
    addInfo("Fabricante:", data['fabricante']);
    if (isMobiliarios) {
      addInfo("Condicion fisica:", data['condicionFisica'], formatTitle: true);
      addInfo("Criticidad:", data['nivelCriticidad'], formatTitle: true);
    }

    final descripcion = data['descripcion']?.toString().trim() ?? '';
    if (descripcion.isNotEmpty) {
      leftColumn.add(pw.SizedBox(height: 6));
      leftColumn.add(pw.Text("Descripcion:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
      leftColumn.add(pw.Text(descripcion, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)));
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: leftColumn,
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Container(
          width: 140,
          height: 140,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            color: imageBytes == null ? PdfColors.grey200 : null,
          ),
          child: imageBytes != null
              ? pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.contain)
              : pw.Center(child: pw.Text("Sin imagen")),
        ),
      ],
    );
  }

  static pw.Widget _buildLocationInfo(Map<String, dynamic> data) {
      final ubicacion = data['ubicacion'] ?? {};
      return _buildPills(
        [
          _PillData(label: 'Bloque', value: ubicacion['bloque']),
          _PillData(label: 'Nivel', value: ubicacion['nivel'] ?? ubicacion['piso']),
          _PillData(label: 'Area', value: ubicacion['area']),
        ],
      );
  }

  static pw.Widget _buildMobiliarioSpecs(Map<String, dynamic> data) {
    return _buildPills(
      [
        _PillData(label: 'Tipo mobiliario', value: data['tipoMobiliario']),
        _PillData(label: 'Material principal', value: data['materialPrincipal']),
        _PillData(label: 'Modelo', value: data['modelo']),
        _PillData(label: 'Fecha adquisicion', value: _formatDate(data['fechaAdquisicion'])),
        _PillData(label: 'Vida util (anios)', value: _formatNumber(data['vidaUtilEsperadaAnios'])),
        _PillData(label: 'Costo reemplazo', value: _formatNumber(data['costoReemplazo'])),
        _PillData(label: 'Movilidad', value: _formatTitleCase(data['movilidad']?.toString() ?? '')),
      ],
    );
  }

  static pw.Widget _buildNotasObservaciones(Map<String, dynamic> data) {
    final notas = data['observaciones'] ?? data['notas'] ?? data['descripcion'] ?? '';
    if (notas.toString().trim().isEmpty) {
      return pw.Text("Sin observaciones registradas.", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600));
    }
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(notas.toString(), style: const pw.TextStyle(fontSize: 11)),
    );
  }

  static pw.Widget _buildReportsTable(List<Map<String, dynamic>> reportes) {
      if (reportes.isEmpty) {
          return pw.Padding(
              padding: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                  "No hay reportes registrados.", 
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey) 
              ),
          );
      }

      final sorted = List<Map<String, dynamic>>.from(reportes)
        ..sort((a, b) => _resolveDate(b['fechaInspeccion'] ?? b['fecha'])
            .compareTo(_resolveDate(a['fechaInspeccion'] ?? a['fecha'])));
      final latest = sorted.take(3).toList();

      return pw.Column(
        children: latest.map((reporte) {
          final tipoReporte = reporte['tipoReporte'] ?? reporte['tipo_reporte'] ?? 'General';
          final estadoAnterior = reporte['estadoAnterior'] ?? 'N/A';
          final estadoOperativo = reporte['estadoNuevo'] ?? reporte['estado_nuevo'] ?? 'N/A';
          final tipoMantenimiento = reporte['tipoMantenimiento'];
          final fechaRaw = reporte['fechaInspeccion'] ?? reporte['fecha'];
          final fecha = _formatDateTime(fechaRaw);
          final requiereReemplazo = reporte['requiereReemplazo'];
          final isReemplazo = _normalizeKey(tipoReporte) == 'reemplazo';
          final showRequiere = !isReemplazo &&
              (_normalizeKey(tipoReporte) == 'mantenimiento' ||
                  _normalizeKey(tipoReporte) == 'inspeccion' ||
                  _normalizeKey(tipoReporte) == 'incidente falla' ||
                  _normalizeKey(tipoReporte) == 'incidente_falla');

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow("Tipo de reporte:", _formatTitleCase(tipoReporte.toString())),
                _infoRow("Estado anterior:", _formatTitleCase(estadoAnterior.toString())),
                _infoRow("Estado nuevo:", _formatTitleCase(estadoOperativo.toString())),
                if (_normalizeKey(tipoReporte) == 'mantenimiento' && tipoMantenimiento != null)
                  _infoRow("Tipo de mantenimiento:", _formatTitleCase(tipoMantenimiento.toString())),
                _infoRow("Fecha:", fecha),
                if (showRequiere)
                  _infoRow(
                    "Requiere reemplazo:",
                    (requiereReemplazo == true) ? 'Sí' : 'No',
                  ),
              ],
            ),
          );
        }).toList(),
      );
    }

  static DateTime _resolveDate(dynamic value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    try {
      final Timestamp valueTs = value as Timestamp;
      return valueTs.toDate();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  static DateTime? _resolveFechaEmision(Map<String, dynamic> reporte) {
    final value = reporte['createdAt'] ?? reporte['fechaEmision'] ?? reporte['fechaInspeccion'] ?? reporte['fecha'];
    final date = _resolveDate(value);
    if (date.year <= 1970) {
      return null;
    }
    return date;
  }

  static String _formatDate(dynamic value) {
    final date = _resolveDate(value);
    if (date.year <= 1970) {
      return '--/--/----';
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String _formatDateTime(dynamic value) {
    final date = _resolveDate(value);
    if (date.year <= 1970) {
      return '--/--/----';
    }
    return formatDateTimeDMYHM(date);
  }

  static String _formatNumber(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is num) {
      if (value % 1 == 0) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    final text = value.toString();
    return text.replaceAll(RegExp(r'\.0$'), '');
  }

  static String _formatTitleCase(String value) {
    if (value.contains('@') || value.contains('/')) {
      return value;
    }
    final normalized = value.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) {
      return value;
    }
    return normalized
        .split(' ')
        .map((word) {
          if (word.isEmpty) {
            return word;
          }
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  static String _normalizeKey(dynamic value) {
    return value.toString().toLowerCase().replaceAll('_', ' ').trim();
  }

  static pw.Widget _infoRow(String label, String? value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4), 
        child: pw.Row(
          children: [
            pw.Text("$label ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), 
            pw.Text(value ?? 'N/A'), 
          ],
        ),
      );
  }

  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text("Generado por AppMant", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            pw.Text("Fecha de impresión: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ],
        )
      ],
    );
  }

  static pw.Widget _buildReportPhotosGrid(List<Uint8List> images) {
    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: images
          .map(
            (bytes) => pw.Container(
              width: 240,
              height: 150,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.Image(
                  pw.MemoryImage(bytes),
                  fit: pw.BoxFit.cover,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  static Future<_PdfFonts> _loadFonts() async {
    if (_cachedFonts != null) {
      return _cachedFonts!;
    }
    final data = await rootBundle.load('assets/fonts/ArialUnicode.ttf');
    final font = pw.Font.ttf(data);
    _cachedFonts = _PdfFonts(
      regular: font,
      bold: font,
      italic: font,
      boldItalic: font,
    );
    return _cachedFonts!;
  }

  static Future<String?> _resolveCategoriaLabel(String disciplinaKey, String? categoriaValue) async {
    if (disciplinaKey.isEmpty || categoriaValue == null || categoriaValue.trim().isEmpty) {
      return null;
    }
    await CategoriasService.instance.fetchByDisciplina(disciplinaKey);
    return CategoriasService.instance.resolveLabel(disciplinaKey, categoriaValue);
  }
}

class _PillData {
  final String label;
  final dynamic value;

  const _PillData({required this.label, required this.value});
}

class _PdfFonts {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;
  final pw.Font boldItalic;

  const _PdfFonts({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
  });
}

_PdfFonts? _cachedFonts;
