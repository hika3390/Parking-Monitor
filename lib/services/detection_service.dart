import 'dart:io' show Platform;
import 'package:camera/camera.dart';

class DetectionService {
  // 緑色の閾値
  static const int greenThreshold = 150;  // G値の最小値
  static const int nonGreenThreshold = 100;  // R,B値の最大値
  static const double requiredGreenRatio = 0.05;  // 必要な緑色ピクセルの割合（5%）

  Future<void> initialize() async {
    // 初期化不要
  }

  Future<bool> detectParkingOfficer(CameraImage image) async {
    final plane = image.planes[0];
    final bytes = plane.bytes;
    final bytesPerRow = plane.bytesPerRow;
    final pixelStride = plane.bytesPerPixel ?? 1;
    
    final height = image.height;
    final width = image.width;

    int greenPixels = 0;
    final totalPixels = width * height;
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixelIndex = y * bytesPerRow + x * pixelStride;
        
        if (pixelIndex + 2 >= bytes.length) continue;
        
        // バイトデータから輝度を取得
        final int value = bytes[pixelIndex] & 0xFF;
        
        // 輝度が緑色の範囲内にあるかを判定
        if (value > greenThreshold && value < 200) {
          greenPixels++;
        }
      }
    }

    // 緑色ピクセルの割合を計算
    final double greenRatio = greenPixels / totalPixels;
    return greenRatio >= requiredGreenRatio;
  }

  Future<void> dispose() async {
    // リソース解放不要
  }
}
