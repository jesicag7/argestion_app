import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/cliente_model.dart';

class ClienteService {
  ClienteService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<ClienteModel>> getClientesStream(String idUsuario) {
    _ensureCurrentUser(idUsuario);
    return _firestore
        .collection('clientes')
        .where('idUsuario', isEqualTo: idUsuario)
        .snapshots()
        .map((snapshot) {
          final clientes = snapshot.docs
              .map((doc) => ClienteModel.fromMap(doc.data(), doc.id))
              .toList();
          clientes.sort(
            (a, b) => a.razonSocialONombre.toLowerCase().compareTo(
              b.razonSocialONombre.toLowerCase(),
            ),
          );
          return clientes;
        });
  }

  Future<void> guardarOActualizarCliente(ClienteModel cliente) async {
    _ensureCurrentUser(cliente.idUsuario);
    final collection = _firestore.collection('clientes');

    if (cliente.id == null || cliente.id!.trim().isEmpty) {
      await collection.add(cliente.toMap());
      return;
    }

    final reference = collection.doc(cliente.id);
    final existing = await reference.get();
    if (!existing.exists) {
      throw StateError('El cliente que se intenta actualizar ya no existe.');
    }
    final existingUser =
        (existing.data()?['idUsuario'] ?? existing.data()?['id_usuario'])
            ?.toString();
    if (existingUser != cliente.idUsuario) {
      throw StateError('No tenés permiso para modificar este cliente.');
    }
    await reference.set(cliente.toMap(), SetOptions(merge: true));
  }

  Future<void> eliminarCliente(String clienteId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Iniciá sesión para eliminar clientes.');
    }
    final reference = _firestore.collection('clientes').doc(clienteId);
    final snapshot = await reference.get();
    if (!snapshot.exists) return;

    final owner =
        (snapshot.data()?['idUsuario'] ?? snapshot.data()?['id_usuario'])
            ?.toString();
    if (owner != user.uid) {
      throw StateError('No tenés permiso para eliminar este cliente.');
    }
    await reference.delete();
  }

  void _ensureCurrentUser(String idUsuario) {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Iniciá sesión para acceder a tu agenda de clientes.');
    }
    if (user.uid != idUsuario) {
      throw StateError(
        'Solo podés acceder a la agenda del usuario autenticado.',
      );
    }
  }
}
