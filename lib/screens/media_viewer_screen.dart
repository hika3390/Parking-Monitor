import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MediaViewerScreen extends StatefulWidget {
  final File file;
  final bool isVideo;

  const MediaViewerScreen({
    required this.file,
    required this.isVideo,
    super.key,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _showControls = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.file(widget.file);
    try {
      await _videoController!.initialize();
      setState(() {
        _isInitialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '動画の読み込みに失敗しました';
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isVideo ? '動画' : '写真'),
      ),
      body: SizedBox.expand(
        child: widget.isVideo
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _showControls = !_showControls;
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildVideoPlayer(),
                    if (_isInitialized && _showControls) ...[
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const SizedBox.expand(),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 32,
                        child: Row(
                          children: [
                            ValueListenableBuilder(
                              valueListenable: _videoController!,
                              builder: (context, VideoPlayerValue value, child) {
                                final position = value.position;
                                final duration = value.duration;
                                return Text(
                                  '${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')} / ${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ValueListenableBuilder(
                                valueListenable: _videoController!,
                                builder: (context, VideoPlayerValue value, child) {
                                  return Slider(
                                    value: value.position.inMilliseconds.toDouble(),
                                    min: 0,
                                    max: value.duration.inMilliseconds.toDouble(),
                                    activeColor: Colors.white,
                                    inactiveColor: Colors.white.withOpacity(0.3),
                                    onChanged: (newPosition) {
                                      _videoController!.seekTo(
                                        Duration(
                                          milliseconds: newPosition.toInt(),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          iconSize: 48,
                          color: Colors.white,
                          onPressed: () {
                            setState(() {
                              if (_videoController!.value.isPlaying) {
                                _videoController!.pause();
                              } else {
                                _videoController!.play();
                              }
                            });
                          },
                          icon: Icon(
                            _videoController!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : Image.file(
                widget.file,
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }
}
