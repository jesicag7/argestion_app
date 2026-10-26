// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

// La clave nunca se versiona: se inyecta en build con
// --dart-define=GROQ_API_KEY=... Sin clave, el asistente usa el fallback local.
const String groqApiKey = String.fromEnvironment(
  'GROQ_API_KEY',
  defaultValue: '',
);

/// Resultado de una consulta al asistente. [esLocal] es true cuando el texto
/// proviene del motor local porque la API no está configurada o no respondió.
class RespuestaAsistente {
  const RespuestaAsistente(this.texto, {required this.esLocal});

  final String texto;
  final bool esLocal;
}

class GeminiService {
  static const String endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  static String get activeApiKey => groqApiKey;

  static bool get isConfigured => activeApiKey.trim().isNotEmpty;

  /// Normaliza el texto quitando acentos y signos antes de buscar coincidencias
  static String _normalizarTexto(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('?', '')
        .replaceAll('¿', '');
  }

  /// Motor fiscal local de respaldo para responder siempre ante problemas de red o IA
  static String responderFallbackLocal(String prompt) {
    final p = _normalizarTexto(prompt);

    if (p.contains('anular') || p.contains('anulo') || p.contains('credito')) {
      return 'Las facturas electrónicas ya autorizadas con CAE por ARCA no se pueden eliminar ni modificar. Para anular una Factura C emitida por error (total o parcialmente), se debe emitir una Nota de Crédito C por el mismo concepto e importe, vinculando el número del comprobante original. De este modo, la Nota de Crédito compensa el impacto fiscal en ARCA.';
    }

    if (p.contains('dni') || p.contains('consumidor')) {
      return 'Al facturar a un Consumidor Final, no es obligatorio identificar al cliente con su DNI siempre que el importe de la operación no supere los topes límites vigentes fijados periódicamente por ARCA. Si la operación supera dicho importe límite (o si el comprador lo solicita expresamente), es obligatorio consignar su número de DNI o CUIT en la Factura C.';
    }

    if (p.contains('tope') || p.contains('supero') || p.contains('limite')) {
      return 'Si superás el tope de facturación de tu categoría actual pero sin exceder el máximo del Monotributo, deberás recategorizarte en la escala superior en el siguiente período semestral (enero o julio). Si tus ingresos acumulados superan el límite anual máximo de la Categoría K (la escala máxima del régimen), quedás automáticamente excluido del Monotributo y debés pasar al Régimen General (inscribirte en IVA, Impuesto a las Ganancias y Autónomos).';
    }

    if (p.contains('vep') ||
        p.contains('pagar') ||
        p.contains('vencimiento') ||
        p.contains('vence')) {
      return 'La cuota mensual del Monotributo tiene su vencimiento los días 20 de cada mes (o el día hábil posterior si es feriado o fin de semana). Podés generar el Volante Electrónico de Pago (VEP) desde el servicio Monotributo de ARCA o copiando el código desde la sección Pagos de ARGestión, y abonarlo ingresando dicho código en tu home banking (Red Link o Banelco) o a través de billeteras virtuales habilitadas.';
    }

    if (p.contains('recategorizacion') ||
        (p.contains('cuando') &&
            !p.contains('vep') &&
            !p.contains('pagar') &&
            !p.contains('vencimiento') &&
            !p.contains('vence'))) {
      return 'La recategorización del Monotributo se realiza de forma semestral en los meses de enero y julio (hasta el día 20 o según el calendario de ARCA). Debés evaluar la facturación bruta y los parámetros de los últimos 12 meses acumulados. Si cambiás de escala, ingresás al portal de ARCA con CUIT y Clave Fiscal en el servicio "Monotributo" y seleccionás "Recategorización". Si mantuviste los parámetros dentro de tu misma categoría, no es necesario hacer ningún trámite.';
    }

    if (p.contains('comprobante') || p.contains('tipo')) {
      return 'Como monotributista debés emitir obligatoriamente Factura C para respaldar todas tus ventas de bienes o locaciones de servicios a cualquier destinatario (consumidores finales, monotributistas o responsables inscriptos). En caso de devoluciones o ajustes de importes, se utilizan Notas de Crédito C o Notas de Débito C.';
    }

    return 'Como asistente de ARGestión puedo orientarte sobre facturación electrónica, categorías de Monotributo, emisión de VEP, topes de facturación y recategorización semestral. ¿En qué tema puntual precisás ayuda?';
  }

  /// Consulta directa con Fallback Local automático garantizado
  static Future<String> enviarConsulta(String prompt) async {
    final respuesta = await sendMessage(prompt: prompt);
    return respuesta.texto;
  }

  static RespuestaAsistente _respuestaLocal(String prompt) =>
      RespuestaAsistente(responderFallbackLocal(prompt), esLocal: true);

  /// Envía una petición de generación de contenido a la API de Groq
  /// utilizando el modelo Llama 3.1 (llama-3.1-8b-instant).
  /// Si no hay clave configurada o falla la red, la API o la respuesta, devuelve
  /// el Fallback Local con [RespuestaAsistente.esLocal] en true.
  static Future<RespuestaAsistente> sendMessage({
    required String prompt,
    String model = 'llama-3.1-8b-instant',
    String? systemInstruction,
    List<Map<String, String>>? history,
  }) async {
    final apiKey = activeApiKey;

    if (apiKey.isEmpty) {
      print('API Key no provista. Activando fallback local.');
      return _respuestaLocal(prompt);
    }

    final url = Uri.parse(endpoint);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final String systemContent =
        (systemInstruction != null && systemInstruction.isNotEmpty)
        ? systemInstruction
        : 'Sos Lionel, un asistente virtual experto y amigable de la aplicación ARGestión para monotributistas de Argentina. Respondé de forma clara, concisa, profesional y en español rioplatense (usando voseo cordial) sobre Monotributo, ARCA/AFIP, Factura C, pago de VEP, topes de facturación, recategorización semestral y vencimientos.';

    final bodyMap = <String, dynamic>{
      'model': model.isNotEmpty ? model : 'llama-3.1-8b-instant',
      'messages': [
        {'role': 'system', 'content': systemContent},
        if (history != null)
          ...history.map(
            (h) => {
              'role': (h['role'] == 'user') ? 'user' : 'assistant',
              'content': h['text'] ?? '',
            },
          ),
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.5,
      'max_tokens': 500,
    };

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(bodyMap))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print(
          'Error Groq HTTP (${response.statusCode}). Activando fallback local.',
        );
        return _respuestaLocal(prompt);
      }
      final dynamic data = jsonDecode(response.body);
      final String? content =
          data['choices'][0]['message']['content'] as String?;
      if (content != null && content.trim().isNotEmpty) {
        return RespuestaAsistente(content.trim(), esLocal: false);
      }
      return _respuestaLocal(prompt);
    } catch (e) {
      print('Excepción en consulta a Groq: $e. Activando fallback local.');
      return _respuestaLocal(prompt);
    }
  }
}
