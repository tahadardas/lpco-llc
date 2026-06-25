import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:lpco_llc/core/utils/image_url_normalizer.dart';

class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
  });

  static String normalizeUrl(dynamic value) =>
      ImageUrlNormalizer.normalize(value);

  static ImageProvider imageProviderFor(String imageUrl) {
    final normalizedUrl = normalizeUrl(imageUrl);
    if (kIsWeb) {
      return NetworkImage(normalizedUrl);
    }
    return CachedNetworkImageProvider(normalizedUrl, cacheKey: normalizedUrl);
  }

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = normalizeUrl(imageUrl);
    if (normalizedUrl.isEmpty) {
      return _buildError();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheWidth = _cacheDimension(
          context,
          width ?? (constraints.hasBoundedWidth ? constraints.maxWidth : null),
        );
        final cacheHeight = _cacheDimension(
          context,
          height ??
              (constraints.hasBoundedHeight ? constraints.maxHeight : null),
        );

        if (kIsWeb) {
          return Image.network(
            normalizedUrl,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return _buildPlaceholder();
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildError();
            },
          );
        }

        return CachedNetworkImage(
          imageUrl: normalizedUrl,
          cacheKey: normalizedUrl,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          memCacheWidth: cacheWidth,
          memCacheHeight: cacheHeight,
          maxWidthDiskCache: cacheWidth,
          maxHeightDiskCache: cacheHeight,
          fadeInDuration: const Duration(milliseconds: 90),
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          useOldImageOnUrlChange: true,
          filterQuality: FilterQuality.medium,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildError(),
        );
      },
    );
  }

  int? _cacheDimension(BuildContext context, double? logicalSize) {
    if (logicalSize == null || logicalSize <= 0 || !logicalSize.isFinite) {
      return null;
    }
    final devicePixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
    return (logicalSize * devicePixelRatio).round().clamp(1, 2400);
  }

  Widget _buildPlaceholder() {
    return SizedBox(
      width: width,
      height: height,
      child: placeholder ?? const _AppImagePlaceholder(),
    );
  }

  Widget _buildError() {
    return SizedBox(
      width: width,
      height: height,
      child: errorWidget ?? const _AppImageError(),
    );
  }
}

class _AppImagePlaceholder extends StatelessWidget {
  const _AppImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFF8FAFC), Color(0xFFEFF4FA)],
        ),
      ),
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.image_outlined,
            size: 18,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

class _AppImageError extends StatelessWidget {
  const _AppImageError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF8FAFC),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 24,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
