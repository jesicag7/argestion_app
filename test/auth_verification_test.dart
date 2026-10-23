import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:argestion_app/services/auth_verification_service.dart';

class FakeVerifiedUser extends Fake implements User {
  @override
  bool get emailVerified => true;
}

class FakeUnverifiedUser extends Fake implements User {
  bool sendEmailVerificationCalled = false;

  @override
  bool get emailVerified => false;

  @override
  Future<void> sendEmailVerification([
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    sendEmailVerificationCalled = true;
  }
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  bool signOutCalled = false;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

void main() {
  group('AuthVerificationService', () {
    test('isEmailVerified retorna true para un usuario verificado', () {
      final user = FakeVerifiedUser();
      expect(AuthVerificationService.isEmailVerified(user), isTrue);
    });

    test(
      'isEmailVerified retorna false para usuario no verificado o nulo',
      () {
        final user = FakeUnverifiedUser();
        expect(AuthVerificationService.isEmailVerified(user), isFalse);
        expect(AuthVerificationService.isEmailVerified(null), isFalse);
      },
    );

    test('mensajes oficiales de verificación coinciden exactamente', () {
      expect(
        AuthVerificationService.mensajeVerificacionEnviada,
        'Te enviamos un correo de verificación. Por favor revisa tu bandeja de entrada o spam antes de iniciar sesión.',
      );
      expect(
        AuthVerificationService.mensajeCuentaNoVerificada,
        'Tu cuenta aún no fue verificada. Revisa el correo que te enviamos.',
      );
    });

    test('sendEmailVerification delega la llamada en el User', () async {
      final fakeAuth = FakeFirebaseAuth();
      final service = AuthVerificationService(auth: fakeAuth);
      final unverified = FakeUnverifiedUser();

      await service.sendEmailVerification(unverified);
      expect(unverified.sendEmailVerificationCalled, isTrue);

      // Si el usuario es null no arroja excepción
      await service.sendEmailVerification(null);
    });

    test('signOut invoca signOut en FirebaseAuth', () async {
      final fakeAuth = FakeFirebaseAuth();
      final service = AuthVerificationService(auth: fakeAuth);

      await service.signOut();
      expect(fakeAuth.signOutCalled, isTrue);
    });
  });
}

