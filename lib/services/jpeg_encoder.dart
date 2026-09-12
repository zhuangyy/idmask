import 'package:flutter/services.dart';

/// PNG 字节 → JPEG 字节。
///
/// Flutter 内置的 `Image.toByteData` 只支持 PNG 编码，没有 JPEG，
/// 所以把这一步交给原生做。绘制逻辑仍在 Flutter 里，只写一遍。
class JpegEncoder {
  const JpegEncoder._();

  static const String channelName = 'com.xzgg.idwm/jpeg';
  static const int defaultQuality = 92;

  static const MethodChannel _channel = MethodChannel(channelName);

  /// 返回 null 表示这条路走不通（例如平台未实现），调用方应回退保存 PNG。
  static Future<Uint8List?> encode(
    Uint8List pngBytes, {
    int quality = defaultQuality,
  }) async {
    try {
      return await _channel.invokeMethod<Uint8List>(
        'encodeJpeg',
        <String, dynamic>{'png': pngBytes, 'quality': quality},
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
