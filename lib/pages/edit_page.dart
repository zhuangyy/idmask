import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/watermark_provider.dart';
import '../widgets/photo_canvas.dart';
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

  void _showRecentPhotos() {
    // 后续任务实现最近照片面板
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WatermarkProvider>();

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
          const SizedBox(
            height: 320,
            width: double.infinity,
            child: PhotoCanvas(),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () => _pick(context),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('从相册选照片'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _showRecentPhotos,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
