import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/watermark_style.dart';
import '../providers/watermark_provider.dart';
import '../services/text_painter_measurer.dart';
import '../services/watermark_layout.dart';
import '../services/watermark_painter.dart';
import 'watermark_drag_layer.dart';

/// 实时预览。
///
/// 与成品图走的是同一套 `WatermarkLayout.compute` + `WatermarkPainter.paint`，
/// 因此预览和输出天然一致。
///
/// 关键点：水印与拖动的坐标系必须是**照片实际显示的区域**，而不是整个预览区。
/// 否则 `BoxFit.contain` 留下的空白也会被盖上水印，与成品图对不上。
class PhotoCanvas extends StatefulWidget {
  const PhotoCanvas({super.key, this.onRequestPick});

  /// 用户点预览区时回调，交给外层打开相册；为 null 时不可点。
  final VoidCallback? onRequestPick;

  @override
  State<PhotoCanvas> createState() => _PhotoCanvasState();
}

class _PhotoCanvasState extends State<PhotoCanvas> {
  ImageStream? _imageStream;
  ImageStreamListener? _listener;
  Size? _photoSize;

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    final listener = _listener;
    if (listener != null) _imageStream?.removeListener(listener);
    _listener = null;
    _imageStream = null;
  }

  /// 解析照片的像素尺寸，用于算出它在预览区里实际占多大。
  ///
  /// 同一张图只解析一次（靠 ImageStream 的 key 判断）。
  void _resolvePhoto(String path) {
    final stream = FileImage(File(path)).resolve(ImageConfiguration.empty);
    if (_imageStream?.key == stream.key) return;

    _detach();
    _imageStream = stream;
    _listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() {
          _photoSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      },
      onError: (Object error, StackTrace? stackTrace) {
        // 图片读不出来时预览也显示不了，保持 _photoSize 为空即可。
      },
    );
    stream.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WatermarkProvider>();
    final path = provider.photoPath;

    final Widget content;
    if (path == null) {
      content = const ColoredBox(
        color: Colors.black12,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.add_photo_alternate_outlined, size: 48),
              SizedBox(height: 8),
              Text('点击这里，从相册选一张证件照'),
            ],
          ),
        ),
      );
    } else {
      _resolvePhoto(path);
      final photoSize = _photoSize;

      content = Center(
        child: photoSize == null
            // 尺寸还没解析好：先只显示照片，不画水印，
            // 避免水印按错误的尺寸闪一下。
            ? Image.file(File(path), fit: BoxFit.contain, gaplessPlayback: true)
            : AspectRatio(
                aspectRatio: photoSize.width / photoSize.height,
                child: WatermarkDragLayer(
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.file(File(path), fit: BoxFit.fill, gaplessPlayback: true),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _WatermarkOverlayPainter(
                            text: provider.effectiveText,
                            style: provider.style,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: provider.isSaving ? null : widget.onRequestPick,
      child: content,
    );
  }
}

/// 只画水印，不画底图 —— 底图交给 Image.file，水印叠在上面。
class _WatermarkOverlayPainter extends CustomPainter {
  _WatermarkOverlayPainter({required this.text, required this.style});

  final String text;
  final WatermarkStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final items = WatermarkLayout.compute(
      canvasSize: size,
      text: text,
      style: style,
      measure: TextPainterMeasurer.measure,
    );
    WatermarkPainter.paint(canvas, items, style);
  }

  @override
  bool shouldRepaint(_WatermarkOverlayPainter old) =>
      old.text != text || old.style != style;
}
