import 'package:flutter/material.dart';
import 'services/gemini_service.dart';

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
  static const String _apiKey = groqApiKey;
  static const String _backupApiKey = geminiApiKey;

  final String _activeApiKey = _apiKey.isNotEmpty ? _apiKey : _backupApiKey;

  bool get _isKeyConfigured => _activeApiKey.trim().isNotEmpty;

  // Modelo oficial vigente en Groq
  static const String _primaryModel = 'llama-3.1-8b-instant';
  final String _modelName = _primaryModel;

  final List<String> _sugerencias = const [
    '¿Cuánto voy facturando?',
    '¿Cuánto cupo me queda?',
    '¿En qué categoría estoy?',
    '¿Tengo facturas por cobrar?',
    '¿Cómo anulo una factura emitida?',
    '¿Cuándo es la recategorización?',
    '¿Qué comprobante puedo emitir?',
    '¿Cómo funciona el modo simulación?',
  ];

  Map<String, dynamic> _userData = {};

  final List<_ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resetConversation();
    _cargarContextoUsuario();
  }

  Future<void> _cargarContextoUsuario() async {
    try {
      final data = await GeminiService.recopilarContextoUsuario();
      if (mounted) {
        setState(() {
          _userData = data;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetConversation() {
    _messages.clear();
    _messages.add(
      _ChatMessage(
        text: _isKeyConfigured
            ? '¡Hola! 👋 Soy Lionel, tu asistente de ARGestion.\n\n'
                  'Te ayudo tanto con el manejo de la app '
                  '(semáforo fiscal, factura express, pagos y reportes) '
                  'como con dudas impositivas del Monotributo '
                  '(facturación, notas de crédito, recategorización y normativas de ARCA).\n\n'
                  'Podés elegir una pregunta frecuente o escribirme tu consulta abajo.'
            : '⚠️ **API Key de Groq no configurada**\n\n'
                  'Para habilitar el Asistente Inteligente con Llama 3, se debe proveer la clave mediante `--dart-define` al compilar o ejecutar la app:\n\n'
                  '```bash\n'
                  'flutter run --dart-define=GROQ_API_KEY=tu_api_key\n'
                  '```',
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

    setState(() {
      _messages.add(
        _ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
    });
    _scrollToBottom();

    // Actualizamos contexto del usuario para asegurar datos en tiempo real
    try {
      _userData = await GeminiService.recopilarContextoUsuario();
    } catch (_) {}

    final history = _messages
        .where((m) => m.text.isNotEmpty)
        .map((m) => {'role': m.isUser ? 'user' : 'model', 'text': m.text})
        .toList();

    String reply;
    try {
      reply = await GeminiService.enviarMensajeConContexto(
        userQuestion: text,
        userData: _userData,
        history: history,
        model: _modelName,
        customApiKey: _activeApiKey,
      );
    } catch (_) {
      reply = GeminiService.responderFallbackLocal(text, _userData);
    }

    if (!mounted) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          text: reply,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    const darkBackground = Colors.transparent;
    const darkCard = Color(0xFFFFFFFF);
    const darkBorder = Color(0xFFE2E8F0);
    const greenOnline = Color(0xFF10B981);

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: darkCard,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            _buildLionelAvatar(size: 36),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Lionel',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
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
                      decoration: BoxDecoration(
                        color: _isKeyConfigured
                            ? greenOnline
                            : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isKeyConfigured ? 'En línea' : 'Sin API Key',
                      style: TextStyle(
                        color: _isKeyConfigured
                            ? greenOnline
                            : const Color(0xFFF59E0B),
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
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
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
          // Banner de aviso si falta configurar la clave
          if (!_isKeyConfigured)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'API Key no detectada. Proveer mediante --dart-define=GROQ_API_KEY=tu_clave',
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

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

  Widget _buildLionelAvatar({
    required double size,
    double marginRight = 0,
    double marginTop = 0,
  }) {
    return Container(
      margin: EdgeInsets.only(right: marginRight, top: marginTop),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF047857), Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF059669).withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.smart_toy_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }

  Widget _buildSugerencias() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 230),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 2),
                child: Text(
                  '💡 Preguntas frecuentes:',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: _sugerencias.map((sugerencia) {
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading
                          ? null
                          : () => _enviarMensaje(sugerencia),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.help_outline_rounded,
                              size: 15,
                              color: Color(0xFF059669),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                sugerencia,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
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
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildLionelAvatar(size: 30, marginRight: 8, marginTop: 2),
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
                        colors: [Color(0xFF064E3B), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  _buildFormattedText(
                    message.text,
                    isUser ? Colors.white : const Color(0xFF0F172A),
                  ),
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
          spans.add(
            TextSpan(
              text: line.substring(lastMatchEnd, match.start),
              style: TextStyle(color: textColor, fontSize: 14, height: 1.45),
            ),
          );
        }
        spans.add(
          TextSpan(
            text: match.group(1),
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1.45,
            ),
          ),
        );
        lastMatchEnd = match.end;
      }

      if (lastMatchEnd < line.length) {
        spans.add(
          TextSpan(
            text: line.substring(lastMatchEnd),
            style: TextStyle(color: textColor, fontSize: 14, height: 1.45),
          ),
        );
      }

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return SelectableText.rich(TextSpan(children: spans));
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
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
                    color: Color(0xFF64748B),
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
        color: Color(0xFFFFFFFF),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextFormField(
                  controller: _textController,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Preguntale algo a Lionel...',
                    hintStyle: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                  ),
                  onFieldSubmitted: _isLoading ? null : (_) => _enviarMensaje(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: _isLoading
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF064E3B), Color(0xFF059669)],
                      ),
                color: _isLoading ? const Color(0xFFE2E8F0) : null,
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
