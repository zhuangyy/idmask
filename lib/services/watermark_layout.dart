import 'dart:math' as math;
import 'dart:ui';

import '../models/watermark_item.dart';
import '../models/watermark_style.dart';

/// 测量文字在给定字号下占多大。生产环境用 TextPainter 实现，测试用估算实现。
typedef TextMeasurer = Size Function(String text, double fontSize);

/// 把文案与样式算成一组绘制指令。
///
/// 纯函数：不依赖 Flutter binding，不碰 Canvas，因此可以用普通 `test()` 覆盖，
/// 并能构造超宽图、超窄图、超长文案等极端情况而不需要真实图片。
///
/// 预览与成品图调用的是同一个 `compute`，区别只是 `canvasSize` 不同；
/// 又因为字号按短边比例、位置是归一化的，两者算出的结果在各自坐标系里等比，
/// 「所见即所得」由结构保证。
class WatermarkLayout {
  const WatermarkLayout._();

  /// 平铺倾斜角：-30 度。
  static const double tileAngle = -math.pi / 6;

  /// 行距相对字号。
  static const double lineHeightFactor = 1.8;

  /// 列间距相对字号。
  static const double columnGapFactor = 1.2;

  /// 单块模式的字号相对平铺放大多少。
  static const double singleFontScale = 1.2;

  static List<WatermarkItem> compute({
    required Size canvasSize,
    required String text,
    required WatermarkStyle style,
    required TextMeasurer measure,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const <WatermarkItem>[];

    final shortSide = canvasSize.shortestSide;
    if (shortSide <= 0 || !shortSide.isFinite) return const <WatermarkItem>[];

    switch (style.mode) {
      case WatermarkLayoutMode.tile:
        return _tile(canvasSize, trimmed, style, measure, shortSide);
      case WatermarkLayoutMode.single:
        return _single(canvasSize, trimmed, style, measure, shortSide);
    }
  }

  static List<WatermarkItem> _tile(
    Size canvasSize,
    String text,
    WatermarkStyle style,
    TextMeasurer measure,
    double shortSide,
  ) {
    final fontSize = shortSide * style.fontSizeRatio;
    if (fontSize <= 0 || !fontSize.isFinite) return const <WatermarkItem>[];

    final textSize = measure(text, fontSize);
    final step = textSize.width + fontSize * columnGapFactor;
    if (step <= 0 || !step.isFinite) return const <WatermarkItem>[];

    final lineHeight = fontSize * lineHeightFactor;
    final theta = tileAngle;
    final cosT = math.cos(theta);
    final sinT = math.sin(theta);

    // 旋转后在两个轴上的投影长度，保证斜着也铺满、不留空白角。
    final extentX = canvasSize.width * cosT.abs() + canvasSize.height * sinT.abs();
    final extentY = canvasSize.width * sinT.abs() + canvasSize.height * cosT.abs();

    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;

    final rowCount = (extentY / lineHeight).ceil() + 1;
    final items = <WatermarkItem>[];

    for (var row = 0; row <= rowCount; row++) {
      final cy = -extentY / 2 + row * lineHeight;

      // 相邻行错开半个步长，形成交错，比整齐网格更难被涂抹。
      final rowOffset = row.isOdd ? step / 2 : 0.0;
      final colCount = (extentX / step).ceil() + 1;

      for (var col = 0; col <= colCount; col++) {
        final cx = -extentX / 2 + rowOffset + col * step;

        items.add(WatermarkItem(
          text: text,
          center: Offset(
            centerX + cx * cosT - cy * sinT,
            centerY + cx * sinT + cy * cosT,
          ),
          fontSize: fontSize,
          rotation: theta,
        ));
      }
    }

    // 超出画布范围的指令照常产出，由画布裁剪丢弃 ——
    // 这样算法不必处理边界特例，代码更短也更不容易出错。
    return items;
  }

  static List<WatermarkItem> _single(
    Size canvasSize,
    String text,
    WatermarkStyle style,
    TextMeasurer measure,
    double shortSide,
  ) {
    final fontSize = shortSide * style.fontSizeRatio * singleFontScale;
    if (fontSize <= 0 || !fontSize.isFinite) return const <WatermarkItem>[];

    final textSize = measure(text, fontSize);
    final w = canvasSize.width;
    final h = canvasSize.height;

    final px = style.singlePosition.dx * w;
    final py = style.singlePosition.dy * h;

    // 夹取，保证文字完整可见。文字比画布还大时该方向居中（无奈的降级）。
    final x = textSize.width <= w
        ? px.clamp(textSize.width / 2, w - textSize.width / 2)
        : w / 2;
    final y = textSize.height <= h
        ? py.clamp(textSize.height / 2, h - textSize.height / 2)
        : h / 2;

    return <WatermarkItem>[
      WatermarkItem(
        text: text,
        center: Offset(x, y),
        fontSize: fontSize,
        rotation: 0,
      ),
    ];
  }
}
