import 'dart:ui';

/// 一条水印的绘制指令，坐标系为成品图的像素坐标。
///
/// 不带颜色与透明度 —— 这两项属于整张图的样式，由 WatermarkStyle 统一施加。
class WatermarkItem {
  final String text;

  /// 文字中心点。
  final Offset center;

  /// 像素字号。
  final double fontSize;

  /// 弧度。
  final double rotation;

  const WatermarkItem({
    required this.text,
    required this.center,
    required this.fontSize,
    required this.rotation,
  });

  @override
  String toString() => 'WatermarkItem($center, fs=$fontSize, rot=$rotation)';
}
