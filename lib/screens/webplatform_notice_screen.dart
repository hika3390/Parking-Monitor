import 'package:flutter/material.dart';

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
