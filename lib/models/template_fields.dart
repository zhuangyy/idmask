/// 模板模式的三个字段。
class TemplateFields {
  final String receiver; // 接收方：证件交给谁
  final String purpose; // 用途：办理什么事
  final DateTime date; // 使用日期

  TemplateFields({
    this.receiver = '',
    this.purpose = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  TemplateFields copyWith({
    String? receiver,
    String? purpose,
    DateTime? date,
  }) {
    return TemplateFields(
      receiver: receiver ?? this.receiver,
      purpose: purpose ?? this.purpose,
      date: date ?? this.date,
    );
  }
}
