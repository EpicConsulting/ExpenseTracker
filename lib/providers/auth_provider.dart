import 'package:flutter/material.dart';
import '../services/biometric_auth_service.dart';

class AuthProvider with ChangeNotifier {
  final BiometricAuthService _bio = BiometricAuthService();
  bool _unlocked = false;
  bool _biometricAvailable = false;
  bool get unlocked => _unlocked;
  bool get biometricAvailable => _biometricAvailable;

  Future<void> init() async {
    _biometricAvailable = await _bio.isBiometricSupported();
    notifyListeners();
  }

  Future<bool> unlock({String reason = 'Authenticate to access Expense Tracker'}) async {
    if (!_biometricAvailable) {
      _unlocked = true; // ถ้าไม่รองรับก็ “ผ่าน” หรือจะบังคับ PIN ก็ได้
      notifyListeners();
      return true;
    }
    final ok = await _bio.authenticate(reason: reason);
    _unlocked = ok;
    notifyListeners();
    return ok;
  }

  void lock() {
    _unlocked = false;
    notifyListeners();
  }
}