import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Binds a student's identity to this device to prevent proxy sign-ins,
/// and securely stores credentials so biometric re-authentication works
/// after sign-out without requiring the student to retype their password.
class DeviceCredentialService {
  // SharedPreferences keys (non-sensitive)
  static const _keyDeviceUid   = 'device_bound_uid';
  static const _keyDeviceEmail = 'device_bound_email';

  // SecureStorage key (sensitive — stored in Android Keystore / iOS Keychain)
  static const _keyDevicePassword = 'device_bound_password';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ─── Write ─────────────────────────────────────────────────────────────────

  /// Call after a successful student email/password login.
  /// Binds [uid] + [email] (prefs) and [password] (secure storage) to the device.
  static Future<void> bindStudent({
    required String uid,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceUid, uid);
    await prefs.setString(_keyDeviceEmail, email);
    await _secure.write(key: _keyDevicePassword, value: password);
  }

  // ─── Read ───────────────────────────────────────────────────────────────────

  static Future<String?> getBoundUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceUid);
  }

  static Future<String?> getBoundEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceEmail);
  }

  static Future<String?> getBoundPassword() async {
    return _secure.read(key: _keyDevicePassword);
  }

  /// Returns true if [currentUid] matches the device-bound UID.
  /// Always returns true on a fresh device (no binding yet).
  static Future<bool> isAuthorized(String currentUid) async {
    final boundUid = await getBoundUid();
    if (boundUid == null) return true; // First login — allow and bind
    return boundUid == currentUid;
  }

  /// True if credentials are stored and biometric re-auth is possible.
  static Future<bool> canBiometricReAuth() async {
    final email    = await getBoundEmail();
    final password = await getBoundPassword();
    return email != null && email.isNotEmpty &&
           password != null && password.isNotEmpty;
  }

  // ─── Clear ─────────────────────────────────────────────────────────────────

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceUid);
    await prefs.remove(_keyDeviceEmail);
    await _secure.delete(key: _keyDevicePassword);
  }
}
