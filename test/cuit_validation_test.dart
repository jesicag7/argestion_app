import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:argestion_app/nueva_factura_screen.dart';
import 'package:argestion_app/dashboard_screen.dart';

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

  group('DigitosConAdvertenciaInputFormatter', () {
    test('permite entrada de dígitos numéricos válidos sin activar advertencia', () {
      bool advertenciaLlamada = false;
      final formatter = DigitosConAdvertenciaInputFormatter(
        onCaracterInvalido: () {
          advertenciaLlamada = true;
        },
      );

      const oldValue = TextEditingValue(text: '20');
      const newValue = TextEditingValue(
        text: '201',
        selection: TextSelection.collapsed(offset: 3),
      );

      final resultado = formatter.formatEditUpdate(oldValue, newValue);

      expect(resultado.text, '201');
      expect(advertenciaLlamada, isFalse);
    });

    test('bloquea letras y dispara callback de advertencia', () {
      bool advertenciaLlamada = false;
      final formatter = DigitosConAdvertenciaInputFormatter(
        onCaracterInvalido: () {
          advertenciaLlamada = true;
        },
      );

      const oldValue = TextEditingValue(
        text: '20',
        selection: TextSelection.collapsed(offset: 2),
      );
      const newValue = TextEditingValue(
        text: '20a',
        selection: TextSelection.collapsed(offset: 3),
      );

      final resultado = formatter.formatEditUpdate(oldValue, newValue);

      expect(resultado.text, '20');
      expect(resultado.selection.end, 2);
      expect(advertenciaLlamada, isTrue);
    });

    test('bloquea caracteres especiales y símbolos, limpiando el texto pegado', () {
      bool advertenciaLlamada = false;
      final formatter = DigitosConAdvertenciaInputFormatter(
        onCaracterInvalido: () {
          advertenciaLlamada = true;
        },
      );

      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '20-11111111-2',
        selection: TextSelection.collapsed(offset: 13),
      );

      final resultado = formatter.formatEditUpdate(oldValue, newValue);

      expect(resultado.text, '20111111112');
      expect(resultado.selection.end, 11);
      expect(advertenciaLlamada, isTrue);
    });

    test('no dispara advertencia cuando el usuario borra texto', () {
      bool advertenciaLlamada = false;
      final formatter = DigitosConAdvertenciaInputFormatter(
        onCaracterInvalido: () {
          advertenciaLlamada = true;
        },
      );

      const oldValue = TextEditingValue(
        text: '201',
        selection: TextSelection.collapsed(offset: 3),
      );
      const newValue = TextEditingValue(
        text: '20',
        selection: TextSelection.collapsed(offset: 2),
      );

      final resultado = formatter.formatEditUpdate(oldValue, newValue);

      expect(resultado.text, '20');
      expect(advertenciaLlamada, isFalse);
    });
  });

  group('DashboardScreen.formatearCuit', () {
    test('formatea correctamente CUIT de 11 dígitos numéricos', () {
      expect(
        DashboardScreen.formatearCuit('20111111112'),
        '20-11111111-2',
      );
      expect(
        DashboardScreen.formatearCuit('27329642335'),
        '27-32964233-5',
      );
      expect(
        DashboardScreen.formatearCuit('20-11111111-2'),
        '20-11111111-2',
      );
    });

    test('retorna "No registrado" para valores nulos o vacíos', () {
      expect(DashboardScreen.formatearCuit(null), 'No registrado');
      expect(DashboardScreen.formatearCuit(''), 'No registrado');
      expect(DashboardScreen.formatearCuit('   '), 'No registrado');
    });

    test('retorna valor limpio cuando no tiene exactamente 11 dígitos', () {
      expect(DashboardScreen.formatearCuit('12345'), '12345');
    });
  });
}
