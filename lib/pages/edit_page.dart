import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/watermark_provider.dart';
import '../widgets/photo_canvas.dart';
import '../widgets/recent_photos_sheet.dart';
import '../widgets/recent_texts_sheet.dart';
import '../widgets/style_controls.dart';
import '../widgets/text_input_section.dart';

class EditPage extends StatelessWidget {
  const EditPage({super.key});

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
        title: const Text('证件水印'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // 预览区固定高度、不放进滚动容器 —— 这样后面的拖动手势不会和滚动打架。
          SizedBox(
            height: 320,
            width: double.infinity,
            child: PhotoCanvas(onRequestPick: () => _pick(context)),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => showRecentPhotosSheet(context),
                    icon: const Icon(Icons.history),
                    label: Text('最近照片（${provider.recentPhotos.length}）'),
                  ),
                  const SizedBox(height: 16),
                  const TextInputSection(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => showRecentTextsSheet(context),
                      icon: const Icon(Icons.history),
                      label: Text('最近文案（${provider.recentTexts.length}）'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  const StyleControls(),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: provider.canSave
                        ? () => context.read<WatermarkProvider>().save()
                        : null,
                    icon: provider.isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt),
                    label: Text(provider.isSaving ? '处理中…' : '保存到相册'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
