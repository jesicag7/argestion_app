# argestion_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Cómo ejecutar la app (Lionel requiere clave de Groq)

La clave de Groq **no está en el repositorio**. Para habilitar el asistente, pasala por consola:

```bash
flutter run --dart-define=GROQ_API_KEY=tu_clave_aqui
```

- Obtené una clave gratuita en la consola de Groq (https://console.groq.com).
- Si no se pasa `GROQ_API_KEY`, la app funciona normalmente, pero Lionel muestra un aviso
  indicando que falta configurar la clave.
- El modelo por defecto es `openai/gpt-oss-20b` (`GeminiService.defaultModel`).
- Para tests: `flutter test test/gemini_service_test.dart` (el test de configuración se ajusta
  según si se pasó la clave).

### Estado de seguridad

Una clave de Groq expuesta en commits anteriores del historial de git debe considerarse
comprometida: revocarla en la consola de Groq y generar una nueva. No la incluyas en el código
ni en archivos versionados. Para una plantilla local, ver `lib/config/secrets.example.dart`
(`lib/config/secrets.dart` está ignorado por git).

### Arquitectura definitiva de producción: backend proxy

La clave no debe estar en la app compilada, porque cualquiera puede extraerla. La arquitectura
recomendada es un proxy en el backend del equipo:

1. **Backend con la clave en el servidor.** Dos opciones:
   - **Cloud Function de Firebase (recomendada).** El proyecto ya usa Firebase Auth
     (`proyectomonotributo`). La función recibe la pregunta y el contexto del usuario, verifica el
     ID token de Firebase y llama a Groq. La clave se guarda como secreto
     (`firebase functions:secrets:set GROQ_API_KEY`), nunca en el repositorio. Requiere plan Blaze
     para salida a internet.
   - **Ruta en el backend Express existente** (`backend/server.js`), desplegada en un hosting
     público (Render, Cloud Run, etc.). Hoy la app apunta por defecto a `http://localhost:3000/api`,
     así que requeriría desplegar el backend y su `service-account.json`.
2. **App Flutter.** `GeminiService` llama al endpoint del proxy con
   `Authorization: Bearer <idToken de FirebaseAuth>`. No maneja ninguna clave de proveedor. La URL
   del endpoint es pública y puede ir en configuración.
3. **Rotación.** Antes de desplegar, revocar las claves expuestas en la consola de Groq y generar
   una nueva, que solo se cargue en el servidor.
4. **Restricciones de Firebase.** Las claves `AIza...` de `firebase_options.dart` y
   `google-services.json` identifican al cliente y no son secretos, pero deben restringirse por
   paquete/SHA y por API en Google Cloud.

Con esta arquitectura, quien clone el repositorio ejecuta `flutter run`, inicia sesión con Firebase
y Lionel funciona sin que nadie configure claves de IA.
