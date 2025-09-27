import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// ตรวจว่า “พร้อม” จริงหรือไม่ (รองรับ + enroll แล้ว)
  Future<bool> isBiometricAvailableAndEnrolled() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final available = await _auth.getAvailableBiometrics();
      debugPrint('[Biometric] supported=$supported canCheck=$canCheck list=$available');
      return supported && canCheck && available.isNotEmpty;
    } catch (e) {
      debugPrint('[Biometric] availability check error: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('[Biometric] getAvailableBiometrics error: $e');
      return [];
    }
  }

  Future<bool> authenticate({String reason = 'Please authenticate'}) async {
    try {
      final didAuth = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,      // ตั้ง true เพื่อบังคับ biometric เท่านั้น (ปรับได้)
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      debugPrint('[Biometric] authenticate result=$didAuth');
      return didAuth;
    } catch (e) {
      debugPrint('[Biometric] authenticate error: $e');
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