import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:idmask/models/watermark_style.dart';
import 'package:idmask/services/backup_excluder.dart';
import 'package:idmask/services/image_renderer.dart';
import 'package:idmask/services/jpeg_encoder.dart';

/// 在真机 / 模拟器上跑的端到端检查。
///
/// 这三件事无法用 `flutter test`（纯 Dart VM）覆盖，因为都跨平台通道或依赖
/// 真实解码器：
///   1. `com.xzgg.idmask/jpeg` —— PNG → JPEG 的原生编码
///   2. 渲染链 —— 解码 → 绘制 → 编码 → 写临时文件
///   3. `com.xzgg.idmask/storage` —— iOS 的 iCloud 备份排除
///
/// 运行方式（需指定设备）：
///   flutter test integration_test/platform_channels_test.dart -d `<device-id>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('平台通道：PNG 交给原生编码，返回合法 JPEG', (tester) async {
    final png = await _makePng(240, 160);
    expect(png.length, greaterThan(0));

    final jpeg = await JpegEncoder.encode(png);

    expect(
      jpeg,
      isNotNull,
      reason: '通道未实现或调用失败 —— 上层会静默回退成保存 PNG，这里必须拦住',
    );
    // JPEG 文件头 SOI = FF D8
    expect(jpeg!.length, greaterThan(100));
    expect(jpeg[0], 0xFF);
    expect(jpeg[1], 0xD8);
  });

  testWidgets('渲染链：解码 → 绘制水印 → 编码 → 写出 JPEG 文件', (tester) async {
    final dir = await getTemporaryDirectory();
    final source = File('${dir.path}/idmask_it_source.png');
    await source.writeAsBytes(await _makePng(600, 400));

    final result = await ImageRenderer.render(
      sourcePath: source.path,
      text: '仅供集成测试使用 2026-09-14',
      style: const WatermarkStyle(),
    );

    expect(await result.file.exists(), isTrue);
    expect(result.wasDownscaled, isFalse, reason: '600×400 远小于 4096 上限');
    expect(
      result.usedPngFallback,
      isFalse,
      reason: '走到 PNG 回退说明 JPEG 通道没工作',
    );
    expect(result.file.path, endsWith('.jpg'));

    final bytes = await result.file.readAsBytes();
    expect(bytes[0], 0xFF, reason: '输出应是 JPEG');
    expect(bytes[1], 0xD8);

    await source.delete();
    await result.file.delete();
  });

  testWidgets('存储通道：请求把目录排除出 iCloud 备份不报错', (tester) async {
    final dir = await getTemporaryDirectory();
    final target = Directory('${dir.path}/idmask_it_exclude')
      ..createSync(recursive: true);

    // 失败会被内部吞掉，所以这里只能确认「调用链可达、不崩」；
    // 属性是否真的落到文件系统上，由 shell 侧 xattr 复核。
    await BackupExcluder.exclude(target.path);

    if (Platform.isIOS) {
      expect(target.existsSync(), isTrue);
    }
    target.deleteSync(recursive: true);
  });
}

/// 用 dart:ui 现画一张 PNG，免得测试依赖仓库里的素材文件。
Future<Uint8List> _makePng(int width, int height) async {
  final w = width.toDouble();
  final h = height.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, w, h));

  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, w, h),
    ui.Paint()..color = const ui.Color(0xFFE8EEF7),
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(w * 0.2, h * 0.25, w * 0.6, h * 0.5),
    ui.Paint()..color = const ui.Color(0xFF2D6BB5),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();

  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) {
    throw StateError('测试素材 PNG 生成失败');
  }
  return data.buffer.asUint8List();
}
