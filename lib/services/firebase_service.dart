import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente.dart';
import '../models/factura.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._();
  FirebaseService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Cliente>> getClientes() async {
    final snapshot = await _db.collection('clientes').get();
    return snapshot.docs.map((doc) => Cliente(
          id: doc.id,
          dni: doc['dni'] as String? ?? '',
          nombre: doc['nombre'] as String? ?? '',
        )).toList();
  }

  Future<String> crearCliente({required String dni, required String nombre, String? condicionIva}) async {
    final data = <String, dynamic>{'dni': dni, 'nombre': nombre};
    if (condicionIva != null) data['condicionIva'] = condicionIva;
    final doc = await _db.collection('clientes').add(data);
    return doc.id;
  }

  Future<void> crearFactura(Factura factura) async {
    await _db.collection('facturas').add(factura.toMap());
  }
}
