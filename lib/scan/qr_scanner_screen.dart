import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appmantflutter/productos/detalle_producto_screen.dart';
import 'package:appmantflutter/reportes/generar_reporte_screen.dart';


class QRScannerScreen extends StatefulWidget {
  final bool goToReport;
  final ValueChanged<String>? onProductFound;

  const QRScannerScreen({super.key, this.goToReport = false, this.onProductFound});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  // Controlador para manejar la cámara (flash, switch camera, etc.)
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates, 
  );
  
  bool _isProcessing = false; // Para evitar múltiples navegaciones simultáneas

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // --- LÓGICA DE BÚSQUEDA EN FIREBASE ---
  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return; 

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() => _isProcessing = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Buscando producto: $code...'), duration: const Duration(seconds: 1)),
    );

    try {
      // 1. Buscar en Firestore el producto con ese 'codigoQR'
      final querySnapshot = await FirebaseFirestore.instance
          .collection('productos')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data() ?? {},
            toFirestore: (data, _) => data,
          )
          .where('codigoQR', isEqualTo: code) // Filtra por el campo codigoQR
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // 2. ¡ENCONTRADO! Obtener el ID del documento
        final doc = querySnapshot.docs.first;
        final String productId = doc.id;
        final data = doc.data();

        if (mounted) {
          if (widget.onProductFound != null) {
            widget.onProductFound!(productId);
            Navigator.pop(context);
            return;
          }
          if (widget.goToReport) {
            final nombre = data['nombre'] ?? 'Sin nombre';
            final categoria = data['categoria'] ?? 'N/A';
            final estado = data['estado'] ?? 'operativo';
            final ubicacion = data['ubicacion'] ?? <String, dynamic>{};
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => GenerarReporteScreen(
                  productId: productId,
                  productName: nombre,
                  productCategory: categoria,
                  initialStatus: estado,
                  productLocation: ubicacion,
                ),
              ),
            );
          } else {
            // Navegar al detalle (usamos pushReplacement para cerrar la cámara)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DetalleProductoScreen(productId: productId),
              ),
            );
          }
        }
      } else {
        // 3. NO ENCONTRADO
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Producto no encontrado en la base de datos.'),
              backgroundColor: Colors.red,
            ),
          );
          // Pausamos un momento y permitimos escanear de nuevo
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            setState(() => _isProcessing = false);
          }
        }
      }
    } catch (e) {
      print("Error al buscar QR: $e");
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Equipo'),
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
        actions: [
          // Botón para el Flash (Corregido para la API moderna)
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>( // Escuchamos el estado completo
              valueListenable: controller,
              builder: (context, state, child) {
                // Accedemos al estado de la linterna desde el objeto 'state'
                return Icon(state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off, color: Colors.white);
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. CÁMARA
          MobileScanner(
            controller: controller,
            onDetect: _handleBarcode,
          ),
          
          // 2. OVERLAY (Marco visual para guiar al usuario)
          _buildOverlay(),
          
          // 3. TEXTO INFORMATIVO
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Apunta el código QR dentro del cuadro",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Diseño del cuadro semitransparente (Se mantiene igual)
  Widget _buildOverlay() {
    return Container(
      decoration: ShapeDecoration(
        shape: QrScannerOverlayShape(
          borderColor: Theme.of(context).colorScheme.primary,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 300, // Tamaño del cuadro de escaneo
        ),
      ),
    );
  }
}

// Clase auxiliar para dibujar el hueco en la pantalla (Overlay) - Se mantiene igual
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..addRect(
        Rect.fromCenter(
          center: rect.center,
          width: cutOutSize,
          height: cutOutSize,
        ),
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()
          ..addRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius))),
      ),
      backgroundPaint,
    );

    // Dibujar esquinas
    final path = Path();
    
    // Top left
    path.moveTo(cutOutRect.left, cutOutRect.top + borderLength);
    path.lineTo(cutOutRect.left, cutOutRect.top);
    path.lineTo(cutOutRect.left + borderLength, cutOutRect.top);

    // Top right
    path.moveTo(cutOutRect.right, cutOutRect.top + borderLength);
    path.lineTo(cutOutRect.right, cutOutRect.top);
    path.lineTo(cutOutRect.right - borderLength, cutOutRect.top);

    // Bottom left
    path.moveTo(cutOutRect.left, cutOutRect.bottom - borderLength);
    path.lineTo(cutOutRect.left, cutOutRect.bottom);
    path.lineTo(cutOutRect.left + borderLength, cutOutRect.bottom);

    // Bottom right
    path.moveTo(cutOutRect.right, cutOutRect.bottom - borderLength);
    path.lineTo(cutOutRect.right, cutOutRect.bottom);
    path.lineTo(cutOutRect.right - borderLength, cutOutRect.bottom);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
