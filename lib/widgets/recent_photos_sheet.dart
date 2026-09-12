import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recent_photo.dart';
import '../providers/watermark_provider.dart';

/// 最近照片的缩略图网格。点选即用，长按删除，底部可一键清空。
Future<void> showRecentPhotosSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _RecentPhotosSheet(),
  );
}

class _RecentPhotosSheet extends StatelessWidget {
  const _RecentPhotosSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WatermarkProvider>();
    final photos = provider.recentPhotos;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('最近照片', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (photos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('还没有用过的照片')),
              )
            else
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return _PhotoTile(
                      photo: photo,
                      onTap: () async {
                        await context
                            .read<WatermarkProvider>()
                            .selectRecentPhoto(photo);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            if (photos.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _confirmClear(context),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('清空全部'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空最近照片？'),
        content: const Text('App 里保存的这些照片副本会被删掉，系统相册里的原图不受影响。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<WatermarkProvider>().clearRecentPhotos();
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.onTap});

  final RecentPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WatermarkProvider>();
    final thumb = File(provider.photosStore.thumbnailPathOf(photo));

    return InkWell(
      onTap: onTap,
      onLongPress: () => _confirmDelete(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: thumb.existsSync()
            ? Image.file(thumb, fit: BoxFit.cover)
            : Container(
                color: Colors.black12,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这张照片？'),
        content: const Text('只会删掉 App 里的副本，系统相册里的原图不受影响。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<WatermarkProvider>().removeRecentPhoto(photo.id);
  }
}
