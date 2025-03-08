import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

enum ViewMode {
  grid,
  list,
}

class MediaFile {
  final File file;
  final DateTime lastModified;
  final int size;
  final String name;
  final bool isVideo;

  MediaFile({
    required this.file,
    required this.lastModified,
    required this.size,
    required this.name,
    required this.isVideo,
  });

  static MediaFile fromFile(File file) {
    return MediaFile(
      file: file,
      lastModified: file.lastModifiedSync(),
      size: file.lengthSync(),
      name: file.path.split('/').last,
      isVideo: file.path.endsWith('.mp4'),
    );
  }
}

class GalleryService {
  final Map<String, File> _videoThumbnails = {};
  List<MediaFile> _mediaFiles = [];

  List<MediaFile> get mediaFiles => _mediaFiles;
  Map<String, File> get videoThumbnails => _videoThumbnails;

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return '今日 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '昨日 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> loadMediaFiles() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/media');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    // サムネイル画像を除外してファイルをフィルタリング
    final files = await mediaDir.list().where((entity) {
      final path = entity.path.toLowerCase();
      return (path.endsWith('.jpg') || path.endsWith('.mp4')) && 
             !path.contains('thumb_') && 
             !path.contains('thumbnail_');
    }).toList();
    
    _mediaFiles = files
        .map((file) => MediaFile.fromFile(File(file.path)))
        .toList();

    // 新しい順に並び替え
    _mediaFiles.sort((a, b) => b.lastModified.compareTo(a.lastModified));

    // ビデオファイルのサムネイルを生成
    for (final file in _mediaFiles) {
      if (file.isVideo) {
        await _generateVideoThumbnail(file.file);
      }
    }
  }

  Future<void> _generateVideoThumbnail(File videoFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
        imageFormat: ImageFormat.JPEG,
        quality: 75,
      );
      
      if (thumbnailPath != null) {
        _videoThumbnails[videoFile.path] = File(thumbnailPath);
      }
    } catch (e) {
      print('サムネイル生成エラー: $e');
    }
  }

  Future<void> deleteFile(MediaFile mediaFile) async {
    await mediaFile.file.delete();
    await loadMediaFiles();
  }

  Future<void> saveToGallery(MediaFile mediaFile) async {
    await ImageGallerySaver.saveFile(mediaFile.file.path);
  }
}
