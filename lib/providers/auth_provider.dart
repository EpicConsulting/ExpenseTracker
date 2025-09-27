import 'package:flutter/material.dart';
import '../services/biometric_auth_service.dart';

class AuthProvider with ChangeNotifier {
  final BiometricAuthService _bio = BiometricAuthService();

  bool _unlocked = false;
  bool _biometricAvailable = false;
  bool _authInProgress = false;

  bool get unlocked => _unlocked;
  bool get biometricAvailable => _biometricAvailable;
  bool get authInProgress => _authInProgress;

  /// เรียกครั้งแรกตอนเริ่มแอป
  Future<void> init() async {
    _biometricAvailable = await _bio.isBiometricAvailableAndEnrolled();
    debugPrint('[AuthProvider] biometricAvailable=$_biometricAvailable');
    notifyListeners();
  }

  /// พยายามปลดล็อค
  Future<bool> unlock({String reason = 'Authenticate to access Expense Tracker'}) async {
    if (_unlocked) return true;

    if (!_biometricAvailable) {
      // ไม่ปลดล็อคอัตโนมัติอีกต่อไป ให้ผู้ใช้ตัดสินใจ (เช่น ปุ่ม Skip ใน LockScreen)
      debugPrint('[AuthProvider] Biometrics not available/enrolled. Waiting user action.');
      return false;
    }

    if (_authInProgress) return false;
    _authInProgress = true;
    notifyListeners();

    final ok = await _bio.authenticate(reason: reason);
    _authInProgress = false;
    if (ok) {
      _unlocked = true;
    }
    notifyListeners();
    return ok;
  }

  /// ข้าม (สำหรับ DEV หรือ fallback) — ใช้เฉพาะระหว่างพัฒนา
  void devBypass() {
    _unlocked = true;
    notifyListeners();
  }

  void lock() {
    _unlocked = false;
    notifyListeners();
  }

  Future<void> recheck() async {
    _biometricAvailable = await _bio.isBiometricAvailableAndEnrolled();
    notifyListeners();
  }
}