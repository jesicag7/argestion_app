import 'package:cloud_firestore/cloud_firestore.dart';

class Factura {
  final String clienteId;
  final String clienteNombre;
  final String clienteDni;
  final double monto;
  final DateTime fecha;
  final String tipoFactura;
  final String condicionIva;
  final String itemServicio;
  final String concepto;
  final DateTime? periodoDesde;
  final DateTime? periodoHasta;
  final DateTime? fechaVencimiento;

  Factura({
    required this.clienteId,
    required this.clienteNombre,
    required this.clienteDni,
    required this.monto,
    required this.fecha,
    required this.tipoFactura,
    required this.condicionIva,
    required this.itemServicio,
    required this.concepto,
    this.periodoDesde,
    this.periodoHasta,
    this.fechaVencimiento,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'tipoComprobante': tipoFactura,
      'concepto': concepto,
      'detalle': itemServicio,
      'monto': monto,
      'cuitReceptor': clienteDni,
      'condicionIvaReceptor': condicionIva,
    };
    if (periodoDesde != null) {
      map['periodoDesde'] = Timestamp.fromDate(periodoDesde!);
    }
    if (periodoHasta != null) {
      map['periodoHasta'] = Timestamp.fromDate(periodoHasta!);
    }
    if (fechaVencimiento != null) {
      map['fechaVencimiento'] = Timestamp.fromDate(fechaVencimiento!);
    }
    return map;
  }
}
