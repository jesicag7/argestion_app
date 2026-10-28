// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/monotributo_category.dart';

const String groqApiKey = String.fromEnvironment(
  'GROQ_API_KEY',
  defaultValue: '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',
);
const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

class GeminiService {
  static const String endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  static const String mensajeErrorConexion =
      'No pude conectarme con el servicio de IA en este momento. Verificá tu conexión a internet o consultá los gráficos de facturación en la pantalla.';

  static String get activeApiKey =>
      groqApiKey.isNotEmpty ? groqApiKey : geminiApiKey;

  static bool get isConfigured => activeApiKey.trim().isNotEmpty;

  /// Sanitiza montos quitando signos '$' o espacios sobrantes para inserción prolija.
  static String sanitizarMonto(dynamic value) {
    if (value == null) return '0';
    final str = value.toString().trim();
    if (str.startsWith(r'$')) {
      return str.substring(1).trim();
    }
    return str;
  }

  /// Construye el System Prompt oficial para Lionel con inyección de contexto en tiempo real (RAG ligero).
  static String buildSystemPromptConContexto(Map<String, dynamic>? userData) {
    final nombre = (userData?['nombre'] ?? userData?['name'] ?? 'Usuario').toString().trim();
    final categoria = (userData?['categoria'] ?? userData?['category'] ?? 'A').toString().trim();
    final totalFacturado = sanitizarMonto(userData?['totalFacturado'] ?? userData?['total_facturado']);
    final cupoDisponible = sanitizarMonto(userData?['cupoDisponible'] ?? userData?['cupo_disponible']);
    final facturasPendientes = (userData?['facturasPendientes'] ?? userData?['facturas_pendientes'] ?? 'Ninguna').toString().trim();
    final ultimoComprobante = (userData?['ultimoComprobante'] ?? userData?['ultimo_comprobante'] ?? 'Ninguno registrado').toString().trim();

    return '''Sos Lionel, el asistente fiscal inteligente de la aplicación ARGestión.
Tu objetivo es asesorar con claridad, empatía y tono argentino profesional al monotributista.

[DATOS ACTUALES DEL MONOTRIBUTISTA EN LA APP]:
- Nombre: $nombre
- Categoría actual: $categoria
- Total facturado en el período: \$$totalFacturado
- Cupo disponible antes de cambiar de categoría: \$$cupoDisponible
- Facturas pendientes de cobro: $facturasPendientes
- Último comprobante: $ultimoComprobante

REGLAS DE RESPUESTA:
1. Si el usuario te pregunta por sus números ("¿cuánto voy facturando?", "¿cuánto cupo me queda?", "¿en qué categoría estoy?", "¿tengo facturas por cobrar?"), responde usando con exactitud los datos provistos arriba.
2. Responde consultas normativas de Monotributo argentino (ARCA/AFIP): recategorizaciones (enero y julio), topes, exclusión, facturación y notas de crédito.
3. Explica el funcionamiento de la app si lo consultan (ej. cómo emitir nota de crédito desde el historial, el modo contingencia/simulación si se corta la red).
4. Si la consulta NO está relacionada con el monotributo, finanzas, facturación o la app, declina amablemente explicando que tu especialidad se enfoca en ARGestión y tributación.
5. Respuestas concisas, bien redactadas, sin inventar leyes ni cifras ajenas a las proporcionadas.

GUÍA OPERATIVA DE LA APP ARGESTIÓN:
- Anulación / Nota de Crédito: En la sección "Historial", seleccionás el comprobante emitido y tocás "Emitir Nota de Crédito" para anularlo (total o parcialmente) y compensar el impacto fiscal en el cupo.
- Modo Simulación / Contingencia: Si el servidor fiscal de ARCA o el backend no responde (o no hay conexión), la app emite de forma transparente un CAE simulado reglamentario de 14 dígitos con vencimiento a 10 días, permitiendo continuar operando sin perder ventas.''';
  }

  /// Recopila los datos fiscales y métricas actuales del usuario desde Firestore y FirebaseAuth.
  static Future<Map<String, dynamic>> recopilarContextoUsuario({
    String? userId,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) async {
    FirebaseAuth? authInstance = auth;
    if (authInstance == null) {
      try {
        authInstance = FirebaseAuth.instance;
      } catch (_) {
        authInstance = null;
      }
    }

    FirebaseFirestore? firestoreInstance = firestore;
    if (firestoreInstance == null) {
      try {
        firestoreInstance = FirebaseFirestore.instance;
      } catch (_) {
        firestoreInstance = null;
      }
    }

    String? uid = userId;
    String nombre = 'Usuario';
    String email = '';

    if (authInstance != null) {
      try {
        final currentUser = authInstance.currentUser;
        uid ??= currentUser?.uid;
        if (currentUser != null) {
          if (currentUser.displayName != null && currentUser.displayName!.trim().isNotEmpty) {
            nombre = currentUser.displayName!.trim();
          } else if (currentUser.email != null && currentUser.email!.contains('@')) {
            final prefix = currentUser.email!.split('@').first;
            if (prefix.isNotEmpty) {
              nombre = '${prefix[0].toUpperCase()}${prefix.substring(1)}';
            }
          }
          email = currentUser.email ?? '';
        }
      } catch (_) {}
    }

    String categoria = 'A';
    if (firestoreInstance != null && uid != null && uid.isNotEmpty) {
      try {
        final userDoc = await firestoreInstance.collection('usuarios').doc(uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null) {
            final docName = data['nombre']?.toString().trim();
            if (docName != null && docName.isNotEmpty && docName.toLowerCase() != 'usuario') {
              nombre = docName;
            }
            final catRaw = data['categoria']?.toString();
            if (catRaw != null && catRaw.trim().isNotEmpty) {
              categoria = MonotributoCategory.normalizarCategoria(catRaw);
            }
          }
        }
      } catch (_) {}
    }

    double totalFacturado = 0.0;
    int cantidadFacturas = 0;
    int cantidadPendientes = 0;
    double montoPendiente = 0.0;
    String ultimoComprobante = 'Ninguno registrado';
    DateTime? fechaUltimo;

    final formatter = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '',
      decimalDigits: 0,
    );

    if (firestoreInstance != null && uid != null && uid.isNotEmpty) {
      try {
        final query = await firestoreInstance
            .collection('facturas')
            .where(
              Filter.or(
                Filter('userId', isEqualTo: uid),
                Filter('id_usuario', isEqualTo: uid),
              ),
            )
            .get();

        final docs = query.docs;
        final ahora = DateTime.now();
        final limite12Meses = DateTime(ahora.year, ahora.month - 11, 1);

        for (final doc in docs) {
          final data = doc.data();
          final monto = (data['monto'] is num)
              ? (data['monto'] as num).toDouble()
              : (double.tryParse(data['monto']?.toString() ?? '') ?? 0.0);

          final esAnulada = data['anulada'] == true || data['es_anulada'] == true;
          final tipo = (data['tipo_comprobante'] ?? data['tipo_factura'] ?? data['tipoFactura'] ?? '').toString().toLowerCase();
          final esNc = data['esNotaCredito'] == true || data['es_nota_credito'] == true || tipo.startsWith('nota de crédito');

          DateTime? fechaEmision;
          final rawFecha = data['fecha_emision'] ?? data['fechaEmision'];
          if (rawFecha is Timestamp) {
            fechaEmision = rawFecha.toDate();
          } else if (rawFecha is String) {
            fechaEmision = DateTime.tryParse(rawFecha);
          } else if (rawFecha is DateTime) {
            fechaEmision = rawFecha;
          }

          // Total facturado 12 meses
          if (!esAnulada) {
            if (fechaEmision != null && !fechaEmision.isBefore(limite12Meses) && !fechaEmision.isAfter(ahora)) {
              if (esNc) {
                totalFacturado -= monto;
              } else {
                totalFacturado += monto;
                cantidadFacturas++;
              }
            } else if (fechaEmision == null) {
              if (!esNc) {
                totalFacturado += monto;
                cantidadFacturas++;
              }
            }
          }

          // Pendientes de cobro
          final estadoCobro = (data['estadoCobro'] ?? data['estado_cobro'] ?? '').toString().toLowerCase();
          final cobrada = data['cobrada']?.toString().toLowerCase();
          final estaCobrada = estadoCobro == 'cobrada' || cobrada == 'true' || cobrada == 'cobrada';

          if (!estaCobrada && !esAnulada && !esNc) {
            cantidadPendientes++;
            montoPendiente += monto;
          }

          // Último comprobante
          if (fechaEmision != null && (fechaUltimo == null || fechaEmision.isAfter(fechaUltimo))) {
            fechaUltimo = fechaEmision;
            final nro = data['nro_factura'] ?? data['nroFactura'] ?? data['numeroComprobante'] ?? '';
            final cliente = data['nombre_cliente'] ?? data['nombreCliente'] ?? 'Consumidor Final';
            final tipoStr = data['tipo_comprobante'] ?? data['tipoFactura'] ?? 'Factura C';
            ultimoComprobante = '$tipoStr $nro por \$${formatter.format(monto).trim()} a $cliente (${fechaEmision.day.toString().padLeft(2, '0')}/${fechaEmision.month.toString().padLeft(2, '0')}/${fechaEmision.year})';
          }
        }
      } catch (_) {}
    }

    if (totalFacturado < 0) totalFacturado = 0;

    final tope = MonotributoCategory.annualIncomeLimits[categoria] ??
        MonotributoCategory.annualIncomeLimits['A'] ?? 7720000.0;
    final cupoDisponible = (tope - totalFacturado).clamp(0.0, double.infinity);

    final facturasPendientesStr = cantidadPendientes > 0
        ? '$cantidadPendientes facturas pendientes por un total de \$${formatter.format(montoPendiente).trim()}'
        : 'Ninguna';

    return {
      'nombre': nombre,
      'categoria': categoria,
      'totalFacturado': formatter.format(totalFacturado).trim(),
      'totalFacturadoNum': totalFacturado,
      'cupoDisponible': formatter.format(cupoDisponible).trim(),
      'cupoDisponibleNum': cupoDisponible,
      'facturasPendientes': facturasPendientesStr,
      'cantidadPendientes': cantidadPendientes,
      'montoPendiente': montoPendiente,
      'ultimoComprobante': ultimoComprobante,
      'cantidadFacturas': cantidadFacturas.toString(),
      'email': email,
    };
  }

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

  /// Motor fiscal local de respaldo con fallback inteligente usando datos del usuario
  static String responderFallbackLocal(String prompt, [Map<String, dynamic>? userData]) {
    final p = _normalizarTexto(prompt);

    // 1. Anulación de comprobantes / Notas de Crédito
    if (p.contains('anular') || p.contains('anulo') || p.contains('credito')) {
      return 'Las facturas electrónicas ya autorizadas con CAE por ARCA no se pueden eliminar ni modificar. Para anular una Factura C emitida por error (total o parcialmente), se debe emitir una Nota de Crédito C por el mismo concepto e importe, vinculando el número del comprobante original. De este modo, la Nota de Crédito compensa el impacto fiscal en ARCA.';
    }

    // 2. Extraer datos del usuario si están presentes para respuestas inteligentes personalizadas
    final String categoria = (userData?['categoria'] ?? userData?['category'] ?? 'A')
        .toString()
        .trim()
        .toUpperCase();
    final String totalFacturado = sanitizarMonto(
        userData?['totalFacturado'] ?? userData?['total_facturado'] ?? '0');
    final String cupoDisponible = sanitizarMonto(
        userData?['cupoDisponible'] ??
            userData?['cupo_disponible'] ??
            userData?['cupoRestante'] ??
            userData?['cupo_restante'] ??
            '0');

    final double topeNum = MonotributoCategory.annualIncomeLimits[categoria] ??
        MonotributoCategory.annualIncomeLimits['A'] ??
        7720000.0;
    final formatter = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '',
      decimalDigits: 0,
    );
    final String topeStr = formatter.format(topeNum).trim();

    final int cantidadPendientes;
    if (userData?['cantidadPendientes'] != null && userData!['cantidadPendientes'] is num) {
      cantidadPendientes = (userData['cantidadPendientes'] as num).toInt();
    } else {
      final pendientesStr = (userData?['facturasPendientes'] ??
              userData?['facturas_pendientes'] ??
              '')
          .toString()
          .toLowerCase();
      final match = RegExp(r'\d+').firstMatch(pendientesStr);
      if (match != null) {
        cantidadPendientes = int.tryParse(match.group(0) ?? '') ?? 0;
      } else {
        cantidadPendientes = 0;
      }
    }

    // 3. Fallback inteligente con datos del usuario:
    // a. Facturas por cobrar / pendientes: "cobrar" o "pendiente"
    // Se evalúa antes de facturación para no colisionar con la palabra "factura" en "facturas por cobrar"
    if (p.contains('cobrar') || p.contains('pendiente') || p.contains('impaga')) {
      if (cantidadPendientes == 0) {
        return 'No tenés facturas impagas pendientes de cobro registradas actualmente.';
      } else if (cantidadPendientes == 1) {
        return 'Tenés 1 factura impaga pendiente de cobro registrada en la app.';
      } else {
        return 'Tenés $cantidadPendientes facturas impagas pendientes de cobro registradas en la app.';
      }
    }

    // b. Cupo restante y límite: "cupo", "límite" o "cuánto me queda"
    if (!p.contains('supero') &&
        !p.contains('exclu') &&
        (p.contains('cupo') || p.contains('limite') || p.contains('cuanto me queda'))) {
      return 'Tu cupo restante disponible es de \$$cupoDisponible antes de alcanzar el tope anual de tu Categoría $categoria (\$$topeStr).';
    }

    // c. Categoría actual: "categoría" (excluyendo "recategorización")
    if (p.contains('categoria') && !p.contains('recategoriz')) {
      return 'Actualmente estás en la Categoría $categoria del Monotributo.';
    }

    // d. Total Facturado: "factur", "total" o "llevo"
    if (!p.contains('comprobante') &&
        !p.contains('tipo') &&
        (p.contains('factur') || p.contains('total') || p.contains('llevo'))) {
      return 'En el período actual tu total facturado es de \$$totalFacturado (llevás facturado \$$totalFacturado).';
    }

    // 4. Consultas generales de monotributo o la app:
    // a. Modo Simulación / Contingencia
    if (p.contains('simulac') || p.contains('contingencia')) {
      return 'El modo contingencia/simulación se activa automáticamente cuando no hay conexión con el backend o ARCA. La app emite un CAE simulado reglamentario de 14 dígitos con vencimiento a 10 días para no interrumpir tu facturación.';
    }

    // b. DNI / Consumidor Final
    if (p.contains('dni') || p.contains('consumidor')) {
      return 'Al facturar a un Consumidor Final, no es obligatorio identificar al cliente con su DNI siempre que el importe de la operación no supere los topes límites vigentes fijados periódicamente por ARCA. Si la operación supera dicho importe límite (o si el comprador lo solicita expresamente), es obligatorio consignar su número de DNI o CUIT en la Factura C.';
    }

    // c. Topes / Exclusión del Monotributo (Categoría K)
    if (p.contains('tope') || p.contains('supero') || p.contains('limite') || p.contains('exclu')) {
      return 'Si superás el tope de facturación de tu categoría actual pero sin exceder el máximo del Monotributo, deberás recategorizarte en la escala superior en el siguiente período semestral (enero o julio). Si tus ingresos acumulados superan el límite anual máximo de la Categoría K (la escala máxima del régimen), quedás automáticamente excluido del Monotributo y debés pasar al Régimen General (inscribirte en IVA, Impuesto a las Ganancias y Autónomos).';
    }

    // d. VEP / Pagar cuota / Vencimiento
    if (p.contains('vep') ||
        p.contains('pagar') ||
        p.contains('vencimiento') ||
        p.contains('vence')) {
      return 'La cuota mensual del Monotributo tiene su vencimiento los días 20 de cada mes (o el día hábil posterior si es feriado o fin de semana). Podés generar el Volante Electrónico de Pago (VEP) desde el servicio Monotributo de ARCA o copiando el código desde la sección Pagos de ARGestión, y abonarlo ingresando dicho código en tu home banking (Red Link o Banelco) o a través de billeteras virtuales habilitadas.';
    }

    // e. Recategorización semestral
    if (p.contains('recategoriz') ||
        (p.contains('cuando') &&
            !p.contains('vep') &&
            !p.contains('pagar') &&
            !p.contains('vencimiento') &&
            !p.contains('vence'))) {
      return 'La recategorización del Monotributo se realiza de forma semestral en los meses de enero y julio (hasta el día 20 o según el calendario de ARCA). Debés evaluar la facturación bruta y los parámetros de los últimos 12 meses acumulados. Si cambiás de escala, ingresás al portal de ARCA con CUIT y Clave Fiscal en el servicio "Monotributo" y seleccionás "Recategorización". Si mantuviste los parámetros dentro de tu misma categoría, no es necesario hacer ningún trámite.';
    }

    // f. Comprobantes / Tipos de factura
    if (p.contains('comprobante') || p.contains('tipo')) {
      return 'Como monotributista debés emitir obligatoriamente Factura C para respaldar todas tus ventas de bienes o locaciones de servicios a cualquier destinatario (consumidores finales, monotributistas o responsables inscriptos). En caso de devoluciones o ajustes de importes, se utilizan Notas de Crédito C o Notas de Débito C.';
    }

    // g. Orientación general por defecto
    return 'Como asistente de ARGestión puedo orientarte sobre facturación electrónica, categorías de Monotributo, emisión de VEP, topes de facturación y recategorización semestral. ¿En qué tema puntual precisás ayuda?';
  }

  /// Alias compatible para invocar el fallback con contexto
  static String responderFallbackConContexto(String prompt, [Map<String, dynamic>? userData]) =>
      responderFallbackLocal(prompt, userData);

  /// Consulta directa con Fallback Local automático garantizado
  static Future<String> enviarConsulta(String prompt, [Map<String, dynamic>? userData]) async {
    final res = await sendMessage(prompt: prompt, userData: userData);
    if (res != null && res.trim().isNotEmpty && res != mensajeErrorConexion) {
      return res.trim();
    }
    return responderFallbackLocal(prompt, userData);
  }

  /// Envía la consulta a Lionel inyectando en el System Prompt el contexto en tiempo real del usuario.
  /// Si la llamada HTTP a Groq devuelve algún error (código distinto de 200, timeout o falta de red),
  /// activa una respuesta local inteligente de contingencia usando el `userData` inyectado.
  static Future<String> enviarMensajeConContexto({
    required String userQuestion,
    required Map<String, dynamic> userData,
    List<Map<String, String>>? history,
    String model = 'llama-3.1-8b-instant',
    String? customApiKey,
    http.Client? client,
  }) async {
    final systemPrompt = buildSystemPromptConContexto(userData);
    try {
      final res = await sendMessage(
        prompt: userQuestion,
        model: model,
        systemInstruction: systemPrompt,
        history: history,
        customApiKey: customApiKey,
        client: client,
        usarMensajeErrorEnFallo: false,
        userData: userData,
      );
      if (res != null && res.trim().isNotEmpty && res != mensajeErrorConexion) {
        return res.trim();
      }
      return responderFallbackLocal(userQuestion, userData);
    } catch (_) {
      return responderFallbackLocal(userQuestion, userData);
    }
  }

  /// Alias compatible para invocaciones en inglés
  static Future<String> sendMessageWithContext({
    required String userQuestion,
    required Map<String, dynamic> userData,
    List<Map<String, String>>? history,
    String model = 'llama-3.1-8b-instant',
    String? customApiKey,
    http.Client? client,
  }) => enviarMensajeConContexto(
    userQuestion: userQuestion,
    userData: userData,
    history: history,
    model: model,
    customApiKey: customApiKey,
    client: client,
  );

  /// Envía una petición de generación de contenido a la API de Groq
  /// utilizando el modelo Llama 3.1 (llama-3.1-8b-instant).
  /// Si ocurre cualquier error HTTP, timeout o red, responde con el Fallback Local inteligente de contingencia.
  static Future<String?> sendMessage({
    required String prompt,
    String model = 'llama-3.1-8b-instant',
    String? systemInstruction,
    List<Map<String, String>>? history,
    String? customApiKey,
    http.Client? client,
    bool usarMensajeErrorEnFallo = false,
    Map<String, dynamic>? userData,
  }) async {
    final apiKey = (customApiKey != null && customApiKey.isNotEmpty)
        ? customApiKey
        : activeApiKey;

    if (apiKey.isEmpty) {
      print('API Key no provista.');
      return usarMensajeErrorEnFallo
          ? mensajeErrorConexion
          : responderFallbackLocal(prompt, userData);
    }

    final url = Uri.parse(endpoint);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final String systemContent = (systemInstruction != null && systemInstruction.isNotEmpty)
        ? systemInstruction
        : 'Sos Lionel, un asistente virtual experto y amigable de la aplicación ARGestión para monotributistas de Argentina. Respondé de forma clara, concisa, profesional y en español rioplatense (usando voseo cordial) sobre Monotributo, ARCA/AFIP, Factura C, pago de VEP, topes de facturación, recategorización semestral y vencimientos.';

    final bodyMap = <String, dynamic>{
      'model': model.isNotEmpty ? model : 'llama-3.1-8b-instant',
      'messages': [
        {
          'role': 'system',
          'content': systemContent,
        },
        if (history != null)
          ...history.map((h) => {
                'role': (h['role'] == 'user') ? 'user' : 'assistant',
                'content': h['text'] ?? '',
              }),
        {
          'role': 'user',
          'content': prompt,
        },
      ],
      'temperature': 0.5,
      'max_tokens': 500,
    };

    try {
      final httpClient = client ?? http.Client();
      final shouldCloseClient = client == null;

      final http.Response response;
      try {
        response = await httpClient
            .post(
              url,
              headers: headers,
              body: jsonEncode(bodyMap),
            )
            .timeout(const Duration(seconds: 10));
      } finally {
        if (shouldCloseClient) {
          httpClient.close();
        }
      }

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        final String? content =
            data['choices'][0]['message']['content'] as String?;
        if (content != null && content.trim().isNotEmpty) {
          return content.trim();
        }
        return usarMensajeErrorEnFallo
            ? mensajeErrorConexion
            : responderFallbackLocal(prompt, userData);
      } else {
        print('Error Groq HTTP (${response.statusCode}): ${response.body}.');
        return usarMensajeErrorEnFallo
            ? mensajeErrorConexion
            : responderFallbackLocal(prompt, userData);
      }
    } catch (e) {
      print('Excepción en consulta a Groq: $e.');
      return usarMensajeErrorEnFallo
          ? mensajeErrorConexion
          : responderFallbackLocal(prompt, userData);
    }
  }
}
