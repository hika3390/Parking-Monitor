import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/camera_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 設定の初期化
  await AppConfig.init();

  // アプリの起動
  runApp(const ParkingMonitorApp());
}

class ParkingMonitorApp extends StatelessWidget {
  const ParkingMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '駐車監視アプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: kIsWeb 
        ? const WebPlatformNotice() 
        : const CameraScreen(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

class WebPlatformNotice extends StatelessWidget {
  const WebPlatformNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('駐車監視アプリ'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 64,
                color: Colors.orange,
              ),
              SizedBox(height: 24),
              Text(
                'このアプリはiOSデバイスでのみ動作します',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'カメラ機能や物体検出機能を使用するため、iPhoneやiPadでご利用ください。',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
