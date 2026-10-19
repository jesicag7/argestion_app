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
}
