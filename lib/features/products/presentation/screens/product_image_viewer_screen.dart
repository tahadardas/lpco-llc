import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:lpco_llc/core/services/image_gallery_service.dart';
import 'package:lpco_llc/core/widgets/app_network_image.dart';

class ProductImageViewerScreen extends StatefulWidget {
  const ProductImageViewerScreen({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    required this.productName,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String productName;

  @override
  State<ProductImageViewerScreen> createState() =>
      _ProductImageViewerScreenState();
}

class _ProductImageViewerScreenState extends State<ProductImageViewerScreen> {
  late final PageController _pageController;
  final ImageGalleryService _galleryService = ImageGalleryService();
  late int _currentIndex;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.imageUrls.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentImage() async {
    if (_saving || widget.imageUrls.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _galleryService.saveRemoteImage(widget.imageUrls[_currentIndex]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u062a\u0645 \u062d\u0641\u0638 \u0627\u0644\u0635\u0648\u0631\u0629 \u0641\u064a \u0627\u0644\u0645\u0639\u0631\u0636',
          ),
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      final message = e.code == 'unsupported_android'
          ? 'حفظ الصور غير متاح حالياً على إصدارات أندرويد القديمة'
          : 'تعذر حفظ الصورة، تحقق من الصلاحيات';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر حفظ الصورة، تحقق من الصلاحيات',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          actions: <Widget>[
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              tooltip: '\u0625\u063a\u0644\u0627\u0642',
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        body: const Center(
          child: Text(
            '\u0644\u0627 \u062a\u0648\u062c\u062f \u0635\u0648\u0631 \u0645\u062a\u0627\u062d\u0629',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.productName, maxLines: 1),
        actions: <Widget>[
          IconButton(
            onPressed: _saving ? null : _saveCurrentImage,
            tooltip: '\u062d\u0641\u0638 \u0627\u0644\u0635\u0648\u0631\u0629',
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '\u0625\u063a\u0644\u0627\u0642',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: AppNetworkImage(
                  imageUrl: widget.imageUrls[index],
                  fit: BoxFit.contain,
                  errorWidget: const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
