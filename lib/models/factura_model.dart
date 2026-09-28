import 'package:cloud_firestore/cloud_firestore.dart';

class FacturaModel {
  final String? id; // ID del documento en Firebase
  final String idUsuario; // Relación con el usuario
  final String nroFactura;
  final String cuitCliente;
  final String nombreCliente;
  final double monto;
  final String tipoFactura;
  final DateTime fechaEmision;

  FacturaModel({
    this.id,
    required this.idUsuario,
    required this.nroFactura,
    required this.cuitCliente,
    required this.nombreCliente,
    required this.monto,
    required this.tipoFactura,
    required this.fechaEmision,
  });

  // 1. TRANSFORMA UN DOCUMENTO DE FIREBASE (MAP) EN UN OBJETO DE DART
  factory FacturaModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parsedFecha;
    if (map['fecha_emision'] is Timestamp) {
      parsedFecha = (map['fecha_emision'] as Timestamp).toDate();
    } else if (map['fecha_emision'] is String) {
      parsedFecha = DateTime.tryParse(map['fecha_emision']) ?? DateTime.now();
    } else {
      parsedFecha = DateTime.now();
    }

    return FacturaModel(
      id: documentId,
      idUsuario: map['userId'] ?? map['id_usuario'] ?? '',
      nroFactura: map['nro_factura'] ?? '',
      cuitCliente: map['cuit_cliente'] ?? '',
      nombreCliente: map['nombre_cliente'] ?? '',
      monto: (map['monto'] ?? 0.0).toDouble(),
      tipoFactura: map['tipo_factura'] ?? 'C',
      fechaEmision: parsedFecha,
    );
  }

  // 2. TRANSFORMA EL OBJETO DART EN UN MAPA JSON PARA SUBIRLO A FIREBASE
  Map<String, dynamic> toMap() {
    return {
      'userId': idUsuario,
      'id_usuario': idUsuario,
      'nro_factura': nroFactura,
      'cuit_cliente': cuitCliente,
      'nombre_cliente': nombreCliente,
      'monto': monto,
      'tipo_factura': tipoFactura,
      'fecha_emision': fechaEmision.toIso8601String(), // ◄ Cambiamos Timestamp por String para la Web
    };
  }
}