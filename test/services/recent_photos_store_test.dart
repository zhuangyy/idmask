import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idmask/models/recent_photo.dart';
import 'package:idmask/services/recent_photos_store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempRoot;
  late Directory workDir;
  late SharedPreferences prefs;

  /// 假的缩略图生成器：只写一个固定内容的小文件，避免测试依赖真实的图片解码。
  Future<void> fakeThumbnail(String source, String dest, int maxSide) async {
    final file = File(dest);
    await file.parent.create(recursive: true);
    await file.writeAsString('thumb:$maxSide');
  }

  RecentPhotosStore newStore() => RecentPhotosStore(
        root: tempRoot,
        prefs: prefs,
        thumbnailGenerator: fakeThumbnail,
      );

  /// 造一个源文件，内容由 seed 决定。
  Future<String> sourceFile(String name, {int seed = 0}) async {
    final file = File(p.join(workDir.path, name));
    await file.writeAsBytes(List<int>.generate(2048, (i) => (i + seed) % 256));
    return file.path;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    tempRoot = await Directory.systemTemp.createTemp('idmask_store_test_');
    workDir = await Directory.systemTemp.createTemp('idmask_src_test_');
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
    if (workDir.existsSync()) await workDir.delete(recursive: true);
  });

  group('add', () {
    test('副本落盘且字节与源文件一致', () async {
      final store = newStore();
      final src = await sourceFile('a.jpg', seed: 1);
      final photo = await store.add(src);

      final copy = File(store.pathOf(photo));
      expect(copy.existsSync(), isTrue);
      expect(await copy.readAsBytes(), await File(src).readAsBytes());
    });

    test('id 保留源文件的扩展名', () async {
      final store = newStore();
      final photo = await store.add(await sourceFile('a.png', seed: 2));
      expect(p.extension(photo.id), '.png');
    });

    test('缩略图写到 thumbs/ 下，长边用 240', () async {
      final store = newStore();
      final photo = await store.add(await sourceFile('a.jpg', seed: 3));
      expect(File(store.thumbnailPathOf(photo)).existsSync(), isTrue);
      expect(await File(store.thumbnailPathOf(photo)).readAsString(), 'thumb:240');
    });

    test('load 返回刚加入的那条', () async {
      final store = newStore();
      final photo = await store.add(await sourceFile('a.jpg', seed: 4));
      final list = await store.load();
      expect(list.length, 1);
      expect(list.single.id, photo.id);
    });

    test('重复加入同一张照片只留一条', () async {
      final store = newStore();
      final src = await sourceFile('a.jpg', seed: 5);
      final first = await store.add(src);
      final second = await store.add(src);

      expect(second.id, first.id);
      expect((await store.load()).length, 1);

      final extraFiles = Directory(tempRoot.path)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => !p.basename(f.path).startsWith(first.id))
          .toList();
      expect(extraFiles, isEmpty, reason: '不该留下多余的副本文件');
    });

    test('内容相同但文件名不同的两份，也判为同一张', () async {
      final store = newStore();
      await store.add(await sourceFile('a.jpg', seed: 6));
      await store.add(await sourceFile('b.jpg', seed: 6));
      expect((await store.load()).length, 1);
    });

    test('第 11 条加入时最旧的记录与它的文件一起消失', () async {
      final store = newStore();
      final added = <RecentPhoto>[];
      for (var i = 0; i < 11; i++) {
        added.add(await store.add(await sourceFile('p$i.jpg', seed: 100 + i)));
      }

      final list = await store.load();
      expect(list.length, RecentPhotosStore.maxCount);
      expect(list.map((e) => e.id), isNot(contains(added.first.id)));
      expect(File(store.pathOf(added.first)).existsSync(), isFalse);
      expect(File(store.thumbnailPathOf(added.first)).existsSync(), isFalse);
    });

    test('load 按加入时间从新到旧', () async {
      final store = newStore();
      for (var i = 0; i < 3; i++) {
        await store.add(await sourceFile('q$i.jpg', seed: 200 + i));
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      final list = await store.load();
      for (var i = 0; i < list.length - 1; i++) {
        expect(list[i].addedAt.isAfter(list[i + 1].addedAt), isTrue);
      }
    });
  });

  group('remove 与 clear', () {
    test('remove 同时删掉副本与缩略图', () async {
      final store = newStore();
      final photo = await store.add(await sourceFile('a.jpg', seed: 7));
      await store.remove(photo.id);

      expect(File(store.pathOf(photo)).existsSync(), isFalse);
      expect(File(store.thumbnailPathOf(photo)).existsSync(), isFalse);
      expect(await store.load(), isEmpty);
    });

    test('remove 一个不存在的 id 不抛异常', () async {
      final store = newStore();
      await expectLater(store.remove('nope.jpg'), completes);
    });

    test('clear 之后除空目录外无残留', () async {
      final store = newStore();
      await store.add(await sourceFile('a.jpg', seed: 8));
      await store.add(await sourceFile('b.jpg', seed: 9));
      await store.clear();

      expect(await store.load(), isEmpty);
      final leftovers = Directory(tempRoot.path)
          .listSync(recursive: true)
          .whereType<File>()
          .toList();
      expect(leftovers, isEmpty);
    });
  });

  group('pruneOrphans', () {
    test('清掉元数据里没有的文件', () async {
      final store = newStore();
      final kept = await store.add(await sourceFile('a.jpg', seed: 10));

      await File(p.join(tempRoot.path, 'orphan.jpg')).writeAsString('x');
      await File(p.join(tempRoot.path, 'thumbs', 'orphan.png')).writeAsString('x');

      await store.pruneOrphans();

      expect(File(p.join(tempRoot.path, 'orphan.jpg')).existsSync(), isFalse);
      expect(File(p.join(tempRoot.path, 'thumbs', 'orphan.png')).existsSync(), isFalse);
      expect(File(store.pathOf(kept)).existsSync(), isTrue);
      expect((await store.load()).length, 1);
    });

    test('元数据里有但文件没了的条目被剔除', () async {
      final store = newStore();
      final photo = await store.add(await sourceFile('a.jpg', seed: 11));
      await File(store.pathOf(photo)).delete();

      await store.pruneOrphans();
      expect(await store.load(), isEmpty);
    });
  });

  group('容错', () {
    test('源文件不存在时 add 抛出异常，由调用方决定降级', () async {
      final store = newStore();
      await expectLater(
        store.add(p.join(workDir.path, 'not-there.jpg')),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
