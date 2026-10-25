import 'package:flutter_test/flutter_test.dart';

import 'package:argestion_app/services/pdf_invoice_service.dart';

void main() {
  group('PdfInvoiceService.generateInvoicePdf', () {
    test('genera el PDF de prueba sin CAE ni QR oficial, sin lanzar error', () async {
      final bytes = await PdfInvoiceService.generateInvoicePdf({
        'nro_factura': '0001-00000012',
        'tipo_comprobante': 'Factura C',
        'monto': 15000.0,
        'fecha_emision': '2026-10-01T10:00:00.000',
        'resultadoEmision': 'Pendiente',
        'modoHomologacion': true,
      });

      expect(bytes.length, greaterThan(0));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('genera el PDF oficial cuando hay CAE, vencimiento y QR', () async {
      final bytes = await PdfInvoiceService.generateInvoicePdf({
        'nro_factura': '0001-00000013',
        'tipo_comprobante': 'Factura C',
        'monto': 2500.5,
        'fecha_emision': '2026-10-01T10:00:00.000',
        'resultadoEmision': 'Aprobado',
        'modoHomologacion': false,
        'cae': '12345678901234',
        'fechaVtoCae': '2026-10-11T00:00:00.000',
        'qrUrl': 'https://www.afip.gob.ar/fe/qr/?p=abc',
      });

      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
