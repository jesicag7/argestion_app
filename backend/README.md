# Backend fiscal de ARGestión

Este servicio recibe las solicitudes de Flutter y, según su configuración,
emite comprobantes mediante WSAA y WSFE de ARCA o responde desde un sandbox
simulado para desarrollo. La simulación no es una autorización fiscal y sus
CAE no son válidos ante ARCA.

## Requisitos e inicio

- Node.js 20 o superior.
- Un archivo de credenciales de servicio de Firebase para verificar el token
  de sesión que envía Flutter.

Desde este directorio:

```sh
copy .env.example .env
npm install
npm start
```

Para desarrollo con reinicio automático, usar `npm run dev`. El backend escucha
por defecto en el puerto 3000; `GET /health` confirma que está activo. La ruta
fiscal es `POST /api/emitir-comprobante`.

## Firebase y pruebas locales

Configurar `FIREBASE_PROJECT_ID` y `GOOGLE_APPLICATION_CREDENTIALS` para que
Firebase Admin valide el token Bearer de Flutter. El archivo de credenciales
debe mantenerse privado y fuera de Git.

Si `ARCA_CERT`, `ARCA_KEY` y `ARCA_CUIT` no están definidos, se habilita la
simulación validada. El contador simulado es incremental durante la ejecución
del proceso y vuelve a empezar cuando se reinicia el servidor. Para ejecutar
pruebas:

```sh
npm test
```

## Certificados ARCA para homologación o producción

Obtener de ARCA un certificado X.509 y su clave privada habilitados para WSFE.
Guardar los archivos en un directorio privado, preferentemente fuera del
repositorio, y definir en `.env`:

```dotenv
ARCA_CERT=C:/ruta/privada/arca.crt
ARCA_KEY=C:/ruta/privada/arca.key
ARCA_CUIT=20123456786
ARCA_KEY_PASSPHRASE=
ARCA_PRODUCTION=false
```

`ARCA_CERT` y `ARCA_KEY` admiten rutas a archivos PEM o contenido PEM directo.
El servidor comprueba la vigencia del certificado y que corresponda a la clave
privada configurada. `ARCA_PRODUCTION=false` apunta a los servicios de
homologación; solo cambiar a `true` una vez que el certificado y el punto de
venta estén habilitados para producción. La configuración parcial o inválida
de certificados detiene la emisión; no se degrada silenciosamente al sandbox.
La autenticación WSAA/CMS y las llamadas SOAP a WSFE se realizan directamente
desde este backend con el certificado local, sin enviar los datos del
comprobante a un intermediario externo.

El servicio verifica el CUIT emisor y lo compara con `ARCA_CUIT`. Las claves,
certificados y credenciales Firebase nunca deben incluirse en el repositorio.
En despliegues públicos, restringir `CORS_ORIGIN`, usar HTTPS y proteger el
acceso de red al servidor.

## Contrato

El backend acepta `tipoComprobante` 11 (Factura C) y 13 (Nota de Crédito C).
Para notas de crédito requiere `CbtesAsoc` o `comprobantesAsociados`, con al
menos un tipo, punto de venta y número de comprobante asociado. Los errores de
validación responden HTTP 400 con `{ "exito": false, "error": "..." }`.

Las respuestas exitosas incluyen `exito`, `success`, `cae`,
`vencimientoCae` (`YYYYMMDD`), `fechaVtoCae`, `numeroComprobante`,
`puntoVenta`, `tipoComprobante`, `resultadoEmision` y `modoSimulacion` para que
Flutter pueda reconocer la respuesta y generar el QR reglamentario para
comprobantes autorizados.

Flutter usa `ARCA_API_URL` como URL base, con valor local predeterminado
`http://localhost:3000/api`, y envía el token Firebase como Bearer.
Para permitir que Flutter use el CUIT de prueba `20111111112` cuando el perfil
no tenga un CUIT válido, activar explícitamente el modo sandbox local:

```sh
flutter run --dart-define=ARCA_SANDBOX=true
```

El fallback solo se habilita con `ARCA_HOMOLOGACION=true` y una URL local. En
los demás casos, la aplicación solicita un CUIT válido y lo guarda en el perfil
antes de emitir.
