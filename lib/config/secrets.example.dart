// PLANTILLA de configuración local. No contiene secretos y sí se versiona.
//
// La app NO importa este archivo: la clave de Groq se lee exclusivamente con
//   flutter run --dart-define=GROQ_API_KEY=tu_clave_aqui
//
// Si preferís guardar la clave localmente, copiá este archivo como `secrets.dart`
// (ignorado por git) y reemplazá el valor. `secrets.dart` nunca debe subirse al repositorio.

const String groqApiKeyLocal = 'REEMPLAZAR_POR_TU_CLAVE_GROQ';
