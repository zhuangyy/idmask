import 'package:flutter/painting.dart';

import '../models/watermark_item.dart';
import '../models/watermark_style.dart';
import 'text_painter_measurer.dart';

/// 把绘制指令画到任意 Canvas 上。
///
/// 预览与成品图调用的是同一个函数，区别只是 Canvas 尺寸不同。
class WatermarkPainter {
  const WatermarkPainter._();

  static void paint(
    Canvas canvas,
    List<WatermarkItem> items,
    WatermarkStyle style,
  ) {
    if (items.isEmpty) return;

    // 透明度按整体施加，避免每条指令各带一份。
    final base = Color(style.colorValue);
    final color = base.withValues(alpha: style.opacity);

    for (final item in items) {
      final painter = TextPainter(
        text: TextSpan(
          text: item.text,
          style: TextStyle(
            color: color,
            fontSize: item.fontSize,
            fontFamilyFallback: TextPainterMeasurer.fontFamilyFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      canvas.save();
      canvas.translate(item.center.dx, item.center.dy);
      if (item.rotation != 0) canvas.rotate(item.rotation);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
      painter.dispose();
    }
  }
}
