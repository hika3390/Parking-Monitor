import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'media_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

enum ViewMode {
  grid,
  list,
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<File> _mediaFiles = [];
  bool _isLoading = true;
  final Map<String, File> _videoThumbnails = {};
  ViewMode _viewMode = ViewMode.list;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }

  @override
  void initState() {
    super.initState();
    _loadMediaFiles();
  }

  Future<void> _loadMediaFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
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
      
      _mediaFiles = files.map((file) => File(file.path)).toList();

      // 新しい順に並び替え
      _mediaFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // ビデオファイルのサムネイルを生成
      for (final file in _mediaFiles) {
        if (file.path.endsWith('.mp4')) {
          await _generateVideoThumbnail(file);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('メディアの読み込みに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
      debugPrint('サムネイル生成エラー: $e');
    }
  }

  Future<void> _deleteFile(File file) async {
    try {
      await file.delete();
      await _loadMediaFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ファイルの削除に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _saveToGallery(File file) async {
    final isVideo = file.path.endsWith('.mp4');
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text('この${isVideo ? '動画' : '写真'}をカメラロールに保存しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (shouldSave != true) return;

    try {
      await ImageGallerySaver.saveFile(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('カメラロールに保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  Widget _buildMediaTile(File file) {
    final isVideo = file.path.endsWith('.mp4');
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaViewerScreen(
                  file: file,
                  isVideo: isVideo,
                ),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // サムネイル画像
              isVideo
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        _videoThumbnails.containsKey(file.path)
                            ? FadeInImage(
                                placeholder: MemoryImage(kTransparentImage),
                                image: FileImage(_videoThumbnails[file.path]!),
                                fit: BoxFit.cover,
                              )
                            : Container(color: Colors.black),
                        const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : FadeInImage(
                      placeholder: MemoryImage(kTransparentImage),
                      image: FileImage(file),
                      fit: BoxFit.cover,
                    ),
              // アクションボタン
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.save_alt,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () => _saveToGallery(file),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 22,
                        ),
                        onPressed: () => _showDeleteDialog(file),
                      ),
                    ],
                  ),
                ),
              ),
              // タイムスタンプ
              Positioned(
                bottom: 8,
                left: 8,
                child: Text(
                  _formatDateTime(file.lastModifiedSync()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  strutStyle: const StrutStyle(
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(File file) {
    final isVideo = file.path.endsWith('.mp4');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaViewerScreen(
                file: file,
                isVideo: isVideo,
              ),
            ),
          );
        },
        leading: SizedBox(
          width: 56,
          height: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                isVideo
                    ? _videoThumbnails.containsKey(file.path)
                        ? Image.file(
                            _videoThumbnails[file.path]!,
                            fit: BoxFit.cover,
                          )
                        : Container(color: Colors.black)
                    : Image.file(
                        file,
                        fit: BoxFit.cover,
                      ),
                if (isVideo)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.videocam,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: _getFileName(file.path),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const TextSpan(text: '\n'),
              TextSpan(
                text: _formatFileSize(file.lengthSync()),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        subtitle: Text(_formatDateTime(file.lastModifiedSync())),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.save_alt),
              onPressed: () => _saveToGallery(file),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete,
                color: Colors.red,
              ),
              onPressed: () => _showDeleteDialog(file),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      // 今日の場合は時刻のみ
      return '今日 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '昨日 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // それ以外は月日と時刻
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _showDeleteDialog(File file) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: const Text('このファイルを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '削除',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteFile(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ギャラリー'),
        actions: [
          PopupMenuButton<ViewMode>(
            icon: const Icon(Icons.more_vert),
            onSelected: (ViewMode mode) {
              setState(() {
                _viewMode = mode;
              });
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: ViewMode.grid,
                child: Row(
                  children: [
                    Icon(
                      Icons.grid_view,
                      color: _viewMode == ViewMode.grid ? Colors.blue : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'サムネイル表示',
                      style: TextStyle(
                        color: _viewMode == ViewMode.grid ? Colors.blue : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ViewMode.list,
                child: Row(
                  children: [
                    Icon(
                      Icons.list,
                      color: _viewMode == ViewMode.list ? Colors.blue : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'リスト表示',
                      style: TextStyle(
                        color: _viewMode == ViewMode.list ? Colors.blue : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mediaFiles.isEmpty
              ? const Center(
                  child: Text('メディアがありません'),
                )
              : RefreshIndicator(
                  onRefresh: _loadMediaFiles,
                  child: _viewMode == ViewMode.grid
                      ? GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.0,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: _mediaFiles.length,
                          itemBuilder: (context, index) {
                            return _buildMediaTile(_mediaFiles[index]);
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _mediaFiles.length,
                          itemBuilder: (context, index) {
                            return _buildListTile(_mediaFiles[index]);
                          },
                        ),
                ),
    );
  }
}
