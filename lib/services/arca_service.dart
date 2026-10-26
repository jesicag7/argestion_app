import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

import '../models/factura_model.dart';

class ArcaFiscalException implements Exception {
  final String message;
  final String? code;

  const ArcaFiscalException(this.message, {this.code});

  @override
  String toString() => message;
}

class ArcaFiscalService {
  static const Duration tiempoMaximoRespuesta = Duration(seconds: 10);
  static const Duration tiempoMaximoRespuestaLocal = Duration(seconds: 3);
  static const Duration timeoutEstandar = Duration(seconds: 10);
  static const Duration timeoutLocalhost = Duration(seconds: 3);
  static const String mensajeServidorNoDisponible =
      'No se pudo conectar con el servidor fiscal. Verificá que el backend '
      'esté ejecutándose en el puerto 3000.';

  ArcaFiscalService({
    http.Client? client,
    Uri? endpoint,
    bool? modoHomologacion,
    FirebaseAuth? firebaseAuth,
  }) : _client = client ?? http.Client(),
       _endpoint = endpoint ?? _configuredEndpoint(),
       modoHomologacion =
           modoHomologacion ??
           const bool.fromEnvironment('ARCA_HOMOLOGACION', defaultValue: true),
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final http.Client _client;
  final Uri? _endpoint;
  final FirebaseAuth _firebaseAuth;

  /// True selects the fiscal intermediary's homologation environment.
  final bool modoHomologacion;

<<<<<<< Updated upstream
  static int _ultimoNumeroSimulado = 0;
  static int _caeSequence = 0;

  /// Reinicia el contador de simulación en memoria (útil para pruebas unitarias).
  static void reiniciarContadorSimulado([int valor = 0]) {
    _ultimoNumeroSimulado = valor;
  }

  /// Genera un CAE simulado reglamentario de 14 dígitos numéricos según formato ARCA/AFIP.
  static String generarCaeSimulado({DateTime? fecha}) {
    final now = fecha ?? DateTime.now();
    _caeSequence = (_caeSequence + 1) % 1000;
    final millis = now.millisecondsSinceEpoch.toString();
    final base = millis.length >= 9
        ? millis.substring(millis.length - 9)
        : millis.padLeft(9, '0');
    final seq = _caeSequence.toString().padLeft(3, '0');
    return '74$base$seq';
  }

  /// Determina si un endpoint apunta a localhost o al entorno local de desarrollo.
  static bool esEndpointLocal(Uri? endpoint) {
    if (endpoint == null) return true;
    final host = endpoint.host.toLowerCase();
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' ||
        host == '0.0.0.0' ||
        endpoint.port == 3000;
  }

  /// Resuelve el timeout adecuado: 3 segundos para endpoints locales (evita cuelgues en teléfonos)
  /// y 10 segundos para servidores remotos en la nube.
  static Duration resolverTimeout(Uri? endpoint) {
    if (esEndpointLocal(endpoint)) {
      return timeoutLocalhost;
    }
    return timeoutEstandar;
  }

  bool _debeUsarSimulacionFallback([Uri? endpoint]) {
    if (!permitirSimulacionFallback) return false;
    return true;
  }

  Future<int> _resolverSiguienteNumeroComprobante({
    required int puntoVenta,
    required String? userId,
  }) async {
    int nextNumber = 1;

    try {
      final firestoreInstance = _firestore ?? FirebaseFirestore.instance;
      if (userId != null && userId.isNotEmpty) {
        final query = await firestoreInstance
            .collection('facturas')
            .where(
              Filter.or(
                Filter('userId', isEqualTo: userId),
                Filter('id_usuario', isEqualTo: userId),
              ),
            )
            .get();

        for (final doc in query.docs) {
          final data = doc.data();
          final pto =
              (data['puntoVenta'] ?? data['punto_venta'] ?? '').toString();
          if (pto.padLeft(4, '0') == puntoVenta.toString().padLeft(4, '0')) {
            final rawNum =
                data['numeroComprobante'] ?? data['numero_comprobante'];
            final n = int.tryParse(rawNum?.toString() ?? '');
            if (n != null && n >= nextNumber) {
              nextNumber = n + 1;
            } else {
              final nroFactura = (data['nro_factura'] ?? '').toString();
              final parts = nroFactura.split('-');
              if (parts.length == 2) {
                final n2 = int.tryParse(parts[1]);
                if (n2 != null && n2 >= nextNumber) {
                  nextNumber = n2 + 1;
                }
              }
            }
          }
        }
      }
    } catch (_) {
      // Ignora errores si Firestore no está inicializado (ej: pruebas unitarias)
    }

    if (nextNumber <= _ultimoNumeroSimulado) {
      nextNumber = _ultimoNumeroSimulado + 1;
    }
    _ultimoNumeroSimulado = nextNumber;
    return nextNumber;
  }

  Future<Map<String, dynamic>> _generarRespuestaSimulada({
    required FacturaModel factura,
    required int puntoVentaNumber,
    required String normalizedCuit,
    required int tipoComprobante,
    required int receptorDoc,
    required String fechaEmision,
    required String? userId,
  }) async {
    final nextNumber = await _resolverSiguienteNumeroComprobante(
      puntoVenta: puntoVentaNumber,
      userId: userId,
    );
    final numeroComprobanteStr = nextNumber.toString().padLeft(8, '0');
    final caeSimulado = generarCaeSimulado(fecha: factura.fechaEmision);
    final fechaVtoCae = factura.fechaEmision.add(const Duration(days: 10));

    final qrUrl = _buildArcaQrUrl(
      fecha: fechaEmision,
      cuitEmisor: normalizedCuit,
      puntoVenta: puntoVentaNumber,
      tipoComprobante: tipoComprobante,
      numeroComprobante: nextNumber,
      importe: factura.monto,
      tipoDocumentoReceptor: factura.tipoDocumentoCliente,
      numeroDocumentoReceptor: receptorDoc,
      cae: caeSimulado,
    );

    return {
      'cae': caeSimulado,
      'fechaVtoCae': fechaVtoCae.toIso8601String(),
      'numeroComprobante': numeroComprobanteStr,
      'puntoVenta': puntoVentaNumber.toString().padLeft(4, '0'),
      'resultadoEmision': 'Aprobado',
      'qrUrl': qrUrl,
      'qrData': qrUrl,
      'modoHomologacion': true,
      'modoSimulacion': true,
      'simulada': true,
      'mensajeAviso': mensajeModoSimulacion,
      'respuestaBackend': {
        'modoSimulacion': true,
        'simulada': true,
        'mensaje': mensajeModoSimulacion,
        'cae': caeSimulado,
        'fechaVtoCae': fechaVtoCae.toIso8601String(),
        'numeroComprobante': numeroComprobanteStr,
      },
    };
  }

=======
>>>>>>> Stashed changes
  static Uri? _configuredEndpoint() {
    const apiUrl = String.fromEnvironment(
      'ARCA_API_URL',
      defaultValue: 'http://10.0.2.2:3000/api',
    );
    final base = Uri.tryParse(apiUrl);
    if (base == null || !base.hasAuthority) return null;
    if (base.path.endsWith('/emitir-comprobante')) return base;
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}/emitir-comprobante',
    );
  }

  static String normalizarCuit(String value) => _onlyDigits(value);

  static bool tieneFormatoCuit(String value) =>
      RegExp(r'^\d{11}$').hasMatch(normalizarCuit(value));

  static bool esCuitValido(String value) {
    final cuit = normalizarCuit(value);
    if (!tieneFormatoCuit(cuit)) return false;
    const weights = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
    var sum = 0;
    for (var i = 0; i < weights.length; i++) {
      sum += int.parse(cuit[i]) * weights[i];
    }
    final remainder = 11 - (sum % 11);
    final checkDigit = remainder == 11
        ? 0
        : remainder == 10
        ? 9
        : remainder;
    return int.parse(cuit[10]) == checkDigit;
  }

  bool get permiteCuitDePrueba =>
      kDebugMode ||
      _endpoint?.host == 'localhost' ||
      _endpoint?.host == '127.0.0.1' ||
      _endpoint?.host == '10.0.2.2';

  static const cuitEmisorDePrueba = '20111111112';

  static String resolverCuitEmisor(String? cuit) {
    final normalizedCuit = normalizarCuit(cuit ?? '');
    if (tieneFormatoCuit(normalizedCuit)) return normalizedCuit;
    return cuitEmisorDePrueba;
  }

  Future<Map<String, dynamic>> emitirFactura({
    required FacturaModel factura,
    required String puntoVenta,
    required String cuitEmisor,
  }) async {
    final endpoint = _endpoint;
    final esLocal = esEndpointLocal(endpoint);
    if (endpoint == null ||
        !endpoint.hasAuthority ||
        (endpoint.scheme != 'https' &&
            !(modoHomologacion &&
                endpoint.scheme == 'http' &&
<<<<<<< Updated upstream
                (esLocal ||
                    endpoint.host == 'localhost' ||
                    endpoint.host == '127.0.0.1')))) {
      if (_debeUsarSimulacionFallback(endpoint)) {
        return emitirFacturaSimulada(
          factura: factura,
          puntoVenta: puntoVenta,
          cuitEmisor: cuitEmisor,
        );
      }
=======
                (endpoint.host == 'localhost' ||
                    endpoint.host == '127.0.0.1' ||
                    endpoint.host == '10.0.2.2')))) {
>>>>>>> Stashed changes
      throw const ArcaFiscalException(
        'La API fiscal no está configurada con una URL HTTPS válida. '
        'Definí ARCA_API_URL con la URL HTTPS del backend fiscal.',
        code: 'API_NOT_CONFIGURED',
      );
    }

    final normalizedCuit = resolverCuitEmisor(cuitEmisor);

    final puntoVentaNumber = int.tryParse(puntoVenta);
    if (puntoVentaNumber == null ||
        puntoVentaNumber < 1 ||
        puntoVentaNumber > 99999) {
      throw const ArcaFiscalException(
        'El punto de venta debe ser un número entre 1 y 99999.',
        code: 'INVALID_POINT_OF_SALE',
      );
    }

    if (factura.monto <= 0 || !factura.monto.isFinite) {
      throw const ArcaFiscalException(
        'El importe total debe ser mayor que cero.',
        code: 'INVALID_AMOUNT',
      );
    }

    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const ArcaFiscalException(
        'La sesión expiró. Iniciá sesión nuevamente para emitir.',
        code: 'AUTH_REQUIRED',
      );
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const ArcaFiscalException(
        'No se pudo validar la sesión con el backend fiscal.',
        code: 'AUTH_TOKEN_UNAVAILABLE',
      );
    }

    final receptorDoc = factura.tipoDocumentoCliente == 99
        ? 0
        : int.tryParse(_onlyDigits(factura.cuitCliente));
    if (receptorDoc == null || receptorDoc < 0) {
      throw const ArcaFiscalException(
        'El número de documento del receptor no es válido.',
        code: 'INVALID_RECEIVER_DOCUMENT',
      );
    }
    final receiverDigits = _onlyDigits(factura.cuitCliente);
    if ((factura.tipoDocumentoCliente == 80 && receiverDigits.length != 11) ||
        (factura.tipoDocumentoCliente == 96 &&
            (receiverDigits.length < 7 || receiverDigits.length > 8))) {
      throw const ArcaFiscalException(
        'El CUIT o DNI del receptor no tiene un formato válido.',
        code: 'INVALID_RECEIVER_DOCUMENT',
      );
    }

    final conceptoCodigo = switch (factura.concepto.toLowerCase()) {
      'productos' => 1,
      'productos y servicios' => 3,
      _ => 2,
    };
    final tipoComprobante = _getTipoComprobanteCode(factura.tipoComprobante);
    final esNotaCredito =
        factura.esNotaCredito ||
        factura.tipoComprobante.startsWith('Nota de Crédito');
    final fechaEmision = _formatDate(factura.fechaEmision);
    final comprobanteAsociado = esNotaCredito
        ? _buildComprobanteAsociado(factura)
        : null;
    final payload = <String, dynamic>{
      'modoHomologacion': modoHomologacion,
      'cuitEmisor': int.parse(normalizedCuit),
      'puntoVenta': puntoVentaNumber,
      'tipoComprobante': tipoComprobante,
      'concepto': conceptoCodigo,
      'tipoDocumentoReceptor': factura.tipoDocumentoCliente,
      'numeroDocumentoReceptor': receptorDoc,
      'importeTotal': factura.monto,
      'importeNeto': factura.montoNeto,
      'moneda': 'PES',
      'cotizacion': 1,
      'fechaEmision': fechaEmision,
      if (factura.periodoDesde != null)
        'fechaServicioDesde': _formatDate(factura.periodoDesde!),
      if (factura.periodoHasta != null)
        'fechaServicioHasta': _formatDate(factura.periodoHasta!),
      if (factura.vencimientoPago != null)
        'fechaVencimientoPago': _formatDate(factura.vencimientoPago!),
      'descripcion': factura.descripcionItem ?? '',
      if (comprobanteAsociado != null) 'CbtesAsoc': [comprobanteAsociado],
    };

    final cuerpoJson = jsonEncode(payload);

    late http.Response response;
    final timeout = resolverTimeout(endpoint);
    try {
      response = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: cuerpoJson,
          )
          .timeout(timeout);
    } on TimeoutException {
<<<<<<< Updated upstream
      if (_debeUsarSimulacionFallback(endpoint)) {
        return _generarRespuestaSimulada(
          factura: factura,
          puntoVentaNumber: puntoVentaNumber,
          normalizedCuit: normalizedCuit,
          tipoComprobante: tipoComprobante,
          receptorDoc: receptorDoc,
          fechaEmision: fechaEmision,
          userId: user?.uid ?? factura.idUsuario,
        );
      }
      final seg = timeout.inSeconds;
      throw ArcaFiscalException(
        'El servidor fiscal no respondió en $seg segundos. Verificá que el '
=======
      throw const ArcaFiscalException(
        'El servidor fiscal no respondió en 10 segundos. Verificá que el '
>>>>>>> Stashed changes
        'backend esté ejecutándose en el puerto 3000.',
        code: 'NETWORK_TIMEOUT',
      );
    } catch (_) {
      throw const ArcaFiscalException(
        mensajeServidorNoDisponible,
        code: 'NETWORK_ERROR',
      );
    }

<<<<<<< Updated upstream
    if ((response.statusCode == 500 ||
            response.statusCode == 502 ||
            response.statusCode == 503 ||
            response.statusCode == 504) &&
        _debeUsarSimulacionFallback(endpoint)) {
      return _generarRespuestaSimulada(
        factura: factura,
        puntoVentaNumber: puntoVentaNumber,
        normalizedCuit: normalizedCuit,
        tipoComprobante: tipoComprobante,
        receptorDoc: receptorDoc,
        fechaEmision: fechaEmision,
        userId: user?.uid ?? factura.idUsuario,
      );
    }

=======
>>>>>>> Stashed changes
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('La respuesta no es un objeto JSON.');
      }
      body = decoded;
    } on FormatException {
      throw ArcaFiscalException(
        'El backend fiscal devolvió una respuesta inesperada '
        '(HTTP ${response.statusCode}).',
        code: 'INVALID_API_RESPONSE',
      );
    }

    final responseData = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : body;
    final errors =
        responseData['errors'] ??
        responseData['Errors'] ??
        responseData['observaciones'] ??
        responseData['Observaciones'];
    if (response.statusCode != 200) {
      throw ArcaFiscalException(
        _extractErrorMessage(responseData, errors, response.statusCode),
        code: 'HTTP_${response.statusCode}',
      );
    }
    final explicitSuccess =
        responseData['success'] == true ||
        responseData['exito'] == true ||
        responseData['resultado']?.toString().toUpperCase() == 'A' ||
        responseData['resultadoEmision']?.toString().toLowerCase() ==
            'aprobado';
    if (responseData['success'] == false ||
        responseData['exito'] == false ||
        responseData['resultado']?.toString().toUpperCase() == 'R' ||
        (errors is List && errors.isNotEmpty) ||
        (errors is Map && errors.isNotEmpty)) {
      throw ArcaFiscalException(
        _extractErrorMessage(responseData, errors, response.statusCode),
        code: (responseData['code'] ?? responseData['codigo'])?.toString(),
      );
    }

    final cae = (responseData['cae'] ?? responseData['CAE'])?.toString();
    final rawVtoCae =
        responseData['fechaVtoCae'] ??
        responseData['vtoCae'] ??
        responseData['fechaVencimientoCAE'] ??
        responseData['vencimientoCae'] ??
        responseData['CAEFchVto'] ??
        responseData['FchVto'];
    final fechaVtoCae = _parseDate(rawVtoCae);
    final rawNumero =
        responseData['numeroComprobante'] ??
        responseData['nroComprobante'] ??
        responseData['CbteDesde'];
    final numeroComprobante = rawNumero?.toString();
    final numeroComprobanteInt = int.tryParse(numeroComprobante ?? '');

    if (!explicitSuccess &&
        response.statusCode >= 200 &&
        response.statusCode < 300) {
      throw const ArcaFiscalException(
        'La respuesta del backend no confirma la autorización de ARCA.',
        code: 'AUTHORIZATION_NOT_CONFIRMED',
      );
    }
    if (cae == null ||
        !RegExp(r'^\d{14}$').hasMatch(cae) ||
        fechaVtoCae == null ||
        numeroComprobanteInt == null ||
        numeroComprobanteInt < 1) {
      throw const ArcaFiscalException(
        'La respuesta indica aprobación, pero faltan el CAE, su vencimiento '
        'o el número oficial de comprobante.',
        code: 'INCOMPLETE_AUTHORIZATION',
      );
    }

    final qrUrl =
        (responseData['qrUrl'] ??
                responseData['qr_url'] ??
                responseData['qrData'] ??
                responseData['qr_data'])
            ?.toString() ??
        _buildArcaQrUrl(
          fecha: fechaEmision,
          cuitEmisor: normalizedCuit,
          puntoVenta: puntoVentaNumber,
          tipoComprobante: tipoComprobante,
          numeroComprobante: numeroComprobanteInt,
          importe: factura.monto,
          tipoDocumentoReceptor: factura.tipoDocumentoCliente,
          numeroDocumentoReceptor: receptorDoc,
          cae: cae,
        );
    final modoHomologacionRespuesta =
        responseData.containsKey('modoHomologacion')
        ? responseData['modoHomologacion'] == true
        : responseData['modoSimulacion'] == true || modoHomologacion;

    return {
      'cae': cae,
      'fechaVtoCae': fechaVtoCae.toIso8601String(),
      'numeroComprobante': numeroComprobante,
      'puntoVenta': puntoVentaNumber.toString().padLeft(4, '0'),
      'resultadoEmision': 'Aprobado',
      'qrUrl': qrUrl,
      'qrData': qrUrl,
      'modoHomologacion': modoHomologacionRespuesta,
      'respuestaBackend': responseData,
    };
  }

  static String _buildArcaQrUrl({
    required String fecha,
    required String cuitEmisor,
    required int puntoVenta,
    required int tipoComprobante,
    required int numeroComprobante,
    required double importe,
    required int tipoDocumentoReceptor,
    required int numeroDocumentoReceptor,
    required String cae,
  }) {
    final qrPayload = {
      'ver': 1,
      'fecha': fecha,
      'cuit': int.parse(cuitEmisor),
      'ptoVta': puntoVenta,
      'tipoCmp': tipoComprobante,
      'nroCmp': numeroComprobante,
      'importe': importe,
      'moneda': 'PES',
      'ctz': 1,
      'tipoDocRec': tipoDocumentoReceptor,
      'nroDocRec': numeroDocumentoReceptor,
      'tipoCodAut': 'E',
      'codAut': cae,
    };
    final encoded = base64.encode(utf8.encode(jsonEncode(qrPayload)));
    return 'https://www.afip.gob.ar/fe/qr/?p=${Uri.encodeQueryComponent(encoded)}';
  }

  static String _extractErrorMessage(
    Map<String, dynamic> response,
    dynamic errors,
    int statusCode,
  ) {
    final esRechazoArca = statusCode != 401 && statusCode < 500;
    final directMessage =
        response['message'] ?? response['mensaje'] ?? response['error'];
    if (directMessage is String && directMessage.trim().isNotEmpty) {
      return esRechazoArca
          ? 'ARCA rechazó la factura: ${directMessage.trim()}'
          : directMessage.trim();
    }
    final errorItems = errors is List
        ? errors
        : errors is Map
        ? [errors]
        : const [];
    if (errorItems.isNotEmpty) {
      final messages = errorItems
          .map((error) {
            if (error is Map) {
              final code = error['code'] ?? error['codigo'] ?? error['Code'];
              final message =
                  error['message'] ?? error['mensaje'] ?? error['Msg'];
              final parts = <String>[];
              if (code != null) parts.add('[$code]');
              if (message != null) parts.add(message.toString());
              return parts.join(' ');
            }
            return error.toString();
          })
          .where((message) => message.trim().isNotEmpty)
          .join('; ');
      if (messages.isNotEmpty) {
        return esRechazoArca ? 'ARCA rechazó la factura: $messages' : messages;
      }
    }
    return 'El backend fiscal rechazó la solicitud (HTTP $statusCode).';
  }

  static String _onlyDigits(String value) =>
      value.replaceAll(RegExp(r'\D'), '');

  static int _getTipoComprobanteCode(String tipo) {
    return switch (tipo) {
      'Factura A' => 1,
      'Factura B' => 6,
      'Factura C' => 11,
      'Nota de Débito A' => 2,
      'Nota de Débito B' => 7,
      'Nota de Débito C' => 12,
      'Nota de Crédito A' => 3,
      'Nota de Crédito B' => 8,
      'Nota de Crédito C' => 13,
      _ => throw ArcaFiscalException(
        'Tipo de comprobante no soportado: $tipo',
        code: 'UNSUPPORTED_RECEIPT_TYPE',
      ),
    };
  }

  static Map<String, int> _buildComprobanteAsociado(FacturaModel factura) {
    final tipo = factura.comprobanteAsociadoTipo?.trim();
    final numero = factura.comprobanteAsociadoNumero?.trim();
    if (tipo == null ||
        tipo.isEmpty ||
        numero == null ||
        numero.isEmpty ||
        factura.comprobanteAsociadoId == null ||
        factura.comprobanteAsociadoId!.isEmpty) {
      throw const ArcaFiscalException(
        'La Nota de Crédito debe estar vinculada a un comprobante existente.',
        code: 'ASSOCIATED_RECEIPT_REQUIRED',
      );
    }

    final match = RegExp(r'^(\d{1,5})-(\d{1,8})$').firstMatch(numero);
    final puntoVenta = match == null
        ? int.tryParse(factura.puntoVenta)
        : int.tryParse(match.group(1)!);
    final numeroComprobante = match == null
        ? int.tryParse(numero)
        : int.tryParse(match.group(2)!);
    if (puntoVenta == null ||
        puntoVenta < 1 ||
        puntoVenta > 99999 ||
        numeroComprobante == null ||
        numeroComprobante < 1) {
      throw const ArcaFiscalException(
        'El número del comprobante asociado no tiene un formato válido.',
        code: 'INVALID_ASSOCIATED_RECEIPT',
      );
    }

    return {
      'Tipo': _getTipoComprobanteCode(tipo),
      'PtoVta': puntoVenta,
      'Nro': numeroComprobante,
    };
  }

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      final normalized = value.trim();
      if (RegExp(r'^\d{8}$').hasMatch(normalized)) {
        return DateTime.tryParse(
          '${normalized.substring(0, 4)}-'
          '${normalized.substring(4, 6)}-'
          '${normalized.substring(6, 8)}',
        );
      }
      return DateTime.tryParse(normalized);
    }
    return null;
  }

  /// Emite directamente una factura simulada reglamentaria sin realizar llamadas de red.
  Future<Map<String, dynamic>> emitirFacturaSimulada({
    required FacturaModel factura,
    required String puntoVenta,
    required String cuitEmisor,
  }) async {
    final normalizedCuit = resolverCuitEmisor(cuitEmisor);
    final puntoVentaNumber = int.tryParse(puntoVenta) ?? 1;
    final receptorDoc = factura.tipoDocumentoCliente == 99
        ? 0
        : int.tryParse(_onlyDigits(factura.cuitCliente)) ?? 0;
    final tipoComprobante = _getTipoComprobanteCode(factura.tipoComprobante);
    final fechaEmision = _formatDate(factura.fechaEmision);

    User? user;
    try {
      if (_firebaseAuth != null) {
        user = _firebaseAuth.currentUser;
      } else {
        user = FirebaseAuth.instance.currentUser;
      }
    } catch (_) {
      user = null;
    }

    return _generarRespuestaSimulada(
      factura: factura,
      puntoVentaNumber: puntoVentaNumber,
      normalizedCuit: normalizedCuit,
      tipoComprobante: tipoComprobante,
      receptorDoc: receptorDoc,
      fechaEmision: fechaEmision,
      userId: user?.uid ?? factura.idUsuario,
    );
  }

  void close() => _client.close();
}