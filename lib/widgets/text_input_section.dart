import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/watermark_provider.dart';

import 'recent_texts_sheet.dart';

/// 水印文案输入。只有一个输入框，外加一个把今天日期插进光标处的快捷按钮。
class TextInputSection extends StatelessWidget {
  const TextInputSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WatermarkProvider>();
    return _TextInput(
      text: provider.text,
      onChanged: provider.setText,
      recentTextsCount: provider.recentTexts.length,
    );
  }
}

class _TextInput extends StatefulWidget {
  const _TextInput({
    required this.text,
    required this.onChanged,
    required this.recentTextsCount,
  });

  final String text;
  final ValueChanged<String> onChanged;
  final int recentTextsCount;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(_TextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 文案被外部改了（例如从「最近文案」里选了一条），同步回输入框。
    if (widget.text != _controller.text) {
      _controller.text = widget.text;
      _controller.selection =
          TextSelection.collapsed(offset: widget.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 把今天的日期插到光标处；没聚焦时追加到末尾。
  void _insertToday() {
    final date = _formatDate(DateTime.now());
    final selection = _controller.selection;
    final hasSelection = selection.isValid;
    final start = hasSelection ? selection.start : _controller.text.length;
    final end = hasSelection ? selection.end : _controller.text.length;
    final updated = _controller.text.replaceRange(start, end, date);

    _controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + date.length),
    );
    widget.onChanged(updated);
    _focusNode.requestFocus();
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          minLines: 1,
          maxLines: 3,
          inputFormatters: <TextInputFormatter>[
            _CollapseNewlinesFormatter(),
          ],
          decoration: InputDecoration(
            labelText: '水印文字',
            hintText: '例如：仅供某某公司办理入职使用 2026-09-12',
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: widget.onChanged,
        ),
        Row(
          children: <Widget>[
            TextButton.icon(
              onPressed: () => showRecentTextsSheet(context),
              icon: const Icon(Icons.history, size: 18),
              label: Text(
                '最近文案（${widget.recentTextsCount}）',
                style: theme.textTheme.labelMedium,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _insertToday,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(
                '插入今天日期',
                style: theme.textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 把换行折叠成空格：水印只画单行，输入框里不该出现换行符。
///
/// 直接删掉会让粘贴进来的多行文本首尾粘连，所以折叠成空格。
class _CollapseNewlinesFormatter extends TextInputFormatter {
  static final RegExp _newlines = RegExp(r'[\r\n]+');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!_newlines.hasMatch(newValue.text)) return newValue;

    final collapsed = newValue.text.replaceAll(_newlines, ' ');
    final removed = newValue.text.length - collapsed.length;
    final offset =
        (newValue.selection.baseOffset - removed).clamp(0, collapsed.length);
    return TextEditingValue(
      text: collapsed,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
