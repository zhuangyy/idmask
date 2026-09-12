import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/watermark_provider.dart';

/// 最近用过的文案，点一条即填回自由编辑模式。
Future<void> showRecentTextsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _RecentTextsSheet(),
  );
}

class _RecentTextsSheet extends StatelessWidget {
  const _RecentTextsSheet();

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<WatermarkProvider>().recentTexts;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('最近文案', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (texts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('还没有用过的文案')),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: texts.length,
                  itemBuilder: (context, index) {
                    final text = texts[index];
                    return ListTile(
                      title: Text(text),
                      onTap: () {
                        context.read<WatermarkProvider>().applyRecentText(text);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
