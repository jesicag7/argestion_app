import 'package:flutter_test/flutter_test.dart';
import 'package:argestion_app/models/monotributo_category.dart';

void main() {
  group('MonotributoCategory.impactoFiscal', () {
    test('subtracts the amount of a credit note', () {
      expect(
        MonotributoCategory.impactoFiscal(monto: 12500, esNotaCredito: true),
        -12500,
      );
    });

    test('keeps a linked original invoice to offset its credit note', () {
      final impactoFacturaOriginal = MonotributoCategory.impactoFiscal(
        monto: 12500,
        anulada: true,
        tieneNotaCreditoAsociada: true,
      );
      expect(impactoFacturaOriginal, 12500);
      expect(
        impactoFacturaOriginal +
            MonotributoCategory.impactoFiscal(
              monto: 12500,
              esNotaCredito: true,
            ),
        0,
      );
      expect(MonotributoCategory.impactoFiscal(monto: 12500, anulada: true), 0);
      expect(MonotributoCategory.impactoFiscal(monto: double.infinity), 0);
    });
  });

  group('MonotributoCategory.determinarCategoriaProyectada', () {
    test('returns category A and margin to B inside A scale', () {
      final projection = MonotributoCategory.determinarCategoriaProyectada(
        1_000_000,
      );

      expect(projection.category, 'A');
      expect(projection.categoryCeiling, 7_720_000);
      expect(projection.nextCategory, 'B');
      expect(projection.marginToNextCategory, 10_450_000);
      expect(projection.exclusionAlert, isFalse);
    });

    test('advances exactly at the next category income limit', () {
      final projection = MonotributoCategory.determinarCategoriaProyectada(
        7_720_001,
      );

      expect(projection.category, 'B');
      expect(projection.categoryCeiling, 11_450_000);
      expect(projection.nextCategory, 'C');
      expect(projection.marginToNextCategory, 8_329_999);
    });

    test('flags income above the category K limit as exclusion risk', () {
      final projection = MonotributoCategory.determinarCategoriaProyectada(
        82_300_001,
      );

      expect(projection.category, 'K');
      expect(projection.marginToNextCategory, 0);
      expect(projection.exclusionAlert, isTrue);
      expect(projection.amountAboveTopCategory, 1);
    });

    test('does not flag exactly the category K limit as exclusion', () {
      final projection = MonotributoCategory.determinarCategoriaProyectada(
        82_300_000,
      );

      expect(projection.category, 'K');
      expect(projection.marginToNextCategory, 0);
      expect(projection.exclusionAlert, isFalse);
      expect(projection.amountAboveTopCategory, 0);
    });
  });
}
