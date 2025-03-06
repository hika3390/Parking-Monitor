import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class MediaStorage {
  static Future<String> get mediaDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/media');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir.path;
  }

  static Future<File> saveMedia(File file, {bool isVideo = false}) async {
    final dir = await mediaDirectory;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = isVideo ? 'mp4' : 'jpg';
    final filename = 'media_$timestamp.$extension';
    final newPath = path.join(dir, filename);
    return file.copy(newPath);
  }
}
