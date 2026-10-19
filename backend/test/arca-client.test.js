const { test } = require('node:test');
const assert = require('node:assert/strict');
const forge = require('node-forge');
const {
  ArcaSoapClient,
  getCredentials,
  signTicket,
  ticketRequestXml,
} = require('../arca-client');

function createTestCredentials() {
  const keys = forge.pki.rsa.generateKeyPair(1024);
  const certificate = forge.pki.createCertificate();
  certificate.publicKey = keys.publicKey;
  certificate.serialNumber = '01';
  certificate.validity.notBefore = new Date(Date.now() - 60_000);
  certificate.validity.notAfter = new Date(Date.now() + 60_000);
  certificate.setSubject([{ name: 'commonName', value: 'Test issuer' }]);
  certificate.setIssuer([{ name: 'commonName', value: 'Test issuer' }]);
  certificate.sign(keys.privateKey, forge.md.sha256.create());

  return getCredentials({
    ARCA_CERT: forge.pki.certificateToPem(certificate),
    ARCA_KEY: forge.pki.privateKeyToPem(keys.privateKey),
    ARCA_CUIT: '20329642330',
    ARCA_PRODUCTION: 'false',
  });
}

test('creates an encapsulated CMS ticket request using the configured key', () => {
  const credentials = createTestCredentials();
  const xml = ticketRequestXml(new Date('2026-10-19T12:00:00.000Z'));
  const cms = signTicket(xml, credentials);
  const asn1 = forge.asn1.fromDer(forge.util.decode64(cms));
  const signedContent =
    asn1.value[1].value[0].value[2].value[1].value[0].value;

  assert.equal(signedContent, xml);
  assert.match(xml, /<service>wsfe<\/service>/);
});

test('calls WSAA then WSFE with the associated receipt for a credit note', async () => {
  const credentials = createTestCredentials();
  let authorizationRequest;
  const soapModule = {
    async createClientAsync(wsdl) {
      if (wsdl.includes('LoginCms')) {
        return {
          async loginCmsAsync({ in0 }) {
            assert.ok(in0.length > 100);
            const expiry = new Date(Date.now() + 60 * 60 * 1000).toISOString();
            return [
              {
                loginCmsReturn: `<loginTicketResponse><credentials><token>token</token><sign>sign</sign><expirationTime>${expiry}</expirationTime></credentials></loginTicketResponse>`,
              },
            ];
          },
        };
      }
      return {
        async FECompUltimoAutorizadoAsync(request) {
          assert.equal(request.CbteTipo, 13);
          return [{ FECompUltimoAutorizadoResult: { CbteNro: 41 } }];
        },
        async FECAESolicitarAsync(request) {
          authorizationRequest = request;
          return [
            {
              FECAESolicitarResult: {
                FeDetResp: {
                  FECAEDetResponse: [
                    {
                      Resultado: 'A',
                      CAE: '74431234567890',
                      CAEFchVto: '20261029',
                      CbteDesde: 42,
                    },
                  ],
                },
              },
            },
          ];
        },
      };
    },
  };

  const client = new ArcaSoapClient(credentials, soapModule);
  const response = await client.emitir({
    puntoVenta: 1,
    tipoComprobante: 13,
    concepto: 2,
    tipoDocReceptor: 99,
    nroDocReceptor: 0,
    importeTotal: 15000,
    importeNeto: 15000,
    fechaEmision: '2026-10-19',
    comprobantesAsociados: [
      { tipo: 11, puntoVenta: 1, numero: 41 },
    ],
  });

  assert.deepEqual(
    authorizationRequest.FeCAEReq.FeDetReq.FECAEDetRequest[0].CbtesAsoc,
    { CbteAsoc: [{ Tipo: 11, PtoVta: 1, Nro: 41 }] },
  );
  assert.equal(response.exito, true);
  assert.equal(response.numeroComprobante, 42);
  assert.equal(response.modoSimulacion, false);
});
