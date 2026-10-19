import 'package:flutter_test/flutter_test.dart';
import 'package:argestion_app/models/pagos_calculator.dart';

void main() {
  group('PagosCalculator', () {
    test('calculates this month due date and moves weekend to Monday', () {
      expect(
        PagosCalculator.proximoVencimiento(DateTime(2026, 10, 1)),
        DateTime(2026, 10, 20),
      );
      expect(
        PagosCalculator.proximoVencimiento(DateTime(2026, 6, 1)),
        DateTime(2026, 6, 22),
      );
      expect(
        PagosCalculator.proximoVencimiento(DateTime(2026, 9, 1)),
        DateTime(2026, 9, 21),
      );
    });

    test('moves to next month after the twentieth and handles year change', () {
      expect(
        PagosCalculator.proximoVencimiento(DateTime(2026, 10, 21)),
        DateTime(2026, 11, 20),
      );
      expect(
        PagosCalculator.proximoVencimiento(DateTime(2026, 12, 21)),
        DateTime(2027, 1, 20),
      );
    });

    test('keeps the current due date throughout the twentieth day', () {
      expect(
        PagosCalculator.proximoVencimiento(DateTime(2026, 10, 20, 23, 59)),
        DateTime(2026, 10, 20),
      );
    });

    test(
      'creates a reference from CUIT and month without formatting chars',
      () {
        expect(
          PagosCalculator.referenciaPago(
            cuit: '20-12345678-9',
            period: DateTime(2026, 10),
          ),
          'MONOTRIBUTO-20123456789-2026-10',
        );
        expect(
          PagosCalculator.referenciaPago(cuit: null, period: DateTime(2026, 1)),
          'MONOTRIBUTO-SIN-CUIT-2026-01',
        );
      },
    );

    test('formats ARS with locale separators', () {
      expect(PagosCalculator.formatoImporte(1234567.8), '\$ 1.234.567,80');
    });

    test('uses the ARCA August 2026 service quota tariff', () {
      expect(PagosCalculator.cuotasMensualesServicios['A'], 49527.18);
      expect(PagosCalculator.cuotasMensualesServicios['K'], 1614446.04);
    });
  });
}
