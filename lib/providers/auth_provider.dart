import 'package:flutter/material.dart';
import '../services/biometric_auth_service.dart';

class AuthProvider with ChangeNotifier {
  final BiometricAuthService _bio = BiometricAuthService();

  bool _unlocked = false;
  bool _checking = false;
  BiometricStatus? _status;
  String? _lastError;

  bool _initializing = false;
  bool _initialized = false;

  bool get unlocked => _unlocked;
  bool get checking => _checking;
  BiometricStatus? get status => _status;
  String? get lastError => _lastError;

  Future<void> init() async {
    if (_initializing || _initialized) return;
    _initializing = true;
    _checking = true;
    notifyListeners();
    try {
      _status = await _bio.checkStatus();
      _initialized = true;
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
    notifyListeners();
  }

  Future<bool> authenticate({bool allowDeviceCredential = true}) async {
    if (!_initialized && !_initializing) {
      await init();
    }
    if (_status != null && (!_status!.supported || !_status!.enrolled)) {
      _lastError = 'Biometric not available or not enrolled.';
      notifyListeners();
      return false;
    }
    final ok = await _bio.authenticate(
      reason: 'Please authenticate to access your expenses',
      allowDeviceCredential: allowDeviceCredential,
    );
    if (ok) {
      _unlocked = true;
      _lastError = null;
    } else {
      _lastError = 'Authentication failed.';
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
    notifyListeners();
  }
}