import 'package:flutter_test/flutter_test.dart';
import 'package:argestion_app/models/factura_model.dart';

void main() {
  test('persists and restores the linked credit note fields', () {
    final notaCredito = FacturaModel(
      idUsuario: 'usuario-1',
      nroFactura: '0001-00000124',
      cuitCliente: '20123456789',
      nombreCliente: 'Cliente',
      monto: 15000,
      tipoFactura: 'Nota de Crédito C',
      tipoComprobante: 'Nota de Crédito C',
      fechaEmision: DateTime(2026, 10, 19),
      esNotaCredito: true,
      comprobanteAsociadoId: 'factura-original',
      comprobanteAsociadoNumero: '0001-00000123',
      comprobanteAsociadoTipo: 'Factura C',
    );

    final restored = FacturaModel.fromMap(notaCredito.toMap(), 'nota-1');

    expect(restored.id, 'nota-1');
    expect(restored.esNotaCredito, isTrue);
    expect(restored.comprobanteAsociadoId, 'factura-original');
    expect(restored.comprobanteAsociadoNumero, '0001-00000123');
    expect(restored.comprobanteAsociadoTipo, 'Factura C');
  });

  test('persiste punto de venta y número del comprobante asociado', () {
    final notaCredito = FacturaModel(
      idUsuario: 'usuario-1',
      nroFactura: '0002-00000456',
      cuitCliente: '20123456789',
      nombreCliente: 'Cliente',
      monto: 15000,
      tipoFactura: 'Nota de Crédito C',
      tipoComprobante: 'Nota de Crédito C',
      fechaEmision: DateTime(2026, 10, 26),
      esNotaCredito: true,
      comprobanteAsociadoId: 'factura-original',
      comprobanteAsociadoNumero: '0002-00000123',
      comprobanteAsociadoTipo: 'Factura C',
      comprobanteAsociadoPuntoVenta: '0002',
      comprobanteAsociadoNumeroComprobante: '00000123',
    );

    final map = notaCredito.toMap();
    final restored = FacturaModel.fromMap(map, 'nota-2');

    expect(map['comprobante_asociado_punto_venta'], '0002');
    expect(map['comprobante_asociado_numero_comprobante'], '00000123');
    expect(restored.comprobanteAsociadoPuntoVenta, '0002');
    expect(restored.comprobanteAsociadoNumeroComprobante, '00000123');
  });

  group('regla de anulación con Nota de Crédito C', () {
    FacturaModel facturaC({
      String tipo = 'Factura C',
      String resultado = 'Aprobado',
      String? cae = '74111111111111',
      String? numero = '00000123',
      bool anulada = false,
      bool esNotaCredito = false,
    }) {
      return FacturaModel(
        id: 'factura-1',
        idUsuario: 'usuario-1',
        nroFactura: '0001-00000123',
        cuitCliente: '20123456789',
        nombreCliente: 'Cliente',
        monto: 15000,
        tipoFactura: 'C',
        tipoComprobante: tipo,
        fechaEmision: DateTime(2026, 10, 20),
        puntoVenta: '0001',
        numeroComprobante: numero,
        cae: cae,
        resultadoEmision: resultado,
        anulada: anulada,
        esNotaCredito: esNotaCredito,
      );
    }

    test('permite anular una Factura C aprobada con CAE', () {
      expect(facturaC().puedeAnularConNotaCredito, isTrue);
    });

    test('bloquea facturas anuladas, notas de crédito y otros tipos', () {
      expect(facturaC(anulada: true).puedeAnularConNotaCredito, isFalse);
      expect(facturaC(esNotaCredito: true).puedeAnularConNotaCredito, isFalse);
      expect(facturaC(tipo: 'Factura B').puedeAnularConNotaCredito, isFalse);
    });

    test('bloquea facturas sin aprobación o sin CAE', () {
      expect(
        facturaC(resultado: 'Pendiente').puedeAnularConNotaCredito,
        isFalse,
      );
      expect(facturaC(cae: null).puedeAnularConNotaCredito, isFalse);
      expect(facturaC(cae: '  ').puedeAnularConNotaCredito, isFalse);
    });

    test('obtiene punto de venta y número aunque falte numeroComprobante', () {
      final factura = facturaC(numero: null);
      expect(factura.puntoVentaFiscal, '0001');
      expect(factura.numeroComprobanteFiscal, '00000123');
      expect(factura.numeroComprobanteCompleto, '0001-00000123');
      expect(factura.puedeAnularConNotaCredito, isTrue);
    });
  });
}
