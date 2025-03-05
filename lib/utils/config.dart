import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String emailKey = 'notification_email';
  static const String detectionIntervalKey = 'detection_interval';
  static const int defaultDetectionInterval = 30; // seconds

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
}
