import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class ImageGalleryService {
  ImageGalleryService({Dio? dio}) : _dio = dio ?? Dio();

  static const MethodChannel _channel = MethodChannel('lpco/image_gallery');
  final Dio _dio;

  Future<void> saveRemoteImage(String imageUrl) async {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || uri.scheme != 'https') {
      throw const FormatException('Invalid image URL');
    }

    final response = await _dio.get<List<int>>(
      imageUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Empty image response');
    }

    final contentType = response.headers.value(Headers.contentTypeHeader);
    final extension = _extensionFor(contentType, uri.path);
    final fileName = 'LPCO_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _channel.invokeMethod<void>('saveImage', <String, Object>{
      'bytes': Uint8List.fromList(bytes),
      'fileName': fileName,
      'mimeType': contentType?.split(';').first.trim() ?? 'image/jpeg',
    });
  }

  String _extensionFor(String? contentType, String path) {
    final mime = contentType?.toLowerCase() ?? '';
    if (mime.contains('png')) return 'png';
    if (mime.contains('webp')) return 'webp';
    final pathExtension = path.split('.').last.toLowerCase();
    if (<String>{'jpg', 'jpeg', 'png', 'webp'}.contains(pathExtension)) {
      return pathExtension;
    }
    return 'jpg';
  }
}
