import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/detection_service.dart';
import '../services/mail_service.dart';
import '../utils/config.dart';

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
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
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
      final image = await _controller!.takePicture();
      
      // 画像ストリームの取得
      late CameraImage cameraImage;
      await _controller!.startImageStream((image) {
        cameraImage = image;
        _controller!.stopImageStream();
      });

      // 画像ストリームが取得できるまで待機
      while (!_controller!.value.isStreamingImages) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final detected = await _detectionService!.detectParkingOfficer(cameraImage);

      if (detected) {
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
    if (email == null) return;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey[300],
            height: 1.0,
          ),
        ),
      ),
      body: _controller?.value.isInitialized == true
          ? Column(
              children: [
                Expanded(
                  child: CameraPreview(_controller!),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1.0,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '検出間隔: ${AppConfig.getDetectionInterval()}秒',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            )
          : _buildFallbackUI(),
    );
  }
}
