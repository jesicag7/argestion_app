import 'package:firebase_auth/firebase_auth.dart';

/// Servicio para la gestión del flujo oficial de verificación de correo electrónico.
class AuthVerificationService {
  final FirebaseAuth _auth;

  AuthVerificationService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  /// Título oficial del diálogo de verificación post-registro.
  static const String tituloDialogoVerificacion =
      'Verificá tu correo electrónico';

  /// Mensaje oficial del diálogo de verificación post-registro.
  static const String mensajeDialogoVerificacion =
      'Te enviamos un enlace de validación a tu casilla. Por favor revisá tu Bandeja de entrada y también la carpeta de Correo no deseado / Spam antes de iniciar sesión.';

  /// Mensaje tras el registro para solicitar la verificación de la cuenta.
  static const String mensajeVerificacionEnviada =
      'Te enviamos un correo de verificación. Por favor revisa tu bandeja de entrada o spam antes de iniciar sesión.';

  /// Mensaje de error en login si la cuenta aún no fue confirmada.
  static const String mensajeCuentaNoVerificada =
      'Tu cuenta aún no fue verificada. Revisa el correo que te enviamos.';

  /// Comprueba si el usuario tiene el correo electrónico verificado.
  static bool isEmailVerified(User? user) {
    return user?.emailVerified == true;
  }

  /// Envía el correo de verificación al usuario si está presente.
  Future<void> sendEmailVerification(User? user) async {
    if (user != null) {
      await user.sendEmailVerification();
    }
  }

  /// Cierra la sesión activa en Firebase Auth.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
