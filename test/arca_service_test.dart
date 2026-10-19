import 'package:flutter_test/flutter_test.dart';
import 'package:argestion_app/services/arca_service.dart';

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
}
