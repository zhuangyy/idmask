import 'dart:math' as math;

/// 由文件字节算出用于去重的指纹。
///
/// 只抽样首、中、末三段，而不是读全文件 —— 去重不值得为此多读几 MB。
/// 它要防的是「用户重复选同一张照片」，不是恶意构造碰撞。
///
/// 用自己写的 FNV-1a 而不是 crypto 包的 SHA-256，是因为不值得为这个用途多引入依赖。
class PhotoFingerprint {
  const PhotoFingerprint._();

  static const int sampleSize = 4096;

  /// 形如 `123456_abcdef-012345-6789ab`：总长度 + 三段哈希。
  static String of(List<int> bytes) {
    final part0 = fnv1a(_sampleAt(bytes, 0));
    final part1 = fnv1a(_sampleAt(bytes, (bytes.length - sampleSize) ~/ 2));
    final part2 = fnv1a(_sampleAt(bytes, bytes.length - sampleSize));
    return '${bytes.length}_'
        '${part0.toRadixString(16)}-'
        '${part1.toRadixString(16)}-'
        '${part2.toRadixString(16)}';
  }

  static List<int> _sampleAt(List<int> bytes, int start) {
    if (bytes.isEmpty) return const <int>[];
    final from = start < 0 ? 0 : start;
    final to = math.min(from + sampleSize, bytes.length);
    if (from >= to) return const <int>[];
    return bytes.sublist(from, to);
  }

  /// FNV-1a，结果保持在 32 位内。
  static int fnv1a(List<int> data) {
    var hash = 0x811c9dc5;
    for (final byte in data) {
      hash ^= byte & 0xFF;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
