import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../utils/config.dart';
import '../services/mail_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _emailController = TextEditingController();
  final _intervalController = TextEditingController();
  final _fpsController = TextEditingController();
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _emailController.text = AppConfig.getEmail() ?? '';
    _intervalController.text = AppConfig.getDetectionInterval().toString();
    _fpsController.text = AppConfig.getCameraFps().toString();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    try {
      _cameras = await availableCameras();
      _selectedCameraIndex = AppConfig.getSelectedCamera();
      // 保存されているインデックスが有効範囲を超えている場合は0に設定
      if (_selectedCameraIndex >= _cameras.length) {
        _selectedCameraIndex = 0;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('カメラの取得に失敗しました: $e')),
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

  String _getCameraName(CameraDescription camera) {
    switch (camera.lensDirection) {
      case CameraLensDirection.back:
        return '背面カメラ';
      case CameraLensDirection.front:
        return '前面カメラ';
      case CameraLensDirection.external:
        return '外部カメラ';
    }
  }

  void _saveSettings() async {
    final email = _emailController.text.trim();
    final interval = int.tryParse(_intervalController.text);
    final fps = int.tryParse(_fpsController.text);
    final selectedCamera = _selectedCameraIndex;

    if (email.isNotEmpty && !MailService.isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メールアドレスの形式が正しくありません')),
      );
      return;
    }

    if (interval == null || interval < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('検出間隔は1秒以上の数値を入力してください')),
      );
      return;
    }

    if (fps == null || fps < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FPSは1以上の数値を入力してください')),
      );
      return;
    }

    await AppConfig.setEmail(email);
    await AppConfig.setDetectionInterval(interval);
    await AppConfig.setSelectedCamera(selectedCamera);
    await AppConfig.setCameraFps(fps);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _intervalController.dispose();
    _fpsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey[300],
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // カメラ設定セクション
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'カメラ設定',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_isLoading && _cameras.isNotEmpty) ...[
                      DropdownButtonFormField<int>(
                        value: _selectedCameraIndex,
                        decoration: const InputDecoration(
                          labelText: '使用するカメラ',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(_cameras.length, (index) {
                          final camera = _cameras[index];
                          return DropdownMenuItem(
                            value: index,
                            child: Text('${_getCameraName(camera)} ${index + 1}'),
                          );
                        }),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCameraIndex = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _fpsController,
                      decoration: const InputDecoration(
                        labelText: 'カメラFPS',
                        hintText: '60',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // 一般設定セクション
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '一般設定',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: '通知先メールアドレス',
                        hintText: 'example@example.com',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _intervalController,
                      decoration: const InputDecoration(
                        labelText: '検出間隔（秒）',
                        hintText: '30',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // 保存ボタン
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1.0,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(top: 24.0),
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    '保存',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
