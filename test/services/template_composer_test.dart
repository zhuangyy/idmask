import 'package:flutter_test/flutter_test.dart';
import 'package:idwm/models/template_fields.dart';
import 'package:idwm/services/template_composer.dart';

void main() {
  final date = DateTime(2026, 9, 12);

  TemplateFields fields({String receiver = '', String purpose = ''}) =>
      TemplateFields(receiver: receiver, purpose: purpose, date: date);

  group('compose 的四种组合', () {
    test('接收方与用途都填', () {
      expect(
        TemplateComposer.compose(fields(receiver: '某某公司', purpose: '入职')),
        '仅供某某公司办理入职使用 2026-09-12',
      );
    });

    test('只填用途', () {
      expect(
        TemplateComposer.compose(fields(purpose: '入职')),
        '仅供办理入职使用 2026-09-12',
      );
    });

    test('只填接收方', () {
      expect(
        TemplateComposer.compose(fields(receiver: '某某公司')),
        '仅供某某公司使用 2026-09-12',
      );
    });

    test('都为空时返回空字符串', () {
      expect(TemplateComposer.compose(fields()), '');
    });

    test('只有空白字符也当作空', () {
      expect(TemplateComposer.compose(fields(receiver: '   ', purpose: '  ')), '');
    });
  });

  group('字段清洗', () {
    test('首尾空白被去掉', () {
      expect(
        TemplateComposer.compose(fields(receiver: '  某某公司 ', purpose: ' 入职  ')),
        '仅供某某公司办理入职使用 2026-09-12',
      );
    });

    test('超长接收方原样保留，不做截断', () {
      final long = '某某' * 100;
      expect(
        TemplateComposer.compose(fields(receiver: long)),
        '仅供$long使用 2026-09-12',
      );
    });
  });

  group('formatDate', () {
    test('月份与日期补零', () {
      expect(TemplateComposer.formatDate(DateTime(2026, 1, 2)), '2026-01-02');
    });

    test('年份按四位输出', () {
      expect(TemplateComposer.formatDate(DateTime(999, 12, 31)), '0999-12-31');
    });
  });
}
