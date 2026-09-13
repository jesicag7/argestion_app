import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'models/gasto_model.dart';

class EgresosScreen extends StatefulWidget {
  const EgresosScreen({super.key});
  @override
  State<EgresosScreen> createState() => _EgresosScreenState();
}

class _EgresosScreenState extends State<EgresosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _conceptoController = TextEditingController();
  final _montoController = TextEditingController();
  String _categoriaSeleccionada = 'Costo Fijo';
  DateTime _fechaSeleccionada = DateTime.now();
  bool _isLoading = false;
  bool _mostrarFormulario = false;

  final List<String> _categorias = [
    'Costo Fijo',
    'Mercadería/Insumos',
    'Logística/Envíos',
    'Impuestos/Servicios',
  ];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _conceptoController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1E293B), // ignore: deprecated_member_use
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _fechaSeleccionada = picked);
    }
  }

  Future<void> _guardarGasto() async {
    if (_uid == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final nuevoGasto = GastoModel(
        idUsuario: _uid!,
        monto: double.parse(_montoController.text.trim()),
        concepto: _conceptoController.text.trim(),
        categoriaGasto: _categoriaSeleccionada,
        fechaGasto: _fechaSeleccionada,
      );

      await FirebaseFirestore.instance.collection('gastos').add(nuevoGasto.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gasto registrado con éxito'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _conceptoController.clear();
        _montoController.clear();
        setState(() {
          _fechaSeleccionada = DateTime.now();
          _categoriaSeleccionada = 'Costo Fijo';
          _mostrarFormulario = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: const Color(0xFFFF3366),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarGasto(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Eliminar gasto', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de que querés eliminar este registro?',
            style: TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Color(0xFFFF3366))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('gastos').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gasto eliminado'),
            backgroundColor: Color(0xFFFF3366),
          ),
        );
      }
    }
  }

  Stream<double> _streamTotalMes() {
    if (_uid == null) return const Stream.empty();

    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);
    final finMes = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return FirebaseFirestore.instance
        .collection('gastos')
        .where('id_usuario', isEqualTo: _uid!)
        .where('fecha_gasto', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
        .where('fecha_gasto', isLessThanOrEqualTo: Timestamp.fromDate(finMes))
        .snapshots()
        .map((snapshot) {
      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['monto'] ?? 0).toDouble();
      }
      return total;
    });
  }

  Color _colorCategoria(String cat) {
    switch (cat) {
      case 'Costo Fijo':
        return const Color(0xFF6366F1);
      case 'Mercadería/Insumos':
        return const Color(0xFF10B981);
      case 'Logística/Envíos':
        return const Color(0xFFF59E0B);
      case 'Impuestos/Servicios':
        return const Color(0xFFFF3366);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatoMoneda = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Gestión de Egresos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              _mostrarFormulario ? Icons.close : Icons.add_circle_outline,
              color: const Color(0xFF10B981),
            ),
            onPressed: () => setState(() => _mostrarFormulario = !_mostrarFormulario),
          ),
        ],
      ),
      body: _uid == null
          ? const Center(
              child: Text('Iniciá sesión para ver tus egresos',
                  style: TextStyle(color: Color(0xFF94A3B8))))
          : Column(
              children: [
                if (_isLoading) const LinearProgressIndicator(color: Color(0xFF10B981)),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _mostrarFormulario
                      ? _buildFormulario()
                      : const SizedBox.shrink(),
                ),
                _buildTotalCard(formatoMoneda),
                Expanded(child: _buildListaGastos(formatoMoneda)),
              ],
            ),
    );
  }

  Widget _buildFormulario() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nuevo Egreso',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _conceptoController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputStyle('Concepto / Descripción', Icons.description_outlined),
              validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _montoController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputStyle('Monto (\$)', Icons.attach_money)
                        .copyWith(
                      prefixText: '\$ ',
                      prefixStyle: const TextStyle(color: Colors.white),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Monto';
                      if (double.tryParse(v) == null) return 'Inválido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    initialValue: _categoriaSeleccionada,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _inputStyle('Tipo', Icons.category_outlined),
                    items: _categorias
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _categoriaSeleccionada = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _seleccionarFecha,
              child: InputDecorator(
                decoration: _inputStyle('Fecha', Icons.calendar_today_outlined),
                child: Text(
                  DateFormat('dd/MM/yyyy').format(_fechaSeleccionada),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardarGasto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Guardar Egreso',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard(NumberFormat formatoMoneda) {
    return StreamBuilder<double>(
      stream: _streamTotalMes(),
      builder: (context, snapshot) {
        final total = snapshot.data ?? 0;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet,
                    color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Gastos del Mes',
                      style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(formatoMoneda.format(total),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListaGastos(NumberFormat formatoMoneda) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gastos')
          .where('id_usuario', isEqualTo: _uid!)
          .orderBy('fecha_gasto', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long, size: 48, color: const Color(0xFF334155)),
                const SizedBox(height: 12),
                const Text('No hay gastos registrados',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
                const SizedBox(height: 4),
                const Text('Tocá + para agregar uno',
                    style: TextStyle(color: Color(0xFF475569), fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final gasto = GastoModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            final color = _colorCategoria(gasto.categoriaGasto);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                title: Text(gasto.concepto,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                subtitle: Text(
                  '${gasto.categoriaGasto}  •  ${DateFormat('dd/MM/yyyy').format(gasto.fechaGasto)}',
                  style:
                      const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatoMoneda.format(gasto.monto),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _eliminarGasto(doc.id),
                      child: const Icon(Icons.delete_outline,
                          color: Color(0xFFFF3366), size: 20),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF475569)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFFF3366)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFFF3366), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
    );
  }
}