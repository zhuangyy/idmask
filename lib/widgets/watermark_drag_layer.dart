import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/watermark_provider.dart';

/// 叠在预览上的手势层：拖动水印，并在单块模式拖动期间画十字参考线。
///
/// 只负责「让用户摆水印」，不负责画水印本身 —— 水印仍由 photo_canvas 绘制。
/// 单块模式拖动改 `WatermarkStyle.singlePosition`，平铺模式拖动改网格整体偏移 `tileOffset`。
class WatermarkDragLayer extends StatefulWidget {
  const WatermarkDragLayer({super.key, required this.child});

  final Widget child;

  @override
  State<WatermarkDragLayer> createState() => _WatermarkDragLayerState();
}

class _WatermarkDragLayerState extends State<WatermarkDragLayer> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WatermarkProvider>();
    final enabled = provider.hasPhoto && !provider.isSaving;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: enabled ? (_) => setState(() => _dragging = true) : null,
          onPanUpdate: enabled
              ? (details) {
                  if (size.width <= 0 || size.height <= 0) return;
                  // 用增量而不是「把水印中心设到手指位置」，
                  // 这样水印不会在按下瞬间跳到手指下方。
                  final delta = Offset(
                    details.delta.dx / size.width,
                    details.delta.dy / size.height,
                  );
                  provider.nudgePosition(delta);
                }
              : null,
          onPanEnd: enabled ? (_) => setState(() => _dragging = false) : null,
          onPanCancel: enabled ? () => setState(() => _dragging = false) : null,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              widget.child,
              if (_dragging && enabled)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _GuideLinePainter(
                        position: provider.style.guidePosition,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 穿过水印中心的十字参考线。只画在预览层，不会进成品图。
class _GuideLinePainter extends CustomPainter {
  _GuideLinePainter({required this.position, required this.color});

  final Offset position; // 归一化
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1;

    final x = position.dx * size.width;
    final y = position.dy * size.height;

    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_GuideLinePainter old) =>
      old.position != position || old.color != color;
}
