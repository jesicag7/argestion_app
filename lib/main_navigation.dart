import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'models/cliente.dart';
import 'models/factura.dart';
import 'services/firebase_service.dart';

class FacturacionScreen extends StatefulWidget {
  const FacturacionScreen({super.key});

  @override
  State<FacturacionScreen> createState() => _FacturacionScreenState();
}

class _FacturacionScreenState extends State<FacturacionScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isMasivo = false;
  List<Cliente> _clientes = [];
  bool _isLoadingClientes = false;

  bool _isModoNuevoCliente = false;
  final _searchController = TextEditingController();
  final _nuevoNombreController = TextEditingController();
  Cliente? _clienteSeleccionado;
  String? _tipoFactura;
  String? _condicionIva;
  bool _esServicio = true;
  DateTime? _periodoDesde;
  DateTime? _periodoHasta;
  DateTime? _fechaVencimiento;
  String? _nuevoClienteCondicionIva;
  final _itemController = TextEditingController();
  final _montoController = TextEditingController();

  final Set<String> _selectedMasivoIds = {};
  final Map<String, TextEditingController> _montosControllers = {};

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nuevoNombreController.dispose();
    _itemController.dispose();
    _montoController.dispose();
    _limpiarMontosControllers();
    super.dispose();
  }

  Future<void> _cargarClientes() async {
    setState(() => _isLoadingClientes = true);
    try {
      final clientes = await FirebaseService.instance.getClientes();
      if (mounted) {
        setState(() {
          _clientes = clientes;
          _isLoadingClientes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingClientes = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar clientes: $e')),
        );
      }
    }
  }

  List<Cliente> get _resultadosBusqueda {
    final q = _searchController.text.toLowerCase();
    if (q.isEmpty) return [];
    return _clientes
        .where((c) => c.nombre.toLowerCase().contains(q) || c.dni.contains(q))
        .take(10)
        .toList();
  }

  void _toggleMasivo(bool value) {
    setState(() {
      _isMasivo = value;
      if (value) {
        for (final c in _clientes) {
          _montosControllers.putIfAbsent(c.id, () => TextEditingController());
        }
      } else {
        _limpiarMontosControllers();
      }
    });
  }

  void _limpiarMontosControllers() {
    for (final c in _montosControllers.values) {
      c.dispose();
    }
    _montosControllers.clear();
    _selectedMasivoIds.clear();
  }

  Map<String, double> _calcularTotales() {
    final monto = double.tryParse(_montoController.text) ?? 0;
    final subtotal = monto;
    final iva = (_tipoFactura == 'A') ? subtotal * 0.21 : 0.0;
    final total = subtotal + iva;
    return {'subtotal': subtotal, 'iva': iva, 'total': total};
  }

  Future<void> _emitirFactura() async {
    debugPrint('[emitirFactura] INICIO _isMasivo=$_isMasivo');
    if (_isMasivo) {
      debugPrint('[emitirFactura] modo masivo');
      if (_selectedMasivoIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccione al menos un cliente')),
        );
        return;
      }
      int creadas = 0;
      for (final id in _selectedMasivoIds) {
        final montoText = _montosControllers[id]?.text ?? '';
        final monto = double.tryParse(montoText);
        if (monto == null || monto <= 0) continue;
        final cliente = _clientes.firstWhere((c) => c.id == id);
        try {
          await FirebaseService.instance.crearFactura(Factura(
            clienteId: id,
            clienteNombre: cliente.nombre,
            clienteDni: cliente.dni,
            monto: monto,
            fecha: DateTime.now(),
            tipoFactura: 'C',
            condicionIva: 'Consumidor Final',
            itemServicio: '',
            concepto: 'Servicios',
          ));
          creadas++;
        } catch (_) {
          continue;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$creadas factura(s) creada(s) correctamente'),
            backgroundColor: const Color(0xFF0052CC),
          ),
        );
      }
      setState(() {
        for (final c in _montosControllers.values) { c.clear(); }
        _selectedMasivoIds.clear();
      });
    } else {
      debugPrint('[emitirFactura] modo individual - validando formulario');
      debugPrint('[emitirFactura] validando formulario...');
      if (!_formKey.currentState!.validate()) {
        debugPrint('[emitirFactura] ERROR: formulario inválido');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Corrija los errores resaltados en el formulario')),
        );
        return;
      }
      debugPrint('[emitirFactura] validación pasó');
      if (_clienteSeleccionado == null && !_isModoNuevoCliente) {
        debugPrint('[emitirFactura] ERROR: sin cliente');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccione o registre un cliente')),
        );
        return;
      }
      debugPrint('[emitirFactura] cliente OK. _tipoFactura=$_tipoFactura _condicionIva=$_condicionIva');
      if (_tipoFactura == null || _condicionIva == null) {
        debugPrint('[emitirFactura] ERROR: campos fiscales incompletos');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complete todos los campos fiscales')),
        );
        return;
      }

      String clienteId;
      String clienteNombre;
      String clienteDni;

      if (_isModoNuevoCliente) {
        debugPrint('[emitirFactura] modo nuevo cliente');
        final dni = _searchController.text.trim();
        final nombre = _nuevoNombreController.text.trim();
        if (nombre.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ingrese el nombre del nuevo cliente')),
          );
          return;
        }
        if (_nuevoClienteCondicionIva == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seleccione la condición frente al IVA')),
          );
          return;
        }
        _condicionIva = _nuevoClienteCondicionIva;
        debugPrint('[emitirFactura] creando cliente en Firebase...');
        try {
          clienteId = await FirebaseService.instance.crearCliente(
            dni: dni,
            nombre: nombre,
            condicionIva: _condicionIva,
          );
          debugPrint('[emitirFactura] cliente creado: $clienteId');
        } catch (e) {
          debugPrint('[emitirFactura] ERROR al crear cliente: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al registrar cliente: $e')),
            );
          }
          return;
        }
        clienteNombre = nombre;
        clienteDni = dni;
        setState(() {
          _clientes.add(Cliente(id: clienteId, dni: dni, nombre: nombre));
        });
      } else {
        debugPrint('[emitirFactura] modo cliente existente');
        clienteId = _clienteSeleccionado!.id;
        clienteNombre = _clienteSeleccionado!.nombre;
        clienteDni = _clienteSeleccionado!.dni;
      }

      debugPrint('[emitirFactura] guardando factura en Firestore...');
      try {
        await FirebaseService.instance.crearFactura(Factura(
          clienteId: clienteId,
          clienteNombre: clienteNombre,
          clienteDni: clienteDni,
          monto: double.parse(_montoController.text),
          fecha: DateTime.now(),
          tipoFactura: _tipoFactura!,
          condicionIva: _isModoNuevoCliente ? _nuevoClienteCondicionIva! : _condicionIva!,
          itemServicio: _itemController.text,
          concepto: _esServicio ? 'Servicios' : 'Productos',
          periodoDesde: _esServicio ? _periodoDesde : null,
          periodoHasta: _esServicio ? _periodoHasta : null,
          fechaVencimiento: _esServicio ? _fechaVencimiento : null,
        ));
        debugPrint('[emitirFactura] factura guardada OK');
      } catch (e) {
        debugPrint('[emitirFactura] ERROR al guardar factura: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar factura: $e')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Factura creada correctamente'),
            backgroundColor: const Color(0xFF0052CC),
          ),
        );
      }
      setState(() {
        _formKey.currentState!.reset();
        _clienteSeleccionado = null;
        _isModoNuevoCliente = false;
        _searchController.clear();
        _nuevoNombreController.clear();
        _nuevoClienteCondicionIva = null;
        _tipoFactura = null;
        _condicionIva = null;
        _esServicio = true;
        _periodoDesde = null;
        _periodoHasta = null;
        _fechaVencimiento = null;
        _itemController.clear();
        _montoController.clear();
      });
    }
  }

  // ──────────────────────── INDIVIDUAL ────────────────────────

  Widget _buildIndividualContent() {
    final t = _calcularTotales();
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _card(
          child: _buildSearchField(),
        ),
        const SizedBox(height: 12),
        _card(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _tipoFactura,
                decoration: InputDecoration(
                  labelText: 'Tipo de Factura',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'A', child: Text('Factura A')),
                  DropdownMenuItem(value: 'B', child: Text('Factura B')),
                  DropdownMenuItem(value: 'C', child: Text('Factura C')),
                ],
                onChanged: (v) => setState(() => _tipoFactura = v),
                validator: (v) => v == null ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _condicionIva,
                decoration: InputDecoration(
                  labelText: 'Condición de IVA',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'Responsable Inscripto', child: Text('Responsable Inscripto')),
                  DropdownMenuItem(value: 'Consumidor Final', child: Text('Consumidor Final')),
                  DropdownMenuItem(value: 'Monotributista', child: Text('Monotributista')),
                ],
                onChanged: (v) => setState(() => _condicionIva = v),
                validator: (v) => v == null ? 'Requerido' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _esServicio ? 'Servicios' : 'Productos',
                decoration: InputDecoration(
                  labelText: 'Concepto',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'Servicios', child: Text('Servicios')),
                  DropdownMenuItem(value: 'Productos', child: Text('Productos')),
                ],
                onChanged: (v) => setState(() {
                  _esServicio = v == 'Servicios';
                  if (!_esServicio) {
                    _periodoDesde = null;
                    _periodoHasta = null;
                  }
                }),
                validator: (v) => v == null ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _itemController,
                decoration: InputDecoration(
                  labelText: 'Ítem / Servicio',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Monto (\$ARS)',
                  prefixText: '\$',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (double.tryParse(v) == null) return 'Inválido';
                  return null;
                },
              ),
              if (_esServicio) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateField(
                        label: 'Período Desde',
                        value: _periodoDesde,
                        onChanged: (d) => setState(() => _periodoDesde = d),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDateField(
                        label: 'Período Hasta',
                        value: _periodoHasta,
                        onChanged: (d) => setState(() => _periodoHasta = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDateField(
                  label: 'Vto. para el Pago',
                  value: _fechaVencimiento,
                  onChanged: (d) => setState(() => _fechaVencimiento = d),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF0052CC).withValues(alpha: 0.05),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: const Color(0xFF0052CC).withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _totalRow('Subtotal', t['subtotal']!),
                const Divider(),
                _totalRow(
                  'IVA 21%${_tipoFactura == 'A' ? '' : ' (exento)'}',
                  t['iva']!,
                  bold: _tipoFactura == 'A',
                ),
                const Divider(thickness: 2),
                _totalRow('Total', t['total']!, bold: true, large: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: large ? 18 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: large ? const Color(0xFF0052CC) : Colors.black87,
            ),
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: large ? 18 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: large ? const Color(0xFF0052CC) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    if (_clienteSeleccionado != null) {
      return Row(
        children: [
          const Icon(Icons.person, color: Color(0xFF0052CC)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_clienteSeleccionado!.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('CUIT: ${_clienteSeleccionado!.dni}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _clienteSeleccionado = null),
          ),
        ],
      );
    }

    if (_isModoNuevoCliente) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add, color: Color(0xFF0052CC)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nuevo Cliente',
                        style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF0052CC))),
                    Text('CUIT/DNI: ${_searchController.text}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() {
                  _isModoNuevoCliente = false;
                  _searchController.clear();
                  _nuevoNombreController.clear();
                  _nuevoClienteCondicionIva = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nuevoNombreController,
            decoration: InputDecoration(
              labelText: 'Nombre / Razón Social',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _nuevoClienteCondicionIva,
            decoration: InputDecoration(
              labelText: 'Condición frente al IVA',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 'Consumidor Final', child: Text('Consumidor Final')),
              DropdownMenuItem(value: 'IVA Responsable Inscripto', child: Text('IVA Responsable Inscripto')),
              DropdownMenuItem(value: 'Monotributista', child: Text('Monotributista')),
            ],
            onChanged: (v) => setState(() => _nuevoClienteCondicionIva = v),
            validator: (v) => v == null ? 'Requerido' : null,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar Cliente por Nombre o CUIT',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_resultadosBusqueda.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _resultadosBusqueda.length,
              itemBuilder: (_, i) {
                final c = _resultadosBusqueda[i];
                return ListTile(
                  dense: true,
                  title: Text(c.nombre, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(c.dni, style: const TextStyle(fontSize: 12)),
                  onTap: () {
                    setState(() {
                      _clienteSeleccionado = c;
                      _searchController.clear();
                    });
                  },
                );
              },
            ),
          )
        else if (_searchController.text.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.person_add, color: Color(0xFF0052CC)),
              title: Text(
                'Registrar "${_searchController.text}" como nuevo cliente',
                style: const TextStyle(fontSize: 14),
              ),
              onTap: () => setState(() => _isModoNuevoCliente = true),
            ),
          ),
      ],
    );
  }

  // ──────────────────────── MASIVO ────────────────────────

  Future<void> _mostrarDialogoNuevoCliente() async {
    final dniCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Cliente'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: dniCtrl,
                decoration: InputDecoration(
                  labelText: 'CUIT / DNI',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nomCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre / Razón Social',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052CC),
              foregroundColor: Colors.white,
            ),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final dni = dniCtrl.text.trim();
      final nombre = nomCtrl.text.trim();
      final id = await FirebaseService.instance.crearCliente(dni: dni, nombre: nombre);
      final nuevo = Cliente(id: id, dni: dni, nombre: nombre);
      setState(() {
        _clientes.add(nuevo);
        _montosControllers[id] = TextEditingController();
      });
    }

    dniCtrl.dispose();
    nomCtrl.dispose();
  }

  Widget _buildMasivoContent() {
    if (_isLoadingClientes) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _card(
          child: InkWell(
            onTap: _mostrarDialogoNuevoCliente,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: Color(0xFF0052CC)),
                  const SizedBox(width: 8),
                  const Text('Registrar Cliente Rápido',
                      style: TextStyle(
                          color: Color(0xFF0052CC),
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_clientes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(child: Text('No hay clientes disponibles')),
          )
        else
          ..._clientes.map((c) {
            final controller = _montosControllers.putIfAbsent(c.id, () => TextEditingController());
            final isSelected = _selectedMasivoIds.contains(c.id);
            return Card(
              key: ValueKey(c.id),
              color: isSelected
                  ? const Color(0xFF0052CC).withValues(alpha: 0.04)
                  : Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF0052CC).withValues(alpha: 0.4)
                        : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedMasivoIds.add(c.id);
                          } else {
                            _selectedMasivoIds.remove(c.id);
                          }
                        });
                      },
                      activeColor: const Color(0xFF0052CC),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 14)),
                          Text(c.dni,
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Monto',
                          prefixText: '\$',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ──────────────────────── HELPERS ────────────────────────

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value != null
              ? '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
              : 'Seleccionar',
          style: TextStyle(
            color: value != null ? Colors.black87 : Colors.grey,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: child,
      ),
    );
  }

  // ──────────────────────── BUILD ────────────────────────

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedMasivoIds.length;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Hacer Facturación',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0052CC),
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SwitchListTile(
                title: const Text('¿Es una facturación masiva?',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                value: _isMasivo,
                onChanged: _toggleMasivo,
                activeTrackColor: const Color(0xFF0052CC),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade300),
            Expanded(
              child: _isMasivo
                  ? _buildMasivoContent()
                  : _buildIndividualContent(),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, -2))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _emitirFactura,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0052CC),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: Text(
                        _isMasivo
                            ? 'Facturar Seleccionados${selectedCount > 0 ? ' ($selectedCount)' : ''}'
                            : 'Generar y Enviar Factura',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (!_isMasivo)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PagosScreen extends StatelessWidget {
  const PagosScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Pantalla de Pagos')));
  }
}

class ReportesScreen extends StatelessWidget {
  const ReportesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Pantalla de Reportes')));
  }
}

class AyudaScreen extends StatelessWidget {
  const AyudaScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Pantalla de Ayuda')));
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const FacturacionScreen(),
    const PagosScreen(),
    const ReportesScreen(),
    const AyudaScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0052CC),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Facturación'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Pagos'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reportes'),
          BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: 'Ayuda'),
        ],
      ),
    );
  }
}