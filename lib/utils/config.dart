import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String emailKey = 'notification_email';
  static const String detectionIntervalKey = 'detection_interval';
  static const String selectedCameraKey = 'selected_camera';
  static const String cameraFpsKey = 'camera_fps';
  static const int defaultDetectionInterval = 30; // seconds
  static const int defaultCameraIndex = 0;
  static const int defaultCameraFps = 60;

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> setEmail(String email) async {
    await _prefs.setString(emailKey, email);
  }

  static String? getEmail() {
    return _prefs.getString(emailKey);
  }

  static Future<void> setDetectionInterval(int seconds) async {
    await _prefs.setInt(detectionIntervalKey, seconds);
  }

  static int getDetectionInterval() {
    return _prefs.getInt(detectionIntervalKey) ?? defaultDetectionInterval;
  }

  static Future<void> setSelectedCamera(int index) async {
    await _prefs.setInt(selectedCameraKey, index);
  }

  static int getSelectedCamera() {
    return _prefs.getInt(selectedCameraKey) ?? defaultCameraIndex;
  }

  static Future<void> setCameraFps(int fps) async {
    await _prefs.setInt(cameraFpsKey, fps);
  }

  static int getCameraFps() {
    return _prefs.getInt(cameraFpsKey) ?? defaultCameraFps;
  }
}
