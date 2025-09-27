import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<BiometricStatus> checkStatus() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final available = await _auth.getAvailableBiometrics();
      debugPrint('[Biometric] supported=$supported canCheck=$canCheck available=$available');
      if (!supported) {
        return BiometricStatus(
          supported: false,
          enrolled: false,
          availableTypes: available,
          reason: 'Device not supported',
        );
      }
      if (available.isEmpty) {
        return BiometricStatus(
          supported: true,
            enrolled: false,
          availableTypes: available,
          reason: 'No biometrics enrolled',
        );
      }
      return BiometricStatus(
        supported: true,
        enrolled: true,
        availableTypes: available,
        reason: 'OK',
      );
    } catch (e) {
      debugPrint('[Biometric] checkStatus error: $e');
      return BiometricStatus(
        supported: false,
        enrolled: false,
        availableTypes: const [],
        reason: 'Error: $e',
      );
    }
  }

  Future<bool> authenticate({
    String reason = 'Authenticate to continue',
    bool allowDeviceCredential = true,
  }) async {
    try {
      // ถ้า allowDeviceCredential = true → ตั้ง biometricOnly=false (ให้ fallback เป็น PIN/Pattern ได้)
      final result = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: !allowDeviceCredential,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
      debugPrint('[Biometric] authenticate result=$result');
      return result;
    } catch (e) {
      debugPrint('[Biometric] authenticate exception: $e');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _auth.stopAuthentication();
    } catch (e) {
      debugPrint('[Biometric] stop error: $e');
    }
  }
}

class BiometricStatus {
  final bool supported;
  final bool enrolled;
  final List<BiometricType> availableTypes;
  final String reason;
  BiometricStatus({
    required this.supported,
    required this.enrolled,
    required this.availableTypes,
    required this.reason,
  });
}