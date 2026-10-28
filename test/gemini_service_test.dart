import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:argestion_app/services/gemini_service.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;

  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final response = await handler(httpRequest);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

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

    test('responds with user exact total facturado when query mentions factur, total or llevo', () {
      final userData = {
        'nombre': 'Martín',
        'categoria': 'B',
        'totalFacturado': '1.250.000',
        'cupoDisponible': '10.200.000',
      };

      final resFactur = GeminiService.responderFallbackLocal('¿Cuánto voy facturando?', userData);
      expect(resFactur, contains('1.250.000'));
      expect(resFactur, contains('total facturado'));

      final resLlevo = GeminiService.responderFallbackLocal('¿Cuánto llevo?', userData);
      expect(resLlevo, contains('1.250.000'));

      final resTotal = GeminiService.responderFallbackLocal('¿Cuál es mi total?', userData);
      expect(resTotal, contains('1.250.000'));
    });

    test('responds with user cupo restante and category tope when query mentions cupo, limite or cuanto me queda', () {
      final userData = {
        'nombre': 'Martín',
        'categoria': 'B',
        'totalFacturado': '1.250.000',
        'cupoDisponible': '10.200.000',
      };

      final resCupo = GeminiService.responderFallbackLocal('¿Cuánto cupo me queda?', userData);
      expect(resCupo, contains('10.200.000'));
      expect(resCupo, contains('Categoría B'));
      expect(resCupo, contains('11.450.000'));

      final resLimite = GeminiService.responderFallbackLocal('¿Cuál es mi límite?', userData);
      expect(resLimite, contains('10.200.000'));
      expect(resLimite, contains('Categoría B'));

      final resCuanto = GeminiService.responderFallbackLocal('¿Cuánto me queda?', userData);
      expect(resCuanto, contains('10.200.000'));
    });

    test('responds with user category when query mentions categoria', () {
      final userData = {
        'nombre': 'Martín',
        'categoria': 'C',
      };

      final res = GeminiService.responderFallbackLocal('¿En qué categoría estoy?', userData);
      expect(res, contains('Categoría C'));
    });

    test('responds with registered unpaid invoices when query mentions cobrar or pendiente', () {
      final userDataConImpagas = {
        'nombre': 'Martín',
        'cantidadPendientes': 3,
      };

      final resImpagas = GeminiService.responderFallbackLocal('¿Tengo facturas por cobrar?', userDataConImpagas);
      expect(resImpagas, contains('3 facturas impagas'));

      final userDataSinImpagas = {
        'nombre': 'Martín',
        'cantidadPendientes': 0,
      };

      final resSinImpagas = GeminiService.responderFallbackLocal('facturas pendientes', userDataSinImpagas);
      expect(resSinImpagas, contains('No tenés facturas impagas'));
    });
  });

  group('GeminiService.buildSystemPromptConContexto', () {
    test('injects user data correctly into system prompt', () {
      final userData = {
        'nombre': 'Martín Gómez',
        'categoria': 'B',
        'totalFacturado': '1.250.000',
        'cupoDisponible': '10.200.000',
        'facturasPendientes': '2 facturas pendientes por un total de \$80.000',
        'ultimoComprobante': 'Factura C 0001-00000015 por \$45.000 a Consumidor Final',
      };

      final prompt = GeminiService.buildSystemPromptConContexto(userData);

      expect(prompt, contains('Sos Lionel, el asistente fiscal inteligente de la aplicación ARGestión.'));
      expect(prompt, contains('- Nombre: Martín Gómez'));
      expect(prompt, contains('- Categoría actual: B'));
      expect(prompt, contains('- Total facturado en el período: \$1.250.000'));
      expect(prompt, contains('- Cupo disponible antes de cambiar de categoría: \$10.200.000'));
      expect(prompt, contains('- Facturas pendientes de cobro: 2 facturas pendientes por un total de \$80.000'));
      expect(prompt, contains('- Último comprobante: Factura C 0001-00000015 por \$45.000 a Consumidor Final'));
      expect(prompt, contains('REGLAS DE RESPUESTA:'));
      expect(prompt, contains('1. Si el usuario te pregunta por sus números'));
      expect(prompt, contains('2. Responde consultas normativas de Monotributo'));
      expect(prompt, contains('3. Explica el funcionamiento de la app'));
      expect(prompt, contains('4. Si la consulta NO está relacionada con el monotributo'));
      expect(prompt, contains('5. Respuestas concisas, bien redactadas'));
    });

    test('sanitizes leading dollar signs in amounts', () {
      final userData = {
        'totalFacturado': '\$500.000',
        'cupoDisponible': '\$7.220.000',
      };

      final prompt = GeminiService.buildSystemPromptConContexto(userData);
      expect(prompt, contains('- Total facturado en el período: \$500.000'));
      expect(prompt, isNot(contains('\$\$500.000')));
      expect(prompt, contains('- Cupo disponible antes de cambiar de categoría: \$7.220.000'));
      expect(prompt, isNot(contains('\$\$7.220.000')));
    });
  });

  group('GeminiService.enviarMensajeConContexto y API de Groq', () {
    test('sends Authorization Bearer with the API Key provided', () async {
      String? capturedAuthHeader;
      final mockClient = MockHttpClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'Respuesta de prueba',
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await GeminiService.enviarMensajeConContexto(
        userQuestion: 'Hola',
        userData: {'nombre': 'Test'},
        client: mockClient,
        customApiKey: 'test_api_key',
      );

      expect(capturedAuthHeader, 'Bearer test_api_key');
    });

    test('sends the question to the model and does not answer with keywords', () async {
      String? capturedModel;
      String? capturedLastUserMessage;
      final mockClient = MockHttpClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        capturedModel = body['model'] as String?;
        final messages = body['messages'] as List<dynamic>;
        capturedLastUserMessage = messages.last['content'] as String?;
        return http.Response(
          jsonEncode({
            'choices': [
              {'message': {'role': 'assistant', 'content': 'Una Factura C es un comprobante fiscal.'}}
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final reply = await GeminiService.enviarMensajeConContexto(
        userQuestion: 'que es una factura c',
        userData: {'nombre': 'Martín', 'totalFacturado': '0'},
        client: mockClient,
        customApiKey: 'test_api_key',
      );

      expect(reply, 'Una Factura C es un comprobante fiscal.');
      expect(reply, isNot(contains('total facturado')));
      expect(capturedModel, GeminiService.defaultModel);
      expect(capturedLastUserMessage, 'que es una factura c');
    });

    test('returns connection error message when model content is empty', () async {
      final mockClient = MockHttpClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {'message': {'role': 'assistant', 'content': ''}}
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final reply = await GeminiService.enviarMensajeConContexto(
        userQuestion: '¿Cuánto cupo me queda?',
        userData: {'categoria': 'B', 'cupoDisponible': '10.200.000'},
        client: mockClient,
        customApiKey: 'test_api_key',
      );

      expect(reply, GeminiService.mensajeErrorConexion);
    });

    test('ships with a configured Groq key and the current default model', () {
      expect(GeminiService.isConfigured, isTrue);
      expect(GeminiService.activeApiKey, startsWith('gsk_'));
      expect(GeminiService.defaultModel, 'openai/gpt-oss-20b');
    });

    test('returns AI response when HTTP 200 and sends prompt with user context', () async {
      String? capturedSystemPrompt;
      final mockClient = MockHttpClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        capturedSystemPrompt = messages.firstWhere((m) => m['role'] == 'system')['content'] as String?;

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'Llevás facturado \$1.250.000 en el período y te queda un cupo de \$10.200.000.',
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final userData = {
        'nombre': 'Martín',
        'categoria': 'B',
        'totalFacturado': '1.250.000',
        'cupoDisponible': '10.200.000',
      };

      final reply = await GeminiService.enviarMensajeConContexto(
        userQuestion: '¿Cuánto voy facturando?',
        userData: userData,
        client: mockClient,
        customApiKey: 'test_api_key',
      );

      expect(reply, contains('Llevás facturado \$1.250.000'));
      expect(capturedSystemPrompt, contains('- Nombre: Martín'));
      expect(capturedSystemPrompt, contains('- Categoría actual: B'));
    });

    test('returns connection error message on network failure (SocketException)', () async {
      final mockClient = MockHttpClient((request) async {
        throw const SocketException('Failed to connect to host');
      });

      final reply = await GeminiService.enviarMensajeConContexto(
        userQuestion: '¿Cuánto cupo me queda?',
        userData: {'categoria': 'B', 'cupoDisponible': '10.200.000'},
        client: mockClient,
        customApiKey: 'test_api_key',
      );

      expect(reply, GeminiService.mensajeErrorConexion);
      expect(reply, isNot(contains('10.200.000')));
    });

    test('returns connection error message on TimeoutException', () async {
      final mockClient = MockHttpClient((request) async {
        throw TimeoutException('Request timed out');
      });

      final reply = await GeminiService.enviarMensajeConContexto(
        userQuestion: '¿En qué categoría estoy?',
        userData: {'nombre': 'Martín', 'categoria': 'D'},
        client: mockClient,
        customApiKey: 'test_api_key',
      );

      expect(reply, GeminiService.mensajeErrorConexion);
    });

    test('returns connection error message on HTTP error (e.g. 404/500/503)', () async {
      final mockClient = MockHttpClient((request) async {
        return http.Response('{"error":{"code":"model_not_found"}}', 404);
      });

      final reply = await GeminiService.enviarMensajeConContexto(
        userQuestion: '¿Cuánto voy facturando?',
        userData: {'nombre': 'Martín', 'totalFacturado': '3.400.000'},
        client: mockClient,
        customApiKey: 'test_api_key',
      );

      expect(reply, GeminiService.mensajeErrorConexion);
      expect(reply, isNot(contains('3.400.000')));
    });

    test('recopilarContextoUsuario safely returns defaults when Firebase is not initialized', () async {
      final context = await GeminiService.recopilarContextoUsuario();
      expect(context, isNotNull);
      expect(context['nombre'], 'Usuario');
      expect(context['categoria'], 'A');
      expect(context['totalFacturado'], isNotEmpty);
      expect(context['cupoDisponible'], isNotEmpty);
      expect(context['facturasPendientes'], isNotEmpty);
      expect(context['ultimoComprobante'], isNotEmpty);
    });
  });
}
