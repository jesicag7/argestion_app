import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Mensaje que se muestra en el prompt nativo del sistema.
const String kBiometricPrompt = 'Escaneá tu rostro o huella para ingresar a ARGestion';

const String kBiometricWebNotice =
    'Estás en Web: la autenticación biométrica se simula para poder probar el flujo.';

enum BiometricStatus {
  authenticated,
  cancelled,
  unavailable,
  notEnrolled,
  failed,
}

class BiometricResult {
  const BiometricResult(this.status, [this.message]);

  final BiometricStatus status;

  /// Mensaje opcional para feedback en pantalla. En Web se usa para
  /// avisar que el escaneo fue simulado.
  final String? message;

  bool get isAuthenticated => status == BiometricStatus.authenticated;
}

class BiometricService {
  BiometricService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// En Web no existe implementación del plugin, así que siempre se considera
  /// disponible y el escaneo se simula.
  bool get isSimulated => kIsWeb;

  /// Indica si el dispositivo puede autenticar con biometría o con credenciales
  /// del dispositivo (PIN, patrón, contraseña).
  Future<bool> isAvailable() async {
    if (kIsWeb) return true;

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final deviceSupported = await _auth.isDeviceSupported();
      return canCheck || deviceSupported;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Si el dispositivo tiene sensor biométrico pero no hay nenhuma huella o
  /// rostro enrolled, vale la pena diferenciar el mensaje.
  Future<bool> _hasEnrolledBiometrics() async {
    try {
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<BiometricResult> authenticate() async {
    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      return const BiometricResult(BiometricStatus.authenticated, kBiometricWebNotice);
    }

    bool canCheck;
    bool deviceSupported;
    try {
      canCheck = await _auth.canCheckBiometrics;
      deviceSupported = await _auth.isDeviceSupported();
    } on PlatformException catch (e) {
      return BiometricResult(BiometricStatus.failed, _mensajeDeError(e));
    } on MissingPluginException {
      return const BiometricResult(
        BiometricStatus.unavailable,
        'La autenticación biométrica no está disponible en esta plataforma.',
      );
    }

    if (!canCheck && !deviceSupported) {
      return const BiometricResult(
        BiometricStatus.unavailable,
        'Tu dispositivo no tiene lector de huella ni de rostro configurado.',
      );
    }

    if (canCheck && !await _hasEnrolledBiometrics()) {
      return const BiometricResult(
        BiometricStatus.notEnrolled,
        'No tenés ningún rostro o huella registrado. Agregá uno en los ajustes del sistema.',
      );
    }

    try {
      final ok = await _auth.authenticate(
        localizedReason: kBiometricPrompt,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (ok) {
        return const BiometricResult(BiometricStatus.authenticated);
      }
      return const BiometricResult(BiometricStatus.cancelled);
    } on PlatformException catch (e) {
      return BiometricResult(BiometricStatus.failed, _mensajeDeError(e));
    } on MissingPluginException {
      return const BiometricResult(
        BiometricStatus.unavailable,
        'La autenticación biométrica no está disponible en esta plataforma.',
      );
    }
  }

  String _mensajeDeError(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
      case 'NotEnrolled':
      case 'PasscodeNotSet':
        return 'Configurá un bloqueo de pantalla o registrá tu huella o rostro para poder entrar.';
      case 'LockedOut':
      case 'PermanentlyLockedOut':
        return 'Demasiados intentos fallidos. Desbloqueá el dispositivo e intentá de nuevo.';
      case 'notAvailable':
      case 'notEnrolled':
        return 'Configurá un bloqueo de pantalla o registrá tu huella o rostro para poder entrar.';
      default:
        return 'No pudimos verificar tu identidad. Intentá de nuevo.';
    }
  }
}
