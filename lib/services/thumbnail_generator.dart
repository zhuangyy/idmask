import 'dart:io';
import 'dart:ui' as ui;

/// 用 dart:ui 把源图等比缩到指定长边，写成 PNG。
///
/// 缩略图只用于列表展示，所以不追求画质，只求快与小。
class DartUiThumbnailGenerator {
  const DartUiThumbnailGenerator._();

  static Future<void> generate(
    String sourcePath,
    String destPath,
    int maxSide,
  ) async {
    final bytes = await File(sourcePath).readAsBytes();

    // 先探测原尺寸，再决定解码目标尺寸，避免为原尺寸分配位图。
    final probe = await ui.instantiateImageCodec(bytes);
    final frame = await probe.getNextFrame();
    final sourceWidth = frame.image.width;
    final sourceHeight = frame.image.height;
    frame.image.dispose();
    probe.dispose();

    if (sourceWidth <= 0 || sourceHeight <= 0) return;

    final longSide = sourceWidth > sourceHeight ? sourceWidth : sourceHeight;
    final scale = maxSide / longSide;
    final targetWidth = (sourceWidth * scale).round().clamp(1, maxSide);
    final targetHeight = (sourceHeight * scale).round().clamp(1, maxSide);

    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final scaled = (await codec.getNextFrame()).image;
    codec.dispose();

    final data = await scaled.toByteData(format: ui.ImageByteFormat.png);
    scaled.dispose();
    if (data == null) return;

    final file = File(destPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data.buffer.asUint8List());
  }
}
