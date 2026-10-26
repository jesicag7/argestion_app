import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:argestion_app/services/arca_service.dart';
import 'package:argestion_app/models/factura_model.dart';

class FakeUser extends Fake implements User {
  @override
  String get uid => 'test_user_id';

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async =>
      'mock_token_123';
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final User? _user;

  FakeFirebaseAuth([this._user]);

  @override
  User? get currentUser => _user;
}

class ThrowingClient extends http.BaseClient {
  final Exception errorToThrow;

  ThrowingClient(this.errorToThrow);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw errorToThrow;
  }
}

class StatusResponseClient extends http.BaseClient {
  final int statusCode;

  StatusResponseClient(this.statusCode);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"error": "Backend not available"}')),
      statusCode,
    );
  }
}

FacturaModel crearFacturaPrueba({DateTime? fecha}) {
  return FacturaModel(
    idUsuario: 'test_user_id',
    nroFactura: '',
    cuitCliente: '20111111112',
    nombreCliente: 'Cliente Test',
    monto: 25000.0,
    tipoFactura: 'Factura C',
    tipoComprobante: 'Factura C',
    fechaEmision: fecha ?? DateTime(2026, 10, 25),
    tipoDocumentoCliente: 80,
  );
}

void main() {
  group('CUIT emisor validation', () {
    test('removes punctuation and validates the check digit', () {
      expect(ArcaFiscalService.normalizarCuit('20-11111111-2'), '20111111112');
      expect(ArcaFiscalService.esCuitValido('20-11111111-2'), isTrue);
      expect(ArcaFiscalService.esCuitValido('20329642330'), isTrue);
    });

    test('rejects missing, malformed, and invalid-check-digit CUITs', () {
      expect(ArcaFiscalService.esCuitValido(''), isFalse);
      expect(ArcaFiscalService.esCuitValido('12345678901'), isFalse);
      expect(ArcaFiscalService.esCuitValido('20111111113'), isFalse);
    });

    test('uses the test CUIT for missing or invalid values in sandbox', () {
      expect(ArcaFiscalService.resolverCuitEmisor(null), '20111111112');
      expect(
        ArcaFiscalService.resolverCuitEmisor('CUIT no configurado'),
        '20111111112',
      );
      expect(
        ArcaFiscalService.resolverCuitEmisor('20-11111111-2'),
        '20111111112',
      );
      expect(
        ArcaFiscalService.resolverCuitEmisor('12345678901'),
        '12345678901',
      );
    });

    test('uses the test CUIT if the sanitized value is not 11 digits', () {
      expect(ArcaFiscalService.resolverCuitEmisor('20-1111'), '20111111112');
      expect(
        ArcaFiscalService.resolverCuitEmisor('20 11111111 2'),
        '20111111112',
      );
    });
  });

  group('Nota de Crédito C con comprobante asociado', () {
    FacturaModel notaCreditoPrueba({
      String tipoAsociado = 'Factura C',
      String puntoVenta = '0002',
      String numero = '00000123',
    }) {
      return FacturaModel(
        idUsuario: 'test_user_id',
        nroFactura: '',
        cuitCliente: '20111111112',
        nombreCliente: 'Cliente Test',
        monto: 25000.0,
        tipoFactura: 'Nota de Crédito C',
        tipoComprobante: 'Nota de Crédito C',
        fechaEmision: DateTime(2026, 10, 26),
        esNotaCredito: true,
        comprobanteAsociadoId: 'factura-original',
        comprobanteAsociadoNumero: '$puntoVenta-$numero',
        comprobanteAsociadoTipo: tipoAsociado,
        comprobanteAsociadoPuntoVenta: puntoVenta,
        comprobanteAsociadoNumeroComprobante: numero,
        tipoDocumentoCliente: 80,
      );
    }

    test(
      'envía CbtesAsoc con tipo, punto de venta y número explícitos',
      () async {
        Map<String, dynamic>? payload;
        final client = MockClient((request) async {
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'cae': '74111111111111',
              'fechaVtoCae': '20261105',
              'numeroComprobante': '00000005',
            }),
            200,
          );
        });
        final service = ArcaFiscalService(
          client: client,
          endpoint: Uri.parse('http://localhost:3000/api/emitir-comprobante'),
          modoHomologacion: true,
          firebaseAuth: FakeFirebaseAuth(FakeUser()),
        );

        final emision = await service.emitirFactura(
          factura: notaCreditoPrueba(),
          puntoVenta: '0002',
          cuitEmisor: '20111111112',
        );

        expect(payload?['tipoComprobante'], 13);
        expect(payload?['CbtesAsoc'], [
          {'Tipo': 11, 'PtoVta': 2, 'Nro': 123},
        ]);
        expect(emision['cae'], '74111111111111');
      },
    );

    test('rechaza una Nota de Crédito C que no anule una Factura C', () async {
      final service = ArcaFiscalService(
        client: MockClient((_) async => http.Response('{}', 200)),
        endpoint: Uri.parse('http://localhost:3000/api/emitir-comprobante'),
        modoHomologacion: true,
        firebaseAuth: FakeFirebaseAuth(FakeUser()),
      );

      expect(
        () => service.emitirFactura(
          factura: notaCreditoPrueba(tipoAsociado: 'Factura B'),
          puntoVenta: '0002',
          cuitEmisor: '20111111112',
        ),
        throwsA(
          isA<ArcaFiscalException>().having(
            (e) => e.code,
            'code',
            'ASSOCIATED_RECEIPT_TYPE_MISMATCH',
          ),
        ),
      );
    });
  });

  group('Fallback de Simulación en ArcaFiscalService', () {
    setUp(() {
      ArcaFiscalService.reiniciarContadorSimulado(0);
    });

    test(
      'generarCaeSimulado produce un CAE válido de 14 dígitos numéricos',
      () {
        final cae = ArcaFiscalService.generarCaeSimulado();
        expect(cae.length, 14);
        expect(RegExp(r'^\d{14}$').hasMatch(cae), isTrue);
        expect(cae.startsWith('74'), isTrue);
      },
    );

    test(
      'emite factura en modo simulación ante error de conexión (SocketException)',
      () async {
        final client = ThrowingClient(
          const SocketException('Connection refused: port 3000'),
        );
        final service = ArcaFiscalService(
          client: client,
          endpoint: Uri.parse('http://localhost:3000/api/emitir-comprobante'),
          modoHomologacion: true,
        );

        final fecha = DateTime(2026, 10, 25);
        final factura = crearFacturaPrueba(fecha: fecha);

        final emision = await service.emitirFactura(
          factura: factura,
          puntoVenta: '0001',
          cuitEmisor: '20111111112',
        );

        expect(emision['resultadoEmision'], 'Aprobado');
        expect(emision['modoSimulacion'], isTrue);
        expect(emision['simulada'], isTrue);
        expect(emision['cae'], matches(RegExp(r'^\d{14}$')));
        expect(emision['numeroComprobante'], '00000001');
        expect(
          emision['fechaVtoCae'],
          '2026-11-04T00:00:00.000',
        ); // Exactamente 10 días
        expect(
          emision['mensajeAviso'],
          'Factura emitida en modo simulación (backend no disponible)',
        );
        expect(emision['qrUrl'], contains('https://www.afip.gob.ar/fe/qr/?p='));
      },
    );

    test('numera los comprobantes simulados de forma incremental', () async {
      final client = ThrowingClient(
        http.ClientException('Failed to connect to localhost:3000'),
      );
      final service = ArcaFiscalService(
        client: client,
        endpoint: Uri.parse('http://localhost:3000/api/emitir-comprobante'),
        modoHomologacion: true,
      );

      final factura = crearFacturaPrueba();

      final emision1 = await service.emitirFactura(
        factura: factura,
        puntoVenta: '0001',
        cuitEmisor: '20111111112',
      );
      expect(emision1['numeroComprobante'], '00000001');

      final emision2 = await service.emitirFactura(
        factura: factura,
        puntoVenta: '0001',
        cuitEmisor: '20111111112',
      );
      expect(emision2['numeroComprobante'], '00000002');

      final emision3 = await service.emitirFactura(
        factura: factura,
        puntoVenta: '0001',
        cuitEmisor: '20111111112',
      );
      expect(emision3['numeroComprobante'], '00000003');
    });

    test(
      'emite factura en modo simulación ante TimeoutException del backend',
      () async {
        final client = ThrowingClient(
          TimeoutException('El backend tardó más de 10s'),
        );
        final service = ArcaFiscalService(
          client: client,
          endpoint: Uri.parse('http://localhost:3000/api/emitir-comprobante'),
          modoHomologacion: true,
        );

        final factura = crearFacturaPrueba();
        final emision = await service.emitirFactura(
          factura: factura,
          puntoVenta: '0001',
          cuitEmisor: '20111111112',
        );

        expect(emision['resultadoEmision'], 'Aprobado');
        expect(emision['modoSimulacion'], isTrue);
        expect(emision['cae'], matches(RegExp(r'^\d{14}$')));
        expect(emision['numeroComprobante'], isNotNull);
      },
    );

    test(
      'emite factura en modo simulación ante HTTP 503 Bad Gateway / Unavailable',
      () async {
        final client = StatusResponseClient(503);
        final service = ArcaFiscalService(
          client: client,
          endpoint: Uri.parse('http://localhost:3000/api/emitir-comprobante'),
          modoHomologacion: true,
        );

        final factura = crearFacturaPrueba();
        final emision = await service.emitirFactura(
          factura: factura,
          puntoVenta: '0001',
          cuitEmisor: '20111111112',
        );

        expect(emision['resultadoEmision'], 'Aprobado');
        expect(emision['modoSimulacion'], isTrue);
        expect(emision['cae'], matches(RegExp(r'^\d{14}$')));
      },
    );

    test(
      'resuelve timeout de 3 segundos para localhost y 10 para servidores remotos',
      () {
        expect(
          ArcaFiscalService.resolverTimeout(
            Uri.parse('http://localhost:3000/api'),
          ),
          const Duration(seconds: 3),
        );
        expect(
          ArcaFiscalService.resolverTimeout(
            Uri.parse('http://127.0.0.1:3000/api'),
          ),
          const Duration(seconds: 3),
        );
        expect(
          ArcaFiscalService.resolverTimeout(
            Uri.parse('http://10.0.2.2:3000/api'),
          ),
          const Duration(seconds: 3),
        );
        expect(
          ArcaFiscalService.resolverTimeout(
            Uri.parse('https://api.arca.gob.ar/ws'),
          ),
          const Duration(seconds: 10),
        );
        expect(
          ArcaFiscalService.esEndpointLocal(Uri.parse('http://localhost:3000')),
          isTrue,
        );
        expect(
          ArcaFiscalService.esEndpointLocal(
            Uri.parse('https://api.arca.gob.ar'),
          ),
          isFalse,
        );
      },
    );

    test(
      'emitirFacturaSimulada genera factura reglamentaria directamente',
      () async {
        final service = ArcaFiscalService();
        final factura = crearFacturaPrueba();
        final emision = await service.emitirFacturaSimulada(
          factura: factura,
          puntoVenta: '0002',
          cuitEmisor: '20111111112',
        );

        expect(emision['resultadoEmision'], 'Aprobado');
        expect(emision['modoSimulacion'], isTrue);
        expect(emision['cae'].toString().length, 14);
        expect(emision['puntoVenta'], '0002');
        expect(
          emision['mensajeAviso'],
          ArcaFiscalService.mensajeModoSimulacion,
        );
      },
    );

    test(
      'lanza ArcaFiscalException si permitirSimulacionFallback es false y hay timeout',
      () async {
        final client = ThrowingClient(TimeoutException('Timeout'));
        final fakeAuth = FakeFirebaseAuth(FakeUser());
        final service = ArcaFiscalService(
          client: client,
          endpoint: Uri.parse('http://localhost:3000/api/emitir-comprobante'),
          modoHomologacion: true,
          permitirSimulacionFallback: false,
          firebaseAuth: fakeAuth,
        );

        final factura = crearFacturaPrueba();
        expect(
          () => service.emitirFactura(
            factura: factura,
            puntoVenta: '0001',
            cuitEmisor: '20111111112',
          ),
          throwsA(
            isA<ArcaFiscalException>().having(
              (e) => e.code,
              'code',
              'NETWORK_TIMEOUT',
            ),
          ),
        );
      },
    );
  });
}
