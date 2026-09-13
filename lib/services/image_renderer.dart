import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/watermark_style.dart';
import 'jpeg_encoder.dart';
import 'text_painter_measurer.dart';
import 'watermark_layout.dart';
import 'watermark_painter.dart';

/// 渲染结果。后两个标志用于给用户提示。
class RenderResult {
  final File file;
  final bool wasDownscaled;
  final bool usedPngFallback;

  const RenderResult({
    required this.file,
    required this.wasDownscaled,
    required this.usedPngFallback,
  });
}

/// 解码 → 绘制 → 编码 → 写临时文件。
class ImageRenderer {
  const ImageRenderer._();

  /// 长边上限。超过就在解码阶段等比缩小，避免为原尺寸分配位图。
  static const int maxDimension = 4096;

  static Future<RenderResult> render({
    required String sourcePath,
    required String text,
    required WatermarkStyle style,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();

    // 先探测原尺寸，再决定解码目标尺寸。
    final probe = await ui.instantiateImageCodec(bytes);
    final probeFrame = await probe.getNextFrame();
    final sourceWidth = probeFrame.image.width;
    final sourceHeight = probeFrame.image.height;
    probeFrame.image.dispose();
    probe.dispose();

    if (sourceWidth <= 0 || sourceHeight <= 0) {
      throw const FormatException('无法读取这张图片，请换一张');
    }

    final longSide = sourceWidth > sourceHeight ? sourceWidth : sourceHeight;
    final wasDownscaled = longSide > maxDimension;
    final scale = wasDownscaled ? maxDimension / longSide : 1.0;

    final targetWidth = (sourceWidth * scale).round().clamp(1, maxDimension);
    final targetHeight = (sourceHeight * scale).round().clamp(1, maxDimension);

    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();

    final size = Size(targetWidth.toDouble(), targetHeight.toDouble());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint(),
    );

    // 水印：与预览同一套计算与绘制
    final items = WatermarkLayout.compute(
      canvasSize: size,
      text: text,
      style: style,
      measure: TextPainterMeasurer.measure,
    );
    WatermarkPainter.paint(canvas, items, style);

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(targetWidth, targetHeight);
    picture.dispose();
    image.dispose();

    final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    if (png == null) {
      throw StateError('图片编码失败');
    }

    final pngBytes = png.buffer.asUint8List();

    // 交给原生编 JPEG；走不通就回退保存 PNG。
    final jpeg = await JpegEncoder.encode(pngBytes);
    final usedPngFallback = jpeg == null;
    final outputBytes = jpeg ?? pngBytes;
    final extension = usedPngFallback ? '.png' : '.jpg';

    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(
      tempDir.path,
      'idmask_${DateTime.now().millisecondsSinceEpoch}$extension',
    ));
    await file.writeAsBytes(Uint8List.fromList(outputBytes));

    return RenderResult(
      file: file,
      wasDownscaled: wasDownscaled,
      usedPngFallback: usedPngFallback,
    );
  }
}
