import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/detection_service.dart';
import '../services/mail_service.dart';
import '../utils/config.dart';
import '../utils/media_storage.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  DetectionService? _detectionService;
  Timer? _detectionTimer;
  bool _isDetecting = false;
  bool _hasCameraPermission = false;
  bool _isCameraAvailable = false;
  String? _errorMessage;
  DateTime? _lastNotificationTime;

  // クラス変数として追加
  bool _isVideoMode = false;
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  String _recordingDuration = '00:00';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (kIsWeb) {
      setState(() {
        _errorMessage = 'このアプリはモバイルデバイスでのみ動作します';
      });
      return;
    }

    // カメラ権限の要求
    final status = await Permission.camera.request();
    setState(() {
      _hasCameraPermission = status.isGranted;
      if (!_hasCameraPermission) {
        _errorMessage = 'カメラのアクセス権限がありません';
      }
    });

    if (!_hasCameraPermission) return;

    // 利用可能なカメラの取得
    try {
      final cameras = await availableCameras();
      setState(() {
        _isCameraAvailable = cameras.isNotEmpty;
        if (!_isCameraAvailable) {
          _errorMessage = '利用可能なカメラがありません';
        }
      });

      if (!_isCameraAvailable) return;

      // カメラコントローラーの初期化
      final camera = cameras.first;
      final controller = CameraController(
        camera,
        ResolutionPreset.ultraHigh,
        enableAudio: true,
        fps: 60,
        imageFormatGroup: ImageFormatGroup.jpeg
      );

      await controller.initialize();
      if (!mounted) return;

      // 検出サービスの初期化
      final detectionService = DetectionService();
      await detectionService.initialize();

      setState(() {
        _controller = controller;
        _detectionService = detectionService;
        _errorMessage = null;
      });

      // 定期的な検出の開始
      _startDetection();
    } catch (e) {
      setState(() {
        _errorMessage = 'カメラの初期化に失敗しました: $e';
      });
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('カメラが準備できていません')),
      );
      return;
    }

    try {
      final XFile image = await _controller!.takePicture();
      
      if (!mounted) return;

      // 画像を保存
      final savedImage = await MediaStorage.saveMedia(File(image.path));
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真を保存しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('写真の撮影に失敗しました: $e')),
      );
    }
  }

  Future<void> _toggleRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('カメラが準備できていません')),
      );
      return;
    }

    try {
      if (_isRecording) {
        // 録画停止
        final XFile videoFile = await _controller!.stopVideoRecording();
        setState(() {
          _isRecording = false;
          _recordingStartTime = null;
        });
        _recordingTimer?.cancel();
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('動画を保存しました')),
        );

        // 動画を保存
        await MediaStorage.saveMedia(File(videoFile.path), isVideo: true);
      } else {
        // 録画開始
        await _controller!.startVideoRecording();
        setState(() {
          _isRecording = true;
          _recordingStartTime = DateTime.now();
          _recordingDuration = '00:00';
        });
        
        // 録画時間を更新するタイマーを開始
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_recordingStartTime != null) {
            final duration = DateTime.now().difference(_recordingStartTime!);
            setState(() {
              _recordingDuration = '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
            });
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('動画の${_isRecording ? '停止' : '開始'}に失敗しました: $e')),
      );
    }
  }

  void _startDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(
      Duration(seconds: AppConfig.getDetectionInterval()),
      (timer) => _detectParkingOfficer(),
    );
  }

  Future<void> _detectParkingOfficer() async {
    if (_isDetecting || _controller == null || _detectionService == null) return;

    _isDetecting = true;
    try {
      // 1フレーム取得
      final completer = Completer<CameraImage>();
      
      _controller!.startImageStream((image) {
        if (!completer.isCompleted) {
          completer.complete(image);
          _controller!.stopImageStream();
        }
      });

      final cameraImage = await completer.future;
      
      // 緑色検出の実行
      final detected = await _detectionService!.detectParkingOfficer(cameraImage);

      if (detected) {
        // 写真を撮影
        final image = await _controller!.takePicture();
        await _sendNotification(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('検出中にエラーが発生しました: $e')),
        );
      }
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _sendNotification(String imagePath) async {
    final email = AppConfig.getEmail();
    if (email == null || email.isEmpty) return;

    // 通知の制限（最後の通知から30秒以上経過している場合のみ送信）
    final now = DateTime.now();
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!) < const Duration(seconds: 30)) {
      return;
    }

    try {
      await MailService.sendNotification(
        toEmail: email,
        subject: '駐車監視員検出通知',
        body: '駐車監視員が検出されました。',
        imageFile: File(imagePath),
      );
      _lastNotificationTime = now;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('通知の送信に失敗しました: $e')),
        );
      }
    }
  }

  Widget _buildFallbackUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_photography,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage ?? 'カメラを利用できません',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (!_hasCameraPermission) ElevatedButton(
              onPressed: () async {
                await openAppSettings();
              },
              child: const Text('カメラ設定を開く'),
            ),
            const SizedBox(height: 24),
            const Text(
              'このアプリはカメラを使用して駐車監視員を検出します。\n'
              'カメラへのアクセスを許可してください。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _recordingTimer?.cancel();
    _detectionService?.dispose();
    _controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      _detectionTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('駐車監視カメラ'),
      ),
      body: _controller?.value.isInitialized == true
        ? Stack(
            children: [
              // カメラプレビューを画面いっぱいに表示
              Positioned.fill(
                child: CameraPreview(_controller!),
              ),
              // 写真/動画切り替えトグルを画面左下に配置
              Positioned(
                bottom: 30,
                left: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.camera_alt,
                          color: _isVideoMode ? Colors.white54 : Colors.white,
                        ),
                        onPressed: () {
                          if (_isVideoMode) {
                            setState(() {
                              _isVideoMode = false;
                            });
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.videocam,
                          color: _isVideoMode ? Colors.white : Colors.white54,
                        ),
                        onPressed: () {
                          if (!_isVideoMode) {
                            setState(() {
                              _isVideoMode = true;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              // 録画時間を画面上部に表示
              if (_isVideoMode && _isRecording)
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.fiber_manual_record,
                            color: Colors.red,
                            size: 12,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _recordingDuration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 撮影ボタンを画面下部中央に配置
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton(
                    onPressed: () {
                      if (_isVideoMode) {
                        _toggleRecording();
                      } else {
                        _takePicture();
                      }
                    },
                    backgroundColor: Colors.white,
                    child: Icon(
                      _isVideoMode 
                        ? (_isRecording ? Icons.stop : Icons.fiber_manual_record)
                        : Icons.camera_alt,
                      color: _isVideoMode && _isRecording ? Colors.red : Colors.black,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          )
        : _buildFallbackUI(),
    );
  }
}
