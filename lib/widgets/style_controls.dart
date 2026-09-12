import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/watermark_style.dart';
import '../providers/watermark_provider.dart';

/// 透明度、字号、颜色三项。版式在设置页，位置靠拖动。
class StyleControls extends StatelessWidget {
  const StyleControls({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WatermarkProvider>();
    final style = provider.style;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('透明度 ${(style.opacity * 100).round()}%',
            style: Theme.of(context).textTheme.labelLarge),
        Slider(
          value: style.opacity,
          min: WatermarkStyle.minOpacity,
          max: WatermarkStyle.maxOpacity,
          onChanged: (v) => provider.setStyle(style.copyWith(opacity: v)),
        ),
        Text('字号 ${(style.fontSizeRatio * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.labelLarge),
        Slider(
          value: style.fontSizeRatio,
          min: WatermarkStyle.minFontSizeRatio,
          max: WatermarkStyle.maxFontSizeRatio,
          onChanged: (v) => provider.setStyle(style.copyWith(fontSizeRatio: v)),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Text('颜色', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 12),
            for (final value in WatermarkStyle.palette)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ColorDot(
                  value: value,
                  selected: value == style.colorValue,
                  onTap: () =>
                      provider.setStyle(style.copyWith(colorValue: value)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(value),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.black26,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
