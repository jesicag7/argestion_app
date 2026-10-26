import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Garantiza que el usuario logueado tenga un documento en `usuarios/{uid}`.
///
/// Si el documento no existe, se crea solo con identificadores técnicos (uid,
/// email y fecha de creación). No se carga ningún dato personal por defecto:
/// nombre, CUIT y categoría quedan vacíos hasta que el usuario los complete.
/// Nunca lanza excepciones: un fallo aquí no debe impedir el inicio de sesión.
class UserProfileService {
  UserProfileService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Datos que el usuario debe completar antes de emitir comprobantes.
  static const List<String> camposObligatorios = [
    'nombre',
    'cuit',
    'categoria',
  ];

  /// Devuelve los campos obligatorios que faltan completar en el perfil.
  /// Lista vacía si el perfil está completo o si no se pudo consultar.
  Future<List<String>> asegurarPerfilUsuarioActual() async {
    final user = _auth.currentUser;
    if (user == null) return const [];

    try {
      final ref = _firestore.collection('usuarios').doc(user.uid);
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        await ref.set({
          'uid': user.uid,
          'email': user.email ?? '',
          'creadoEn': FieldValue.serverTimestamp(),
        });
        return List<String>.of(camposObligatorios);
      }
      return camposPendientes(snapshot.data());
    } catch (e) {
      debugPrint('[perfil] No se pudo asegurar usuarios/${user.uid}: $e');
      return const [];
    }
  }

  /// Campos obligatorios vacíos o ausentes en [data].
  static List<String> camposPendientes(Map<String, dynamic>? data) {
    return camposObligatorios.where((campo) {
      final valor = data?[campo];
      return valor == null || valor.toString().trim().isEmpty;
    }).toList();
  }
}
