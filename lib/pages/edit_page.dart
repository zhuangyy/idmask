import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/watermark_provider.dart';
import '../widgets/photo_canvas.dart';
import '../widgets/recent_photos_sheet.dart';
import '../widgets/section_card.dart';
import '../widgets/style_controls.dart';
import '../widgets/text_input_section.dart';

class EditPage extends StatelessWidget {
  const EditPage({super.key, required this.version});

  /// App 版本号，以小字显示在标题后面。
  final String version;

  Future<void> _pick(BuildContext context) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return; // 用户取消，静默返回
    if (!context.mounted) return;
    await context.read<WatermarkProvider>().pickPhoto(picked.path);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WatermarkProvider>();

    // 一次性消息提示：message 非空时在下一帧弹 SnackBar，并顺带带上警告文本。
    final message = provider.message;
    if (message != null) {
      final warning = provider.lastWarning;
      final text = warning == null ? message : '$message（$warning）';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
        context.read<WatermarkProvider>().clearMessage();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            const Text('证件水印'),
            const SizedBox(width: 6),
            Text(
              'v$version',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => showRecentPhotosSheet(context),
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: Text('最近照片（${provider.recentPhotos.length}）'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          // 预览区固定高度、不放进滚动容器 ——
          // 否则里面的拖动手势会和页面滚动在手势竞技场里打架。
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              height: 320,
              child: SectionCard(
                padding: EdgeInsets.zero,
                child: PhotoCanvas(onRequestPick: () => _pick(context)),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SectionCard(child: TextInputSection()),
                  const SizedBox(height: 16),
                  const SectionCard(child: StyleControls()),
                ],
              ),
            ),
          ),
          _SaveBar(
            enabled: provider.canSave,
            saving: provider.isSaving,
            onPressed: () => context.read<WatermarkProvider>().save(),
          ),
        ],
      ),
    );
  }
}

/// 固定在底部的保存条。
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.enabled,
    required this.saving,
    required this.onPressed,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt),
              label: Text(saving ? '处理中…' : '保存到相册'),
            ),
          ),
        ),
      ),
    );
  }
}
