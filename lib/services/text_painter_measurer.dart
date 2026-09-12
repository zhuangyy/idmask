import 'package:flutter/painting.dart';

/// 生产环境的文字测量实现，接 [TextPainter]。
///
/// 与 `WatermarkPainter` 必须用同一套字体设置，否则布局算出的宽高
/// 与实际画出来的对不上，平铺会出现忽宽忽窄的缝隙。
class TextPainterMeasurer {
  const TextPainterMeasurer._();

  /// 中文字体回退链。不打包自定义字体，靠系统字体渲染。
  static const List<String> fontFamilyFallback = <String>[
    'PingFang SC', // iOS 苹方
    'Noto Sans CJK SC', // Android 思源黑体常见的族名
    'Heiti SC',
    'sans-serif',
  ];

  static Size measure(String text, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontFamilyFallback: fontFamilyFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final size = Size(painter.width, painter.height);
    painter.dispose();
    return size;
  }
}
