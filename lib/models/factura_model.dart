import 'package:cloud_firestore/cloud_firestore.dart';

class FacturaModel {
  final String? id;
  final String idUsuario;
  final String nroFactura;
  final String cuitCliente;
  final String nombreCliente;
  final double monto;
  final String tipoFactura;
  final DateTime fechaEmision;
  final String puntoVenta;
  final String? numeroComprobante;
  final String? cae;
  final DateTime? fechaVtoCae;
  final String resultadoEmision;
  final String? qrUrl;
  final String? qrData;
  final String estadoCobro;
  final bool modoHomologacion;
  final String concepto;
  final int tipoDocumentoCliente;
  final DateTime? periodoDesde;
  final DateTime? periodoHasta;
  final DateTime? vencimientoPago;
  final double montoNeto;
  final String tipoComprobante;
  final String? emisorNombre;
  final String? emisorCuit;
  final String? emisorDomicilio;
  final String? descripcionItem;
  final String? condicionIvaCliente;
  final String? domicilioCliente;
  final String? condicionVenta;
  final String? vtoCae;
  final bool esNotaCredito;
  final String? comprobanteAsociadoId;
  final String? comprobanteAsociadoNumero;
  final String? comprobanteAsociadoTipo;
  final bool anulada;
  final String? anuladaPorNcId;
  final String? anuladaPorNcNumero;

  bool get estaCobrada => estadoCobro.trim().toLowerCase() == 'cobrada';

  FacturaModel({
    this.id,
    required this.idUsuario,
    required this.nroFactura,
    required this.cuitCliente,
    required this.nombreCliente,
    required this.monto,
    required this.tipoFactura,
    required this.fechaEmision,
    this.puntoVenta = '0001',
    this.numeroComprobante,
    this.cae,
    this.fechaVtoCae,
    this.resultadoEmision = 'Pendiente',
    this.qrUrl,
    this.qrData,
    this.estadoCobro = 'Pendiente',
    this.modoHomologacion = false,
    this.concepto = 'Servicios',
    this.tipoDocumentoCliente = 99,
    this.periodoDesde,
    this.periodoHasta,
    this.vencimientoPago,
    double? montoNeto,
    this.tipoComprobante = 'Factura C',
    this.emisorNombre,
    this.emisorCuit,
    this.emisorDomicilio,
    this.descripcionItem,
    this.condicionIvaCliente,
    this.domicilioCliente,
    this.condicionVenta,
    this.vtoCae,
    this.esNotaCredito = false,
    this.comprobanteAsociadoId,
    this.comprobanteAsociadoNumero,
    this.comprobanteAsociadoTipo,
    this.anulada = false,
    this.anuladaPorNcId,
    this.anuladaPorNcNumero,
  }) : montoNeto = montoNeto ?? monto;

  FacturaModel copyWith({
    String? nroFactura,
    String? puntoVenta,
    String? numeroComprobante,
    String? cae,
    DateTime? fechaVtoCae,
    String? resultadoEmision,
    String? qrUrl,
    String? qrData,
    bool? modoHomologacion,
  }) {
    return FacturaModel(
      id: id,
      idUsuario: idUsuario,
      nroFactura: nroFactura ?? this.nroFactura,
      cuitCliente: cuitCliente,
      nombreCliente: nombreCliente,
      monto: monto,
      tipoFactura: tipoFactura,
      fechaEmision: fechaEmision,
      puntoVenta: puntoVenta ?? this.puntoVenta,
      numeroComprobante: numeroComprobante ?? this.numeroComprobante,
      cae: cae ?? this.cae,
      fechaVtoCae: fechaVtoCae ?? this.fechaVtoCae,
      resultadoEmision: resultadoEmision ?? this.resultadoEmision,
      qrUrl: qrUrl ?? this.qrUrl,
      qrData: qrData ?? this.qrData,
      estadoCobro: estadoCobro,
      modoHomologacion: modoHomologacion ?? this.modoHomologacion,
      concepto: concepto,
      tipoDocumentoCliente: tipoDocumentoCliente,
      periodoDesde: periodoDesde,
      periodoHasta: periodoHasta,
      vencimientoPago: vencimientoPago,
      montoNeto: montoNeto,
      tipoComprobante: tipoComprobante,
      emisorNombre: emisorNombre,
      emisorCuit: emisorCuit,
      emisorDomicilio: emisorDomicilio,
      descripcionItem: descripcionItem,
      condicionIvaCliente: condicionIvaCliente,
      domicilioCliente: domicilioCliente,
      condicionVenta: condicionVenta,
      vtoCae: vtoCae,
      esNotaCredito: esNotaCredito,
      comprobanteAsociadoId: comprobanteAsociadoId,
      comprobanteAsociadoNumero: comprobanteAsociadoNumero,
      comprobanteAsociadoTipo: comprobanteAsociadoTipo,
      anulada: anulada,
      anuladaPorNcId: anuladaPorNcId,
      anuladaPorNcNumero: anuladaPorNcNumero,
    );
  }

  factory FacturaModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final montoValue = map['monto'] ?? map['imp_total'] ?? 0;
    final monto = montoValue is num
        ? montoValue.toDouble()
        : double.tryParse(montoValue.toString()) ?? 0;
    final rawMontoNeto = map['monto_neto'] ?? monto;
    final montoNeto = rawMontoNeto is num
        ? rawMontoNeto.toDouble()
        : double.tryParse(rawMontoNeto.toString()) ?? monto;
    final rawTipoDocumento =
        map['tipoDocumentoCliente'] ?? map['tipo_documento_cliente_id'] ?? 99;
    final tipoDocumento = rawTipoDocumento is int
        ? rawTipoDocumento
        : int.tryParse(rawTipoDocumento.toString()) ?? 99;
    final fechaEmision =
        parseDate(map['fecha_emision'] ?? map['fechaEmision']) ??
        DateTime.now();
    final estadoCobroRaw =
        (map['estadoCobro'] ?? map['estado_cobro'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final cobradaRaw = map['cobrada']?.toString().trim().toLowerCase();
    final estaCobrada =
        (cobradaRaw == 'true' || cobradaRaw == 'cobrada') ||
        estadoCobroRaw == 'cobrada';

    return FacturaModel(
      id: documentId,
      idUsuario: (map['userId'] ?? map['id_usuario'] ?? '').toString(),
      nroFactura: (map['nro_factura'] ?? '').toString(),
      cuitCliente: (map['cuit_cliente'] ?? '').toString(),
      nombreCliente: (map['nombre_cliente'] ?? '').toString(),
      monto: monto,
      tipoFactura: (map['tipo_factura'] ?? 'C').toString(),
      fechaEmision: fechaEmision,
      puntoVenta: (map['puntoVenta'] ?? map['punto_venta'] ?? '0001')
          .toString(),
      numeroComprobante: (map['numeroComprobante'] ?? map['numero_comprobante'])
          ?.toString(),
      cae: map['cae']?.toString(),
      fechaVtoCae: parseDate(map['fechaVtoCae'] ?? map['vto_cae']),
      resultadoEmision:
          (map['resultadoEmision'] ?? map['resultado_emision'] ?? 'Pendiente')
              .toString(),
      qrUrl: (map['qrUrl'] ?? map['qr_url'])?.toString(),
      qrData: (map['qrData'] ?? map['qr_data'])?.toString(),
      estadoCobro: estaCobrada ? 'Cobrada' : 'Pendiente',
      modoHomologacion: map['modoHomologacion'] == true,
      concepto: (map['concepto'] ?? 'Servicios').toString(),
      tipoDocumentoCliente: tipoDocumento,
      periodoDesde: parseDate(map['periodo_desde']),
      periodoHasta: parseDate(map['periodo_hasta']),
      vencimientoPago: parseDate(map['vencimiento_pago']),
      montoNeto: montoNeto,
      tipoComprobante:
          (map['tipo_comprobante'] ?? map['tipo_factura'] ?? 'Factura C')
              .toString(),
      emisorNombre: map['emisor_nombre']?.toString(),
      emisorCuit: map['emisor_cuit']?.toString(),
      emisorDomicilio: map['emisor_domicilio']?.toString(),
      descripcionItem: (map['descripcion_item'] ?? map['descripcion'])
          ?.toString(),
      condicionIvaCliente: map['condicion_iva_cliente']?.toString(),
      domicilioCliente: map['domicilio_cliente']?.toString(),
      condicionVenta: map['condicion_venta']?.toString(),
      vtoCae: map['vto_cae']?.toString(),
      esNotaCredito:
          map['esNotaCredito'] == true ||
          map['es_nota_credito'] == true ||
          (map['tipo_comprobante'] ?? '').toString().startsWith(
            'Nota de Crédito',
          ),
      comprobanteAsociadoId:
          (map['comprobanteAsociadoId'] ?? map['comprobante_asociado_id'])
              ?.toString(),
      comprobanteAsociadoNumero:
          (map['comprobanteAsociadoNumero'] ??
                  map['comprobante_asociado_numero'])
              ?.toString(),
      comprobanteAsociadoTipo:
          (map['comprobanteAsociadoTipo'] ??
                  map['comprobante_asociado_tipo'])
              ?.toString(),
      anulada: map['anulada'] == true || map['es_anulada'] == true,
      anuladaPorNcId:
          (map['anuladaPorNcId'] ?? map['anulada_por_nc_id'])?.toString(),
      anuladaPorNcNumero:
          (map['anuladaPorNcNumero'] ?? map['anulada_por_nc_numero'])
              ?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': idUsuario,
      'id_usuario': idUsuario,
      'nro_factura': nroFactura,
      'puntoVenta': puntoVenta,
      'punto_venta': puntoVenta,
      'numeroComprobante': numeroComprobante,
      'numero_comprobante': numeroComprobante,
      'cuit_cliente': cuitCliente,
      'nombre_cliente': nombreCliente,
      'monto': monto,
      'monto_neto': montoNeto,
      'tipo_factura': tipoFactura,
      'tipo_comprobante': tipoComprobante,
      'fecha_emision': fechaEmision.toIso8601String(),
      'cae': cae,
      'fechaVtoCae': fechaVtoCae?.toIso8601String() ?? vtoCae,
      'vto_cae': fechaVtoCae?.toIso8601String() ?? vtoCae,
      'resultadoEmision': resultadoEmision,
      'resultado_emision': resultadoEmision,
      'qrUrl': qrUrl,
      'qr_url': qrUrl,
      'qrData': qrData,
      'qr_data': qrData,
      'estadoCobro': estadoCobro,
      'estado_cobro': estadoCobro,
      'cobrada': estaCobrada,
      'modoHomologacion': modoHomologacion,
      'concepto': concepto,
      'tipoDocumentoCliente': tipoDocumentoCliente,
      'tipo_documento_cliente_id': tipoDocumentoCliente,
      'periodo_desde': periodoDesde?.toIso8601String(),
      'periodo_hasta': periodoHasta?.toIso8601String(),
      'vencimiento_pago': vencimientoPago?.toIso8601String(),
      'emisor_nombre': emisorNombre,
      'emisor_cuit': emisorCuit,
      'emisor_domicilio': emisorDomicilio,
      'descripcion_item': descripcionItem,
      'condicion_iva_cliente': condicionIvaCliente,
      'domicilio_cliente': domicilioCliente,
      'condicion_venta': condicionVenta,
      'esNotaCredito': esNotaCredito,
      'es_nota_credito': esNotaCredito,
      'comprobanteAsociadoId': comprobanteAsociadoId,
      'comprobante_asociado_id': comprobanteAsociadoId,
      'comprobanteAsociadoNumero': comprobanteAsociadoNumero,
      'comprobante_asociado_numero': comprobanteAsociadoNumero,
      'comprobanteAsociadoTipo': comprobanteAsociadoTipo,
      'comprobante_asociado_tipo': comprobanteAsociadoTipo,
      'anulada': anulada,
      'es_anulada': anulada,
      'anuladaPorNcId': anuladaPorNcId,
      'anulada_por_nc_id': anuladaPorNcId,
      'anuladaPorNcNumero': anuladaPorNcNumero,
      'anulada_por_nc_numero': anuladaPorNcNumero,
    };
  }
}
