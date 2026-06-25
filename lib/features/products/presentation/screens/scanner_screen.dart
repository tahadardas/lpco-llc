import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/navigation/app_back_scope.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/data/repositories/product_repository.dart';
import 'package:lpco_llc/features/products/presentation/cubit/product_cubit.dart';

class ScannerScreen extends StatefulWidget {
  final bool returnScannedCode;

  const ScannerScreen({super.key, this.returnScannedCode = false});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    autoStart: true,
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 800,
    facing: CameraFacing.back,
    torchEnabled: false,
    autoZoom: false,
    formats: const <BarcodeFormat>[
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.itf14,
    ],
  );
  final ProductRepository _productRepository = ProductRepository();

  bool _isProcessing = false;
  PermissionStatus _permissionStatus = PermissionStatus.provisional;
  bool _isCheckingPermission = true;
  DateTime? _lastAcceptedAt;
  String? _lastAcceptedCode;
  Timer? _steadyHintTimer;
  bool _showSteadyHint = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() {
        _permissionStatus = status;
        _isCheckingPermission = false;
      });
      _startSteadyHintTimer();
      return;
    }

    setState(() => _isCheckingPermission = false);
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _permissionStatus = status);
    if (status.isGranted) {
      _startSteadyHintTimer();
    }
  }

  @override
  void dispose() {
    _steadyHintTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _startSteadyHintTimer() {
    _steadyHintTimer?.cancel();
    _steadyHintTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _isProcessing) return;
      setState(() => _showSteadyHint = true);
    });
  }

  void _onDetect(BarcodeCapture capture, Rect scanWindow, Size previewSize) {
    if (_isProcessing) return;

    _logScanCapture(capture);

    final barcode = _selectBarcode(
      capture,
      scanWindow,
      previewSize,
    )?.rawValue?.trim();
    if (barcode == null || barcode.isEmpty) return;

    final now = DateTime.now();
    if (_lastAcceptedAt != null &&
        now.difference(_lastAcceptedAt!) < const Duration(milliseconds: 1200)) {
      _logScanRejected('debounce active for value=$barcode');
      return;
    }

    if (_lastAcceptedCode == barcode) {
      _logScanRejected('duplicate consecutive value=$barcode');
      return;
    }

    _lastAcceptedAt = now;
    _lastAcceptedCode = barcode;
    _steadyHintTimer?.cancel();
    if (_showSteadyHint) {
      setState(() => _showSteadyHint = false);
    }
    _logScanSelected(barcode);
    _handleCode(barcode);
  }

  Future<void> _handleCode(String code) async {
    if (_isProcessing) return;

    final products = widget.returnScannedCode
        ? const <ProductModel>[]
        : context.read<ProductCubit>().state.products;

    setState(() => _isProcessing = true);
    await controller.stop();
    if (!mounted) return;

    final normalized = code.trim().toLowerCase();
    if (widget.returnScannedCode) {
      Navigator.of(context).pop(code.trim());
      return;
    }

    ProductModel? matched = await _productRepository.getProductByBarcodeExact(
      code,
      guest: true,
    );
    matched ??= _findLocalExactBarcodeMatch(products, normalized);

    if (!mounted) return;

    if (matched != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم العثور على المنتج')));
      context.replace(AppRoutePaths.productUrl(matched.id), extra: matched);
      return;
    }

    _lastAcceptedCode = null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('لم يتم العثور على منتج مطابق: $code')),
    );

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() => _isProcessing = false);
    await controller.start();
    _startSteadyHintTimer();
  }

  Barcode? _selectBarcode(
    BarcodeCapture capture,
    Rect scanWindow,
    Size previewSize,
  ) {
    final candidates = capture.barcodes
        .where((barcode) => (barcode.rawValue ?? '').trim().isNotEmpty)
        .toList(growable: false);
    if (candidates.isEmpty) return null;

    if (candidates.length == 1) {
      final barcode = candidates.first;
      final center = _reliableBarcodeCenter(barcode, previewSize);
      if (center == null) {
        return barcode;
      }
      if (_isNearScanWindow(center, scanWindow)) {
        return barcode;
      }
      _logScanRejected(
        'single candidate outside scan window: ${barcode.rawValue}',
      );
      return null;
    }

    final scanCenter = scanWindow.center;
    Barcode? best;
    double? bestDistance;
    for (final barcode in candidates) {
      final center = _reliableBarcodeCenter(barcode, previewSize);
      if (center == null || !_isNearScanWindow(center, scanWindow)) continue;
      final dx = center.dx - scanCenter.dx;
      final dy = center.dy - scanCenter.dy;
      final distance = dx * dx + dy * dy;
      if (bestDistance == null || distance < bestDistance) {
        best = barcode;
        bestDistance = distance;
      }
    }
    if (best != null) {
      return best;
    }

    final fallback = candidates.first;
    _logScanRejected(
      'no screen-compatible corners; accepting scanWindow-filtered value=${fallback.rawValue}',
    );
    return fallback;
  }

  bool _isNearScanWindow(Offset point, Rect scanWindow) {
    final relaxed = scanWindow.inflate(24);
    return relaxed.contains(point);
  }

  Offset? _reliableBarcodeCenter(Barcode barcode, Size previewSize) {
    final corners = barcode.corners;
    if (corners.isEmpty) return null;
    if (previewSize.width <= 0 || previewSize.height <= 0) return null;

    var x = 0.0;
    var y = 0.0;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final corner in corners) {
      if (!corner.dx.isFinite || !corner.dy.isFinite) return null;
      x += corner.dx;
      y += corner.dy;
      minX = math.min(minX, corner.dx);
      minY = math.min(minY, corner.dy);
      maxX = math.max(maxX, corner.dx);
      maxY = math.max(maxY, corner.dy);
    }

    final center = Offset(x / corners.length, y / corners.length);
    final relaxedPreview = Rect.fromLTWH(
      0,
      0,
      previewSize.width,
      previewSize.height,
    ).inflate(math.max(previewSize.width, previewSize.height) * 0.15);
    final boundsWidth = maxX - minX;
    final boundsHeight = maxY - minY;
    if (!relaxedPreview.contains(center) ||
        boundsWidth > previewSize.width * 1.3 ||
        boundsHeight > previewSize.height * 1.3) {
      return null;
    }
    return center;
  }

  void _logScanCapture(BarcodeCapture capture) {
    if (!kDebugMode) return;
    debugPrint('[BARCODE_SCAN] detected count=${capture.barcodes.length}');
    debugPrint(
      '[BARCODE_SCAN] raw values=${capture.barcodes.map((b) => b.rawValue).toList()}',
    );
    debugPrint(
      '[BARCODE_SCAN] corners=${capture.barcodes.map((b) => b.corners).toList()}',
    );
  }

  void _logScanSelected(String value) {
    if (!kDebugMode) return;
    debugPrint('[BARCODE_SCAN] selected value=$value');
  }

  void _logScanRejected(String reason) {
    if (!kDebugMode) return;
    debugPrint('[BARCODE_SCAN] rejected reason=$reason');
  }

  ProductModel? _findLocalExactBarcodeMatch(
    List<ProductModel> products,
    String normalized,
  ) {
    final scanned = _barcodeMatchCandidates(normalized);
    if (scanned.isEmpty) return null;

    for (final product in products) {
      if (_barcodeMatchCandidates(
        product.sku,
      ).intersection(scanned).isNotEmpty) {
        return product;
      }

      final hasBarcodeField =
          <String>[
            product.barcode1,
            product.barcode2,
            product.barcode3,
            product.barcode4,
            ...product.barcodes,
          ].any(
            (value) =>
                _barcodeMatchCandidates(value).intersection(scanned).isNotEmpty,
          );
      if (hasBarcodeField) return product;

      final hasBarcodeMeta = product.metaData.any((item) {
        final key = item.key.toLowerCase();
        final value = (item.value ?? '').toString().trim().toLowerCase();
        return <String>{
              'barcode',
              'bar_code',
              '_barcode',
              '_barcode_1',
              '_barcode_2',
              '_barcode_3',
              '_barcode_4',
              'ean',
              'upc',
              'dms_barcode',
              '_dms_barcode',
              'product_barcode',
            }.contains(key) &&
            _barcodeMatchCandidates(value).intersection(scanned).isNotEmpty;
      });
      if (hasBarcodeMeta) return product;
    }
    return null;
  }

  Set<String> _barcodeMatchCandidates(String value) {
    final canonical = value.trim().toLowerCase();
    if (canonical.isEmpty) return <String>{};

    final compact = canonical.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final candidates = <String>{canonical};
    if (compact.isNotEmpty) {
      candidates.add(compact);
      if (compact.length == 13 && compact.startsWith('0')) {
        candidates.add(compact.substring(1));
      } else if (compact.length == 12) {
        candidates.add('0$compact');
      }
    }
    return candidates;
  }

  void _showManualInputDialog() {
    final controllerInput = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('بحث يدوي'),
          content: TextField(
            controller: controllerInput,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'أدخل الباركود أو SKU',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final value = controllerInput.text.trim();
                Navigator.pop(context);
                if (value.isNotEmpty) {
                  if (widget.returnScannedCode) {
                    Navigator.of(context).pop(value);
                  } else {
                    _handleCode(value);
                  }
                }
              },
              child: const Text('بحث'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackScope(
      fallbackLocation: AppRoutePaths.home,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مسح الباركود'),
          actions: _permissionStatus.isGranted
              ? [
                  IconButton(
                    tooltip: 'تشغيل الفلاش',
                    icon: const Icon(Icons.flash_on),
                    onPressed: controller.toggleTorch,
                  ),
                  IconButton(
                    tooltip: 'إعادة ضبط التقريب',
                    icon: const Icon(Icons.zoom_out_map_rounded),
                    onPressed: controller.resetZoomScale,
                  ),
                  IconButton(
                    tooltip: 'تبديل الكاميرا',
                    icon: const Icon(Icons.cameraswitch),
                    onPressed: controller.switchCamera,
                  ),
                ]
              : null,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isCheckingPermission) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_permissionStatus.isGranted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              const Text(
                'نحتاج إذن الكاميرا فقط لمسح باركود المنتج. يمكنك البحث يدوياً إذا لم ترغب بمنح الإذن.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'يستخدم التطبيق الكاميرا فقط للبحث عن المنتج بسرعة. لا يتم تصوير أو تخزين أو إرسال صور من الكاميرا.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('رجوع'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _showManualInputDialog,
                    icon: const Icon(Icons.search),
                    label: const Text('بحث يدوي'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _requestPermission,
                child: const Text('منح إذن الكاميرا'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final scanWidth = math.min(320.0, size.width - 40);
        final scanHeight = math.min(170.0, math.max(140.0, size.height * 0.22));
        final scanWindow = Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: scanWidth,
          height: scanHeight,
        );

        return Stack(
          children: [
            MobileScanner(
              controller: controller,
              scanWindow: scanWindow,
              scanWindowUpdateThreshold: 8,
              onDetect: (capture) => _onDetect(capture, scanWindow, size),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _ScannerOverlayPainter(
                  scanWindow: scanWindow,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Column(
                children: [
                  const Text(
                    'ضع الباركود داخل الإطار',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                  if (_showSteadyHint) ...const <Widget>[
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'قرّب الكاميرا قليلاً وثبّت الباركود داخل الإطار',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: _showManualInputDialog,
                    icon: const Icon(Icons.edit),
                    label: const Text('إدخال يدوي'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final Color color;

  const _ScannerOverlayPainter({required this.scanWindow, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.58);
    final fullPath = Path()..addRect(Offset.zero & size);
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanWindow, const Radius.circular(18)),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, fullPath, cutoutPath),
      overlayPaint,
    );

    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanWindow, const Radius.circular(18)),
      borderPaint,
    );

    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(scanWindow.left + 18, scanWindow.center.dy),
      Offset(scanWindow.right - 18, scanWindow.center.dy),
      guidePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow || oldDelegate.color != color;
  }
}
