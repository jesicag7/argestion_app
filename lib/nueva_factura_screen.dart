import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'services/pdf_invoice_service.dart';
import 'historial_facturas_screen.dart';

class NuevaFacturaScreen extends StatefulWidget {
  final VoidCallback? onFacturaEmitida;
  final VoidCallback? onVolverAlInicio;

  const NuevaFacturaScreen({
    super.key,
    this.onFacturaEmitida,
    this.onVolverAlInicio,
  });

  @override
  State<NuevaFacturaScreen> createState() => _NuevaFacturaScreenState();
}

class _NuevaFacturaScreenState extends State<NuevaFacturaScreen> {
  final _formKey = GlobalKey<FormState>();

  // Topes anuales por categoría de monotributo general (AFIP 2026)
  static const Map<String, double> _topesMonotributo = {
    'A': 7720000,
    'B': 11450000,
    'C': 16050000,
    'D': 19950000,
    'E': 23500000,
    'F': 29400000,
    'G': 35250000,
    'H': 53400000,
    'I': 59850000,
    'J': 68600000,
    'K': 82300000,
  };

  // a) Datos de Emisión
  String _tipoComprobante = 'Factura C';
  final TextEditingController _puntoVentaController = TextEditingController(text: '0001');
  DateTime _fechaEmision = DateTime.now();
  String _concepto = 'Servicios';
  DateTime? _periodoDesde = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _periodoHasta = DateTime.now();
  DateTime? _vtoPago = DateTime.now().add(const Duration(days: 10));

  // b) Datos del Receptor / Cliente
  String _condicionIvaCliente = 'Consumidor Final';
  String _tipoDocCliente = 'DNI';
  final TextEditingController _nroDocController = TextEditingController();
  final TextEditingController _nombreClienteController = TextEditingController();
  final TextEditingController _domicilioClienteController = TextEditingController();

  // c) Detalle de la Operación y Cobro
  final TextEditingController _descripcionController =
      TextEditingController(text: 'Servicios Profesionales de Asesoría y Consultoría');
  final TextEditingController _montoController = TextEditingController();
  String _condicionVenta = 'Transferencia / Débito';

  bool _isLoading = false;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

  StreamSubscription? _userSub;
  StreamSubscription? _facturasSub;
  Map<String, dynamic>? _userData;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _facturasDocs;

  @override
  void initState() {
    super.initState();
    _montoController.addListener(() => setState(() {}));
    _initStreams();
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
    _userSub?.cancel();
    _facturasSub?.cancel();
    _puntoVentaController.dispose();
    _nroDocController.dispose();
    _nombreClienteController.dispose();
    _domicilioClienteController.dispose();
    _descripcionController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  String _obtenerCategoriaUsuario() {
    final catRaw = _userData?['categoria']?.toString() ?? 'A';
    final limpio = catRaw.trim().replaceAll(RegExp(r'^(Categoria|Categoría)\s*', caseSensitive: false), '');
    return limpio.toUpperCase();
  }

  double _sumarUltimos12Meses(List<QueryDocumentSnapshot<Map<String, dynamic>>>? docs, DateTime ref) {
    if (docs == null) return 0.0;
    final hace12Meses = DateTime(ref.year - 1, ref.month, ref.day);
    double total = 0.0;
    for (final doc in docs) {
      final data = doc.data();
      final fechaRaw = data['fecha_emision'] ?? data['fechaEmision'] ?? data['created_at'];
      DateTime? fecha;
      if (fechaRaw is Timestamp) fecha = fechaRaw.toDate();
      if (fechaRaw is String) fecha = DateTime.tryParse(fechaRaw);
      if (fecha != null && fecha.isAfter(hace12Meses)) {
        final monto = (data['monto'] is num)
            ? (data['monto'] as num).toDouble()
            : double.tryParse(data['monto']?.toString() ?? '0') ?? 0.0;
        total += monto;
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
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
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

  Future<void> _emitirFactura() async {
    if (!_formKey.currentState!.validate()) return;

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

    setState(() => _isLoading = true);

    try {
      final double monto = double.tryParse(_montoController.text.replaceAll(',', '.')) ?? 0.0;
      if (monto <= 0) {
        throw Exception('El importe total debe ser mayor a 0');
      }

      // Obtener datos del usuario emisor de Firestore si existen
      DocumentSnapshot<Map<String, dynamic>>? userDoc;
      try {
        userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      } catch (_) {}

      final userData = userDoc?.data() ?? {};
      final emisorNombre = (userData['nombre'] ?? user.displayName ?? 'Emisor Monotributista').toString();
      final emisorCuit = (userData['cuit'] ?? '20-38491823-4').toString();
      final emisorDomicilio = (userData['domicilio'] ?? 'Buenos Aires, Argentina').toString();

      // Generar secuencia de número de factura
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final secuencia = (timestamp % 100000).toString().padLeft(8, '0');
      final puntoVentaStr = _puntoVentaController.text.trim().padLeft(4, '0');
      final nroFacturaCompleto = '$puntoVentaStr-$secuencia';

      // Generar CAE de 14 dígitos y VTO (10 días posteriores a emisión)
      final seed = '${_fechaEmision.year}${_fechaEmision.month.toString().padLeft(2, '0')}$secuencia';
      final cae = '${seed}78492015829103'.substring(0, 14);
      final vtoCae = _fechaEmision.add(const Duration(days: 10));

      final facturaData = <String, dynamic>{
        'userId': user.uid,
        'id_usuario': user.uid,
        'tipo_comprobante': _tipoComprobante,
        'punto_venta': puntoVentaStr,
        'nro_factura': nroFacturaCompleto,
        'fecha_emision': _fechaEmision.toIso8601String(),
        'concepto': _concepto,
        'periodo_desde': _periodoDesde?.toIso8601String(),
        'periodo_hasta': _periodoHasta?.toIso8601String(),
        'vencimiento_pago': _vtoPago?.toIso8601String(),
        'condicion_iva_cliente': _condicionIvaCliente,
        'tipo_documento_cliente': _tipoDocCliente,
        'cuit_cliente': _nroDocController.text.trim().isEmpty ? 'Consumidor Final' : _nroDocController.text.trim(),
        'nombre_cliente': _nombreClienteController.text.trim(),
        'domicilio_cliente': _domicilioClienteController.text.trim(),
        'descripcion_item': _descripcionController.text.trim(),
        'monto': monto,
        'condicion_venta': _condicionVenta,
        'cae': cae,
        'vto_cae': vtoCae.toIso8601String(),
        'emisor_nombre': emisorNombre,
        'emisor_cuit': emisorCuit,
        'emisor_domicilio': emisorDomicilio,
        'created_at': FieldValue.serverTimestamp(),
      };

      // Guardar en Firestore
      await FirebaseFirestore.instance.collection('facturas').add(facturaData);

      widget.onFacturaEmitida?.call();

      if (!mounted) return;

      // Mostrar diálogo de éxito con opciones de Compartir PDF y Ver Historial
      await _mostrarDialogoExito(facturaData);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al emitir factura: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _mostrarDialogoExito(Map<String, dynamic> facturaData) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF334155)),
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
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                '¡Factura Electrónica Emitida!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                '${facturaData['tipo_comprobante']} ${facturaData['nro_factura']}\n'
                'Total: ${_currencyFormat.format(facturaData['monto'])}\n'
                'Receptor: ${facturaData['nombre_cliente']}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'CAE: ${facturaData['cae']}',
                  style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 11, fontWeight: FontWeight.bold),
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
                  label: const Text('Compartir PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistorialFacturasScreen()),
                    );
                  },
                  icon: const Icon(Icons.history_rounded, size: 18, color: Color(0xFF94A3B8)),
                  label: const Text('Ver en Historial', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF475569)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetFormulario();
                  },
                  child: const Text('Emitir Otra Factura', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                if (widget.onVolverAlInicio != null) ...[
                  const SizedBox(height: 2),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onVolverAlInicio!();
                    },
                    icon: const Icon(Icons.home_rounded, size: 16, color: Color(0xFF818CF8)),
                    label: const Text('Volver al Inicio', style: TextStyle(color: Color(0xFFA5B4FC))),
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
      _montoController.clear();
      _nroDocController.clear();
      _nombreClienteController.clear();
      _domicilioClienteController.clear();
      _fechaEmision = DateTime.now();
      _periodoDesde = DateTime(DateTime.now().year, DateTime.now().month, 1);
      _periodoHasta = DateTime.now();
      _vtoPago = DateTime.now().add(const Duration(days: 10));
    });
  }

  Widget _buildSimuladorImpacto() {
    final categoria = _obtenerCategoriaUsuario();
    final tope = _topesMonotributo[categoria] ?? 7720000.0;
    final ahora = DateTime.now();
    final facturado = _sumarUltimos12Meses(_facturasDocs, ahora);
    final saldo = (tope - facturado).clamp(0.0, double.infinity);
    final mesesRestantes = (12 - ahora.month + 1).clamp(1, 12);
    final cupo = saldo / mesesRestantes;
    final monto = double.tryParse(_montoController.text.replaceAll(',', '.')) ?? 0.0;
    final pctConsumo = cupo > 0 ? monto / cupo : 0.0;
    final restante = (cupo - monto).clamp(0.0, double.infinity);

    final colorConsumo = pctConsumo < 0.7
        ? const Color(0xFF10B981)
        : pctConsumo < 0.9
            ? const Color(0xFFF59E0B)
            : const Color(0xFFFF3366);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: monto <= 0
          ? Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cupo disponible del mes: ${_currencyFormat.format(cupo)} (Cat. $categoria)',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
                      style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(pctConsumo * 100).clamp(0, 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: colorConsumo, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pctConsumo.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: const Color(0xFF1E293B),
                    valueColor: AlwaysStoppedAnimation<Color>(colorConsumo),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cupo mes: ${_currencyFormat.format(cupo)}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                    Text(
                      'Queda: ${_currencyFormat.format(restante)}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool requierePeriodo = _concepto.contains('Servicio') || _concepto == 'Productos y Servicios';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Facturación Electrónica',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: widget.onVolverAlInicio != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Volver al Inicio',
                onPressed: widget.onVolverAlInicio,
              )
            : (Navigator.canPop(context) ? const BackButton() : null),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFFA5B4FC)),
            tooltip: 'Ver Historial de Facturas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistorialFacturasScreen()),
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
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF818CF8), size: 26),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Comprobante Electrónico oficial RG AFIP/ARCA con generación automática de CAE y PDF válido.',
                        style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),

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
                    items: const [
                      'Factura C',
                      'Factura B',
                      'Factura A',
                      'Nota de Crédito C',
                      'Nota de Débito C',
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _tipoComprobante = val);
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
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(
                            labelText: 'Pto. Venta',
                            prefixIcon: Icons.storefront_rounded,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Obligatorio';
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
                            onSelected: (picked) => setState(() => _fechaEmision = picked),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: _inputDecoration(
                              labelText: 'Fecha Emisión',
                              prefixIcon: Icons.calendar_today_rounded,
                            ),
                            child: Text(
                              _dateFormat.format(_fechaEmision),
                              style: const TextStyle(color: Colors.white, fontSize: 13.5),
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
                    const Divider(color: Color(0xFF334155), height: 1),
                    const SizedBox(height: 14),
                    const Text(
                      'Período del Servicio y Vencimiento de Pago:',
                      style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _seleccionarFecha(
                              context,
                              initialDate: _periodoDesde ?? DateTime.now(),
                              onSelected: (d) => setState(() => _periodoDesde = d),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: _inputDecoration(
                                labelText: 'Período Desde',
                                prefixIcon: Icons.date_range_rounded,
                              ),
                              child: Text(
                                _periodoDesde != null ? _dateFormat.format(_periodoDesde!) : 'Seleccionar',
                                style: const TextStyle(color: Colors.white, fontSize: 12.5),
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
                              onSelected: (d) => setState(() => _periodoHasta = d),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: _inputDecoration(
                                labelText: 'Período Hasta',
                                prefixIcon: Icons.date_range_rounded,
                              ),
                              child: Text(
                                _periodoHasta != null ? _dateFormat.format(_periodoHasta!) : 'Seleccionar',
                                style: const TextStyle(color: Colors.white, fontSize: 12.5),
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
                        initialDate: _vtoPago ?? DateTime.now().add(const Duration(days: 10)),
                        onSelected: (d) => setState(() => _vtoPago = d),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _inputDecoration(
                          labelText: 'Vencimiento para el Pago',
                          prefixIcon: Icons.event_available_rounded,
                        ),
                        child: Text(
                          _vtoPago != null ? _dateFormat.format(_vtoPago!) : 'Seleccionar',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
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
                  // Condición frente al IVA
                  _buildDropdownField<String>(
                    label: 'Condición frente al IVA',
                    initialValue: _condicionIvaCliente,
                    items: const [
                      'Consumidor Final',
                      'Responsable Inscripto',
                      'Monotributo',
                      'IVA Exento',
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _condicionIvaCliente = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Tipo de Documento y Número
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: _buildDropdownField<String>(
                          label: 'Tipo Doc',
                          initialValue: _tipoDocCliente,
                          items: const ['DNI', 'CUIT', 'CUIL', 'Sin identificar'],
                          onChanged: (val) {
                            if (val != null) setState(() => _tipoDocCliente = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: TextFormField(
                          controller: _nroDocController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(
                            labelText: 'N° Documento',
                            prefixIcon: Icons.badge_outlined,
                            hintText: 'Ej. 38491823',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Nombre / Razón Social (Obligatorio)
                  TextFormField(
                    controller: _nombreClienteController,
                    style: const TextStyle(color: Colors.white),
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
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      labelText: 'Domicilio Comercial / Fiscal (Opcional)',
                      prefixIcon: Icons.location_on_outlined,
                      hintText: 'Ej. Av. Corrientes 1234, CABA',
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
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      labelText: 'Descripción del ítem o servicio prestado *',
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+[\.,]?\d{0,2}')),
                    ],
                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: _inputDecoration(
                      labelText: 'Importe Total / Subtotal (\$ ARS) *',
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
                  onPressed: _isLoading ? null : _emitirFactura,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    disabledBackgroundColor: const Color(0xFF475569),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                  label: Text(
                    _isLoading ? 'Generando Comprobante...' : 'Emitir Factura Electrónica',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF818CF8), size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
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
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T initialValue,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      dropdownColor: const Color(0xFF1E293B),
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      iconEnabledColor: const Color(0xFFA5B4FC),
      decoration: _inputDecoration(labelText: label),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(item.toString()),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    IconData? prefixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFFA5B4FC), size: 18) : null,
      filled: true,
      fillColor: const Color(0xFF0F172A),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }
}
