import 'package:flutter_test/flutter_test.dart';
import 'package:idmask/models/watermark_style.dart';
import 'package:idmask/services/recent_texts_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late RecentTextsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    store = RecentTextsStore(prefs: prefs);
  });

  group('最近文案', () {
    test('空存储返回空列表', () {
      expect(store.loadTexts(), isEmpty);
    });

    test('新推入的排在最前', () async {
      await store.pushText('甲');
      await store.pushText('乙');
      expect(store.loadTexts(), <String>['乙', '甲']);
    });

    test('重复文案被提到最前，不产生第二条', () async {
      await store.pushText('甲');
      await store.pushText('乙');
      await store.pushText('甲');
      expect(store.loadTexts(), <String>['甲', '乙']);
    });

    test('空白文案被忽略', () async {
      await store.pushText('   ');
      expect(store.loadTexts(), isEmpty);
    });

    test('首尾空白被去掉后再存', () async {
      await store.pushText('  甲  ');
      expect(store.loadTexts(), <String>['甲']);
    });

    test('超过 10 条时淘汰最旧的', () async {
      for (var i = 0; i < 12; i++) {
        await store.pushText('文案$i');
      }
      final texts = store.loadTexts();
      expect(texts.length, RecentTextsStore.maxCount);
      expect(texts.first, '文案11');
      expect(texts, isNot(contains('文案0')));
      expect(texts, isNot(contains('文案1')));
    });

    test('存储内容坏掉时返回空列表而不是抛异常', () {
      prefs.setString(RecentTextsStore.textsKey, '这不是 JSON');
      expect(store.loadTexts(), isEmpty);
    });
  });

  group('样式', () {
    test('没存过时返回默认样式', () {
      expect(store.loadStyle(), const WatermarkStyle());
    });

    test('保存后能读回', () async {
      const style = WatermarkStyle(
        mode: WatermarkLayoutMode.single,
        singlePosition: Offset(0.3, 0.7),
        opacity: 0.5,
        fontSizeRatio: 0.09,
        colorValue: 0xFFD0021B,
      );
      await store.saveStyle(style);
      expect(store.loadStyle(), style);
    });

    test('存进去的越界值在读回时被夹住', () async {
      prefs.setString(
        RecentTextsStore.styleKey,
        '{"mode":"single","positionX":9,"positionY":-9,"opacity":9,'
        '"fontSizeRatio":9,"colorValue":1}',
      );
      final style = store.loadStyle();
      expect(style.singlePosition, const Offset(1.0, 0.0));
      expect(style.opacity, 1.0);
      expect(style.fontSizeRatio, 0.12);
      expect(style.colorValue, WatermarkStyle.defaultColor);
    });

    test('存储内容坏掉时返回默认样式', () {
      prefs.setString(RecentTextsStore.styleKey, '{坏掉的');
      expect(store.loadStyle(), const WatermarkStyle());
    });
  });
}
