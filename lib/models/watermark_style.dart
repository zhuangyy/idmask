import 'dart:ui';

/// 水印版式。
enum WatermarkLayoutMode { tile, single }

/// 水印样式。
///
/// 除 `const` 直接构造外，所有入口（`sanitized` / `fromJson` / `copyWith`）都会
/// 把取值夹到合法区间。这样即使持久化的数据被改坏，布局层也不会算出离谱的结果。
class WatermarkStyle {
  static const double minOpacity = 0.05;
  static const double maxOpacity = 1.0;
  static const double minFontSizeRatio = 0.02;
  static const double maxFontSizeRatio = 0.12;

  /// 平铺网格整体偏移的绝对值上限（归一化）。
  /// 拖得再多就会露出大片无水印区域，失去平铺的保护意义。
  static const double maxTileOffset = 0.25;

  /// 预设色板：黑、深灰、红、白、蓝。
  static const List<int> palette = <int>[
    0xFF000000,
    0xFF404040,
    0xFFD0021B,
    0xFFFFFFFF,
    0xFF1E6FD9,
  ];

  static const int defaultColor = 0xFF404040;

  final WatermarkLayoutMode mode;

  /// 归一化坐标，仅单块模式使用。
  final Offset singlePosition;

  /// 平铺网格的整体偏移（归一化），仅平铺模式使用。默认 (0, 0) 即铺满。
  final Offset tileOffset;

  final double opacity;

  /// 字号相对图片短边的比例。
  final double fontSizeRatio;

  /// ARGB 颜色值。
  final int colorValue;

  /// 直接构造，不做夹取。只用于代码里写死的取值。
  const WatermarkStyle({
    this.mode = WatermarkLayoutMode.tile,
    this.singlePosition = const Offset(0.5, 0.5),
    this.tileOffset = Offset.zero,
    this.opacity = 0.28,
    this.fontSizeRatio = 0.045,
    this.colorValue = defaultColor,
  });

  /// 夹取后的构造。用户输入与反序列化都走这里。
  factory WatermarkStyle.sanitized({
    WatermarkLayoutMode mode = WatermarkLayoutMode.tile,
    Offset singlePosition = const Offset(0.5, 0.5),
    Offset tileOffset = Offset.zero,
    double opacity = 0.28,
    double fontSizeRatio = 0.045,
    int colorValue = defaultColor,
  }) {
    return WatermarkStyle(
      mode: mode,
      singlePosition: _clampUnit(singlePosition),
      tileOffset: _clampTileOffset(tileOffset),
      opacity: opacity.clamp(minOpacity, maxOpacity),
      fontSizeRatio: fontSizeRatio.clamp(minFontSizeRatio, maxFontSizeRatio),
      colorValue: palette.contains(colorValue) ? colorValue : defaultColor,
    );
  }

  static Offset _clampUnit(Offset o) =>
      Offset(o.dx.clamp(0.0, 1.0), o.dy.clamp(0.0, 1.0));

  static Offset _clampTileOffset(Offset o) => Offset(
        o.dx.clamp(-maxTileOffset, maxTileOffset),
        o.dy.clamp(-maxTileOffset, maxTileOffset),
      );

  /// 拖动参考线穿过的归一化位置。
  ///
  /// 单块模式是文字块的中心；平铺模式是网格的中心（即相对画布中心偏移了多少）。
  Offset get guidePosition => mode == WatermarkLayoutMode.single
      ? singlePosition
      : Offset(0.5 + tileOffset.dx, 0.5 + tileOffset.dy);

  WatermarkStyle copyWith({
    WatermarkLayoutMode? mode,
    Offset? singlePosition,
    Offset? tileOffset,
    double? opacity,
    double? fontSizeRatio,
    int? colorValue,
  }) {
    return WatermarkStyle.sanitized(
      mode: mode ?? this.mode,
      singlePosition: singlePosition ?? this.singlePosition,
      tileOffset: tileOffset ?? this.tileOffset,
      opacity: opacity ?? this.opacity,
      fontSizeRatio: fontSizeRatio ?? this.fontSizeRatio,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': mode.name,
        'positionX': singlePosition.dx,
        'positionY': singlePosition.dy,
        'tileOffsetX': tileOffset.dx,
        'tileOffsetY': tileOffset.dy,
        'opacity': opacity,
        'fontSizeRatio': fontSizeRatio,
        'colorValue': colorValue,
      };

  factory WatermarkStyle.fromJson(Map<String, dynamic> json) {
    return WatermarkStyle.sanitized(
      mode: _modeFromName(json['mode'] as String?),
      singlePosition: Offset(
        (json['positionX'] as num?)?.toDouble() ?? 0.5,
        (json['positionY'] as num?)?.toDouble() ?? 0.5,
      ),
      tileOffset: Offset(
        (json['tileOffsetX'] as num?)?.toDouble() ?? 0,
        (json['tileOffsetY'] as num?)?.toDouble() ?? 0,
      ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.28,
      fontSizeRatio: (json['fontSizeRatio'] as num?)?.toDouble() ?? 0.045,
      colorValue: (json['colorValue'] as num?)?.toInt() ?? defaultColor,
    );
  }

  static WatermarkLayoutMode _modeFromName(String? name) =>
      name == WatermarkLayoutMode.single.name
          ? WatermarkLayoutMode.single
          : WatermarkLayoutMode.tile;

  @override
  bool operator ==(Object other) =>
      other is WatermarkStyle &&
      other.mode == mode &&
      other.singlePosition == singlePosition &&
      other.tileOffset == tileOffset &&
      other.opacity == opacity &&
      other.fontSizeRatio == fontSizeRatio &&
      other.colorValue == colorValue;

  @override
  int get hashCode =>
      Object.hash(mode, singlePosition, tileOffset, opacity, fontSizeRatio, colorValue);

  @override
  String toString() =>
      'WatermarkStyle(${mode.name}, $singlePosition, $opacity, $fontSizeRatio, '
      '0x${colorValue.toRadixString(16)})';
}
