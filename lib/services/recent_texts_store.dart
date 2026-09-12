import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/watermark_style.dart';

/// 最近文案与样式设置的持久化。键值存储足够，不建表。
class RecentTextsStore {
  static const int maxCount = 10;

  static const String textsKey = 'recent_texts';
  static const String styleKey = 'watermark_style';

  final SharedPreferences prefs;

  RecentTextsStore({required this.prefs});

  /// 从新到旧。
  List<String> loadTexts() {
    final raw = prefs.getString(textsKey);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>[];
      return decoded.whereType<String>().toList();
    } catch (_) {
      return <String>[];
    }
  }

  /// 去重、置顶、截断。返回更新后的列表。
  Future<List<String>> pushText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return loadTexts();

    final texts = loadTexts()
      ..removeWhere((e) => e == trimmed)
      ..insert(0, trimmed);
    while (texts.length > maxCount) {
      texts.removeLast();
    }
    await prefs.setString(textsKey, jsonEncode(texts));
    return texts;
  }

  WatermarkStyle loadStyle() {
    final raw = prefs.getString(styleKey);
    if (raw == null || raw.isEmpty) return const WatermarkStyle();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const WatermarkStyle();
      return WatermarkStyle.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const WatermarkStyle();
    }
  }

  Future<void> saveStyle(WatermarkStyle style) async {
    await prefs.setString(styleKey, jsonEncode(style.toJson()));
  }
}
