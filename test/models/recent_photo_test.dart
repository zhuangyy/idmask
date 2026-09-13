import 'package:flutter_test/flutter_test.dart';
import 'package:idmask/models/recent_photo.dart';

void main() {
  test('JSON 往返保留全部字段', () {
    final photo = RecentPhoto(
      id: '1757654321000.jpg',
      fingerprint: '12345_abc-def-012',
      addedAt: DateTime.parse('2026-09-12T18:30:00.000'),
    );
    final back = RecentPhoto.fromJson(photo.toJson());
    expect(back, photo);
    expect(back.addedAt, photo.addedAt);
  });

  test('addedAt 序列化为 ISO8601 字符串', () {
    final photo = RecentPhoto(
      id: 'a.png',
      fingerprint: 'f',
      addedAt: DateTime.parse('2026-01-02T03:04:05.000'),
    );
    expect(photo.toJson()['addedAt'], '2026-01-02T03:04:05.000');
  });
}
