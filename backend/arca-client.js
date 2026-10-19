const fs = require('node:fs');
const path = require('node:path');
const forge = require('node-forge');
const soap = require('soap');

const HOMOLOGATION_URLS = {
  wsaa: 'https://wsaahomo.afip.gov.ar/ws/services/LoginCms?WSDL',
  wsfe: 'https://wswhomo.afip.gov.ar/wsfev1/service.asmx?WSDL',
};

const PRODUCTION_URLS = {
  wsaa: 'https://wsaa.afip.gov.ar/ws/services/LoginCms?WSDL',
  wsfe: 'https://servicios1.afip.gov.ar/wsfev1/service.asmx?WSDL',
};

function resolvePem(value, label) {
  if (!value) throw new Error(`Falta configurar ${label}.`);
  if (value.includes('-----BEGIN')) return value.replace(/\\n/g, '\n');
  return fs.readFileSync(path.resolve(process.cwd(), value), 'utf8');
}

function getCredentials(env = process.env) {
  const configured = Boolean(env.ARCA_CERT || env.ARCA_KEY || env.ARCA_CUIT);
  if (!configured) return null;
  if (!env.ARCA_CERT || !env.ARCA_KEY || !env.ARCA_CUIT) {
    throw new Error('ARCA_CERT, ARCA_KEY y ARCA_CUIT deben configurarse juntos.');
  }

  const certPem = resolvePem(env.ARCA_CERT, 'ARCA_CERT');
  const keyPem = resolvePem(env.ARCA_KEY, 'ARCA_KEY');
  const certificate = forge.pki.certificateFromPem(certPem);
  const privateKey = forge.pki.privateKeyFromPem(
    keyPem,
    env.ARCA_KEY_PASSPHRASE || undefined,
  );

  if (new Date(certificate.validity.notAfter).getTime() <= Date.now()) {
    throw new Error('El certificado ARCA configurado está vencido.');
  }
  if (new Date(certificate.validity.notBefore).getTime() > Date.now()) {
    throw new Error('El certificado ARCA todavía no es válido.');
  }
  if (
    certificate.publicKey.n.compareTo(privateKey.n) !== 0 ||
    certificate.publicKey.e.compareTo(privateKey.e) !== 0
  ) {
    throw new Error('ARCA_CERT y ARCA_KEY no pertenecen al mismo certificado.');
  }

  return {
    certPem,
    keyPem,
    certificate,
    privateKey,
    cuit: normalizeDigits(env.ARCA_CUIT),
    production: env.ARCA_PRODUCTION === 'true',
  };
}

function normalizeDigits(value) {
  return String(value ?? '').replace(/\D/g, '');
}

function toSoapDate(value) {
  const date = value ? new Date(value) : new Date();
  if (!Number.isFinite(date.getTime())) {
    throw new Error('La fecha de emisión no tiene un formato válido.');
  }
  return [
    date.getUTCFullYear(),
    String(date.getUTCMonth() + 1).padStart(2, '0'),
    String(date.getUTCDate()).padStart(2, '0'),
  ].join('');
}

function ticketRequestXml(now = new Date()) {
  const generationTime = new Date(now.getTime() - 10 * 60 * 1000);
  const expirationTime = new Date(now.getTime() + 10 * 60 * 1000);
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<loginTicketRequest version="1.0">',
    '<header>',
    `<uniqueId>${Math.floor(now.getTime() / 1000)}</uniqueId>`,
    `<generationTime>${generationTime.toISOString()}</generationTime>`,
    `<expirationTime>${expirationTime.toISOString()}</expirationTime>`,
    '</header>',
    '<service>wsfe</service>',
    '</loginTicketRequest>',
  ].join('');
}

function signTicket(xml, credentials) {
  const signedData = forge.pkcs7.createSignedData();
  signedData.content = forge.util.createBuffer(xml, 'utf8');
  signedData.addCertificate(credentials.certificate);
  signedData.addSigner({
    key: credentials.privateKey,
    certificate: credentials.certificate,
    digestAlgorithm: forge.pki.oids.sha256,
    authenticatedAttributes: [
      { type: forge.pki.oids.contentType, value: forge.pki.oids.data },
      { type: forge.pki.oids.messageDigest },
      { type: forge.pki.oids.signingTime, value: new Date() },
    ],
  });
  signedData.sign({ detached: false });
  return forge.util.encode64(forge.asn1.toDer(signedData.toAsn1()).getBytes());
}

function findXmlValue(xml, name) {
  const match = String(xml).match(
    new RegExp(`<${name}>([\\s\\S]*?)</${name}>`, 'i'),
  );
  return match?.[1] ?? null;
}

function findValue(object, key) {
  if (!object || typeof object !== 'object') return undefined;
  if (Object.hasOwn(object, key)) return object[key];
  for (const value of Object.values(object)) {
    const found = findValue(value, key);
    if (found !== undefined) return found;
  }
  return undefined;
}

function unwrap(value) {
  if (Array.isArray(value)) return value[0];
  return value;
}

class ArcaSoapClient {
  constructor(credentials, soapModule = soap) {
    this.credentials = credentials;
    this.soap = soapModule;
    this.ticket = null;
  }

  async getTicket() {
    if (this.ticket && this.ticket.expiresAt > Date.now() + 30_000) {
      return this.ticket;
    }

    const urls = this.credentials.production
      ? PRODUCTION_URLS
      : HOMOLOGATION_URLS;
    const client = await this.soap.createClientAsync(urls.wsaa);
    const cms = signTicket(ticketRequestXml(), this.credentials);
    const [response] = await client.loginCmsAsync({ in0: cms });
    const xml = findValue(response, 'loginCmsReturn');
    const token = findXmlValue(xml, 'token');
    const sign = findXmlValue(xml, 'sign');
    const expiration = findXmlValue(xml, 'expirationTime');
    if (!token || !sign || !expiration) {
      throw new Error('WSAA no devolvió un ticket de acceso válido.');
    }

    this.ticket = { token, sign, expiresAt: Date.parse(expiration) };
    return this.ticket;
  }

  async emitir(payload) {
    const urls = this.credentials.production
      ? PRODUCTION_URLS
      : HOMOLOGATION_URLS;
    const ticket = await this.getTicket();
    const client = await this.soap.createClientAsync(urls.wsfe);
    const auth = {
      Token: ticket.token,
      Sign: ticket.sign,
      Cuit: Number(this.credentials.cuit),
    };
    const [lastVoucherResponse] =
      await client.FECompUltimoAutorizadoAsync({
        Auth: auth,
        PtoVta: payload.puntoVenta,
        CbteTipo: payload.tipoComprobante,
      });
    const lastVoucher = Number(findValue(lastVoucherResponse, 'CbteNro'));
    if (!Number.isSafeInteger(lastVoucher) || lastVoucher < 0) {
      throw new Error('WSFE devolvió un último número de comprobante inválido.');
    }

    const voucherNumber = lastVoucher + 1;
    const detail = {
      Concepto: payload.concepto,
      DocTipo: payload.tipoDocReceptor,
      DocNro: payload.nroDocReceptor,
      CbteDesde: voucherNumber,
      CbteHasta: voucherNumber,
      CbteFch: toSoapDate(payload.fechaEmision),
      ImpTotal: payload.importeTotal,
      ImpTotConc: 0,
      ImpNeto: payload.importeNeto ?? payload.importeTotal,
      ImpOpEx: 0,
      ImpIVA: 0,
      ImpTrib: 0,
      MonId: payload.moneda ?? 'PES',
      MonCotiz: payload.cotizacion ?? 1,
      ...(payload.concepto === 2 || payload.concepto === 3
        ? {
            FchServDesde: toSoapDate(
              payload.fechaServicioDesde || payload.fechaEmision,
            ),
            FchServHasta: toSoapDate(
              payload.fechaServicioHasta || payload.fechaEmision,
            ),
            FchVtoPago: toSoapDate(
              payload.fechaVencimientoPago || payload.fechaEmision,
            ),
          }
        : {}),
      ...(payload.comprobantesAsociados.length
        ? {
            CbtesAsoc: {
              CbteAsoc: payload.comprobantesAsociados.map((item) => ({
                Tipo: item.tipo,
                PtoVta: item.puntoVenta,
                Nro: item.numero,
              })),
            },
          }
        : {}),
    };

    const [authorizationResponse] = await client.FECAESolicitarAsync({
      Auth: auth,
      FeCAEReq: {
        FeCabReq: {
          CantReg: 1,
          PtoVta: payload.puntoVenta,
          CbteTipo: payload.tipoComprobante,
        },
        FeDetReq: { FECAEDetRequest: [detail] },
      },
    });

    const authorization = findValue(
      authorizationResponse,
      'FECAEDetResponse',
    );
    const voucher = unwrap(authorization);
    const result = voucher?.Resultado ?? findValue(authorizationResponse, 'Resultado');
    if (String(result).toUpperCase() !== 'A') {
      const errors = findValue(authorizationResponse, 'Obs') ??
        findValue(authorizationResponse, 'Err');
      const details = JSON.stringify(errors ?? 'ARCA rechazó la emisión.');
      const error = new Error(`ARCA rechazó el comprobante: ${details}`);
      error.statusCode = 422;
      throw error;
    }

    const cae = String(voucher.CAE ?? '');
    const dueDate = String(voucher.CAEFchVto ?? '');
    const authorizedNumber = Number(voucher.CbteDesde ?? voucher.CbteHasta);
    if (!/^\d{14}$/.test(cae) || !/^\d{8}$/.test(dueDate) ||
        !Number.isSafeInteger(authorizedNumber)) {
      throw new Error('WSFE no devolvió los datos completos de autorización.');
    }

    return {
      exito: true,
      success: true,
      resultado: 'A',
      resultadoEmision: 'Aprobado',
      cae,
      vencimientoCae: dueDate,
      fechaVtoCae: dueDate,
      numeroComprobante: authorizedNumber,
      puntoVenta: payload.puntoVenta,
      tipoComprobante: payload.tipoComprobante,
      modoSimulacion: false,
      modoHomologacion: !this.credentials.production,
      mensaje: 'Comprobante autorizado correctamente por ARCA',
    };
  }
}

module.exports = {
  ArcaSoapClient,
  getCredentials,
  normalizeDigits,
  signTicket,
  ticketRequestXml,
  toSoapDate,
};
