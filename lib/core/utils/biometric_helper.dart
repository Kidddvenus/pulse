import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricHelper {
  static final _auth = LocalAuthentication();

  /// Checks whether there is local authentication available on this device.
  static Future<bool> hasEnrolledBiometrics() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Authenticates using biometrics or device PIN/pattern.
  static Future<bool> authenticate(String localizedReason) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
      );
    } on PlatformException {
      return false;
    }
  }
}
