import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:idmask/services/photo_fingerprint.dart';

Uint8List bytesOf(int length, {int seed = 0}) {
  final rnd = math.Random(seed);
  return Uint8List.fromList(
    List<int>.generate(length, (_) => rnd.nextInt(256)),
  );
}

void main() {
  test('同样的字节得到同样的指纹', () {
    final a = bytesOf(20000, seed: 1);
    final b = Uint8List.fromList(a);
    expect(PhotoFingerprint.of(a), PhotoFingerprint.of(b));
  });

  test('改动开头、中间、结尾的任意一段都会改变指纹', () {
    final base = bytesOf(30000, seed: 2);
    final original = PhotoFingerprint.of(base);

    for (final offset in <int>[10, 15000, 29990]) {
      final changed = Uint8List.fromList(base);
      changed[offset] = changed[offset] ^ 0xFF;
      expect(PhotoFingerprint.of(changed), isNot(original),
          reason: '改动 offset=$offset 后指纹没变');
    }
  });

  test('长度不同则指纹不同', () {
    expect(
      PhotoFingerprint.of(bytesOf(10000, seed: 3)),
      isNot(PhotoFingerprint.of(bytesOf(10001, seed: 3))),
    );
  });

  test('空字节不崩', () {
    expect(PhotoFingerprint.of(<int>[]), isNotEmpty);
  });

  test('比抽样长度还短的文件不崩，且不同内容不同指纹', () {
    final a = <int>[1, 2, 3];
    final b = <int>[1, 2, 4];
    expect(PhotoFingerprint.of(a), isNot(PhotoFingerprint.of(b)));
  });

  test('fnv1a 对空输入返回 32 位偏移基准', () {
    expect(PhotoFingerprint.fnv1a(const <int>[]), 0x811c9dc5);
  });

  test('fnv1a 结果始终落在 32 位内', () {
    expect(PhotoFingerprint.fnv1a(bytesOf(100000, seed: 4)),
        lessThanOrEqualTo(0xFFFFFFFF));
  });
}
