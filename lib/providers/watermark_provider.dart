import 'dart:io';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

import '../models/recent_photo.dart';
import '../models/watermark_style.dart';
import '../services/image_renderer.dart';
import '../services/photo_saver.dart';
import '../services/recent_photos_store.dart';
import '../services/recent_texts_store.dart';

/// 全 App 唯一的状态持有者。
class WatermarkProvider extends ChangeNotifier {
  final RecentPhotosStore photosStore;
  final RecentTextsStore textsStore;

  WatermarkProvider({required this.photosStore, required this.textsStore});

  WatermarkStyle _style = const WatermarkStyle();
  String _text = '';
  String? _photoPath;
  List<RecentPhoto> _recentPhotos = <RecentPhoto>[];
  List<String> _recentTexts = <String>[];
  bool _isSaving = false;
  String? _message;
  String? _lastWarning;

  WatermarkStyle get style => _style;
  String get text => _text;
  String? get photoPath => _photoPath;
  List<RecentPhoto> get recentPhotos => List<RecentPhoto>.unmodifiable(_recentPhotos);
  List<String> get recentTexts => List<String>.unmodifiable(_recentTexts);
  bool get isSaving => _isSaving;
  String? get message => _message;

  /// 「已按 4096 压缩」「文件较大」这类非错误提示。
  String? get lastWarning => _lastWarning;

  bool get hasPhoto => _photoPath != null;

  /// 当前真正要画上去的文案：输入内容去掉首尾空白。
  String get effectiveText => _text.trim();

  /// 没选图、文案为空或正在处理中，都不能保存。
  bool get canSave => hasPhoto && effectiveText.isNotEmpty && !_isSaving;

  // ---- 启动 ----

  Future<void> loadFromStorage() async {
    _style = textsStore.loadStyle();
    _recentTexts = textsStore.loadTexts();
    await photosStore.pruneOrphans();
    _recentPhotos = await photosStore.load();
    notifyListeners();
  }

  // ---- 修改 ----

  void setStyle(WatermarkStyle value) {
    if (value == _style) return;
    _style = value;
    notifyListeners();
  }

  void setText(String value) {
    final normalized = _collapseNewlines(value);
    if (normalized == _text) return;
    _text = normalized;
    notifyListeners();
  }

  static final RegExp _newlinePattern = RegExp(r'[\r\n]+');

  /// 水印只画单行，换行统一折成空格。
  static String _collapseNewlines(String value) =>
      value.replaceAll(_newlinePattern, ' ');

  /// 把一条历史文案填回输入框。
  void applyRecentText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setText(trimmed);
  }

  void updateSinglePosition(Offset position) {
    setStyle(_style.copyWith(singlePosition: position));
  }

  /// 拖动水印：单块模式改位置，平铺模式改网格的整体偏移。
  /// 两者都是归一化坐标，夹取由 WatermarkStyle 负责。
  void nudgePosition(Offset delta) {
    final style = _style;
    if (style.mode == WatermarkLayoutMode.single) {
      setStyle(style.copyWith(singlePosition: style.singlePosition + delta));
    } else {
      setStyle(style.copyWith(tileOffset: style.tileOffset + delta));
    }
  }

  // ---- 照片 ----

  /// 选图后统一落到私有目录，之后所有环节都读副本路径。
  Future<void> pickPhoto(String sourcePath) async {
    try {
      final photo = await photosStore.add(sourcePath);
      _photoPath = photosStore.pathOf(photo);
      _recentPhotos = await photosStore.load();
      _message = null;
    } on FileSystemException {
      // 空间不足或源文件读不到：本次仍用临时路径继续，只是不进最近列表。
      _photoPath = sourcePath;
      _message = '无法读取这张图片，请换一张';
    } catch (_) {
      _photoPath = sourcePath;
      _message = '无法读取这张图片，请换一张';
    }
    notifyListeners();
  }

  Future<void> selectRecentPhoto(RecentPhoto photo) async {
    final path = photosStore.pathOf(photo);
    if (!File(path).existsSync()) {
      await photosStore.remove(photo.id);
      _recentPhotos = await photosStore.load();
      _message = '这张照片已经不在 App 里了，请重新选择';
      notifyListeners();
      return;
    }
    _photoPath = path;
    _message = null;
    notifyListeners();
  }

  Future<void> removeRecentPhoto(String id) async {
    await photosStore.remove(id);
    _recentPhotos = await photosStore.load();
    notifyListeners();
  }

  Future<void> clearRecentPhotos() async {
    await photosStore.clear();
    _recentPhotos = <RecentPhoto>[];
    notifyListeners();
  }

  /// 记住这次用过的文案与样式。
  Future<void> rememberText() async {
    final text = effectiveText;
    if (text.isNotEmpty) {
      _recentTexts = await textsStore.pushText(text);
    }
    await textsStore.saveStyle(_style);
    notifyListeners();
  }

  // ---- 保存 ----

  void beginSaving() {
    _isSaving = true;
    _message = null;
    _lastWarning = null;
    notifyListeners();
  }

  void endSaving({String? message}) {
    _isSaving = false;
    _message = message;
    notifyListeners();
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  /// 保存到系统相册。返回是否成功。
  Future<bool> save() async {
    final path = _photoPath;
    if (path == null || effectiveText.isEmpty) return false;

    beginSaving();
    try {
      final result = await ImageRenderer.render(
        sourcePath: path,
        text: effectiveText,
        style: _style,
      );

      try {
        await PhotoSaver.save(result.file.path);
      } on GalException catch (e) {
        endSaving(
          message: e.type == GalExceptionType.accessDenied
              ? '没有相册权限，请到系统设置里打开'
              : '保存失败，请再试一次',
        );
        return false;
      }

      if (result.wasDownscaled) {
        _lastWarning = '图片已按 4096 像素长边压缩';
      } else if (result.usedPngFallback) {
        _lastWarning = '已保存为 PNG，文件较大';
      }

      await rememberText();

      try {
        await result.file.delete();
      } catch (_) {
        // 删不掉就留着，系统会清临时目录
      }

      endSaving(message: '已保存到相册');
      return true;
    } on FormatException {
      endSaving(message: '无法读取这张图片，请换一张');
      return false;
    } catch (_) {
      endSaving(message: '图片过大，处理失败，建议先裁剪');
      return false;
    }
  }
}
