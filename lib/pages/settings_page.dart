import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/watermark_style.dart';
import '../providers/watermark_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WatermarkProvider>();
    final style = provider.style;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: <Widget>[
          const ListTile(
            title: Text('水印版式'),
            subtitle: Text('平铺难以裁剪去除；单块不遮挡画面，可在预览上拖动摆放'),
          ),
          RadioGroup<WatermarkLayoutMode>(
            groupValue: style.mode,
            onChanged: (v) {
              if (v == null) return;
              provider.setStyle(style.copyWith(mode: v));
            },
            child: const Column(
              children: <Widget>[
                RadioListTile<WatermarkLayoutMode>(
                  title: Text('平铺满画面'),
                  value: WatermarkLayoutMode.tile,
                ),
                RadioListTile<WatermarkLayoutMode>(
                  title: Text('单块'),
                  value: WatermarkLayoutMode.single,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
