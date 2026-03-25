import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  final LocalAuthentication _auth;

  BiometricAuthService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  Future<bool> authenticate({required String reason}) async {
    final canCheck = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    if (!canCheck || !isSupported) {
      throw StateError('Biometric authentication is not available on this device.');
    }

    return _auth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  }
}
