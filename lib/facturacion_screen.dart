import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/factura_model.dart';

class FacturaExpressScreen extends StatefulWidget {
  final VoidCallback? onVolverAlInicio;

  const FacturaExpressScreen({super.key, this.onVolverAlInicio});

  @override
  State<FacturaExpressScreen> createState() => _FacturaExpressScreenState();
}

class _FacturaExpressScreenState extends State<FacturaExpressScreen> {
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

  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _cuitController = TextEditingController();
  final TextEditingController _conceptoController =
      TextEditingController(text: 'Servicios Profesionales / Venta');

  bool _isLoading = false;
  bool _conCuit = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _montoController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _montoController.dispose();
    _cuitController.dispose();
    _conceptoController.dispose();
    super.dispose();
  }

  String _normalizarCategoria(String? valor) {
    if (valor == null || valor.trim().isEmpty) return 'A';
    final limpio = valor.trim().replaceAll(
      RegExp(r'^(Categoria|Categoría)\s*', caseSensitive: false),
      '',
    );
    return limpio.toUpperCase();
  }

  DateTime? _parseFecha(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  double _sumarUltimos12Meses(List<QueryDocumentSnapshot<Object?>>? docs, DateTime ahora) {
    if (docs == null) return 0;
    final limite = DateTime(ahora.year, ahora.month - 11, 1);
    double total = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final fecha = _parseFecha(data['fecha_emision']);
      if (fecha != null && !fecha.isBefore(limite) && !fecha.isAfter(ahora)) {
        total += (data['monto'] ?? 0).toDouble();
      }
    }
    return total;
  }

  double _parseMonto(String raw) {
    var t = raw.trim();
    t = t.replaceAll(RegExp(r'\.(?=\d{3}(\.\d{3})*($|[.,]))'), '');
    t = t.replaceAll(',', '.');
    return double.tryParse(t) ?? 0;
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _emitirFactura() async {
    final monto = _parseMonto(_montoController.text);

    if (monto <= 0) {
      _mostrarError('Ingresá un monto mayor a cero para emitir la factura.');
      return;
    }
    if (_conCuit) {
      final cuit = _cuitController.text.trim();
      if (cuit.isEmpty) {
        _mostrarError('Ingresá el CUIT / DNI del destinatario.');
        return;
      }
      if (cuit.length < 6) {
        _mostrarError('El CUIT / DNI debe tener al menos 6 dígitos.');
        return;
      }
    }
    if (_uid == null) {
      _mostrarError('Iniciá sesión para poder facturar.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fecha = DateTime.now();
      final nuevaFactura = FacturaModel(
        idUsuario: _uid!,
        nroFactura:
            '0001-${fecha.millisecondsSinceEpoch.toString().substring(7)}',
        cuitCliente: _conCuit ? _cuitController.text.trim() : 'Consumidor Final',
        nombreCliente: _conCuit ? '' : 'Consumidor Final',
        monto: monto,
        tipoFactura: 'C',
        fechaEmision: fecha,
      );

      await FirebaseFirestore.instance
          .collection('facturas')
          .add(nuevaFactura.toMap());

      if (!mounted) return;

      final formato =
          NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
      final resumen = 'Factura emitida en ARGestión\n'
          'Monto: ${formato.format(monto.round())}\n'
          'Destinatario: ${_conCuit ? nuevaFactura.cuitCliente : 'Consumidor Final'}\n'
          'Concepto: ${_conceptoController.text.trim()}\n'
          'Fecha: ${fecha.day}/${fecha.month}/${fecha.year}';

      setState(() {
        _montoController.clear();
        _cuitController.clear();
      });

      await mostrarExito(resumen);
    } catch (e) {
      _mostrarError('No se pudo emitir la factura. Verificá tu conexión e intentá de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> mostrarExito(String resumen) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 72),
            const SizedBox(height: 12),
            const Text(
              '¡Factura emitida!',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              resumen,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), height: 1.5),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _compartirWhatsApp(resumen);
            },
            icon: const Icon(Icons.share, color: Color(0xFF25D366)),
            label: const Text(
              'Compartir por WhatsApp',
              style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onVolverAlInicio?.call();
            },
            icon: const Icon(Icons.home_outlined),
            label: const Text('Volver al Inicio', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _compartirWhatsApp(String resumen) async {
    try {
      final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(resumen)}');
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok) _mostrarError('No se pudo abrir WhatsApp.');
    } catch (_) {
      _mostrarError('No se pudo abrir WhatsApp.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Factura Express',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _uid == null
          ? const Center(
              child: Text('Iniciá sesión para facturar',
                  style: TextStyle(color: Color(0xFF94A3B8))))
          : _buildContenido(context),
    );
  }

  Widget _buildContenido(BuildContext context) {
    final uid = _uid!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
        }

        Map<String, dynamic>? userData;
        try {
          userData = userSnap.data?.data() as Map<String, dynamic>?;
        } catch (_) {
          userData = null;
        }
        final categoria = _normalizarCategoria(userData?['categoria'] as String?);
        final tope = _topesMonotributo[categoria] ?? _topesMonotributo['A']!;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('facturas')
              .where('id_usuario', isEqualTo: uid)
              .snapshots(),
          builder: (context, facSnap) {
            if (facSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF10B981)));
            }

            final ahora = DateTime.now();
            final facturado = _sumarUltimos12Meses(facSnap.data?.docs, ahora);
            final saldo = (tope - facturado).clamp(0.0, double.infinity);
            final mesesRestantes = (12 - ahora.month + 1).clamp(1, 12);
            final cupo = saldo / mesesRestantes;
            final monto = _parseMonto(_montoController.text);
            final pctConsumo = cupo > 0 ? monto / cupo : 0.0;
            final restante = (cupo - monto).clamp(0.0, double.infinity);
            final colorConsumo =
                pctConsumo < 0.7
                    ? const Color(0xFF10B981)
                    : pctConsumo < 0.9
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFFF3366);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 💰 Monto grande
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF4338CA).withValues(alpha: 0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const Text(
                            'Importe',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFFA5B4FC)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _montoController,
                            autofocus: true,
                            enabled: !_isLoading,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                            ],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 46,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                  fontSize: 46,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569)),
                              prefixText: '\$  ',
                              prefixStyle: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              border: InputBorder.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 📊 Simulador de impacto en vivo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: monto <= 0
                        ? const Text(
                            'Ingresá un monto para ver el impacto en tu cupo disponible.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Consumís el ${(pctConsumo * 100).clamp(0, 100).toStringAsFixed(1)}% de tu cupo disponible de este mes',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: pctConsumo.clamp(0.0, 1.0),
                                  minHeight: 10,
                                  backgroundColor: const Color(0xFF0F172A),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(colorConsumo),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildDatoSim('Cupo del mes', cupo),
                                  _buildDatoSim('Queda si emitís', restante),
                                ],
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  // 👤 Destinatario
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Destinatario',
                          style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'cf',
                                label: Text('Consumidor Final'),
                                icon: Icon(Icons.person_outline),
                              ),
                              ButtonSegment(
                                value: 'cuit',
                                label: Text('Con CUIT / DNI'),
                                icon: Icon(Icons.badge_outlined),
                              ),
                            ],
                            selected: {_conCuit ? 'cuit' : 'cf'},
                            onSelectionChanged: _isLoading
                                ? null
                                : (sel) {
                                    setState(() {
                                      _conCuit = sel.first == 'cuit';
                                    });
                                  },
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.resolveWith((states) {
                                return states.contains(WidgetState.selected)
                                    ? const Color(0xFF6366F1)
                                    : const Color(0xFF0F172A);
                              }),
                              foregroundColor:
                                  WidgetStateProperty.resolveWith((states) {
                                return states.contains(WidgetState.selected)
                                    ? Colors.white
                                    : const Color(0xFF94A3B8);
                              }),
                              side: WidgetStatePropertyAll(
                                  const BorderSide(color: Color(0xFF475569))),
                            ),
                          ),
                        ),
                        if (_conCuit) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _cuitController,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'CUIT / DNI (solo números)',
                              labelStyle: const TextStyle(
                                  color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.badge_outlined,
                                  color: Color(0xFF64748B)),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                    color: Color(0xFF475569)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                    color: Color(0xFF6366F1), width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 📝 Concepto
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: TextFormField(
                      controller: _conceptoController,
                      enabled: !_isLoading,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Concepto',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.description_outlined,
                            color: Color(0xFF64748B)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF475569)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Color(0xFF6366F1), width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 🚀 Botón principal
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _emitirFactura,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Emitir Factura',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDatoSim(String title, double value) {
    final formato =
        NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(formato.format(value.round()),
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}