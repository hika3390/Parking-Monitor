import 'package:flutter/material.dart';
import 'package:transparent_image/transparent_image.dart';
import '../services/gallery_service.dart';
import 'media_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final GalleryService _galleryService = GalleryService();
  bool _isLoading = true;
  ViewMode _viewMode = ViewMode.list;

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
      await _galleryService.loadMediaFiles();
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

  Future<void> _deleteFile(MediaFile file) async {
    try {
      await _galleryService.deleteFile(file);
      setState(() {}); // 画面を更新
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ファイルの削除に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _saveToGallery(MediaFile file) async {
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text('この${file.isVideo ? '動画' : '写真'}をカメラロールに保存しますか？'),
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
      await _galleryService.saveToGallery(file);
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

  Widget _buildMediaTile(MediaFile file) {
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
                  file: file.file,
                  isVideo: file.isVideo,
                ),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // サムネイル画像
              file.isVideo
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        _galleryService.videoThumbnails.containsKey(file.file.path)
                            ? FadeInImage(
                                placeholder: MemoryImage(kTransparentImage),
                                image: FileImage(_galleryService.videoThumbnails[file.file.path]!),
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
                      image: FileImage(file.file),
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
                  _galleryService.formatDateTime(file.lastModified),
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

  Widget _buildListTile(MediaFile file) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaViewerScreen(
                file: file.file,
                isVideo: file.isVideo,
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
                file.isVideo
                    ? _galleryService.videoThumbnails.containsKey(file.file.path)
                        ? Image.file(
                            _galleryService.videoThumbnails[file.file.path]!,
                            fit: BoxFit.cover,
                          )
                        : Container(color: Colors.black)
                    : Image.file(
                        file.file,
                        fit: BoxFit.cover,
                      ),
                if (file.isVideo)
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
                text: file.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const TextSpan(text: '\n'),
              TextSpan(
                text: _galleryService.formatFileSize(file.size),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        subtitle: Text(_galleryService.formatDateTime(file.lastModified)),
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

  Future<void> _showDeleteDialog(MediaFile file) async {
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
          : _galleryService.mediaFiles.isEmpty
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
                          itemCount: _galleryService.mediaFiles.length,
                          itemBuilder: (context, index) {
                            return _buildMediaTile(_galleryService.mediaFiles[index]);
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _galleryService.mediaFiles.length,
                          itemBuilder: (context, index) {
                            return _buildListTile(_galleryService.mediaFiles[index]);
                          },
                        ),
                ),
    );
  }
}
