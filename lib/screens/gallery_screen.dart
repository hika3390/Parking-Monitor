import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'media_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<File> _mediaFiles = [];
  bool _isLoading = true;

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

      final files = await mediaDir.list().toList();
      _mediaFiles = files
          .where((file) => file.path.endsWith('.jpg') || file.path.endsWith('.mp4'))
          .map((file) => File(file.path))
          .toList();

      // 新しい順に並び替え
      _mediaFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
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
    try {
      final result = await ImageGallerySaver.saveFile(file.path);
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
    return Card(
      margin: const EdgeInsets.all(4),
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
                ? Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  )
                : FadeInImage(
                    placeholder: MemoryImage(kTransparentImage),
                    image: FileImage(file),
                    fit: BoxFit.cover,
                  ),
            // アクションボタン
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.save_alt, color: Colors.white),
                    onPressed: () => _saveToGallery(file),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _showDeleteDialog(file),
                  ),
                ],
              ),
            ),
            // タイムスタンプ
            Positioned(
              bottom: 8,
              left: 8,
              child: Text(
                '${file.lastModifiedSync().toString().split('.')[0]}',
                style: const TextStyle(
                  color: Colors.white,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mediaFiles.isEmpty
              ? const Center(
                  child: Text('メディアがありません'),
                )
              : RefreshIndicator(
                  onRefresh: _loadMediaFiles,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.0,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: _mediaFiles.length,
                    itemBuilder: (context, index) {
                      return _buildMediaTile(_mediaFiles[index]);
                    },
                  ),
                ),
    );
  }
}
