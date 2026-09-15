import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idmask/main.dart';
import 'package:idmask/models/watermark_style.dart';
import 'package:idmask/pages/edit_page.dart';
import 'package:idmask/providers/watermark_provider.dart';
import 'package:idmask/services/recent_photos_store.dart';
import 'package:idmask/services/recent_texts_store.dart';
import 'package:idmask/services/thumbnail_generator.dart';

/// 用 App 的真实界面生成 App Store 截图。
///
/// 为什么不用系统相册选图：iOS 的 PHPicker 是跨进程远程视图，模拟器上无法用
/// AppleScript / CGEvent 驱动（点击与输入都进不去），所以这里直接调 provider 的
/// 公开接口（`pickPhoto` / `setText` / `setStyle`）把界面推到目标状态，
/// 再用 `takeScreenshot` 截屏。渲染出来的是真机尺寸的 App 界面。
///
/// 运行：
///   flutter test integration_test/appstore_screenshots_test.dart -d `<device-id>`
/// 截图落在设备沙盒的临时目录，文件名前缀 `appstore_`。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('生成 App Store 截图', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final supportDir = await getApplicationSupportDirectory();
    final photosDir = Directory(p.join(supportDir.path, 'idmask_photos'));
    await photosDir.create(recursive: true);

    final provider = WatermarkProvider(
      photosStore: RecentPhotosStore(
        root: photosDir,
        prefs: prefs,
        thumbnailGenerator: DartUiThumbnailGenerator.generate,
      ),
      textsStore: RecentTextsStore(prefs: prefs),
    );

    // 示例证件（脚本画的，不含任何真实信息）
    final tmp = await getTemporaryDirectory();
    final idCard = File(p.join(tmp.path, 'sample_id.png'));
    await idCard.writeAsBytes(await _idCard());
    final diploma = File(p.join(tmp.path, 'sample_diploma.png'));
    await diploma.writeAsBytes(await _diploma());

    // 先用一张，再换一张，让「最近照片」里有两张
    await provider.pickPhoto(diploma.path);
    await provider.pickPhoto(idCard.path);

    provider.setText('仅供示例公司办理入职使用 2026-09-14');
    await provider.rememberText();

    await tester.pumpWidget(
      ChangeNotifierProvider<WatermarkProvider>.value(
        value: provider,
        child: const IdMaskApp(version: '1.1.1'),
      ),
    );
    await tester.pumpAndSettle();

    // ① 平铺满画面
    await _shot(binding, '01-tile-watermark');

    // ② 单块，拖到右下角
    provider.setStyle(provider.style.copyWith(
      mode: WatermarkLayoutMode.single,
      singlePosition: const Offset(0.70, 0.60),
    ));
    await tester.pumpAndSettle();
    await _shot(binding, '02-single-drag');

    // ③ 样式区（滚下去让颜色色板露出来）
    await tester.drag(find.byType(EditPage), const Offset(0, -260));
    await tester.pumpAndSettle();
    await _shot(binding, '03-style-controls');
    await tester.drag(find.byType(EditPage), const Offset(0, 260));
    await tester.pumpAndSettle();

    // ④ 最近照片列表
    await tester.tap(find.textContaining('最近照片（'));
    await tester.pumpAndSettle();
    await _shot(binding, '04-recent-photos');
    await tester.tapAt(const Offset(200, 60));

    await tester.pumpAndSettle();

    // ⑤ 最近文案列表
    await tester.tap(find.textContaining('最近文案（'));
    await tester.pumpAndSettle();
    await _shot(binding, '05-recent-texts');
  });
}

/// 把界面停在当前场景几秒，供外部 `xcrun simctl io screenshot` 抓取。
/// iOS 上 takeScreenshot / flutter drive 都不稳，交给外部截图更可靠。
Future<void> _shot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  debugPrint('=== SHOT $name ===');
  await Future<void>.delayed(const Duration(seconds: 6));
}

// ---------- 示例证件（脚本绘制） ----------

Future<Uint8List> _render(int w, int h, void Function(ui.Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
  );
  paint(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void _text(
  ui.Canvas canvas,
  String value,
  double x,
  double y,
  double size,
  ui.Color color, {
  bool bold = false,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, Offset(x, y));
}

void _stampMark(ui.Canvas c, double x, double y) {
  c.save();
  c.translate(x, y);
  c.rotate(-0.26);
  _text(c, '非真实证件', 0, 0, 34, const ui.Color(0x80C82828), bold: true);
  c.restore();
}

Future<Uint8List> _idCard() => _render(1200, 760, (c) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, 1200, 760),
        Paint()..color = const Color(0xFFE7EFF9),
      );
      c.drawRect(
        const Rect.fromLTWH(40, 40, 1120, 680),
        Paint()..color = const Color(0xFFF8FBFF),
      );
      _text(c, '示例证件（演示用图）', 84, 84, 46, const Color(0xFF20304A),
          bold: true);
      c.drawRect(
        const Rect.fromLTWH(90, 220, 240, 300),
        Paint()..color = const Color(0xFFDCE5F0),
      );
      _text(c, '示例照片', 148, 356, 24, const Color(0xFF8B98AA));
      const rows = <String>[
        '姓　　名：示例·张三',
        '性　　别：男　　民族：示例',
        '出生日期：1990 年 01 月 01 日',
        '住　　址：示例省示例市示例区示例路 1 号',
        '证件号码：0000 0000 0000 0000 00',
      ];
      for (var i = 0; i < rows.length; i++) {
        _text(c, rows[i], 380, 250 + i * 62, 28, const Color(0xFF31415C));
      }
      _stampMark(c, 880, 140);
      _text(c, '本图由脚本生成，仅用于演示，不含任何真实个人信息。', 84, 690, 22,
          const Color(0xFF8B98AA));
    });

Future<Uint8List> _diploma() => _render(1000, 1400, (c) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, 1000, 1400),
        Paint()..color = const Color(0xFFF3F1EA),
      );
      c.drawRect(
        const Rect.fromLTWH(50, 50, 900, 1300),
        Paint()..color = const Color(0xFFFDFBF6),
      );
      _text(c, '示例学历证书', 90, 110, 48, const Color(0xFF21304A), bold: true);
      _text(c, '（演示用图 · 非真实证件）', 90, 180, 26, const Color(0xFF8B98AA));
      const rows = <String>[
        '姓　　名：示例·李四',
        '出生日期：1991 年 02 月 02 日',
        '毕业院校：示例大学',
        '专　　业：示例专业',
        '证书编号：0000 1111 2222 3333',
      ];
      for (var i = 0; i < rows.length; i++) {
        _text(c, rows[i], 120, 420 + i * 78, 30, const Color(0xFF31415C));
      }
      _stampMark(c, 640, 250);
      _text(c, '本图由脚本生成，仅用于演示，不含任何真实个人信息。', 90, 1290, 22,
          const Color(0xFF8B98AA));
    });
