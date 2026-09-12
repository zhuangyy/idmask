import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idwm/models/watermark_style.dart';
import 'package:idwm/pages/edit_page.dart';
import 'package:idwm/providers/watermark_provider.dart';
import 'package:idwm/services/recent_photos_store.dart';
import 'package:idwm/services/recent_texts_store.dart';
import 'package:idwm/widgets/photo_canvas.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempRoot;
  late WatermarkProvider provider;

  /// 假的缩略图生成器，避开真实图片解码。
  Future<void> fakeThumbnail(String source, String dest, int maxSide) async {}

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    tempRoot = await Directory.systemTemp.createTemp('idwm_widget_test_');
    provider = WatermarkProvider(
      photosStore: RecentPhotosStore(
        root: tempRoot,
        prefs: prefs,
        thumbnailGenerator: fakeThumbnail,
      ),
      textsStore: RecentTextsStore(prefs: prefs),
    );
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<WatermarkProvider>.value(
        value: provider,
        child: const MaterialApp(home: EditPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 把目标控件滚到可见再操作 —— 编辑页内容比一屏长，直接 tap/drag 会失败。
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  // 保存按钮是 FilledButton.icon，实际类型是私有子类 _FilledButtonWithIcon，
  // find.byType 用 runtimeType 精确匹配会漏掉，所以按文本定位再向上找 FilledButton。
  final saveButton = find.ancestor(
    of: find.text('保存到相册'),
    matching: find.byWidgetPredicate((Widget w) => w is FilledButton),
  );

  testWidgets('未选图时显示空状态引导', (tester) async {
    await pumpPage(tester);
    expect(find.text('点击这里，从相册选一张证件照'), findsOneWidget);
  });

  testWidgets('文案为空时保存按钮禁用', (tester) async {
    await pumpPage(tester);
    await reveal(tester, saveButton);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
  });

  testWidgets('未选图时即使填了文案也不能保存', (tester) async {
    await pumpPage(tester);
    final field = find.widgetWithText(TextField, '水印文字');
    await reveal(tester, field);
    await tester.enterText(field, '仅供某某公司办理入职使用 2026-09-12');
    await tester.pumpAndSettle();

    expect(provider.effectiveText, '仅供某某公司办理入职使用 2026-09-12');

    await reveal(tester, saveButton);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull,
        reason: '没选图不该能保存');
  });

  testWidgets('点预览区会触发选图回调', (tester) async {
    var picked = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider<WatermarkProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: PhotoCanvas(onRequestPick: () => picked++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PhotoCanvas));
    await tester.pumpAndSettle();

    expect(picked, 1, reason: '点预览区应当触发一次选图回调');
  });

  testWidgets('插入今天日期会把日期填进文案', (tester) async {
    await pumpPage(tester);

    final button = find.widgetWithText(TextButton, '插入今天日期');
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final expected = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    expect(provider.text, contains(expected));
  });

  testWidgets('拖动透明度滑块后样式跟着变，且不低于下限', (tester) async {
    await pumpPage(tester);
    final before = provider.style.opacity;

    final slider = find.byType(Slider).first;
    await reveal(tester, slider);
    await tester.drag(slider, const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(provider.style.opacity, lessThan(before));
    expect(provider.style.opacity,
        greaterThanOrEqualTo(WatermarkStyle.minOpacity));
  });

  testWidgets('点最近照片按钮能弹出空状态', (tester) async {
    await pumpPage(tester);

    // 按钮文案是「最近照片（0）」，已挪到标题栏，是 TextButton.icon（私有子类），
    // 所以按包含文本定位再向上找 TextButton。
    final button = find.ancestor(
      of: find.textContaining('最近照片'),
      matching: find.byWidgetPredicate((Widget w) => w is TextButton),
    );
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('还没有用过的照片'), findsOneWidget);
  });

  testWidgets('点最近文案按钮能弹出空状态', (tester) async {
    await pumpPage(tester);

    final button = find.ancestor(
      of: find.textContaining('最近文案'),
      matching: find.byWidgetPredicate((Widget w) => w is TextButton),
    );
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('还没有用过的文案'), findsOneWidget);
  });
}
