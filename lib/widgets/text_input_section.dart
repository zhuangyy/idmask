import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/template_fields.dart';
import '../providers/watermark_provider.dart';
import '../services/template_composer.dart';

/// 模板与自由编辑双模式。两个模式的输入内容各自保留，来回切换不丢东西。
class TextInputSection extends StatelessWidget {
  const TextInputSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WatermarkProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedButton<bool>(
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(value: true, label: Text('模板')),
            ButtonSegment<bool>(value: false, label: Text('自由编辑')),
          ],
          selected: <bool>{provider.useTemplate},
          onSelectionChanged: (selection) =>
              provider.setUseTemplate(selection.first),
        ),
        const SizedBox(height: 12),
        if (provider.useTemplate)
          _TemplateFieldsInput(fields: provider.templateFields)
        else
          _FreeTextInput(text: provider.freeText),
        const SizedBox(height: 12),
        _GeneratedPreview(text: provider.effectiveText),
      ],
    );
  }
}

class _TemplateFieldsInput extends StatelessWidget {
  const _TemplateFieldsInput({required this.fields});

  final TemplateFields fields;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WatermarkProvider>();

    return Column(
      children: <Widget>[
        TextFormField(
          initialValue: fields.receiver,
          decoration: const InputDecoration(
            labelText: '接收方',
            hintText: '例如：某某公司',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) =>
              provider.setTemplateFields(fields.copyWith(receiver: v)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: fields.purpose,
          decoration: const InputDecoration(
            labelText: '用途',
            hintText: '例如：入职',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) =>
              provider.setTemplateFields(fields.copyWith(purpose: v)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text('日期：${TemplateComposer.formatDate(fields.date)}'),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: fields.date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked == null) return;
            provider.setTemplateFields(fields.copyWith(date: picked));
          },
        ),
      ],
    );
  }
}

class _FreeTextInput extends StatelessWidget {
  const _FreeTextInput({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WatermarkProvider>();

    return TextFormField(
      initialValue: text,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: '水印文字',
        hintText: '例如：仅供某某公司办理入职使用 2026-09-12',
        border: OutlineInputBorder(),
      ),
      onChanged: provider.setFreeText,
    );
  }
}

class _GeneratedPreview extends StatelessWidget {
  const _GeneratedPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text('将显示：$text', style: Theme.of(context).textTheme.bodySmall);
  }
}
