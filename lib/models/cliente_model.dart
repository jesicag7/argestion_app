import 'package:cloud_firestore/cloud_firestore.dart';

class ClienteModel {
  final String? id;
  final String idUsuario;
  final String razonSocialONombre;
  final String tipoDocumento;
  final String numeroDocumento;
  final String condicionIva;
  final String? email;
  final String? telefono;
  final DateTime creadoEn;

  const ClienteModel({
    this.id,
    required this.idUsuario,
    required this.razonSocialONombre,
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.condicionIva,
    this.email,
    this.telefono,
    required this.creadoEn,
  });

  factory ClienteModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawCreated = map['creadoEn'] ?? map['creado_en'];
    final creadoEn = switch (rawCreated) {
      Timestamp value => value.toDate(),
      DateTime value => value,
      String value => DateTime.tryParse(value) ?? DateTime.now(),
      _ => DateTime.now(),
    };
    final email = map['email']?.toString();
    final telefono = map['telefono']?.toString();

    return ClienteModel(
      id: docId,
      idUsuario: (map['idUsuario'] ?? map['id_usuario'] ?? '').toString(),
      razonSocialONombre:
          (map['razonSocialONombre'] ??
                  map['razon_social_o_nombre'] ??
                  map['nombre'] ??
                  '')
              .toString(),
      tipoDocumento: (map['tipoDocumento'] ?? map['tipo_documento'] ?? 'DNI')
          .toString(),
      numeroDocumento:
          (map['numeroDocumento'] ?? map['numero_documento'] ?? '').toString(),
      condicionIva:
          (map['condicionIva'] ??
                  map['condicion_iva'] ??
                  'Consumidor Final')
              .toString(),
      email: email?.trim().isNotEmpty == true ? email : null,
      telefono: telefono?.trim().isNotEmpty == true ? telefono : null,
      creadoEn: creadoEn,
    );
  }

  Map<String, dynamic> toMap() => {
    'idUsuario': idUsuario,
    'id_usuario': idUsuario,
    'razonSocialONombre': razonSocialONombre,
    'razon_social_o_nombre': razonSocialONombre,
    'tipoDocumento': tipoDocumento,
    'tipo_documento': tipoDocumento,
    'numeroDocumento': numeroDocumento,
    'numero_documento': numeroDocumento,
    'condicionIva': condicionIva,
    'condicion_iva': condicionIva,
    'email': email,
    'telefono': telefono,
    'creadoEn': Timestamp.fromDate(creadoEn),
    'creado_en': Timestamp.fromDate(creadoEn),
  };
}
