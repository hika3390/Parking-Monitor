import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/webplatform_notice_screen.dart';
import 'screens/main_screen.dart';
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
        : const MainScreen(),
    );
  }
}
