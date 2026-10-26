import 'package:flutter_test/flutter_test.dart';
import 'package:argestion_app/services/gemini_service.dart';

void main() {
  group('GeminiService.responderFallbackLocal', () {
    test('explains invoice cancellation with a credit note', () {
      final response = GeminiService.responderFallbackLocal(
        '¿Cómo anulo una factura?',
      );

      expect(response, contains('Nota de Crédito C'));
    });

    test('explains the monotributo income limit and exclusion risk', () {
      final response = GeminiService.responderFallbackLocal(
        '¿Qué pasa si supero el tope?',
      );

      expect(response, contains('Categoría K'));
      expect(response, contains('excluido del Monotributo'));
    });

    test('returns general guidance for an unrelated question', () {
      final response = GeminiService.responderFallbackLocal(
        '¿Qué podés hacer?',
      );

      expect(response, contains('facturación electrónica'));
      expect(response, contains('recategorización semestral'));
    });
  });

  group('GeminiService.sendMessage sin API key', () {
    test('responde en modo local y lo informa, sin usar otra clave', () async {
      // Los tests no reciben --dart-define: la clave de Groq está vacía.
      final respuesta = await GeminiService.sendMessage(
        prompt: '¿Cómo anulo una factura?',
      );

      expect(respuesta.esLocal, isTrue);
      expect(respuesta.texto, contains('Nota de Crédito C'));
      expect(GeminiService.activeApiKey, groqApiKey);
    });
  });
}
