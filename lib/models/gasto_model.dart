import 'package:cloud_firestore/cloud_firestore.dart';

class GastoModel {
  final String? id; // ID del documento en Firebase
  final String idUsuario; // Relación con el usuario
  final double monto;
  final String concepto;
  final String categoriaGasto; // 'Alquiler', 'Servicios', 'Mercadería', 'Otros'
  final DateTime fechaGasto;

  GastoModel({
    this.id,
    required this.idUsuario,
    required this.monto,
    required this.concepto,
    required this.categoriaGasto,
    required this.fechaGasto,
  });

  // TRANSFORMA UN DOCUMENTO DE FIREBASE (MAP) EN UN OBJETO DE DART
  factory GastoModel.fromMap(Map<String, dynamic> map, String documentId) {
    return GastoModel(
      id: documentId,
      idUsuario: map['id_usuario'] ?? '',
      monto: (map['monto'] ?? 0.0).toDouble(),
      concepto: map['concepto'] ?? '',
      categoriaGasto: map['categoria_gasto'] ?? 'Otros',
      fechaGasto: (map['fecha_gasto'] as Timestamp).toDate(),
    );
  }

  // TRANSFORMA EL OBJETO DART EN UN MAPA JSON PARA SUBIRLO A FIREBASE
  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'monto': monto,
      'concepto': concepto,
      'categoria_gasto': categoriaGasto,
      'fecha_gasto': Timestamp.fromDate(fechaGasto),
    };
  }
}