import 'package:flutter_test/flutter_test.dart';
import 'package:idwm/models/watermark_style.dart';

void main() {
  group('默认值', () {
    test('平铺、居中、0.28 透明度、0.045 字号比例、深灰', () {
      const s = WatermarkStyle();
      expect(s.mode, WatermarkLayoutMode.tile);
      expect(s.singlePosition, const Offset(0.5, 0.5));
      expect(s.tileOffset, Offset.zero);
      expect(s.opacity, 0.28);
      expect(s.fontSizeRatio, 0.045);
      expect(s.colorValue, 0xFF404040);
    });
  });

  group('夹取', () {
    test('透明度越界被夹到 0.05–1.0', () {
      expect(WatermarkStyle.sanitized(opacity: 0.0).opacity, 0.05);
      expect(WatermarkStyle.sanitized(opacity: 2.0).opacity, 1.0);
    });

    test('字号比例越界被夹到 0.02–0.12', () {
      expect(WatermarkStyle.sanitized(fontSizeRatio: 0.001).fontSizeRatio, 0.02);
      expect(WatermarkStyle.sanitized(fontSizeRatio: 1).fontSizeRatio, 0.12);
    });

    test('位置越界被夹到 0–1', () {
      final s = WatermarkStyle.sanitized(singlePosition: const Offset(-1, 3));
      expect(s.singlePosition, const Offset(0.0, 1.0));
    });

    test('平铺偏移越界被夹到 ±0.75', () {
      expect(
        WatermarkStyle.sanitized(tileOffset: const Offset(1, -1)).tileOffset,
        const Offset(0.75, -0.75),
      );
    });

    test('平铺偏移在上限内时原值保留', () {
      expect(
        WatermarkStyle.sanitized(tileOffset: const Offset(0.5, -0.5)).tileOffset,
        const Offset(0.5, -0.5),
      );
    });

    test('色板外的颜色回落到深灰', () {
      expect(WatermarkStyle.sanitized(colorValue: 0xFF123456).colorValue, 0xFF404040);
    });

    test('色板内的颜色被保留', () {
      expect(WatermarkStyle.sanitized(colorValue: 0xFFD0021B).colorValue, 0xFFD0021B);
    });
  });

  group('JSON', () {
    test('往返序列化保留全部字段', () {
      const s = WatermarkStyle(
        mode: WatermarkLayoutMode.single,
        singlePosition: Offset(0.2, 0.8),
        opacity: 0.5,
        fontSizeRatio: 0.08,
        colorValue: 0xFFD0021B,
      );
      final back = WatermarkStyle.fromJson(s.toJson());
      expect(back, s);
      expect(back.singlePosition, const Offset(0.2, 0.8));
    });

    test('平铺偏移能往返序列化', () {
      const s = WatermarkStyle(tileOffset: Offset(0.2, -0.1));
      expect(WatermarkStyle.fromJson(s.toJson()).tileOffset,
          const Offset(0.2, -0.1));
    });

    test('fromJson 同样做夹取', () {
      final back = WatermarkStyle.fromJson(<String, dynamic>{
        'mode': 'single',
        'positionX': 5.0,
        'positionY': -5.0,
        'opacity': 9.0,
        'fontSizeRatio': 0.0,
        'colorValue': 0xFF123456,
      });
      expect(back.singlePosition, const Offset(1.0, 0.0));
      expect(back.opacity, 1.0);
      expect(back.fontSizeRatio, 0.02);
      expect(back.colorValue, 0xFF404040);
    });

    test('mode 无法识别时回落到平铺', () {
      expect(WatermarkStyle.fromJson(<String, dynamic>{'mode': 'nonsense'}).mode,
          WatermarkLayoutMode.tile);
    });

    test('字段缺失时用默认值', () {
      final back = WatermarkStyle.fromJson(<String, dynamic>{});
      expect(back, const WatermarkStyle());
    });
  });

  group('copyWith', () {
    test('只改指定字段', () {
      const s = WatermarkStyle();
      final moved = s.copyWith(singlePosition: const Offset(0.1, 0.9));
      expect(moved.singlePosition, const Offset(0.1, 0.9));
      expect(moved.opacity, s.opacity);
      expect(moved.mode, s.mode);
    });

    test('结果同样经过夹取', () {
      expect(const WatermarkStyle().copyWith(opacity: 5.0).opacity, 1.0);
    });
  });
}
