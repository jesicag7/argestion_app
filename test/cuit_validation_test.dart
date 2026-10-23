import 'package:flutter_test/flutter_test.dart';
import 'package:argestion_app/nueva_factura_screen.dart';

void main() {
  group('NuevaFacturaScreen.validarCuitCliente', () {
    test('retorna mensaje de campo obligatorio si está vacío o es nulo', () {
      expect(
        NuevaFacturaScreen.validarCuitCliente(null),
        'Por favor ingresá el CUIT/CUIL',
      );
      expect(
        NuevaFacturaScreen.validarCuitCliente(''),
        'Por favor ingresá el CUIT/CUIL',
      );
      expect(
        NuevaFacturaScreen.validarCuitCliente('   '),
        'Por favor ingresá el CUIT/CUIL',
      );
    });

    test('retorna mensaje de longitud si tiene menos de 11 dígitos', () {
      expect(
        NuevaFacturaScreen.validarCuitCliente('20'),
        'El CUIT debe tener exactamente 11 números',
      );
      expect(
        NuevaFacturaScreen.validarCuitCliente('2012345678'),
        'El CUIT debe tener exactamente 11 números',
      );
    });

    test('retorna mensaje de CUIT no válido si no pasa el algoritmo Módulo 11', () {
      expect(
        NuevaFacturaScreen.validarCuitCliente('12345678901'),
        'El CUIT ingresado no es válido',
      );
      expect(
        NuevaFacturaScreen.validarCuitCliente('20111111113'),
        'El CUIT ingresado no es válido',
      );
      expect(
        NuevaFacturaScreen.validarCuitCliente('27111111119'),
        'El CUIT ingresado no es válido',
      );
    });

    test('retorna null (válido) si cumple con el algoritmo oficial Módulo 11', () {
      expect(NuevaFacturaScreen.validarCuitCliente('20111111112'), isNull);
      expect(NuevaFacturaScreen.validarCuitCliente('20329642330'), isNull);
      expect(NuevaFacturaScreen.validarCuitCliente('27329642335'), isNull);
    });

    test('permite validar DNI cuando tipoDoc es DNI', () {
      expect(
        NuevaFacturaScreen.validarCuitCliente('', tipoDoc: 'DNI'),
        'Por favor ingresá el DNI',
      );
      expect(
        NuevaFacturaScreen.validarCuitCliente('12345', tipoDoc: 'DNI'),
        'El DNI debe tener 7 u 8 números',
      );
      expect(
        NuevaFacturaScreen.validarCuitCliente('38491823', tipoDoc: 'DNI'),
        isNull,
      );
    });

    test('permite documento vacío cuando tipoDoc es Consumidor Final', () {
      expect(
        NuevaFacturaScreen.validarCuitCliente('', tipoDoc: 'Consumidor Final'),
        isNull,
      );
    });
  });
}

