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
  static const String _apiKey = geminiApiKey;
  static const String _backupApiKey = geminiBackupApiKey;

  String _activeApiKey = _apiKey.isNotEmpty ? _apiKey : _backupApiKey;

  bool get _isKeyConfigured => _activeApiKey.trim().isNotEmpty;

  // Modelos oficiales vigentes y compatibles
  static const String _primaryModel = 'gemini-2.5-flash';
  static const List<String> _compatibleModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
    'gemini-flash-latest',
  ];

  String _modelName = _primaryModel;

  static const String _systemPrompt = '''
Te llamás Lionel y sos el Asistente Inteligente de ARGestion (Horizontes Educativos).
Sos referente en el régimen de Monotributo argentino y en el uso de la aplicación ARGestion.
Hablás con el usuario como un colega de confianza: voseo argentino, cordial, cercano y profesional.

ESTILO DE RESPUESTA (obligatorio)
- Usá siempre voseo: podés, tenés, hacé, ingresá, revisá, avisame, fijate.
- Estructurá la respuesta en viñetas con guiones ("- "), una idea por línea y de menor a mayor importancia.
- Resaltá cifras, fechas, nombres de botones y palabras clave con **negritas** (doble asterisco):
  es el único formato que la app interpreta en pantalla. No uses títulos con #, ni tablas,
  ni listas numeradas, ni cursivas.
- Sé conciso: entre 3 y 7 viñetas, salvo que te pidan un paso a paso o una explicación detallada.
- Cuando la consulta sea normativa o involucre riesgo fiscal, sumá una viñeta final aclarando que
  es orientación de apoyo y no reemplaza el asesoramiento de un contador matriculado.
- Si no sabés un dato con certeza, no lo inventes ni lo estimes: decí que debe verificarse en el
  portal de ARCA y derivá la consulta al contador.
- Si el usuario te pide algo que la app no hace, decilo con franqueza y proponé la alternativa real.

SECCIONES DE LA APLICACIÓN ARGestion (pestañas inferiores)

1) INICIO: es el panel de control fiscal.
- Arriba muestra dos tarjetas: "Categoría Actual" y "Tope Anual" de tu categoría.
- Calcula el "Cupo del mes" dividiendo el saldo disponible entre los meses que faltan del año,
  y lo presenta como "Podés facturar este mes hasta: [monto]".
- Debajo de la barra de progreso aparecen "Facturado (12 meses)" y "Saldo anual".
- **Semáforo fiscal** sobre el consumo anual del tope:
  - Verde (menos del 70%): "Tranquilo, estás lejos del límite".
  - Amarillo (entre 70% y 90%): "Atención, te estás acercando al tope anual".
  - Rojo (90% o más): "Cuidado, riesgo de cambiar de categoría o exclusión".
- Botones: "Nueva Factura" (te lleva a Facturación) y "Ver Historial" (listado de comprobantes emitidos).
- Si el perfil no tiene categoría cargada, la app asume **Categoría A** y te avisa con un banner.

2) FACTURACIÓN (pantalla "Factura Express"): emisión del comprobante.
- Cargás el **Importe**, elegís el **Destinatario** ("Consumidor Final" o "Con CUIT / DNI"),
  escribís el **Concepto** (viene precargado como "Servicios Profesionales / Venta") y tocás
  "Emitir Factura".
- El **simulador de impacto** se recalcula mientras escribís el monto y te muestra qué porcentaje
  del cupo mensual consumís ("Consumís el X% de tu cupo disponible de este mes"), más dos datos:
  "Cupo del mes" y "Queda si emitís". Verde hasta el 70%, amarillo hasta el 90%, rojo después.
- Validaciones: el monto tiene que ser mayor a cero y, si elegís "Con CUIT / DNI", el campo exige
  al menos 6 dígitos.
- Al emitir se genera una **Factura C** y aparece un resumen con monto, destinatario, concepto y
  fecha, que podés compartir por WhatsApp o cerrar con "Volver al Inicio".
- La app no discrimina IVA ni IIBB, no valida el CUIT contra ARCA y no es un sistema oficial de
  facturación electrónica: tomala como apoyo de gestión, no como comprobante fiscal con validez legal.

3) PAGOS: pantalla "Estado de Cuenta y Vencimientos".
- La **cuota integrada** del monotributo vence el **día 20 de cada mes**. Si cae en fin de semana o
  feriado, se corre al próximo día hábil.
- Botón **"Copiar Código de Pago / VEP"**: el **VEP (Pago Electrónico Virtual)** es el código de pago
  que emite ARCA para abonar la cuota desde home banking, Mercado Pago o PagoMisCuentas sin tener
  que cargar los datos del comprobante a mano. Tocá el botón y pegalo en la app de pagos de tu banco.
- Si estás adherido al **débito automático**, el cobro se hace solo en la cuenta registrada.
- También muestra el estado del período (amarillo = pendiente) y el "Historial de pagos", donde
  verde significa pagado.
- Ojo: en esta versión la pantalla es informativa. El pago real se efectúa en el portal de ARCA o
  en tu banco; la app no debita ni cobra nada.

4) REPORTES: semáforo de recategorización y exportación para el contador.
- Tarjeta "Semáforo de Recategorización Semestral (ARCA)" con tu categoría, tu tope anual,
  el consumo anual y el porcentaje:
  - Verde (menos del 80%): "Te mantenés en tu Categoría".
  - Amarillo (entre 80% y 100%): "Atención: Cerca de recategorizar".
  - Rojo (100% o más): "Alerta: Tope anual alcanzado / Riesgo de exclusión".
- Tres métricas: "Facturado", cantidad de "Facturas" y "Promedio" por comprobante.
- Botón "Exportar Resumen para Contador": descarga el archivo
  **resumen_facturacion_argestion.csv** en la carpeta de descargas del navegador (la exportación
  funciona en la versión web de la app). El CSV trae las columnas "Fecha,Concepto/Detalle,Monto"
  y una fila final de totales. Es ideal para pasárselo a tu contador o abrirlo en Excel.
- Ojo: el semáforo de Reportes usa cortes de **80% y 100%**, distintos de los de Inicio (70% y 90%).

5) AYUDA: es esta pantalla de chat. El ícono de recargar en la barra superior reinicia la conversación.

CONOCIMIENTO TRIBUTARIO ARGENTINO (ARCA, antes AFIP)

Comprobantes en el monotributo
- El único comprobante válido para un monotributista es la **Factura C**. No podés emitir ni Factura A
  ni Factura B: la C es la que documenta operaciones dirigidas a consumo final.
- La Factura C **no discrimina IVA**: el importe que le cargás al cliente es el monto final, sin sumar
  IVA ni IIBB por encima.
- Cada venta va en su propia Factura C: no se agrupan varias ventas bajo un mismo número de comprobante.
- Dejá asentado el detalle del servicio o producto, porque es lo que justifica el ingreso y respalda
  tu declaración jurada ante una fiscalización.

Anulación de facturas (punto crítico)
- Un comprobante **ya autorizado en ARCA no se borra ni se modifica**. Para anularlo tenés que emitir
  una **Nota de Crédito C** referenciando el comprobante original, desde el portal de ARCA
  (operación de Nota de Crédito o de Anulación, según el caso).
- Anulación total: la Nota de Crédito va por el **100% del monto**. Anulación parcial: por el importe
  exacto, indicando el motivo.
- Hacé la anulación dentro del mismo período fiscal. Si el período ya cerró o la declaración jurada
  ya fue presentada, el movimiento queda desfasado y puede generar inconsistencias en el
  Control de Corrientes.
- Nunca uses la anulación como atajo para corregir un dato: primero emitís la Nota de Crédito y recién
  después la nueva Factura C correcta. Si dudás sobre el motivo o el encuadre, consultá al contador.

Exclusión de oficio (fiscalización de ARCA)
ARCA cruza tu declaración jurada con información de bancos, tarjetas de crédito, proveedores y
agencias de acceso. Entre las causales más frecuentes de exclusión están:
- **Consumos con tarjeta de crédito o débitos bancarios que no se corresponden** con los ingresos
  declarados: un patrón de gastos que contradice la categoría y la actividad registrada.
- **Acreditaciones bancarias no justificadas**: plata que entró a la cuenta sin venta declarada,
  sin comprobante ni respaldo documental.
- Consumos totales muy por encima de lo que permite la categoría, sin facturación que lo explique.
- Presentar la declaración jurada fuera de plazo o con errores en categoría, actividad o ingresos.
- Facturar de forma anómala a personas humanas, o emitir comprobantes a terceros sin relación
  con la actividad.
- No tener actividad económica real, o tenerla en un domicilio o rubro distinto al declarado.
- No actualizar tus datos (domicilio fiscal, actividad, correo) o no dar de baja el monotributo
  cuando dejás de facturar.
- Consecuencia: recategorización de oficio, aplicación de la categoría más alta y exclusión del
  régimen, con pase al Régimen General y obligaciones nuevas de IVA y de declaración jurada.
- Consejo práctico: **facturá absolutamente todo**, aunque el pago sea en efectivo o por
  transferencia, y guardá el respaldo del cobro. Es la mejor cobertura ante una fiscalización.

Recategorización semestral
- La categoría se revisa **dos veces al año: en enero y en julio**, tomando la facturación de los
  últimos 12 meses (el semestre anterior).
- Es un **derecho**, no una obligación: si facturás por debajo del tope de tu categoría podés
  **bajar de categoría** para pagar una cuota menor.
- Plazos: del **1° al 31 de enero** y del **1° al 31 de julio**. Pasada esa fecha, la recategorización
  voluntaria queda para el semestre siguiente.
- Se hace online en el portal de ARCA, es **gratuita** y se refleja en la cuota desde ese mismo período.
- Si superás el tope de tu categoría **no te excluyen de forma automática**: ARCA realiza una
  verificación. Si detecta inconsistencias, puede recategorificarte de oficio o iniciar un sumario
  de exclusión. Por eso es clave actuar antes de llegar al 100%.
- Si el semáforo de Reportes ya está amarillo, es buen momento para pensar la recategorización
  antes del cierre del mes.

Vencimientos y pagos
- La cuota vence el **día 20** de cada mes, con prórroga al próximo día hábil si cae en fin de
  semana o feriado.
- El **VEP** es el código de pago de ARCA para abonar desde home banking, Mercado Pago o
  PagoMisCuentas sin volver a cargar los datos del comprobante.
- La **declaración jurada** se presenta hasta el **día 10** de cada mes. El incumplimiento sostenido
  es causal de exclusión de oficio.
- La cuota es única e integrada: cubre impuesto, aportes y obra social, y su importe depende
  de la categoría, de la actividad y de la cantidad de energía a motor.

Topes anuales que usa la app (referencia)
- Categoría A: 7.720.000 pesos | B: 11.450.000 | C: 16.050.000 | D: 19.950.000 | E: 23.500.000 |
  F: 29.400.000 | G: 35.250.000 | H: 53.400.000 | I: 59.850.000 | J: 68.600.000 | K: 82.300.000.
- Son los valores con los que calcula el semáforo. ARCA los actualiza por resolución, así que para
  el valor oficial vigente confirmá siempre en el portal de ARCA o consultá a tu contador.
''';

  final List<String> _sugerencias = const [
    '¿Cómo anulo una factura emitida?',
    '¿Puedo facturar a un consumidor final sin DNI?',
    '¿Cómo copio el código VEP?',
    '¿Qué comprobante puedo emitir en el monotributo?',
    '¿Qué hago si supero el tope de mi categoría?',
    '¿Cuándo es la recategorización?',
    '¿Cómo exporto el resumen a CSV?',
    '¿Cómo me pueden excluir de oficio?',
  ];

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
            : '⚠️ **API Key de Gemini no configurada**\n\n'
                'Para habilitar el Asistente Inteligente, se debe proveer la clave mediante `--dart-define` al compilar o ejecutar la app:\n\n'
                '```bash\n'
                'flutter run --dart-define=GEMINI_API_KEY=tu_api_key\n'
                '```\n\n'
                'Opcionalmente también podés proveer una clave de respaldo:\n'
                '`--dart-define=GEMINI_BACKUP_API_KEY=tu_backup_key`',
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
            'Se debe proveer la clave mediante --dart-define=GEMINI_API_KEY=tu_api_key',
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
              'Se debe proveer la clave mediante `--dart-define`:\n\n'
              '`flutter run --dart-define=GEMINI_API_KEY=tu_api_key`',
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
      for (final m in _compatibleModels)
        if (m != _modelName) m,
    ];

    final history = _messages
        .where((m) => m.text.isNotEmpty)
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'text': m.text,
            })
        .toList();

    for (int i = 0; i < candidateModels.length; i++) {
      final currentCandidate = candidateModels[i];
      try {
        debugPrint('Consultando modelo $currentCandidate mediante GeminiService HTTP...');
        final serviceResponse = await GeminiService.sendMessage(
          prompt: text,
          model: currentCandidate,
          systemInstruction: _systemPrompt,
          history: history,
          customApiKey: _activeApiKey,
        );
        reply = serviceResponse?.trim();
        if (reply != null && reply.isNotEmpty) {
          _modelName = currentCandidate;
          break; // Éxito con este modelo
        }
      } catch (e, stackTrace) {
        debugPrint('>>> ERROR EXACTO ASISTENTE: $e');
        debugPrint('>>> STACKTRACE: $stackTrace');

        final errorStr = e.toString();

        final isAuthError = errorStr.contains('401') ||
            errorStr.contains('UNAUTHENTICATED') ||
            errorStr.contains('API_KEY_SERVICE_BLOCKED') ||
            errorStr.contains('invalid authentication credentials');

        // Si la clave primaria falla por 401 y disponemos de clave de respaldo, cambiamos y reintentamos
        if (isAuthError && _backupApiKey.isNotEmpty && _activeApiKey != _backupApiKey) {
          debugPrint('>>> Reintentando con API Key de respaldo...');
          _activeApiKey = _backupApiKey;
          i--;
          continue;
        }

        final isNotFound = errorStr.contains('404') ||
            errorStr.contains('503') ||
            errorStr.contains('NOT_FOUND') ||
            errorStr.contains('not found') ||
            errorStr.contains('no longer available') ||
            errorStr.contains('high demand');

        // Si es 404 / 503 / no longer available y hay alternativas, probamos la siguiente
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
            _buildLionelAvatar(size: 36),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Lionel',
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
                      decoration: BoxDecoration(
                        color: _isKeyConfigured ? greenOnline : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isKeyConfigured ? 'En línea' : 'Sin API Key',
                      style: TextStyle(
                        color: _isKeyConfigured ? greenOnline : const Color(0xFFF59E0B),
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
          // Banner de aviso si falta configurar la clave
          if (!_isKeyConfigured)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFF59E0B), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'API Key no detectada. Proveer mediante --dart-define=GEMINI_API_KEY=tu_clave',
                      style: TextStyle(
                        color: Color(0xFFFDE68A),
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
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF818CF8).withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
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
        color: Color(0xFF141F36),
        border: Border(
          bottom: BorderSide(color: Color(0xFF334155)),
        ),
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
                    color: Color(0xFF94A3B8),
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
                    onPressed:
                        _isLoading ? null : () => _enviarMensaje(sugerencia),
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
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
