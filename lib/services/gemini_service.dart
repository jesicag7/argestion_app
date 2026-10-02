import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
const String geminiBackupApiKey = String.fromEnvironment('GEMINI_BACKUP_API_KEY', defaultValue: '');

class GeminiService {
  static const String baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  static String get activeApiKey =>
      geminiApiKey.isNotEmpty ? geminiApiKey : geminiBackupApiKey;

  static bool get isConfigured => activeApiKey.trim().isNotEmpty;

  /// Envía una petición de generación de contenido a Google Gemini API
  /// (generativelanguage.googleapis.com).
  ///
  /// AUTENTICACIÓN SEGURA:
  /// NO se envía el header "Authorization: Bearer ..." ya que causa el error
  /// "Expected OAuth 2 access token". La clave se envía en el header 'x-goog-api-key'
  /// y además se incluye en el parámetro de consulta '?key=' de la URL.
  static Future<String?> sendMessage({
    required String prompt,
    String model = 'gemini-2.5-flash',
    String? systemInstruction,
    List<Map<String, String>>? history,
    String? customApiKey,
  }) async {
    final apiKey = (customApiKey != null && customApiKey.isNotEmpty)
        ? customApiKey
        : activeApiKey;

    if (apiKey.isEmpty) {
      debugPrint('GeminiService: No se ha configurado la API Key. Usa --dart-define=GEMINI_API_KEY=...');
      return null;
    }

    final cleanModel = model.startsWith('models/') ? model.substring('models/'.length) : model;
    final url = Uri.parse('$baseUrl/$cleanModel:generateContent?key=$apiKey');

    // Headers seguros para la API de Gemini (sin Authorization Bearer)
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    };

    final contents = <Map<String, dynamic>>[];
    if (history != null && history.isNotEmpty) {
      for (final msg in history) {
        contents.add({
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [
            {'text': msg['text'] ?? ''}
          ],
        });
      }
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ],
    });

    final bodyMap = <String, dynamic>{
      'contents': contents,
    };

    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      bodyMap['systemInstruction'] = {
        'parts': [
          {'text': systemInstruction}
        ],
      };
    }

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(bodyMap),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final candidate = candidates.first as Map<String, dynamic>;
          final content = candidate['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final text = (parts.first as Map<String, dynamic>)['text'] as String?;
            return text?.trim();
          }
        }
        return null;
      } else {
        debugPrint('GeminiService HTTP Error ${response.statusCode}: ${response.body}');
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('>>> ERROR EN GEMINI SERVICE: $e');
      debugPrint('>>> STACKTRACE: $stackTrace');
      rethrow;
    }
  }
}

