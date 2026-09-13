import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:idmask/models/watermark_item.dart';
import 'package:idmask/models/watermark_style.dart';
import 'package:idmask/services/watermark_layout.dart';

/// 按字数估算的假测量器。宽度 0.6 倍字号，高度 1.2 倍字号。
Size fakeMeasure(String text, double fontSize) =>
    Size(text.length * fontSize * 0.6, fontSize * 1.2);

const text = '仅供某某公司办理入职使用 2026-09-12';

List<WatermarkItem> compute({
  required Size canvasSize,
  required WatermarkStyle style,
  String t = text,
}) =>
    WatermarkLayout.compute(
      canvasSize: canvasSize,
      text: t,
      style: style,
      measure: fakeMeasure,
    );

void main() {
  group('公共行为', () {
    test('空文案返回空列表', () {
      expect(
        compute(canvasSize: const Size(1000, 1000), style: const WatermarkStyle(), t: ''),
        isEmpty,
      );
    });

    test('只有空白的文案也返回空列表', () {
      expect(
        compute(canvasSize: const Size(1000, 1000), style: const WatermarkStyle(), t: '   '),
        isEmpty,
      );
    });

    test('画布尺寸为零时不崩，返回空列表', () {
      expect(compute(canvasSize: Size.zero, style: const WatermarkStyle()), isEmpty);
    });
  });

  group('平铺', () {
    test('产出的指令条数大于零', () {
      final items = compute(canvasSize: const Size(1200, 900), style: const WatermarkStyle());
      expect(items.length, greaterThan(0));
    });

    test('每条指令的 rotation 都是 -30 度', () {
      final items = compute(canvasSize: const Size(1200, 900), style: const WatermarkStyle());
      for (final item in items) {
        expect(item.rotation, closeTo(-math.pi / 6, 1e-9));
      }
    });

    test('字号等于短边乘字号比例', () {
      final items = compute(canvasSize: const Size(1200, 900), style: const WatermarkStyle());
      expect(items.first.fontSize, closeTo(900 * 0.045, 1e-9));
    });

    test('窄高图与宽扁图都能铺满，不出现空行区间', () {
      for (final size in const [Size(400, 2400), Size(2400, 400)]) {
        final items = compute(canvasSize: size, style: const WatermarkStyle());
        expect(items.length, greaterThan(10), reason: '尺寸 $size 产出的指令太少');
      }
    });

    test('字号比例调大后指令变少（间距变大）', () {
      const canvas = Size(1200, 900);
      final dense = compute(canvasSize: canvas, style: const WatermarkStyle(fontSizeRatio: 0.02));
      final sparse = compute(canvasSize: canvas, style: const WatermarkStyle(fontSizeRatio: 0.12));
      expect(sparse.length, lessThan(dense.length));
    });

    test('偏移 (0,0) 时与水印未偏移的结果一致', () {
      final a = compute(canvasSize: const Size(1200, 900), style: const WatermarkStyle());
      final b = compute(
        canvasSize: const Size(1200, 900),
        style: const WatermarkStyle(tileOffset: Offset.zero),
      );
      expect(b.length, a.length);
      for (var i = 0; i < a.length; i++) {
        expect(b[i].center, a[i].center);
      }
    });

    test('偏移会把整个网格整体平移，指令条数不变', () {
      const canvas = Size(1200, 900);
      const offset = Offset(0.2, -0.1);
      final base = compute(canvasSize: canvas, style: const WatermarkStyle());
      final moved = compute(
        canvasSize: canvas,
        style: const WatermarkStyle(tileOffset: offset),
      );

      // 期望位移 = offset × (画布边长 + 旋转后真实跨度) / 2
      // 真实跨度 = extentX·|cos30°| + extentY·|sin30°|（旋转后沿单轴的实际范围）
      const theta = math.pi / 6;
      final extentX = canvas.width * math.cos(theta).abs() + canvas.height * math.sin(theta).abs();
      final extentY = canvas.width * math.sin(theta).abs() + canvas.height * math.cos(theta).abs();
      final spanX = extentX * math.cos(theta).abs() + extentY * math.sin(theta).abs();
      final spanY = extentX * math.sin(theta).abs() + extentY * math.cos(theta).abs();
      final shift = Offset(
        offset.dx * (canvas.width + spanX) / 2,
        offset.dy * (canvas.height + spanY) / 2,
      );

      expect(moved.length, base.length);
      for (var i = 0; i < base.length; i++) {
        expect(moved[i].center.dx, closeTo(base[i].center.dx + shift.dx, 1e-6));
        expect(moved[i].center.dy, closeTo(base[i].center.dy + shift.dy, 1e-6));
      }
    });

    test('偏移足够大时，画布左侧出现完全没有水印的竖条', () {
      const canvas = Size(1200, 900);
      // 把网格整体往右推 0.75 张
      final items = compute(
        canvasSize: canvas,
        style: const WatermarkStyle(tileOffset: Offset(0.75, 0)),
      );
      // 画布内的最左边缘一带应当没有任何文字中心落在这里。
      // （画布外的中心会被裁剪丢弃，所以只检查 0 <= x < 阈值 的区间。）
      // 阈值 0.03 张：实测偏移 0.75 张后，画布内最左文字中心在 x≈802.57（约 0.669 张），
      // 0.03 张（36px）远落在「左侧空白」区间 [0, 802.57) 内，留出充足余量，
      // 对布局算法的微调最不敏感。
      final nearLeftEdge = items.where(
          (i) => i.center.dx >= 0 && i.center.dx < 1200 * 0.03);
      expect(nearLeftEdge, isEmpty,
          reason: '偏移后左侧应当露出没有水印的区域');
    });

    test('偏移拉到上限 0.75 时，画布上四分之三左右没有水印', () {
      const canvas = Size(1200, 900);
      final items = compute(
        canvasSize: canvas,
        style: const WatermarkStyle(tileOffset: Offset(0.75, 0)),
      );

      // 只看落在画布内的文字中心，统计落在左侧多少比例的空区域内
      final inCanvas = items
          .where((i) => i.center.dx >= 0 && i.center.dx <= canvas.width)
          .toList();
      expect(inCanvas, isNotEmpty, reason: '向右偏移后右侧应当还有水印');

      final minX = inCanvas.map((i) => i.center.dx).reduce((a, b) => a < b ? a : b);
      // 左侧这一整段都应当是没有水印的
      expect(minX / canvas.width, greaterThan(0.6),
          reason: '偏移 0.75 张后左侧至少应空出 60% 宽度，实测 ${minX / canvas.width}');
    });
  });

  group('单块', () {
    const base = WatermarkStyle(mode: WatermarkLayoutMode.single);

    test('只有一条指令且不旋转', () {
      final items = compute(canvasSize: const Size(1200, 900), style: base);
      expect(items.length, 1);
      expect(items.single.rotation, 0);
    });

    test('字号比平铺放大 1.2 倍', () {
      final items = compute(canvasSize: const Size(1200, 900), style: base);
      expect(items.single.fontSize, closeTo(900 * 0.045 * 1.2, 1e-9));
    });

    test('位置 (0.5, 0.5) 时落在画布中心', () {
      final items = compute(canvasSize: const Size(1200, 900), style: base);
      expect(items.single.center.dx, closeTo(600, 1e-9));
      expect(items.single.center.dy, closeTo(450, 1e-9));
    });

    test('位置 (0, 0) 时文字被夹住，仍完整落在画布内', () {
      final items = compute(
        canvasSize: const Size(1200, 900),
        style: base.copyWith(singlePosition: const Offset(0, 0)),
      );
      final item = items.single;
      final measured = fakeMeasure(item.text, item.fontSize);
      expect(item.center.dx - measured.width / 2, greaterThanOrEqualTo(-1e-9));
      expect(item.center.dy - measured.height / 2, greaterThanOrEqualTo(-1e-9));
      expect(item.center.dx + measured.width / 2, lessThanOrEqualTo(1200 + 1e-9));
      expect(item.center.dy + measured.height / 2, lessThanOrEqualTo(900 + 1e-9));
    });

    test('位置 (1, 1) 时文字被夹住，仍完整落在画布内', () {
      final items = compute(
        canvasSize: const Size(1200, 900),
        style: base.copyWith(singlePosition: const Offset(1, 1)),
      );
      final item = items.single;
      final measured = fakeMeasure(item.text, item.fontSize);
      expect(item.center.dx - measured.width / 2, greaterThanOrEqualTo(-1e-9));
      expect(item.center.dy - measured.height / 2, greaterThanOrEqualTo(-1e-9));
      expect(item.center.dx + measured.width / 2, lessThanOrEqualTo(1200 + 1e-9));
      expect(item.center.dy + measured.height / 2, lessThanOrEqualTo(900 + 1e-9));
    });

    test('文案比画布还宽时，水平方向改为居中', () {
      // 单块模式的字号也按短边比例算，所以默认字号下文字宽度只有短边的约 0.75 倍，
      // 永远超不过画布。这里把字号比例拉到上限 0.12，让文字确实宽过画布。
      final items = compute(
        canvasSize: const Size(1200, 900),
        style: base.copyWith(
          singlePosition: const Offset(0.1, 0.5),
          fontSizeRatio: 0.12,
        ),
      );
      final item = items.single;
      final measured = fakeMeasure(item.text, item.fontSize);
      expect(measured.width, greaterThan(1200), reason: '前提不成立：文字并未宽过画布');
      expect(item.center.dx, closeTo(600, 1e-9));
    });

    test('同一归一化位置在两种画布尺寸下产生等比的结果', () {
      const style = WatermarkStyle(
        mode: WatermarkLayoutMode.single,
        singlePosition: Offset(0.25, 0.75),
      );
      final small = compute(canvasSize: const Size(1000, 800), style: style).single;
      final large = compute(canvasSize: const Size(2000, 1600), style: style).single;
      expect(large.center.dx, closeTo(small.center.dx * 2, 1e-6));
      expect(large.center.dy, closeTo(small.center.dy * 2, 1e-6));
      expect(large.fontSize, closeTo(small.fontSize * 2, 1e-9));
    });
  });

  group('guideCenter 参考线位置', () {
    test('单块模式返回夹取后的文字中心', () {
      const canvas = Size(1200, 900);
      const style = WatermarkStyle(
        mode: WatermarkLayoutMode.single,
        singlePosition: Offset(0, 0), // 故意拖到左上角，应被夹取
      );
      final center = WatermarkLayout.guideCenter(
        canvasSize: canvas,
        text: text,
        style: style,
        measure: fakeMeasure,
      );

      // 应当与真正的绘制位置一致
      final drawn = WatermarkLayout.compute(
        canvasSize: canvas,
        text: text,
        style: style,
        measure: fakeMeasure,
      ).single.center;
      expect(center.dx * canvas.width, closeTo(drawn.dx, 1e-6));
      expect(center.dy * canvas.height, closeTo(drawn.dy, 1e-6));
    });

    test('平铺模式偏移为 0 时返回画布中心', () {
      final center = WatermarkLayout.guideCenter(
        canvasSize: const Size(1200, 900),
        text: text,
        style: const WatermarkStyle(),
        measure: fakeMeasure,
      );
      expect(center.dx, closeTo(0.5, 1e-9));
      expect(center.dy, closeTo(0.5, 1e-9));
    });

    test('平铺模式返回网格中心，而非简单累加 tileOffset', () {
      const canvas = Size(1200, 900);
      const off = Offset(0.75, 0);
      final center = WatermarkLayout.guideCenter(
        canvasSize: canvas,
        text: text,
        style: const WatermarkStyle(tileOffset: off),
        measure: fakeMeasure,
      );

      // 网格实际位移 = offset × (画布边长 + 跨度) / 2
      const theta = math.pi / 6;
      final extentX = canvas.width * math.cos(theta).abs() + canvas.height * math.sin(theta).abs();
      final extentY = canvas.width * math.sin(theta).abs() + canvas.height * math.cos(theta).abs();
      final spanX = extentX * math.cos(theta).abs() + extentY * math.sin(theta).abs();
      final expected = 0.5 + off.dx * (canvas.width + spanX) / 2 / canvas.width;

      expect(center.dx, closeTo(expected, 1e-6));
      // 而且它必须明显大于「简单累加」的 1.25，否则就是旧 bug
      expect(center.dx, greaterThan(1.25));
    });

    test('画布尺寸无效时回落到中心', () {
      final center = WatermarkLayout.guideCenter(
        canvasSize: Size.zero,
        text: text,
        style: const WatermarkStyle(),
        measure: fakeMeasure,
      );
      expect(center, const Offset(0.5, 0.5));
    });
  });
}
