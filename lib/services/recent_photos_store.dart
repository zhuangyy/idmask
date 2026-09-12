import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recent_photo.dart';
import 'photo_fingerprint.dart';

/// 把源图等比缩到指定长边并写成 PNG。
///
/// 抽成 typedef 是为了让 [RecentPhotosStore] 可测 —— 测试传一个写假文件的实现即可，
/// 不需要真实的图片解码，也不需要 Flutter binding。
typedef ThumbnailGenerator = Future<void> Function(
  String sourcePath,
  String destPath,
  int maxSide,
);

/// 「最近照片」的存储层。
///
/// 负责副本文件的增删查、容量淘汰与孤儿清理。根目录与缩略图生成器都从构造注入，
/// 内部不碰 path_provider，也不碰 dart:ui。
class RecentPhotosStore {
  /// 最多保留多少张。
  static const int maxCount = 10;

  /// 缩略图长边。
  static const int thumbnailMaxSide = 240;

  static const String _prefsKey = 'recent_photos';

  final Directory root;
  final SharedPreferences prefs;
  final ThumbnailGenerator thumbnailGenerator;

  RecentPhotosStore({
    required this.root,
    required this.prefs,
    ThumbnailGenerator? thumbnailGenerator,
  }) : thumbnailGenerator = thumbnailGenerator ?? _noThumbnail;

  /// 未注入生成器时的兜底：不生成缩略图，列表那格显示占位图。
  static Future<void> _noThumbnail(String s, String d, int m) async {}

  Directory get thumbsDir => Directory(p.join(root.path, 'thumbs'));

  String pathOf(RecentPhoto photo) => p.join(root.path, photo.id);

  String thumbnailPathOf(RecentPhoto photo) =>
      p.join(thumbsDir.path, '${photo.id}.png');

  /// 按加入时间从新到旧返回。
  Future<List<RecentPhoto>> load() async {
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return <RecentPhoto>[];
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return <RecentPhoto>[];
    }
    if (decoded is! List) return <RecentPhoto>[];

    final photos = <RecentPhoto>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        photos.add(RecentPhoto.fromJson(Map<String, dynamic>.from(entry)));
      } catch (_) {
        // 单条坏数据不该让整个列表打不开
        continue;
      }
    }
    photos.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return photos;
  }

  /// 加入一张照片。内容已在列表里就复用旧记录，不重复落盘。
  Future<RecentPhoto> add(String sourcePath) async {
    await root.create(recursive: true);
    await thumbsDir.create(recursive: true);

    final bytes = await File(sourcePath).readAsBytes();
    final fingerprint = PhotoFingerprint.of(bytes);

    final existing = await load();
    for (final photo in existing) {
      if (photo.fingerprint == fingerprint && File(pathOf(photo)).existsSync()) {
        return photo;
      }
    }

    final extension = p.extension(sourcePath);
    final id = '${DateTime.now().millisecondsSinceEpoch}'
        '${extension.isEmpty ? '.jpg' : extension}';

    final photo = RecentPhoto(
      id: id,
      fingerprint: fingerprint,
      addedAt: DateTime.now(),
    );

    // 直接复制源字节，不改格式、不重新编码 —— 保留原始画质。
    await File(sourcePath).copy(pathOf(photo));

    try {
      await thumbnailGenerator(
        sourcePath,
        thumbnailPathOf(photo),
        thumbnailMaxSide,
      );
    } catch (_) {
      // 缩略图失败不影响照片本身，列表那格会用占位图
    }

    final updated = <RecentPhoto>[photo, ...existing];
    while (updated.length > maxCount) {
      await _deleteFiles(updated.removeLast());
    }
    await _persist(updated);
    return photo;
  }

  Future<void> remove(String id) async {
    final kept = <RecentPhoto>[];
    for (final photo in await load()) {
      if (photo.id == id) {
        await _deleteFiles(photo);
      } else {
        kept.add(photo);
      }
    }
    await _persist(kept);
  }

  Future<void> clear() async {
    for (final photo in await load()) {
      await _deleteFiles(photo);
    }
    await _persist(<RecentPhoto>[]);
  }

  /// 清掉目录里元数据没有的文件，并剔除元数据里文件已丢失的条目。
  /// 在 App 启动时调一次。
  Future<void> pruneOrphans() async {
    final alive = <RecentPhoto>[];
    for (final photo in await load()) {
      if (File(pathOf(photo)).existsSync()) alive.add(photo);
    }

    final known = <String>{
      for (final photo in alive) p.basename(pathOf(photo)),
      for (final photo in alive) p.basename(thumbnailPathOf(photo)),
    };

    if (root.existsSync()) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (known.contains(p.basename(entity.path))) continue;
        try {
          await entity.delete();
        } catch (_) {
          // 删不掉就留着，下次启动再试
        }
      }
    }

    await _persist(alive);
  }

  Future<void> _deleteFiles(RecentPhoto photo) async {
    for (final path in <String>[pathOf(photo), thumbnailPathOf(photo)]) {
      final file = File(path);
      if (!file.existsSync()) continue;
      try {
        await file.delete();
      } catch (_) {
        // 文件正被占用等情况，忽略即可，pruneOrphans 会兜底
      }
    }
  }

  Future<void> _persist(List<RecentPhoto> photos) async {
    await prefs.setString(
      _prefsKey,
      jsonEncode(photos.map((e) => e.toJson()).toList()),
    );
  }
}
