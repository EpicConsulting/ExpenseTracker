import 'package:flutter/material.dart';
import '../services/biometric_auth_service.dart';

class AuthProvider with ChangeNotifier {
  final BiometricAuthService _bio = BiometricAuthService();

  bool _unlocked = false;
  bool _checking = false;
  bool _authInProgress = false;
  bool _autoAuthAttempted = false; // ป้องกัน auto authenticate ซ้ำ
  BiometricStatus? _status;
  String? _lastError;
  bool _initializing = false;
  bool _initialized = false;

  bool get unlocked => _unlocked;
  bool get checking => _checking;
  bool get authInProgress => _authInProgress;
  bool get autoAuthAttempted => _autoAuthAttempted;
  BiometricStatus? get status => _status;
  String? get lastError => _lastError;

  Future<void> init() async {
    if (_initializing || _initialized) return;
    _initializing = true;
    _checking = true;
    _lastError = null;
    notifyListeners();
    try {
      _status = await _bio.checkStatus();
      _initialized = true;
      _autoAuthAttempted = false; // reset เมื่อ init ใหม่
    } catch (e) {
      _lastError = 'Init error: $e';
    } finally {
      _checking = false;
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshStatus() async {
    _status = await _bio.checkStatus();
    if (_status?.enrolled == true) {
      _autoAuthAttempted = false;
    }
    notifyListeners();
  }

  Future<bool> authenticate({
    bool allowDeviceCredential = false, // Option1: บังคับให้ false (pure biometric)
    bool auto = false,
  }) async {
    if (_authInProgress) return false;

    if (_status == null && !_checking) {
      await init();
    }
    if (_status != null && (!_status!.supported || !_status!.enrolled)) {
      _lastError = 'Biometric not available or not enrolled.';
      notifyListeners();
      return false;
    }

    _authInProgress = true;
    _lastError = null;
    if (auto) _autoAuthAttempted = true;
    notifyListeners();

    final ok = await _bio.authenticate(
      reason: 'Please authenticate to access your expenses',
      allowDeviceCredential: allowDeviceCredential,
    );

    _authInProgress = false;
    if (ok) {
      _unlocked = true;
      _lastError = null;
    } else {
      _lastError = auto
          ? 'Authentication failed. Try again.'
          : 'Authentication failed.';
    }
    notifyListeners();
    return ok;
  }

  void devBypass() {
    _unlocked = true;
    notifyListeners();
  }

  void lock() {
    _unlocked = false;
    _autoAuthAttempted = false;
    notifyListeners();
  }
}