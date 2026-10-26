import 'package:flutter_test/flutter_test.dart';
import 'package:argestion_app/models/factura_model.dart';
import 'package:argestion_app/models/monotributo_category.dart';

/// Documento de factura C tal como se guarda en `facturas`.
Map<String, dynamic> factura({
  double monto = 100,
  bool cobrada = false,
  bool anulada = false,
  String? ncId,
  String tipo = 'Factura C',
}) {
  return {
    'userId': 'usuario-1',
    'tipo_comprobante': tipo,
    'monto': monto,
    'estadoCobro': cobrada ? 'Cobrada' : 'Pendiente',
    'cobrada': cobrada,
    'anulada': anulada,
    'es_anulada': anulada,
    'anuladaPorNcId': ncId,
    'anulada_por_nc_id': ncId,
    'resultadoEmision': 'Aprobado',
    'cae': '74111111111111',
    'fecha_emision': '2026-10-10T00:00:00.000',
  };
}

/// Nota de Crédito C que anula la factura [asociadaId].
Map<String, dynamic> notaCredito({
  required String asociadaId,
  double monto = 100,
}) {
  return {
    'userId': 'usuario-1',
    'tipo_comprobante': 'Nota de Crédito C',
    'esNotaCredito': true,
    'monto': monto,
    'estadoCobro': 'Pendiente',
    'cobrada': false,
    'anulada': false,
    'comprobanteAsociadoId': asociadaId,
    'fecha_emision': '2026-10-12T00:00:00.000',
  };
}

typedef _Doc = ({String id, Map<String, dynamic> data});

void main() {
  group('Impacto fiscal (tope y cupo mensual)', () {
    test('factura sola suma su importe completo', () {
      expect(
        MonotributoCategory.impactoFiscalDocumento(factura(monto: 100)),
        100,
      );
    });

    test('factura pendiente + NC: el total facturado neto es 0', () {
      final docs = [
        factura(monto: 100),
        notaCredito(asociadaId: 'f1', monto: 100),
      ];
      final total = docs.fold<double>(
        0,
        (suma, d) => suma + MonotributoCategory.impactoFiscalDocumento(d),
      );
      expect(total, 0);
    });

    test('factura anulada con NC asociada suma 0 con su NC', () {
      final docs = [
        factura(monto: 100, anulada: true, ncId: 'nc1'),
        notaCredito(asociadaId: 'f1', monto: 100),
      ];
      final total = docs.fold<double>(
        0,
        (suma, d) => suma + MonotributoCategory.impactoFiscalDocumento(d),
      );
      expect(total, 0);
    });

    test('la NC nunca suma al tope aunque su monto venga positivo', () {
      expect(
        MonotributoCategory.impactoFiscalDocumento(
          notaCredito(asociadaId: 'f1', monto: 250),
        ),
        -250,
      );
    });
  });

  group('Ingresos cobrados (neto)', () {
    test('factura cobrada sola suma su importe', () {
      final docs = <_Doc>[(id: 'f1', data: factura(cobrada: true))];
      expect(
        MonotributoCategory.netoCobrado(docs, enPeriodo: (_) => true),
        100,
      );
    });

    test('factura pendiente sola no suma ingresos cobrados', () {
      final docs = <_Doc>[(id: 'f1', data: factura())];
      expect(MonotributoCategory.netoCobrado(docs, enPeriodo: (_) => true), 0);
    });

    test('factura cobrada + NC: neto cobrado 0', () {
      final docs = <_Doc>[
        (id: 'f1', data: factura(cobrada: true, anulada: true, ncId: 'nc1')),
        (id: 'nc1', data: notaCredito(asociadaId: 'f1')),
      ];
      expect(MonotributoCategory.netoCobrado(docs, enPeriodo: (_) => true), 0);
    });

    test('factura pendiente + NC: neto cobrado 0, sin saldo negativo', () {
      final docs = <_Doc>[
        (id: 'f1', data: factura(anulada: true, ncId: 'nc1')),
        (id: 'nc1', data: notaCredito(asociadaId: 'f1')),
      ];
      final neto = MonotributoCategory.netoCobrado(
        docs,
        enPeriodo: (_) => true,
      );
      expect(neto, 0);
      expect(neto, isNot(lessThan(0)));
    });

    test('NC que no referencia una factura cobrada no resta', () {
      final docs = <_Doc>[
        (id: 'f2', data: factura(cobrada: true)),
        (id: 'nc1', data: notaCredito(asociadaId: 'otra-factura')),
      ];
      expect(
        MonotributoCategory.netoCobrado(docs, enPeriodo: (_) => true),
        100,
      );
    });

    test('solo cuenta documentos dentro del período', () {
      final docs = <_Doc>[
        (id: 'f1', data: factura(cobrada: true)),
        (id: 'nc1', data: notaCredito(asociadaId: 'f1')),
      ];
      // La NC cae en el período y la factura no: se resta lo cobrado de
      // origen fuera de período, por eso el neto del período es -100.
      final neto = MonotributoCategory.netoCobrado(
        docs,
        enPeriodo: (data) => data['tipo_comprobante'] == 'Nota de Crédito C',
      );
      expect(neto, -100);
    });
  });

  group('Anulación: validación antes de emitir la NC', () {
    test('factura válida puede anularse', () {
      expect(FacturaModel.motivoNoAnulable(factura()), isNull);
    });

    test('no permite emitir NC sobre una factura ya anulada', () {
      final motivo = FacturaModel.motivoNoAnulable(
        factura(anulada: true, ncId: 'nc-existente'),
      );
      expect(motivo, isNotNull);
      expect(motivo, contains('ya fue anulada'));
    });

    test('detecta anulación por NC aunque el flag anulada falte', () {
      final motivo = FacturaModel.motivoNoAnulable(
        factura(ncId: 'nc-existente'),
      );
      expect(motivo, isNotNull);
    });

    test('rechaza factura inexistente', () {
      expect(FacturaModel.motivoNoAnulable(null), isNotNull);
    });

    test(
      'rechaza anular una Nota de Crédito o un tipo distinto de Factura C',
      () {
        expect(
          FacturaModel.motivoNoAnulable(notaCredito(asociadaId: 'f1')),
          isNotNull,
        );
        expect(
          FacturaModel.motivoNoAnulable(factura(tipo: 'Factura B')),
          isNotNull,
        );
      },
    );

    test('la excepción expone el motivo como mensaje', () {
      const e = FacturaNoAnulableException('motivo de prueba');
      expect(e.toString(), 'motivo de prueba');
    });
  });
}
