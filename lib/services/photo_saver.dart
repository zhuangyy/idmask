import 'package:gal/gal.dart';

/// 把成品文件写进系统相册。原图不受影响。
class PhotoSaver {
  const PhotoSaver._();

  static Future<void> save(String filePath) async {
    await Gal.putImage(filePath);
  }
}
