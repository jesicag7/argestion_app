require('dotenv').config();

const fs = require('node:fs');
const path = require('node:path');
const cors = require('cors');
const express = require('express');
const { cert, getApps, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const {
  ArcaSoapClient,
  getCredentials,
  normalizeDigits,
} = require('./arca-client');

const SIMULATED_CAE = '74431234567890';
let simulatedVoucherNumber = 0;
let firebaseApp;

function isValidCuit(value) {
  const cuit = normalizeDigits(value);
  if (!/^\d{11}$/.test(cuit)) return false;
  const weights = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
  const sum = weights.reduce(
    (total, weight, index) => total + Number(cuit[index]) * weight,
    0,
  );
  const remainder = 11 - (sum % 11);
  const checkDigit = remainder === 11 ? 0 : remainder === 10 ? 9 : remainder;
  return Number(cuit[10]) === checkDigit;
}

function numberInRange(value, min, max) {
  const number = Number(value);
  return Number.isSafeInteger(number) && number >= min && number <= max;
}

function associatedVouchers(body) {
  const raw =
    body.comprobantesAsociados ??
    body.CbtesAsoc ??
    body.cbtesAsoc ??
    [];
  const items = Array.isArray(raw)
    ? raw
    : Array.isArray(raw.CbteAsoc)
      ? raw.CbteAsoc
      : [];
  return items.map((item) => ({
    tipo: Number(item.tipo ?? item.Tipo),
    puntoVenta: Number(item.puntoVenta ?? item.PtoVta),
    numero: Number(item.numero ?? item.Nro),
  }));
}

function validatePayload(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'El cuerpo debe ser un objeto JSON.' };
  }

  const issuerCuit = normalizeDigits(body.cuitEmisor);
  if (!isValidCuit(issuerCuit)) {
    return { error: 'El CUIT del emisor no es válido.' };
  }
  if (!numberInRange(body.puntoVenta, 1, 99999)) {
    return { error: 'El punto de venta debe estar entre 1 y 99999.' };
  }
  if (![11, 13].includes(Number(body.tipoComprobante))) {
    return { error: 'Solo se admiten Factura C (11) y Nota de Crédito C (13).' };
  }
  if (!numberInRange(body.concepto, 1, 3)) {
    return { error: 'El concepto debe ser 1 (productos), 2 (servicios) o 3.' };
  }

  const tipoDocReceptor = Number(
    body.tipoDocReceptor ?? body.tipoDocumentoReceptor,
  );
  const nroDocReceptor = Number(
    body.nroDocReceptor ?? body.numeroDocumentoReceptor,
  );
  if (![80, 86, 96, 99].includes(tipoDocReceptor)) {
    return { error: 'El tipo de documento del receptor no es válido.' };
  }
  if (!Number.isSafeInteger(nroDocReceptor) || nroDocReceptor < 0) {
    return { error: 'El número de documento del receptor no es válido.' };
  }
  if ([80, 86].includes(tipoDocReceptor) && !isValidCuit(nroDocReceptor)) {
    return { error: 'El CUIT/CUIL del receptor no es válido.' };
  }
  if (
    tipoDocReceptor === 96 &&
    !/^\d{7,8}$/.test(String(nroDocReceptor))
  ) {
    return { error: 'El DNI del receptor debe tener 7 u 8 dígitos.' };
  }
  if (tipoDocReceptor === 99 && nroDocReceptor !== 0) {
    return { error: 'Consumidor final debe informarse con documento 0.' };
  }

  const importeTotal = Number(body.importeTotal);
  if (!Number.isFinite(importeTotal) || importeTotal <= 0) {
    return { error: 'El importe total debe ser mayor que cero.' };
  }
  const importeNeto = Number(body.importeNeto ?? importeTotal);
  if (!Number.isFinite(importeNeto) || importeNeto < 0 || importeNeto > importeTotal) {
    return { error: 'El importe neto debe estar entre cero y el importe total.' };
  }
  const fechaEmision =
    typeof body.fechaEmision === 'string' &&
    /^\d{4}-\d{2}-\d{2}$/.test(body.fechaEmision)
      ? new Date(`${body.fechaEmision}T00:00:00Z`)
      : null;
  if (
    !fechaEmision ||
    !Number.isFinite(fechaEmision.getTime()) ||
    fechaEmision.toISOString().slice(0, 10) !== body.fechaEmision
  ) {
    return { error: 'La fecha de emisión debe tener formato YYYY-MM-DD.' };
  }

  const comprobantesAsociados = associatedVouchers(body);
  if (Number(body.tipoComprobante) === 13) {
    if (
      comprobantesAsociados.length === 0 ||
      comprobantesAsociados.some(
        (item) =>
          !numberInRange(item.tipo, 1, 999) ||
          !numberInRange(item.puntoVenta, 1, 99999) ||
          !numberInRange(item.numero, 1, 99999999),
      )
    ) {
      return {
        error: 'La Nota de Crédito requiere al menos un comprobante asociado válido.',
      };
    }
  } else if (comprobantesAsociados.length > 0) {
    return { error: 'Una Factura C no debe incluir comprobantes asociados.' };
  }

  return {
    payload: {
      ...body,
      cuitEmisor: issuerCuit,
      puntoVenta: Number(body.puntoVenta),
      tipoComprobante: Number(body.tipoComprobante),
      concepto: Number(body.concepto),
      tipoDocReceptor,
      nroDocReceptor,
      importeTotal,
      importeNeto,
      comprobantesAsociados,
    },
  };
}

function buildFirebaseOptions(env) {
  const projectId = env.FIREBASE_PROJECT_ID;
  const serviceAccountPath = env.FIREBASE_SERVICE_ACCOUNT_PATH;
  const absolutePath = serviceAccountPath
    ? path.resolve(process.cwd(), serviceAccountPath)
    : null;
  // verifyIdToken valida la firma con las claves públicas de Google y solo
  // necesita el projectId. Las credenciales de servicio se usan si el archivo
  // existe; si falta, no se fuerza un error de credenciales.
  if (absolutePath && fs.existsSync(absolutePath)) {
    return {
      credential: cert(JSON.parse(fs.readFileSync(absolutePath, 'utf8'))),
      projectId,
    };
  }
  if (!projectId) {
    console.error(
      '[auth] FIREBASE_PROJECT_ID no está definido en backend/.env; ' +
        'la verificación de sesiones Firebase fallará.',
    );
  } else if (absolutePath) {
    console.warn(
      `[auth] No se encontró ${serviceAccountPath}; se verifica el token ` +
        'solo con FIREBASE_PROJECT_ID.',
    );
  }
  return { projectId };
}

function getFirebaseVerifier(env = process.env) {
  if (!firebaseApp) {
    if (getApps().length > 0) {
      firebaseApp = getApps()[0];
    } else {
      firebaseApp = initializeApp(buildFirebaseOptions(env));
    }
  }
  return (token) => getAuth(firebaseApp).verifyIdToken(token);
}

function errorResponse(res, status, message) {
  return res.status(status).json({ exito: false, error: message });
}

function createApp({
  verifyToken = (token) => getFirebaseVerifier(env)(token),
  emit = emitirComprobante,
  env = process.env,
} = {}) {
  const app = express();
  const origins = (env.CORS_ORIGIN || '*')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  app.use(
    cors({
      origin: origins.includes('*') ? '*' : origins,
      allowedHeaders: ['Content-Type', 'Authorization'],
    }),
  );
  app.use(express.json({ limit: '32kb' }));

  app.get('/health', (_req, res) => res.json({ status: 'ok' }));

  app.post('/api/emitir-comprobante', async (req, res) => {
    const authorization = req.get('authorization') || '';
    const tokenMatch = authorization.match(/^Bearer\s+(.+)$/i);
    if (!tokenMatch) {
      return errorResponse(res, 401, 'Se requiere una sesión Firebase válida.');
    }
    try {
      await verifyToken(tokenMatch[1]);
    } catch (error) {
      console.error(
        `[auth] verifyIdToken falló (${error?.code ?? 'sin código'}): ` +
          `${error?.message ?? error}`,
      );
      return errorResponse(res, 401, 'La sesión Firebase no es válida.');
    }

    const validation = validatePayload(req.body);
    if (validation.error) return errorResponse(res, 400, validation.error);

    try {
      const result = await emit(validation.payload, env);
      return res.status(200).json(result);
    } catch (error) {
      const status = Number(error.statusCode);
      const responseStatus =
        status === 400 || status === 422 ? status : 502;
      return errorResponse(
        res,
        responseStatus,
        status === 400 || status === 422
          ? error.message
          : 'No se pudo completar la autorización con ARCA.',
      );
    }
  });

  app.use((error, _req, res, _next) => {
    if (error instanceof SyntaxError && 'body' in error) {
      return errorResponse(res, 400, 'El JSON recibido no es válido.');
    }
    return errorResponse(res, 500, 'Error interno del backend fiscal.');
  });

  return app;
}

async function emitirComprobante(payload, env) {
  const credentials = getCredentials(env);
  if (!credentials) {
    if (!isValidCuit(payload.cuitEmisor)) {
      throw new Error('CUIT del emisor inválido.');
    }
    simulatedVoucherNumber += 1;
    const dueDate = new Date();
    dueDate.setUTCDate(dueDate.getUTCDate() + 10);
    const vencimientoCae = [
      dueDate.getUTCFullYear(),
      String(dueDate.getUTCMonth() + 1).padStart(2, '0'),
      String(dueDate.getUTCDate()).padStart(2, '0'),
    ].join('');
    return {
      exito: true,
      success: true,
      resultado: 'A',
      resultadoEmision: 'Aprobado',
      cae: SIMULATED_CAE,
      vencimientoCae,
      fechaVtoCae: vencimientoCae,
      numeroComprobante: simulatedVoucherNumber,
      puntoVenta: payload.puntoVenta,
      tipoComprobante: payload.tipoComprobante,
      modoSimulacion: true,
      modoHomologacion: true,
      mensaje: 'Comprobante emitido correctamente en entorno de prueba fiscal',
    };
  }

  if (!isValidCuit(credentials.cuit)) {
    const error = new Error('El CUIT configurado en ARCA_CUIT no es válido.');
    error.statusCode = 400;
    throw error;
  }
  if (payload.cuitEmisor !== credentials.cuit) {
    const error = new Error('El CUIT emisor no coincide con ARCA_CUIT.');
    error.statusCode = 400;
    throw error;
  }

  const client = new ArcaSoapClient(credentials);
  return client.emitir(payload);
}

if (require.main === module) {
  const port = Number(process.env.PORT || 3000);
  createApp().listen(port, '0.0.0.0', () => {
    console.log(`Backend fiscal disponible en http://localhost:${port}`);
  });
}

module.exports = {
  createApp,
  isValidCuit,
  validatePayload,
  emitirComprobante,
};
