import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/edit_page.dart';
import 'pages/settings_page.dart';
import 'providers/watermark_provider.dart';
import 'services/recent_photos_store.dart';
import 'services/recent_texts_store.dart';
import 'services/thumbnail_generator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final supportDir = await getApplicationSupportDirectory();
  final photosDir = Directory(p.join(supportDir.path, 'idwm_photos'));

  final provider = WatermarkProvider(
    photosStore: RecentPhotosStore(
      root: photosDir,
      prefs: prefs,
      thumbnailGenerator: DartUiThumbnailGenerator.generate,
    ),
    textsStore: RecentTextsStore(prefs: prefs),
  );
  await provider.loadFromStorage();

  runApp(
    ChangeNotifierProvider<WatermarkProvider>.value(
      value: provider,
      child: const IdwmApp(),
    ),
  );
}

class IdwmApp extends StatelessWidget {
  const IdwmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '证件水印',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E6FD9),
        useMaterial3: true,
      ),
      routes: <String, WidgetBuilder>{
        '/': (_) => const EditPage(),
        '/settings': (_) => const SettingsPage(),
      },
    );
  }
}
