import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:flutter/material.dart' show Size;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class DetectionService {
  static const confidenceThreshold = 0.5;
  static const targetLabels = ['person', 'uniform', 'clothing'];
  
  late final ObjectDetector _detector;
  bool _isInitialized = false;

  Future<String> _getModelPath() async {
    final modelName = 'efficientdet_lite0.tflite';
    final manifestContent = await File('pubspec.yaml').readAsString();
    if (!manifestContent.contains('assets/ml/')) {
      throw Exception('ML modelがassetsに設定されていません');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final modelPath = path.join(appDir.path, modelName);
    
    // モデルファイルが存在しない場合、アセットからコピー
    final modelFile = File(modelPath);
    if (!await modelFile.exists()) {
      final modelBytes = await File('assets/ml/$modelName').readAsBytes();
      await modelFile.writeAsBytes(modelBytes);
    }
    
    return modelPath;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    final modelPath = await _getModelPath();
    final options = LocalObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
      confidenceThreshold: confidenceThreshold,
      modelPath: modelPath,
    );

    _detector = ObjectDetector(options: options);
    _isInitialized = true;
  }

  Future<bool> detectParkingOfficer(CameraImage image) async {
    if (!_isInitialized) {
      throw Exception('DetectionService has not been initialized');
    }

    final inputImage = InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.bgra8888,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );

    final objects = await _detector.processImage(inputImage);
    
    // 人物が検出され、その人物が制服または特定の衣類を着ている場合を検出
    for (final object in objects) {
      if (object.labels.any((label) => 
          targetLabels.contains(label.text.toLowerCase()) &&
          label.confidence >= confidenceThreshold)) {
        return true;
      }
    }

    return false;
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      _detector.close();
      _isInitialized = false;
    }
  }
}
