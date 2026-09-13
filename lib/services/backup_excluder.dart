import 'dart:io';

import 'package:flutter/services.dart';

/// 把照片副本目录排除出 iCloud 备份。
///
/// 这是隐私承诺的一部分：证件照副本不该被同步上云。
/// 只在 iOS 上有意义，其它平台空操作。
class BackupExcluder {
  const BackupExcluder._();

  static const MethodChannel _channel = MethodChannel('com.xzgg.idmask/storage');

  static Future<void> exclude(String path) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<bool>(
        'excludeFromBackup',
        <String, dynamic>{'path': path},
      );
    } catch (_) {
      // 排除备份失败不该挡住 App 启动
    }
  }
}
