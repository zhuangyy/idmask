import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/watermark_style.dart';
import '../providers/watermark_provider.dart';
import '../services/text_painter_measurer.dart';
import '../services/watermark_layout.dart';
import '../services/watermark_painter.dart';
import 'watermark_drag_layer.dart';

/// 实时预览。
///
/// 与成品图走的是同一套 `WatermarkLayout.compute` + `WatermarkPainter.paint`，
/// 因此预览和输出天然一致。
class PhotoCanvas extends StatelessWidget {
  const PhotoCanvas({super.key, this.onRequestPick});

  /// 用户点预览区时回调，交给外层打开相册；为 null 时不可点。
  final VoidCallback? onRequestPick;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WatermarkProvider>();
    final path = provider.photoPath;

    final Widget content;
    if (path == null) {
      content = const ColoredBox(
        color: Colors.black12,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.add_photo_alternate_outlined, size: 48),
              SizedBox(height: 8),
              Text('点击这里，从相册选一张证件照'),
            ],
          ),
        ),
      );
    } else {
      content = WatermarkDragLayer(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.file(File(path), fit: BoxFit.contain, gaplessPlayback: true),
            Positioned.fill(
              child: CustomPaint(
                painter: _WatermarkOverlayPainter(
                  text: provider.effectiveText,
                  style: provider.style,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: provider.isSaving ? null : onRequestPick,
      child: content,
    );
  }
}

/// 只画水印，不画底图 —— 底图交给 Image.file，水印叠在上面。
class _WatermarkOverlayPainter extends CustomPainter {
  _WatermarkOverlayPainter({required this.text, required this.style});

  final String text;
  final WatermarkStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final items = WatermarkLayout.compute(
      canvasSize: size,
      text: text,
      style: style,
      measure: TextPainterMeasurer.measure,
    );
    WatermarkPainter.paint(canvas, items, style);
  }

  @override
  bool shouldRepaint(_WatermarkOverlayPainter old) =>
      old.text != text || old.style != style;
}
