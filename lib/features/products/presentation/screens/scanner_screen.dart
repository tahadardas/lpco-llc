import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:lpco_llc/app/router/app_routes.dart';
import 'package:lpco_llc/core/navigation/app_back_scope.dart';
import 'package:lpco_llc/features/products/data/models/product_model.dart';
import 'package:lpco_llc/features/products/presentation/cubit/product_cubit.dart';

class ScannerScreen extends StatefulWidget {
  final bool returnScannedCode;

  const ScannerScreen({super.key, this.returnScannedCode = false});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcode = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (barcode == null || barcode.isEmpty) return;
    _handleCode(barcode);
  }

  void _handleCode(String code) async {
    if (_isProcessing) return;

    final products = widget.returnScannedCode
        ? const <ProductModel>[]
        : context.read<ProductCubit>().state.products;

    setState(() => _isProcessing = true);
    await controller.stop();
    if (!mounted) return;

    if (widget.returnScannedCode) {
      Navigator.of(context).pop(code.trim());
      return;
    }

    final normalized = code.trim().toLowerCase();
    ProductModel? matched;

    for (final p in products) {
      if (p.sku.toLowerCase() == normalized) {
        matched = p;
        break;
      }

      final hasBarcodeMeta = p.metaData.any((item) {
        final key = item.key.toLowerCase();
        final value = (item.value ?? '').toString().toLowerCase();
        return [
              'barcode',
              'bar_code',
              '_barcode',
              'ean',
              'upc',
            ].contains(key) &&
            value == normalized;
      });

      if (hasBarcodeMeta) {
        matched = p;
        break;
      }
    }

    if (!mounted) return;

    if (matched != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم العثور على المنتج')));
      context.replace(AppRoutePaths.productUrl(matched.id), extra: matched);
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('لم يتم العثور على منتج: $code')));

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() => _isProcessing = false);
    await controller.start();
  }

  void _showManualInputDialog() {
    final controllerInput = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('إدخال يدوي'),
          content: TextField(
            controller: controllerInput,
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
          actions: [
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: controller.toggleTorch,
            ),
            IconButton(
              icon: const Icon(Icons.cameraswitch),
              onPressed: controller.switchCamera,
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(controller: controller, onDetect: _onDetect),
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 4,
                  ),
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
                    'قم بتوجيه الكاميرا نحو الباركود',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
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
        ),
      ),
    );
  }
}
