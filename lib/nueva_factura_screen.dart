import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'services/pdf_invoice_service.dart';
import 'historial_facturas_screen.dart';
import 'models/factura_model.dart';
import 'models/cliente_model.dart';
import 'services/arca_service.dart';
import 'services/cliente_service.dart';
import 'models/monotributo_category.dart';

/// Formateador de texto que restringe la entrada a dígitos numéricos y activa
/// una notificación inmediata cuando el usuario intenta tipear letras o caracteres especiales.
class DigitosConAdvertenciaInputFormatter extends TextInputFormatter {
  final VoidCallback onCaracterInvalido;

  const DigitosConAdvertenciaInputFormatter({required this.onCaracterInvalido});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text == newValue.text) {
      return newValue;
    }

    if (RegExp(r'[^\d]').hasMatch(newValue.text)) {
      onCaracterInvalido();
      final cleanText = newValue.text.replaceAll(RegExp(r'\D'), '');

      int digitsBeforeCursor = 0;
      final cursor = newValue.selection.end.clamp(0, newValue.text.length);
      for (int i = 0; i < cursor; i++) {
        if (RegExp(r'\d').hasMatch(newValue.text[i])) {
          digitsBeforeCursor++;
        }
      }

      return TextEditingValue(
        text: cleanText,
        selection: TextSelection.collapsed(
          offset: digitsBeforeCursor.clamp(0, cleanText.length),
        ),
      );
    }

    return newValue;
  }
}

class NuevaFacturaScreen extends StatefulWidget {
  final VoidCallback? onFacturaEmitida;
  final VoidCallback? onVolverAlInicio;
  final FacturaModel? comprobanteAAnular;

  const NuevaFacturaScreen({
    super.key,
    this.onFacturaEmitida,
    this.onVolverAlInicio,
    this.comprobanteAAnular,
  });

  /// Validación estricta de CUIT/CUIL del cliente (Algoritmo Módulo 11 ARCA/AFIP)
  static String? validarCuitCliente(String? val, {String tipoDoc = 'CUIT'}) {
    if (tipoDoc == 'CUIT') {
      final text = val?.trim() ?? '';
      if (text.isEmpty) {
        return 'Por favor ingresá el CUIT/CUIL';
      }
      if (text.length < 11) {
        return 'El CUIT debe tener exactamente 11 números';
      }
      if (!ArcaFiscalService.esCuitValido(text)) {
        return 'El CUIT ingresado no es válido';
      }
      return null;
    }
    if (tipoDoc == 'DNI') {
      final text = val?.trim() ?? '';
      if (text.isEmpty) {
        return 'Por favor ingresá el DNI';
      }
      if (text.length < 7 || text.length > 8) {
        return 'El DNI debe tener 7 u 8 números';
      }
      return null;
    }
    return null;
  }

  @override
  State<NuevaFacturaScreen> createState() => _NuevaFacturaScreenState();
}

class _NuevaFacturaScreenState extends State<NuevaFacturaScreen> {
  final _formKey = GlobalKey<FormState>();

  // a) Datos de Emisión
  String _tipoComprobante = 'Factura C';
  final TextEditingController _puntoVentaController = TextEditingController(
    text: '0001',
  );
  DateTime _fechaEmision = DateTime.now();
  String _concepto = 'Servicios';
  DateTime? _periodoDesde = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime? _periodoHasta = DateTime.now();
  DateTime? _vtoPago = DateTime.now().add(const Duration(days: 10));

  // b) Datos del Receptor / Cliente
  String _condicionIvaCliente = 'Consumidor Final';
  String _tipoDocCliente = 'CUIT';
  final TextEditingController _nroDocController = TextEditingController();
  final TextEditingController _nombreClienteController =
      TextEditingController();
  final TextEditingController _emailClienteController = TextEditingController();
  final TextEditingController _telefonoClienteController =
      TextEditingController();
  final TextEditingController _domicilioClienteController =
      TextEditingController();
  final ClienteService _clienteService = ClienteService();
  Stream<List<ClienteModel>> _clientesStream = const Stream.empty();
  List<ClienteModel> _clientes = [];
  String? _clienteIdSeleccionado;
  bool _guardarEnAgenda = false;
  bool _actualizandoClienteSeleccionado = false;
  String? _advertenciaFormatoDoc;
  Timer? _advertenciaTimer;

  void _mostrarAdvertenciaCaracterInvalido() {
    _advertenciaTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _advertenciaFormatoDoc =
          'Solo se permiten números (sin letras ni caracteres especiales)';
    });

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Solo se permiten números (sin letras ni caracteres especiales)',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    _advertenciaTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _advertenciaFormatoDoc = null;
        });
      }
    });
  }

  // c) Detalle de la Operación y Cobro
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _montoController = TextEditingController();
  String _condicionVenta = 'Transferencia / Débito';

  bool _isLoading = false;
  final ArcaFiscalService _arcaFiscalService = ArcaFiscalService();

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_AR',
    symbol: '\$',
    decimalDigits: 0,
  );

  StreamSubscription? _userSub;
  StreamSubscription? _facturasSub;
  Map<String, dynamic>? _userData;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _facturasDocs;

  /// Factura C elegida desde el selector "Comprobante Asociado a Anular".
  /// Cuando la pantalla se abre desde el historial, el comprobante llega por
  /// [NuevaFacturaScreen.comprobanteAAnular] y este campo queda nulo.
  FacturaModel? _facturaAsociada;

  /// Comprobante que la Nota de Crédito C anula (desde el historial o el selector).
  FacturaModel? get _facturaOriginal =>
      widget.comprobanteAAnular ?? _facturaAsociada;

  bool get _esNotaCredito => _tipoComprobante == 'Nota de Crédito C';

  /// Facturas C del usuario que todavía pueden anularse con una Nota de Crédito.
  /// Devuelve lista vacía mientras Firestore no entregó datos.
  List<FacturaModel> get _facturasAnulables {
    final docs = _facturasDocs;
    if (docs == null) return const [];
    final anulables = docs
        .map((doc) => FacturaModel.fromMap(doc.data(), doc.id))
        .where((factura) => factura.puedeAnularConNotaCredito)
        .toList();
    anulables.sort((a, b) => b.fechaEmision.compareTo(a.fechaEmision));
    return anulables;
  }

  /// Completa el formulario con los datos de la factura a anular.
  /// No marca la fecha de emisión: la NC siempre se emite con la fecha actual.
  void _precargarDesdeFactura(FacturaModel facturaAAnular) {
    _actualizandoClienteSeleccionado = true;
    _puntoVentaController.text = facturaAAnular.puntoVenta;
    _concepto = facturaAAnular.concepto;
    _periodoDesde = facturaAAnular.periodoDesde;
    _periodoHasta = facturaAAnular.periodoHasta;
    _vtoPago = facturaAAnular.vencimientoPago;
    _condicionIvaCliente =
        facturaAAnular.condicionIvaCliente ?? 'Consumidor Final';
    _tipoDocCliente = switch (facturaAAnular.tipoDocumentoCliente) {
      80 => 'CUIT',
      96 => 'DNI',
      _ => 'Consumidor Final',
    };
    _nroDocController.text = facturaAAnular.cuitCliente == 'Consumidor Final'
        ? ''
        : facturaAAnular.cuitCliente;
    _nombreClienteController.text = facturaAAnular.nombreCliente;
    _domicilioClienteController.text = facturaAAnular.domicilioCliente ?? '';
    _descripcionController.text =
        facturaAAnular.descripcionItem ?? facturaAAnular.concepto;
    _montoController.text = facturaAAnular.monto.toStringAsFixed(2);
    _condicionVenta = facturaAAnular.condicionVenta ?? 'Transferencia / Débito';
    _clienteIdSeleccionado = null;
    _actualizandoClienteSeleccionado = false;
  }

  void _seleccionarFacturaAsociada(String? facturaId) {
    final factura = _facturasAnulables
        .where((item) => item.id == facturaId)
        .firstOrNull;
    setState(() {
      _facturaAsociada = factura;
      if (factura != null) _precargarDesdeFactura(factura);
    });
  }

  void _onTipoComprobanteChanged(String tipo) {
    setState(() {
      _tipoComprobante = tipo;
      if (!_esNotaCredito) _facturaAsociada = null;
    });
  }

  @override
  void initState() {
    super.initState();
    final facturaAAnular = widget.comprobanteAAnular;
    if (facturaAAnular != null) {
      _tipoComprobante = 'Nota de Crédito C';
      _fechaEmision = DateTime.now();
      _precargarDesdeFactura(facturaAAnular);
    }
    _montoController.addListener(() => setState(() {}));
    _nombreClienteController.addListener(_onDatosClienteEditados);
    _nroDocController.addListener(_onDatosClienteEditados);
    _emailClienteController.addListener(_onDatosClienteEditados);
    _telefonoClienteController.addListener(_onDatosClienteEditados);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) _clientesStream = _clienteService.getClientesStream(uid);
    _initStreams();
  }

  void _onDatosClienteEditados() {
    if (_actualizandoClienteSeleccionado || !mounted) return;
    setState(() {
      _clienteIdSeleccionado = null;
    });
  }

  String _normalizarDocumento(String value) =>
      value.replaceAll(RegExp(r'\D'), '');

  Future<String> _resolverCuitEmisor(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    final cuitPerfil = (userData['cuit'] ?? '').toString();
    final cuitActual = ArcaFiscalService.normalizarCuit(cuitPerfil);
    if (ArcaFiscalService.tieneFormatoCuit(cuitActual)) {
      if (cuitPerfil != cuitActual) {
        await FirebaseFirestore.instance.collection('usuarios').doc(userId).set(
          {'cuit': cuitActual},
          SetOptions(merge: true),
        );
      }
      return cuitActual;
    }

    final cuitDePrueba = ArcaFiscalService.resolverCuitEmisor(cuitPerfil);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _arcaFiscalService.permiteCuitDePrueba
                ? 'Usando CUIT de prueba. Este comprobante no tiene validez fiscal.'
                : 'El perfil no tiene un CUIT de 11 dígitos; se usará el CUIT de prueba.',
          ),
        ),
      );
    }
    return cuitDePrueba;
  }

  ClienteModel? _buscarClienteCoincidente() {
    final documento = _normalizarDocumento(_nroDocController.text);
    if (documento.isNotEmpty) {
      for (final cliente in _clientes) {
        if (_normalizarDocumento(cliente.numeroDocumento) == documento) {
          return cliente;
        }
      }
      return null;
    }
    final nombre = _nombreClienteController.text.trim().toLowerCase();
    if (nombre.isEmpty) return null;
    for (final cliente in _clientes) {
      if (cliente.razonSocialONombre.trim().toLowerCase() == nombre &&
          cliente.numeroDocumento.isEmpty) {
        return cliente;
      }
    }
    return null;
  }

  void _seleccionarCliente(ClienteModel? cliente) {
    if (cliente == null) return;
    _actualizandoClienteSeleccionado = true;
    _nombreClienteController.text = cliente.razonSocialONombre;
    _tipoDocCliente = cliente.tipoDocumento;
    _nroDocController.text = cliente.numeroDocumento;
    _condicionIvaCliente = cliente.condicionIva;
    _emailClienteController.text = cliente.email ?? '';
    _telefonoClienteController.text = cliente.telefono ?? '';
    _domicilioClienteController.clear();
    _guardarEnAgenda = false;
    _clienteIdSeleccionado = cliente.id;
    _actualizandoClienteSeleccionado = false;
    setState(() {});
  }

  Widget _buildSelectorClientes() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<ClienteModel>>(
      stream: _clientesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'No se pudo cargar la agenda: ${snapshot.error}',
            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
          );
        }
        _clientes = snapshot.data ?? [];
        final clienteExistente = _buscarClienteCoincidente();
        final puedeGuardar =
            _nombreClienteController.text.trim().isNotEmpty &&
            _clienteIdSeleccionado == null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(_clienteIdSeleccionado),
              initialValue: _clienteIdSeleccionado,
              isExpanded: true,
              dropdownColor: Colors.white,
              decoration: _inputDecoration(
                labelText: 'Clientes frecuentes',
                prefixIcon: Icons.contacts_outlined,
              ),
              hint: Text(
                snapshot.connectionState == ConnectionState.waiting
                    ? 'Cargando agenda...'
                    : 'Seleccionar de mi agenda',
                overflow: TextOverflow.ellipsis,
              ),
              items: _clientes
                  .where((cliente) => cliente.id != null)
                  .map(
                    (cliente) => DropdownMenuItem<String>(
                      value: cliente.id,
                      child: Text(
                        cliente.numeroDocumento.isEmpty
                            ? cliente.razonSocialONombre
                            : '${cliente.razonSocialONombre} · '
                                  '${cliente.numeroDocumento}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id == null) {
                  setState(() {
                    _clienteIdSeleccionado = null;
                    _guardarEnAgenda = false;
                  });
                  return;
                }
                final cliente = _clientes
                    .where((item) => item.id == id)
                    .firstOrNull;
                _seleccionarCliente(cliente);
              },
            ),
            if (puedeGuardar) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _guardarEnAgenda,
                onChanged: (value) =>
                    setState(() => _guardarEnAgenda = value ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF059669),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  clienteExistente == null
                      ? 'Guardar en mi agenda de clientes'
                      : 'Actualizar cliente en mi agenda',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _initStreams() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userSub = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .snapshots()
          .listen((doc) {
            if (mounted) setState(() => _userData = doc.data());
          });

      _facturasSub = FirebaseFirestore.instance
          .collection('facturas')
          .where(
            Filter.or(
              Filter('userId', isEqualTo: user.uid),
              Filter('id_usuario', isEqualTo: user.uid),
            ),
          )
          .snapshots()
          .listen((snap) {
            if (mounted) setState(() => _facturasDocs = snap.docs);
          });
    }
  }

  @override
  void dispose() {
    _advertenciaTimer?.cancel();
    _userSub?.cancel();
    _facturasSub?.cancel();
    _puntoVentaController.dispose();
    _nroDocController.dispose();
    _nombreClienteController.dispose();
    _emailClienteController.dispose();
    _telefonoClienteController.dispose();
    _domicilioClienteController.dispose();
    _descripcionController.dispose();
    _montoController.dispose();
    _arcaFiscalService.close();
    super.dispose();
  }

  String _obtenerCategoriaUsuario() {
    final catRaw = _userData?['categoria']?.toString() ?? 'A';
    final limpio = catRaw.trim().replaceAll(
      RegExp(r'^(Categoria|Categoría)\s*', caseSensitive: false),
      '',
    );
    return limpio.toUpperCase();
  }

  double _sumarUltimos12Meses(
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? docs,
    DateTime ref,
  ) {
    if (docs == null) return 0.0;
    final hace12Meses = DateTime(ref.year - 1, ref.month, ref.day);
    double total = 0.0;
    for (final doc in docs) {
      final data = doc.data();
      final fechaRaw =
          data['fecha_emision'] ?? data['fechaEmision'] ?? data['created_at'];
      DateTime? fecha;
      if (fechaRaw is Timestamp) fecha = fechaRaw.toDate();
      if (fechaRaw is String) fecha = DateTime.tryParse(fechaRaw);
      if (fecha != null && fecha.isAfter(hace12Meses)) {
        total += MonotributoCategory.impactoFiscalDocumento(data);
      }
    }
    return total;
  }

  Future<void> _seleccionarFecha(
    BuildContext context, {
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? now.subtract(const Duration(days: 120)),
      lastDate: lastDate ?? now.add(const Duration(days: 120)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF059669),
              onPrimary: Colors.white,
              surface: Color(0xFFFFFFFF),
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onSelected(picked);
    }
  }

  /// Paso 1: Valida el formulario e inicia la previsualización modal antes de emitir.
  Future<void> _solicitarEmisionFactura() async {
    if (!_formKey.currentState!.validate()) return;
    final facturaOriginal = _facturaOriginal;
    if (_esNotaCredito && facturaOriginal == null) {
      _mostrarErrorEmision(
        'Seleccioná la Factura C que vas a anular en "Comprobante Asociado a Anular".',
      );
      return;
    }
    if (_esNotaCredito &&
        facturaOriginal != null &&
        (facturaOriginal.tipoComprobante != 'Factura C' ||
            facturaOriginal.numeroComprobanteFiscal == null)) {
      _mostrarErrorEmision(
        'El comprobante asociado debe ser una Factura C con número de comprobante válido.',
      );
      return;
    }
    if (_esNotaCredito &&
        widget.comprobanteAAnular == null &&
        !_facturasAnulables.any((item) => item.id == facturaOriginal?.id)) {
      setState(() => _facturaAsociada = null);
      _mostrarErrorEmision(
        'La factura seleccionada ya no está disponible para anular. Elegí otra.',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Iniciá sesión para emitir comprobantes.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final double monto =
        double.tryParse(_montoController.text.replaceAll(',', '.')) ?? 0.0;
    if (monto <= 0) {
      _mostrarErrorEmision('El importe total debe ser mayor a 0');
      return;
    }
    if (facturaOriginal != null &&
        monto.toStringAsFixed(2) != facturaOriginal.monto.toStringAsFixed(2)) {
      _mostrarErrorEmision(
        'El importe de la Nota de Crédito debe coincidir con el total de la factura original.',
      );
      return;
    }
    if (facturaOriginal != null && facturaOriginal.id == null) {
      _mostrarErrorEmision(
        'No se pudo identificar la factura original para vincular la anulación.',
      );
      return;
    }

    // Proyección del impacto en el cupo mensual del monotributo
    final categoria = _obtenerCategoriaUsuario();
    final tope =
        MonotributoCategory.annualIncomeLimits[categoria] ??
        MonotributoCategory.annualIncomeLimits['A']!;
    final ahora = DateTime.now();
    final facturado = _sumarUltimos12Meses(_facturasDocs, ahora);
    final saldo = (tope - facturado).clamp(0.0, double.infinity);
    final mesesRestantes = (12 - ahora.month + 1).clamp(1, 12);
    final cupoMes = saldo / mesesRestantes;
    final pctConsumo = cupoMes > 0 ? (monto / cupoMes) : 0.0;
    final cupoRestante = (cupoMes - monto).clamp(0.0, double.infinity);

    final rawDocument = _nroDocController.text.trim();
    final cuitCliente = rawDocument.isEmpty ? 'Consumidor Final' : rawDocument;
    final nombreCliente = _nombreClienteController.text.trim();
    final descripcion = _descripcionController.text.trim().isNotEmpty
        ? _descripcionController.text.trim()
        : _concepto;

    // Despliega el modal interactivo de previsualización y confirmación
    final confirmar = await _mostrarDialogoConfirmacion(
      monto: monto,
      cuitCliente: cuitCliente,
      tipoDocCliente: _tipoDocCliente,
      nombreCliente: nombreCliente,
      concepto: _concepto,
      descripcion: descripcion,
      condicionVenta: _condicionVenta,
      categoria: categoria,
      cupoMes: cupoMes,
      pctConsumo: pctConsumo,
      cupoRestante: cupoRestante,
    );

    if (confirmar == true && mounted) {
      await _ejecutarEmisionFiscal(monto);
    }
  }

  /// Entrada directa compatible con los llamados existentes
  Future<void> _emitirFactura() => _solicitarEmisionFactura();

  /// Despliega el modal centrado de confirmación y vista previa antes de emitir.
  Future<bool?> _mostrarDialogoConfirmacion({
    required double monto,
    required String cuitCliente,
    required String tipoDocCliente,
    required String nombreCliente,
    required String concepto,
    required String descripcion,
    required String condicionVenta,
    required String categoria,
    required double cupoMes,
    required double pctConsumo,
    required double cupoRestante,
  }) {
    final colorConsumo = pctConsumo < 0.7
        ? const Color(0xFF10B981)
        : pctConsumo < 0.9
        ? const Color(0xFFF59E0B)
        : const Color(0xFFDC2626);

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF059669),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Confirmar Emisión de Factura',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta resumen con diseño prolijo
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Importe Total a Facturar ($ ARS) destacado en negrita
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Importe Total a Facturar',
                              style: TextStyle(
                                color: Color(0xFF065F46),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currencyFormat.format(monto),
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // CUIT / CUIL y Nombre del Cliente
                      _buildResumenFila(
                        icon: Icons.person_outline_rounded,
                        label: 'Cliente / Receptor',
                        valor: nombreCliente.isNotEmpty
                            ? nombreCliente
                            : 'Consumidor Final',
                        subvalor:
                            cuitCliente.isNotEmpty &&
                                cuitCliente != 'Consumidor Final'
                            ? '$tipoDocCliente: $cuitCliente'
                            : 'Consumidor Final',
                      ),
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),

                      // Concepto / Descripción
                      _buildResumenFila(
                        icon: Icons.work_outline_rounded,
                        label: 'Concepto / Descripción',
                        valor: descripcion.isNotEmpty ? descripcion : concepto,
                        subvalor:
                            descripcion.isNotEmpty && descripcion != concepto
                            ? 'Tipo: $concepto'
                            : null,
                      ),
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),

                      // Condición de venta / Medio de pago
                      _buildResumenFila(
                        icon: Icons.payments_outlined,
                        label: 'Condición de Venta / Pago',
                        valor: condicionVenta,
                      ),
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),

                      // Impacto proyectado en el cupo mensual del monotributo
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.analytics_outlined,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Impacto en Cupo Mensual (Cat. $categoria)',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Consume ${(pctConsumo * 100).clamp(0, 100).toStringAsFixed(1)}% del cupo',
                                style: TextStyle(
                                  color: colorConsumo,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Queda: ${_currencyFormat.format(cupoRestante)}',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pctConsumo.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorConsumo,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cupo disponible del mes: ${_currencyFormat.format(cupoMes)}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Leyenda de advertencia fiscal sutil
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Una vez emitida la factura, solo podrá anularse mediante una Nota de Crédito.',
                          style: TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 11,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogCtx, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Volver / Corregir',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirmar y Emitir',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildResumenFila({
    required IconData icon,
    required String label,
    required String valor,
    String? subvalor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subvalor != null && subvalor.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  subvalor,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Paso 2: Ejecuta la emisión fiscal propiamente dicha tras la confirmación.
  Future<void> _ejecutarEmisionFiscal(double monto) async {
    final facturaOriginal = _facturaOriginal;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _mostrarErrorEmision('Iniciá sesión para emitir comprobantes.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final emisorNombre =
          (userData['nombre'] ?? user.displayName ?? 'Emisor Monotributista')
              .toString();
      final emisorCuit = await _resolverCuitEmisor(user.uid, userData);
      final emisorDomicilio =
          (userData['domicilio'] ?? 'Buenos Aires, Argentina').toString();

      final puntoVentaStr = _puntoVentaController.text.trim().padLeft(4, '0');
      final rawDocument = _nroDocController.text.trim();
      final tipoDocumento = rawDocument.isEmpty
          ? 99
          : switch (_tipoDocCliente) {
              'CUIT' => 80,
              'DNI' => 96,
              _ => 99,
            };
      if (_guardarEnAgenda) {
        final clienteExistente = _buscarClienteCoincidente();
        final cliente = ClienteModel(
          id: clienteExistente?.id,
          idUsuario: user.uid,
          razonSocialONombre: _nombreClienteController.text.trim(),
          tipoDocumento: _tipoDocCliente,
          numeroDocumento: rawDocument,
          condicionIva: _condicionIvaCliente,
          email: _emailClienteController.text.trim().isEmpty
              ? null
              : _emailClienteController.text.trim(),
          telefono: _telefonoClienteController.text.trim().isEmpty
              ? null
              : _telefonoClienteController.text.trim(),
          creadoEn: clienteExistente?.creadoEn ?? DateTime.now(),
        );
        await _clienteService.guardarOActualizarCliente(cliente);
      }
      final factura = FacturaModel(
        idUsuario: user.uid,
        nroFactura: '',
        puntoVenta: puntoVentaStr,
        cuitCliente: rawDocument.isEmpty ? 'Consumidor Final' : rawDocument,
        nombreCliente: _nombreClienteController.text.trim(),
        monto: monto,
        tipoFactura: _tipoComprobante,
        tipoComprobante: _tipoComprobante,
        esNotaCredito: _tipoComprobante == 'Nota de Crédito C',
        comprobanteAsociadoId: facturaOriginal?.id,
        comprobanteAsociadoNumero: facturaOriginal == null
            ? null
            : '${facturaOriginal.puntoVentaFiscal}-'
                  '${facturaOriginal.numeroComprobanteFiscal ?? ''}',
        comprobanteAsociadoTipo: facturaOriginal?.tipoComprobante,
        comprobanteAsociadoPuntoVenta: facturaOriginal?.puntoVentaFiscal,
        comprobanteAsociadoNumeroComprobante:
            facturaOriginal?.numeroComprobanteFiscal,
        fechaEmision: _fechaEmision,
        concepto: _concepto,
        tipoDocumentoCliente: tipoDocumento,
        periodoDesde: _periodoDesde,
        periodoHasta: _periodoHasta,
        vencimientoPago: _vtoPago,
        descripcionItem: _descripcionController.text.trim(),
        condicionIvaCliente: _condicionIvaCliente,
        domicilioCliente: _domicilioClienteController.text.trim(),
        condicionVenta: _condicionVenta,
        emisorNombre: emisorNombre,
        emisorCuit: emisorCuit,
        emisorDomicilio: emisorDomicilio,
      );
      // Chequeo previo: si la factura original ya fue anulada, no se llama a ARCA.
      final idOriginal = facturaOriginal?.id;
      if (idOriginal != null) {
        final actual = await FirebaseFirestore.instance
            .collection('facturas')
            .doc(idOriginal)
            .get();
        final motivo = FacturaModel.motivoNoAnulable(actual.data());
        if (motivo != null) throw FacturaNoAnulableException(motivo);
      }

      Map<String, dynamic> emision;
      try {
        emision = await _arcaFiscalService.emitirFactura(
          factura: factura,
          puntoVenta: puntoVentaStr,
          cuitEmisor: emisorCuit,
        );
      } on ArcaFiscalException catch (e) {
        if (_arcaFiscalService.permitirSimulacionFallback &&
            (e.code == 'NETWORK_TIMEOUT' ||
                e.code == 'NETWORK_ERROR' ||
                e.code == 'API_NOT_CONFIGURED' ||
                e.message.contains('no respondió') ||
                e.message.contains('puerto 3000') ||
                e.message.contains('No se pudo conectar'))) {
          emision = await _arcaFiscalService.emitirFacturaSimulada(
            factura: factura,
            puntoVenta: puntoVentaStr,
            cuitEmisor: emisorCuit,
          );
        } else {
          rethrow;
        }
      }

      await _guardarFacturaYNotificar(
        emision: emision,
        factura: factura,
        puntoVentaStr: puntoVentaStr,
        facturaOriginal: facturaOriginal,
      );
    } on FacturaNoAnulableException catch (e) {
      _mostrarErrorEmision(e.message);
    } on ArcaFiscalException catch (e) {
      _mostrarErrorEmision(e.message);
    } catch (e) {
      _mostrarErrorEmision('Error al emitir la factura: $e');
    } finally {
      // Siempre se libera el estado de carga para que el botón vuelva a habilitarse.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarFacturaYNotificar({
    required Map<String, dynamic> emision,
    required FacturaModel factura,
    required String puntoVentaStr,
    FacturaModel? facturaOriginal,
  }) async {
    final numeroComprobante = emision['numeroComprobante'].toString();
    final esSimulada =
        emision['modoSimulacion'] == true || emision['simulada'] == true;
    final facturaAprobada = factura.copyWith(
      nroFactura: '$puntoVentaStr-$numeroComprobante',
      puntoVenta: emision['puntoVenta'].toString(),
      numeroComprobante: numeroComprobante,
      cae: emision['cae'].toString(),
      fechaVtoCae: DateTime.parse(emision['fechaVtoCae'].toString()),
      resultadoEmision: 'Aprobado',
      qrUrl: emision['qrUrl']?.toString(),
      qrData: emision['qrData']?.toString(),
      modoHomologacion: emision['modoHomologacion'] == true,
    );
    final facturaData = facturaAprobada.toMap()
      ..['created_at'] = FieldValue.serverTimestamp()
      ..['modoSimulacion'] = esSimulada
      ..['simulada'] = esSimulada;

    final facturas = FirebaseFirestore.instance.collection('facturas');
    final nuevaFactura = facturas.doc();
    final originalId = facturaOriginal?.id;
    if (originalId == null) {
      await nuevaFactura.set(facturaData);
    } else {
      // Alta de la NC y anulación de la original en una sola transacción:
      // si otra NC ya anuló la factura, no se registra nada.
      final originalRef = facturas.doc(originalId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final actual = await tx.get(originalRef);
        final motivo = FacturaModel.motivoNoAnulable(actual.data());
        if (motivo != null) {
          throw FacturaNoAnulableException(
            '$motivo La Nota de Crédito pudo quedar autorizada por ARCA sin '
            'registrarse en la app: verificala en ARCA antes de reintentar.',
          );
        }
        tx.set(nuevaFactura, facturaData);
        tx.update(originalRef, {
          'anulada': true,
          'es_anulada': true,
          'anuladaPorNcId': nuevaFactura.id,
          'anulada_por_nc_id': nuevaFactura.id,
          'anuladaPorNcNumero': facturaAprobada.nroFactura,
          'anulada_por_nc_numero': facturaAprobada.nroFactura,
        });
      });
    }

    widget.onFacturaEmitida?.call();

    if (!mounted) return;

    if (esSimulada) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Factura emitida en modo simulación (backend no disponible)',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
    }

    // Mostrar diálogo de éxito con opciones de Compartir PDF y Ver Historial
    await _mostrarDialogoExito(facturaData);
  }

  void _mostrarErrorEmision(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 6),
        ),
      );
  }

  Future<void> _mostrarDialogoExito(Map<String, dynamic> facturaData) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                facturaData['modoSimulacion'] == true ||
                        facturaData['simulada'] == true
                    ? 'Comprobante emitido (Modo Simulación)'
                    : facturaData['modoHomologacion'] == true
                    ? 'Autorización en homologación'
                    : facturaData['esNotaCredito'] == true
                    ? '¡Nota de Crédito autorizada por ARCA!'
                    : '¡Factura autorizada por ARCA!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (facturaData['modoSimulacion'] == true ||
                  facturaData['simulada'] == true) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFFB45309),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Factura emitida en modo simulación (backend no disponible)',
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ] else if (facturaData['modoHomologacion'] == true) ...[
                const Text(
                  'Este comprobante de prueba no tiene validez fiscal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                '${facturaData['tipo_comprobante']} ${facturaData['nro_factura']}\n'
                'Total: ${_currencyFormat.format(facturaData['monto'])}\n'
                'Receptor: ${facturaData['nombre_cliente']}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'CAE: ${facturaData['cae']}',
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await PdfInvoiceService.shareInvoicePdf(facturaData);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error al compartir PDF: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text(
                    'Compartir PDF',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HistorialFacturasScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  label: const Text(
                    'Ver en Historial',
                    style: TextStyle(color: Color(0xFF0F172A)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (widget.comprobanteAAnular == null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _resetFormulario();
                    },
                    child: const Text(
                      'Emitir Otra Factura',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                if (widget.onVolverAlInicio != null) ...[
                  const SizedBox(height: 2),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onVolverAlInicio!();
                    },
                    icon: const Icon(
                      Icons.home_rounded,
                      size: 16,
                      color: Color(0xFF059669),
                    ),
                    label: const Text(
                      'Volver al Inicio',
                      style: TextStyle(color: Color(0xFF059669)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  void _resetFormulario() {
    setState(() {
      _facturaAsociada = null;
      _montoController.clear();
      _nroDocController.clear();
      _nombreClienteController.clear();
      _emailClienteController.clear();
      _telefonoClienteController.clear();
      _domicilioClienteController.clear();
      _clienteIdSeleccionado = null;
      _guardarEnAgenda = false;
      _tipoDocCliente = 'CUIT';
      _fechaEmision = DateTime.now();
      _periodoDesde = DateTime(DateTime.now().year, DateTime.now().month, 1);
      _periodoHasta = DateTime.now();
      _vtoPago = DateTime.now().add(const Duration(days: 10));
    });
  }

  Widget _buildSimuladorImpacto() {
    final categoria = _obtenerCategoriaUsuario();
    final tope =
        MonotributoCategory.annualIncomeLimits[categoria] ??
        MonotributoCategory.annualIncomeLimits['A']!;
    final ahora = DateTime.now();
    final facturado = _sumarUltimos12Meses(_facturasDocs, ahora);
    final saldo = (tope - facturado).clamp(0.0, double.infinity);
    final mesesRestantes = (12 - ahora.month + 1).clamp(1, 12);
    final cupo = saldo / mesesRestantes;
    final monto =
        double.tryParse(_montoController.text.replaceAll(',', '.')) ?? 0.0;
    final pctConsumo = cupo > 0 ? monto / cupo : 0.0;
    final restante = (cupo - monto).clamp(0.0, double.infinity);

    final colorConsumo = pctConsumo < 0.7
        ? const Color(0xFF10B981)
        : pctConsumo < 0.9
        ? const Color(0xFFF59E0B)
        : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: monto <= 0
          ? Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF64748B),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cupo disponible del mes: ${_currencyFormat.format(cupo)} (Cat. $categoria)',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Impacto en cupo mensual:',
                      style: TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(pctConsumo * 100).clamp(0, 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: colorConsumo,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pctConsumo.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: const Color(0xFFFFFFFF),
                    valueColor: AlwaysStoppedAnimation<Color>(colorConsumo),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cupo mes: ${_currencyFormat.format(cupo)}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Queda: ${_currencyFormat.format(restante)}',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool requierePeriodo =
        _concepto.contains('Servicio') || _concepto == 'Productos y Servicios';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _esNotaCredito ? 'Nota de Crédito C' : 'Facturación Electrónica',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFFFFFF),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        leading: widget.onVolverAlInicio != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Volver al Inicio',
                onPressed: widget.onVolverAlInicio,
              )
            : (Navigator.canPop(context) ? const BackButton() : null),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFF059669)),
            tooltip: 'Ver Historial de Facturas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HistorialFacturasScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // BANNER NORMATIVA ARCA / AFIP
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF047857),
                      Color(0xFF059669),
                      Color(0xFF10B981),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _esNotaCredito
                            ? 'La Nota de Crédito se guarda únicamente después de recibir la autorización y el CAE de ARCA.'
                            : 'La factura se guarda únicamente después de recibir la autorización y el CAE del backend fiscal conectado con ARCA.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ==========================================
              // SECCIÓN NC: COMPROBANTE ASOCIADO A ANULAR
              // ==========================================
              if (_esNotaCredito) ...[
                _buildSeccionComprobanteAsociado(),
                const SizedBox(height: 24),
              ],

              // ==========================================
              // SECCIÓN A: DATOS DE EMISIÓN DEL COMPROBANTE
              // ==========================================
              _buildSectionHeader(
                icon: Icons.receipt_long_rounded,
                title: 'a) Datos de Emisión del Comprobante',
              ),
              const SizedBox(height: 12),
              _buildCardContainer(
                children: [
                  // Tipo de Comprobante
                  _buildDropdownField<String>(
                    label: 'Tipo de Comprobante',
                    initialValue: _tipoComprobante,
                    items: widget.comprobanteAAnular == null
                        ? const [
                            'Factura C',
                            'Factura B',
                            'Factura A',
                            'Nota de Crédito C',
                            'Nota de Débito C',
                          ]
                        : const ['Nota de Crédito C'],
                    onChanged: (val) {
                      if (val != null) _onTipoComprobanteChanged(val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Punto de Venta y Fecha de Emisión
                  Row(
                    children: [
                      // Punto de venta
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: _puntoVentaController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          style: const TextStyle(color: Color(0xFF0F172A)),
                          decoration: _inputDecoration(
                            labelText: 'Pto. Venta',
                            prefixIcon: Icons.storefront_rounded,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Obligatorio';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Selector de Fecha de Emisión (Editable en creación)
                      Expanded(
                        flex: 6,
                        child: InkWell(
                          onTap: () => _seleccionarFecha(
                            context,
                            initialDate: _fechaEmision,
                            onSelected: (picked) =>
                                setState(() => _fechaEmision = picked),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: _inputDecoration(
                              labelText: 'Fecha Emisión',
                              prefixIcon: Icons.calendar_today_rounded,
                            ),
                            child: Text(
                              _dateFormat.format(_fechaEmision),
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Concepto a incluir
                  _buildDropdownField<String>(
                    label: 'Concepto a incluir',
                    initialValue: _concepto,
                    items: const [
                      'Servicios',
                      'Productos',
                      'Productos y Servicios',
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _concepto = val);
                    },
                  ),

                  // Período facturado y vencimiento si es Servicios
                  if (requierePeriodo) ...[
                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 14),
                    const Text(
                      'Período del Servicio y Vencimiento de Pago:',
                      style: TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _seleccionarFecha(
                              context,
                              initialDate: _periodoDesde ?? DateTime.now(),
                              onSelected: (d) =>
                                  setState(() => _periodoDesde = d),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: _inputDecoration(
                                labelText: 'Período Desde',
                                prefixIcon: Icons.date_range_rounded,
                              ),
                              child: Text(
                                _periodoDesde != null
                                    ? _dateFormat.format(_periodoDesde!)
                                    : 'Seleccionar',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _seleccionarFecha(
                              context,
                              initialDate: _periodoHasta ?? DateTime.now(),
                              onSelected: (d) =>
                                  setState(() => _periodoHasta = d),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: _inputDecoration(
                                labelText: 'Período Hasta',
                                prefixIcon: Icons.date_range_rounded,
                              ),
                              child: Text(
                                _periodoHasta != null
                                    ? _dateFormat.format(_periodoHasta!)
                                    : 'Seleccionar',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _seleccionarFecha(
                        context,
                        initialDate:
                            _vtoPago ??
                            DateTime.now().add(const Duration(days: 10)),
                        onSelected: (d) => setState(() => _vtoPago = d),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _inputDecoration(
                          labelText: 'Vencimiento para el Pago',
                          prefixIcon: Icons.event_available_rounded,
                        ),
                        child: Text(
                          _vtoPago != null
                              ? _dateFormat.format(_vtoPago!)
                              : 'Seleccionar',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),

              // ==========================================
              // SECCIÓN B: DATOS DEL RECEPTOR / CLIENTE
              // ==========================================
              _buildSectionHeader(
                icon: Icons.person_rounded,
                title: 'b) Datos del Receptor / Cliente',
              ),
              const SizedBox(height: 12),
              _buildCardContainer(
                children: [
                  _buildSelectorClientes(),
                  const SizedBox(height: 14),
                  // Condición frente al IVA
                  _buildDropdownField<String>(
                    label: 'Condición frente al IVA',
                    initialValue: _condicionIvaCliente,
                    items: const [
                      'Consumidor Final',
                      'Responsable Inscripto',
                      'Monotributista',
                      'Exento',
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _condicionIvaCliente = val;
                          if (val == 'Responsable Inscripto' ||
                              val == 'Monotributista' ||
                              val == 'Exento') {
                            _tipoDocCliente = 'CUIT';
                          }
                          _clienteIdSeleccionado = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Tipo de Documento y Número
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: _buildDropdownField<String>(
                          key: ValueKey(_tipoDocCliente),
                          label: 'Tipo Doc',
                          initialValue: _tipoDocCliente,
                          items: const ['CUIT', 'DNI', 'Consumidor Final'],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _tipoDocCliente = val;
                                _clienteIdSeleccionado = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: TextFormField(
                          controller: _nroDocController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            DigitosConAdvertenciaInputFormatter(
                              onCaracterInvalido:
                                  _mostrarAdvertenciaCaracterInvalido,
                            ),
                            LengthLimitingTextInputFormatter(11),
                          ],
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          style: const TextStyle(color: Color(0xFF0F172A)),
                          decoration: _inputDecoration(
                            labelText: _tipoDocCliente == 'CUIT'
                                ? 'CUIT / CUIL *'
                                : 'N° Documento',
                            prefixIcon: Icons.badge_outlined,
                            hintText: _tipoDocCliente == 'CUIT'
                                ? 'Ej. 20111111112'
                                : 'Ej. 38491823',
                            helperText: _advertenciaFormatoDoc,
                            helperStyle: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            errorText: _advertenciaFormatoDoc,
                          ),
                          validator: (val) {
                            if (_advertenciaFormatoDoc != null) {
                              return _advertenciaFormatoDoc;
                            }
                            return NuevaFacturaScreen.validarCuitCliente(
                              val,
                              tipoDoc: _tipoDocCliente,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Nombre / Razón Social (Obligatorio)
                  TextFormField(
                    controller: _nombreClienteController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: _inputDecoration(
                      labelText: 'Apellido y Nombre / Razón Social *',
                      prefixIcon: Icons.account_circle_outlined,
                      hintText: 'Ej. Juan Pérez o Empresa SRL',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Ingresá el nombre o razón social del cliente';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Domicilio Fiscal / Comercial (Opcional)
                  TextFormField(
                    controller: _domicilioClienteController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: _inputDecoration(
                      labelText: 'Domicilio Comercial / Fiscal (Opcional)',
                      prefixIcon: Icons.location_on_outlined,
                      hintText: 'Ej. Av. Corrientes 1234, CABA',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailClienteController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: _inputDecoration(
                      labelText: 'Email (Opcional)',
                      prefixIcon: Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _telefonoClienteController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: _inputDecoration(
                      labelText: 'Teléfono (Opcional)',
                      prefixIcon: Icons.phone_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ==========================================
              // SECCIÓN C: DETALLE DE LA OPERACIÓN Y PAGO
              // ==========================================
              _buildSectionHeader(
                icon: Icons.payments_rounded,
                title: 'c) Detalle de la Operación y Cobro',
              ),
              const SizedBox(height: 12),
              _buildCardContainer(
                children: [
                  // Descripción del servicio o producto
                  TextFormField(
                    controller: _descripcionController,
                    maxLines: 2,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: _inputDecoration(
                      labelText: 'Descripción del ítem o servicio prestado *',
                      hintText: 'Ej. Servicios profesionales de consultoría',
                      prefixIcon: Icons.description_outlined,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Ingresá la descripción del concepto facturado';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Importe Subtotal / Total ($)
                  TextFormField(
                    controller: _montoController,
                    readOnly: _facturaOriginal != null,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+[\.,]?\d{0,2}'),
                      ),
                    ],
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    decoration: _inputDecoration(
                      labelText: _facturaOriginal == null
                          ? 'Importe Total / Subtotal (\$ ARS) *'
                          : 'Importe total de la anulación (\$ ARS)',
                      prefixIcon: Icons.attach_money_rounded,
                      hintText: '0.00',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Ingresá el importe de la factura';
                      }
                      final parsed = double.tryParse(val.replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) {
                        return 'El importe debe ser mayor a 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // 📊 Simulador de Impacto en vivo
                  _buildSimuladorImpacto(),
                  const SizedBox(height: 14),

                  // Condición de Venta / Forma de Pago
                  _buildDropdownField<String>(
                    label: 'Condición de Venta / Medio de Pago',
                    initialValue: _condicionVenta,
                    items: const [
                      'Transferencia / Débito',
                      'Efectivo',
                      'Mercado Pago',
                      'Cuenta Corriente',
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _condicionVenta = val);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // BOTÓN PRINCIPAL DE EMISIÓN
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed:
                      _isLoading || (_esNotaCredito && _facturaOriginal == null)
                      ? null
                      : _emitirFactura,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                  label: Text(
                    _isLoading
                        ? 'Conectando con ARCA...'
                        : _esNotaCredito
                        ? 'Emitir Nota de Crédito C'
                        : 'Emitir Factura Electrónica',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _nombreReceptor(FacturaModel factura) {
    final nombre = factura.nombreCliente.trim();
    if (nombre.isNotEmpty) return nombre;
    final cuit = factura.cuitCliente.trim();
    return cuit.isEmpty ? 'Consumidor Final' : cuit;
  }

  /// Sección obligatoria de la Nota de Crédito C: identifica la Factura C anulada.
  Widget _buildSeccionComprobanteAsociado() {
    final facturaFija = widget.comprobanteAAnular;
    final anulables = _facturasAnulables;
    final cargando = facturaFija == null && _facturasDocs == null;
    final sinFacturas = facturaFija == null && !cargando && anulables.isEmpty;

    final Widget contenido;
    if (facturaFija != null) {
      contenido = _buildResumenFacturaAsociada(facturaFija);
    } else if (cargando) {
      contenido = const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(
            color: Color(0xFF059669),
            strokeWidth: 2,
          ),
        ),
      );
    } else if (sinFacturas) {
      contenido = _buildAvisoSinFacturasC();
    } else {
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSelectorFacturaAsociada(anulables),
          if (_facturaAsociada != null) ...[
            const SizedBox(height: 10),
            _buildResumenFacturaAsociada(_facturaAsociada!),
            const SizedBox(height: 6),
            const Text(
              'Los datos del receptor se precargaron desde la factura. Podés editarlos antes de emitir.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          icon: Icons.assignment_return_outlined,
          title: 'Comprobante Asociado a Anular',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF97316), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Obligatorio: una Nota de Crédito C debe anular una Factura C emitida previamente.',
                style: TextStyle(
                  color: Color(0xFF9A3412),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              contenido,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvisoSinFacturasC() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No hay Facturas C emitidas para anular. Primero emití una Factura C: '
              'no se puede emitir una Nota de Crédito C sin comprobante asociado, '
              'por eso la emisión queda bloqueada.',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorFacturaAsociada(List<FacturaModel> anulables) {
    final seleccionadaId = _facturaAsociada?.id;
    final valorActual = anulables.any((f) => f.id == seleccionadaId)
        ? seleccionadaId
        : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('factura-asociada-$valorActual'),
      initialValue: valorActual,
      isExpanded: true,
      dropdownColor: const Color(0xFFFFFFFF),
      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
      iconEnabledColor: const Color(0xFF059669),
      decoration: _inputDecoration(
        labelText: 'Factura C a anular *',
        prefixIcon: Icons.receipt_long_outlined,
      ),
      hint: const Text(
        'Seleccionar factura emitida',
        overflow: TextOverflow.ellipsis,
      ),
      validator: (valor) =>
          valor == null ? 'Seleccioná la Factura C que vas a anular' : null,
      selectedItemBuilder: (context) => anulables
          .map(
            (f) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${f.numeroComprobanteCompleto} · '
                '${_currencyFormat.format(f.monto)}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
          .toList(),
      items: anulables
          .map(
            (f) => DropdownMenuItem<String>(
              value: f.id,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'N° ${f.numeroComprobanteCompleto}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    '${_dateFormat.format(f.fechaEmision)} · '
                    '${_nombreReceptor(f)} · '
                    '${_currencyFormat.format(f.monto)}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: _seleccionarFacturaAsociada,
    );
  }

  Widget _buildResumenFacturaAsociada(FacturaModel factura) {
    final cuit = factura.cuitCliente.trim();
    final tieneCuit = cuit.isNotEmpty && cuit != 'Consumidor Final';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildResumenFila(
            icon: Icons.receipt_long_outlined,
            label: 'Número de comprobante',
            valor:
                '${factura.tipoComprobante} ${factura.numeroComprobanteCompleto}',
          ),
          const Divider(height: 16, color: Color(0xFFE2E8F0)),
          _buildResumenFila(
            icon: Icons.calendar_today_rounded,
            label: 'Fecha de emisión',
            valor: _dateFormat.format(factura.fechaEmision),
          ),
          const Divider(height: 16, color: Color(0xFFE2E8F0)),
          _buildResumenFila(
            icon: Icons.person_outline_rounded,
            label: 'Receptor',
            valor: _nombreReceptor(factura),
            subvalor: tieneCuit ? 'CUIT / DNI: $cuit' : null,
          ),
          const Divider(height: 16, color: Color(0xFFE2E8F0)),
          _buildResumenFila(
            icon: Icons.attach_money_rounded,
            label: 'Importe',
            valor: _currencyFormat.format(factura.monto),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF059669), size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildDropdownField<T>({
    Key? key,
    required String label,
    required T initialValue,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      key: key,
      initialValue: initialValue,
      isExpanded: true,
      dropdownColor: const Color(0xFFFFFFFF),
      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
      iconEnabledColor: const Color(0xFF059669),
      decoration: _inputDecoration(labelText: label),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            item.toString(),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    IconData? prefixIcon,
    String? hintText,
    String? helperText,
    TextStyle? helperStyle,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: const Color(0xFF64748B), size: 18)
          : null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      helperText: helperText,
      helperStyle: helperStyle,
      errorText: errorText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }
}
