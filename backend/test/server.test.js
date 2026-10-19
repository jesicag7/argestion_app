const { after, before, test } = require('node:test');
const assert = require('node:assert/strict');
const {
  createApp,
  emitirComprobante,
  isValidCuit,
  validatePayload,
} = require('../server');

let server;
let baseUrl;
let nextVoucher = 1;

before(async () => {
  const app = createApp({
    verifyToken: async (token) => {
      if (token !== 'valid-test-token') throw new Error('invalid');
      return { uid: 'test-user' };
    },
    emit: async (payload) => ({
      exito: true,
      success: true,
      resultadoEmision: 'Aprobado',
      cae: '74431234567890',
      vencimientoCae: '20261029',
      fechaVtoCae: '20261029',
      numeroComprobante: nextVoucher++,
      puntoVenta: payload.puntoVenta,
      tipoComprobante: payload.tipoComprobante,
      modoSimulacion: true,
      modoHomologacion: true,
      mensaje: 'Comprobante emitido correctamente en entorno de prueba fiscal',
    }),
  });
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  if (server) await new Promise((resolve) => server.close(resolve));
});

const facturaC = {
  cuitEmisor: '20329642330',
  puntoVenta: 1,
  tipoComprobante: 11,
  concepto: 2,
  tipoDocReceptor: 99,
  nroDocReceptor: 0,
  importeTotal: 1000,
  importeNeto: 1000,
  fechaEmision: '2026-10-19',
};

test('validates CUIT check digits', () => {
  assert.equal(isValidCuit('20329642330'), true);
  assert.equal(isValidCuit('20329642331'), false);
});

test('simulated issuer is marked as a sandbox and increments voucher numbers', async () => {
  const first = await emitirComprobante(
    { ...facturaC, puntoVenta: 5 },
    {},
  );
  const second = await emitirComprobante(
    { ...facturaC, puntoVenta: 5 },
    {},
  );

  assert.equal(first.exito, true);
  assert.equal(first.modoSimulacion, true);
  assert.equal(first.puntoVenta, 5);
  assert.equal(second.numeroComprobante, first.numeroComprobante + 1);
  assert.match(first.vencimientoCae, /^\d{8}$/);
});

test('accepts valid Factura C payload', () => {
  const result = validatePayload(facturaC);
  assert.equal(result.error, undefined);
  assert.equal(result.payload.tipoComprobante, 11);
});

test('requires a valid associated voucher for Nota de Crédito C', () => {
  const result = validatePayload({
    ...facturaC,
    tipoComprobante: 13,
    CbtesAsoc: [{ Tipo: 11, PtoVta: 1, Nro: 123 }],
  });
  assert.equal(result.error, undefined);
  assert.deepEqual(result.payload.comprobantesAsociados, [
    { tipo: 11, puntoVenta: 1, numero: 123 },
  ]);
  assert.match(
    validatePayload({ ...facturaC, tipoComprobante: 13 }).error,
    /comprobante asociado/,
  );
});

test('rejects invalid receiver CUIT and negative amounts', async () => {
  assert.match(
    validatePayload({
      ...facturaC,
      tipoDocReceptor: 80,
      nroDocReceptor: 20123456789,
    }).error,
    /CUIT\/CUIL del receptor/,
  );

  const response = await fetch(`${baseUrl}/api/emitir-comprobante`, {
    method: 'POST',
    headers: {
      Authorization: 'Bearer valid-test-token',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ ...facturaC, importeTotal: -1 }),
  });
  assert.equal(response.status, 400);
  assert.equal((await response.json()).exito, false);
});

test('requires Firebase bearer token and returns the Flutter-compatible shape', async () => {
  const unauthorized = await fetch(`${baseUrl}/api/emitir-comprobante`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(facturaC),
  });
  assert.equal(unauthorized.status, 401);

  const response = await fetch(`${baseUrl}/api/emitir-comprobante`, {
    method: 'POST',
    headers: {
      Authorization: 'Bearer valid-test-token',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(facturaC),
  });
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.exito, true);
  assert.equal(body.success, true);
  assert.equal(body.resultadoEmision, 'Aprobado');
  assert.equal(body.numeroComprobante, 1);
  assert.equal(body.modoSimulacion, true);
});
