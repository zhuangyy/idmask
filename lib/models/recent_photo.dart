/// 最近照片的元数据。图片文件本身在私有目录里，这里只记索引信息。
class RecentPhoto {
  /// 副本文件名（含扩展名），同时是列表键。
  final String id;

  /// 内容指纹，用于去重。存下来避免每次选图都重算 10 个文件的指纹。
  final String fingerprint;

  /// 加入时间，用于排序与展示。
  final DateTime addedAt;

  const RecentPhoto({
    required this.id,
    required this.fingerprint,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fingerprint': fingerprint,
        'addedAt': addedAt.toIso8601String(),
      };

  factory RecentPhoto.fromJson(Map<String, dynamic> json) => RecentPhoto(
        id: json['id'] as String,
        fingerprint: json['fingerprint'] as String? ?? '',
        addedAt: DateTime.parse(json['addedAt'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is RecentPhoto &&
      other.id == id &&
      other.fingerprint == fingerprint &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(id, fingerprint, addedAt);

  @override
  String toString() => 'RecentPhoto($id, $fingerprint, $addedAt)';
}
