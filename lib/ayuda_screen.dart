import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AyudaScreen extends StatefulWidget {
  const AyudaScreen({super.key});

  @override
  State<AyudaScreen> createState() => _AyudaScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class _AyudaScreenState extends State<AyudaScreen> {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  bool get _isKeyConfigured => _apiKey.trim().isNotEmpty;

  // Modelo verificado y activo con respuesta exitosa (código 200) de Google
  String _modelName = 'gemini-3.8-flash';

  static const String _systemPrompt =
      'Eres el Asistente Inteligente de ARGestion (Horizontes Educativos). '
      'Tu rol es orientar a profesionales y monotributistas en el uso de la aplicación '
      '(emisión de comprobantes, interpretación del semáforo fiscal en Reportes, historial y exportación a CSV) '
      'y responder consultas conceptuales sobre el régimen de Monotributo en Argentina '
      '(topes de categorías vigentes, recategorización semestral de enero y julio, comprobantes Factura C, etc.). '
      'Responde con tono cordial, conciso y profesional adaptado a Argentina. '
      'Recuerda siempre aclarar que la orientación es de apoyo y no reemplaza el asesoramiento de un contador matriculado.';

  final List<String> _sugerencias = const [
    '¿Cuándo es la recategorización?',
    '¿Cuáles son los topes de monotributo?',
    '¿Cómo exporto mis reportes a CSV?',
    '¿Qué hago si supero el límite de mi categoría?',
  ];

  GenerativeModel? _model;
  ChatSession? _chatSession;

  final List<_ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resetConversation();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  GenerativeModel _createModel(String modelName) {
    final cleanModelName = modelName.startsWith('models/')
        ? modelName.substring('models/'.length)
        : modelName;

    return GenerativeModel(
      model: cleanModelName,
      apiKey: _apiKey,
      systemInstruction: Content.system(_systemPrompt),
    );
  }

  void _resetConversation() {
    if (_isKeyConfigured) {
      _model = _createModel(_modelName);
      _chatSession = _model!.startChat();
    } else {
      _model = null;
      _chatSession = null;
    }
    _messages.clear();
    _messages.add(
      _ChatMessage(
        text: _isKeyConfigured
            ? '¡Hola! 👋 Soy tu Asistente Inteligente de **ARGestion**.\n\n'
                'Puedo orientarte con el uso de la aplicación (facturación, reportes, semáforo fiscal) '
                'y resolver tus dudas sobre el régimen de Monotributo en Argentina '
                '(fechas de recategorización, topes anuales, comprobantes).\n\n'
                '¿En qué te puedo ayudar hoy?'
            : '⚠️ **API Key de Gemini no configurada**\n\n'
                'Para habilitar el Asistente Inteligente, proporcioná tu clave de Gemini ejecutando la app con:\n\n'
                '`flutter run --dart-define=GEMINI_API_KEY=tu_api_key`\n\n'
                'O configurala en tus variables de entorno / configuración de ejecución.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviarMensaje([String? customText]) async {
    final text = (customText ?? _textController.text).trim();
    if (text.isEmpty || _isLoading) return;

    if (customText == null) {
      _textController.clear();
    }

    if (!_isKeyConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Falta configurar la API Key de Gemini. Ejecuta con --dart-define=GEMINI_API_KEY=...',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 4),
        ),
      );
      setState(() {
        _messages.add(_ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ));
        _messages.add(_ChatMessage(
          text:
              '⚠️ **No se pudo enviar la consulta**: Falta configurar la API Key de Gemini.\n\n'
              'Iniciá la aplicación pasando el parámetro:\n'
              '`--dart-define=GEMINI_API_KEY=tu_api_key`',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    String? reply;

    final candidateModels = [
      _modelName,
      if (_modelName != 'gemini-3.8-flash') 'gemini-3.8-flash',
      'gemini-flash-latest',
    ];

    for (int i = 0; i < candidateModels.length; i++) {
      final currentCandidate = candidateModels[i];
      try {
        if (currentCandidate != _modelName || _chatSession == null) {
          debugPrint('Probando modelo: $currentCandidate');
          _modelName = currentCandidate;
          _model = _createModel(_modelName);
          _chatSession = _model!.startChat();
        }

        final response = await _chatSession!.sendMessage(Content.text(text));
        reply = response.text?.trim();
        if (reply != null && reply.isNotEmpty) {
          break; // Éxito con este modelo
        }
      } catch (e, stackTrace) {
        debugPrint('Error en Gemini: $e');
        debugPrint('StackTrace: $stackTrace');

        final errorStr = e.toString();
        final isNotFound = errorStr.contains('404') ||
            errorStr.contains('NOT_FOUND') ||
            errorStr.contains('not found') ||
            errorStr.contains('no longer available');

        // Si es 404 / no longer available y hay alternativas, probamos la siguiente
        if (isNotFound && i < candidateModels.length - 1) {
          continue;
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al conectar con el Asistente: ${errorStr.split('\n').first}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
        reply =
            'Disculpá, ocurrió un problema al procesar tu consulta con Gemini. Por favor verificá tu conexión e intentá de nuevo.';
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(
        text: reply ?? 'No pude generar una respuesta en este momento.',
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isLoading = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    const darkBackground = Color(0xFF0F172A);
    const darkCard = Color(0xFF1E293B);
    const darkBorder = Color(0xFF334155);
    const greenOnline = Color(0xFF10B981);

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: darkCard,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Color(0xFF818CF8),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Asistente ARGestion',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: greenOnline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'En línea',
                      style: TextStyle(
                        color: greenOnline,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8)),
            tooltip: 'Reiniciar conversación',
            onPressed: () {
              setState(() {
                _resetConversation();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conversación reiniciada'),
                  backgroundColor: Color(0xFF10B981),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: darkBorder, height: 1),
        ),
      ),
      body: Column(
        children: [
          // Barra de sugerencias rápidas
          _buildSugerencias(),

          // Lista de mensajes
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Indicador "El asistente está escribiendo..."
          if (_isLoading) _buildTypingIndicator(),

          // Barra inferior de entrada
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildSugerencias() {
    return Container(
      height: 46,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _sugerencias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final sugerencia = _sugerencias[index];
          return ActionChip(
            backgroundColor: const Color(0xFF1E293B),
            elevation: 0,
            pressElevation: 1,
            side: const BorderSide(color: Color(0xFF334155)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            avatar: const Icon(
              Icons.help_outline_rounded,
              size: 15,
              color: Color(0xFF818CF8),
            ),
            label: Text(
              sugerencia,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: _isLoading ? null : () => _enviarMensaje(sugerencia),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;
    final hora =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 8, top: 2),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Color(0xFF818CF8),
                size: 16,
              ),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : const Color(0xFF1E293B),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: const Color(0xFF334155)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  _buildFormattedText(message.text, Colors.white),
                  const SizedBox(height: 5),
                  Text(
                    hora,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xFF64748B),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text, Color textColor) {
    final lines = text.split('\n');
    final spans = <InlineSpan>[];
    final boldRegex = RegExp(r'\*\*(.*?)\*\*');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      int lastMatchEnd = 0;

      for (final match in boldRegex.allMatches(line)) {
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(
            text: line.substring(lastMatchEnd, match.start),
            style: TextStyle(color: textColor, fontSize: 14, height: 1.45),
          ));
        }
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            height: 1.45,
          ),
        ));
        lastMatchEnd = match.end;
      }

      if (lastMatchEnd < line.length) {
        spans.add(TextSpan(
          text: line.substring(lastMatchEnd),
          style: TextStyle(color: textColor, fontSize: 14, height: 1.45),
        ));
      }

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF10B981),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'El asistente está escribiendo...',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(
          top: BorderSide(color: Color(0xFF334155)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Hacé tu consulta sobre monotributo o la app...',
                    hintStyle: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: _isLoading ? null : (_) => _enviarMensaje(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: _isLoading
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      ),
                color: _isLoading ? const Color(0xFF334155) : null,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: _isLoading ? const Color(0xFF64748B) : Colors.white,
                  size: 20,
                ),
                onPressed: _isLoading ? null : () => _enviarMensaje(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
