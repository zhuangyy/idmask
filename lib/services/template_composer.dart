import '../models/template_fields.dart';

/// 把模板字段拼成一句水印文案。
///
/// 纯函数，不依赖任何 Flutter API，可单独测试。
class TemplateComposer {
  const TemplateComposer._();

  /// 两个字段都为空时返回空字符串，表示「没有可用文案」。
  static String compose(TemplateFields fields) {
    final receiver = fields.receiver.trim();
    final purpose = fields.purpose.trim();
    if (receiver.isEmpty && purpose.isEmpty) return '';
    final date = formatDate(fields.date);
    if (receiver.isEmpty) return '仅供办理$purpose使用 $date';
    if (purpose.isEmpty) return '仅供$receiver使用 $date';
    return '仅供$receiver办理$purpose使用 $date';
  }

  /// 固定 YYYY-MM-DD。
  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
