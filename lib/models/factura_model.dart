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
    return FacturaModel(
      id: documentId,
      idUsuario: map['id_usuario'] ?? '',
      nroFactura: map['nro_factura'] ?? '',
      cuitCliente: map['cuit_cliente'] ?? '',
      nombreCliente: map['nombre_cliente'] ?? '',
      monto: (map['monto'] ?? 0.0).toDouble(),
      tipoFactura: map['tipo_factura'] ?? 'C',
      // Firebase maneja las fechas como 'Timestamp', lo pasamos a DateTime de Dart
      fechaEmision: (map['fecha_emision'] as Timestamp).toDate(),
    );
  }

  // 2. TRANSFORMA EL OBJETO DART EN UN MAPA JSON PARA SUBIRLO A FIREBASE
 // TRANSFORMA EL OBJETO DART EN UN MAPA JSON PARA SUBIRLO A FIREBASE
  Map<String, dynamic> toMap() {
    return {
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