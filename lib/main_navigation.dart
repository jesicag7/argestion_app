import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';
import 'models/factura_model.dart';
import 'historial_facturas_screen.dart';
import 'facturacion_screen.dart';
import 'pagos_screen.dart';
import 'reportes_screen.dart';
import 'ayuda_screen.dart';

class ItemFactura {
  final Key key = UniqueKey();
  final TextEditingController dniController = TextEditingController();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController montoController = TextEditingController();

  void dispose() {
    dniController.dispose();
    nombreController.dispose();
    montoController.dispose();
  }
}

class FacturacionScreen extends StatefulWidget {
  const FacturacionScreen({super.key});
  @override
  State<FacturacionScreen> createState() => _FacturacionScreenState();
}

class _FacturacionScreenState extends State<FacturacionScreen> {
  final _formKey = GlobalKey<FormState>();
  List<ItemFactura> _listaFacturas = [ItemFactura()];
  bool _isLoading = false; // Estado de carga para Firebase

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    for (var item in _listaFacturas) {
      item.dispose();
    }
    super.dispose();
  }

  void _agregarRenglon() {
    setState(() {
      _listaFacturas.add(ItemFactura());
    });
  }

  void _eliminarRenglon(int index) {
    if (_listaFacturas.length > 1) {
      setState(() {
        _listaFacturas[index].dispose();
        _listaFacturas.removeAt(index);
      });
    }
  }

  // 🔥 ¡CONEXIÓN REAL A FIREBASE FIRESTORE!
  Future<void> _emitirLote() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        if (_uid == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Iniciá sesión para poder facturar'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
          return;
        }

        final collection = FirebaseFirestore.instance.collection('facturas');

        // Recorremos las facturas cargadas en la pantalla y las subimos una por una
        for (var item in _listaFacturas) {
          final nuevaFactura = FacturaModel(
            idUsuario: _uid!,
            nroFactura:
                '0001-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
            cuitCliente: item.dniController.text,
            nombreCliente: item.nombreController.text,
            monto: double.parse(item.montoController.text),
            tipoFactura: 'C',
            fechaEmision: DateTime.now(),
          );

          final facturaData = nuevaFactura.toMap();
          facturaData['userId'] = FirebaseAuth.instance.currentUser!.uid;

          // Sube el mapa JSON a Firestore
          await collection.add(facturaData);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Emitidas ${_listaFacturas.length} facturas con éxito!',
            ),
            backgroundColor: const Color(0xFF10B981), // Verde éxito
          ),
        );

        setState(() {
          _formKey.currentState!.reset();
          _listaFacturas = [ItemFactura()];
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al conectar con la base de datos: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🌌 Modo oscuro unificado
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Hacer Facturación',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_isLoading)
              const LinearProgressIndicator(color: Color(0xFF10B981)),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _listaFacturas.length,
                itemBuilder: (context, index) {
                  final item = _listaFacturas[index];

                  return Card(
                    key: item.key,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 16.0),
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.04),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${index + 1}- Factura',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF059669),
                                ),
                              ),
                              if (_listaFacturas.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFDC2626),
                                  ),
                                  onPressed: () => _eliminarRenglon(index),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: item.dniController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                  ),
                                  decoration: _inputStyle('DNI / CUIT'),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Requerido'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: item.nombreController,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                  ),
                                  decoration: _inputStyle('Nombre'),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Requerido'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: item.montoController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                  ),
                                  decoration: _inputStyle('Monto').copyWith(
                                    prefixText: '\$ ',
                                    prefixStyle: const TextStyle(
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Monto';
                                    if (double.tryParse(v) == null) {
                                      return 'Inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _agregarRenglon,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Agregar Factura'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE2E8F0),
                          foregroundColor: const Color(0xFF0F172A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      Text(
                        'Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF059669),
                            Color(0xFF10B981),
                          ], // Degradado verde plano moderno
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _emitirLote,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Hacer Factura',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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

  InputDecoration _inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
}

// --- Arquitectura de Navegación Unificada ---
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex =
      0; // ◄ ¡Corregido! Arranca en Inicio (0) en vez de Facturación (1)

  @override
  Widget build(BuildContext context) {
    // Definimos las pantallas acá adentro para pasarle la función del botón dinámicamente
    final List<Widget> screens = [
      DashboardScreen(
        onNuevaFacturaPressed: () {
          setState(() => _currentIndex = 1);
        },
        onVerHistorialPressed: () {
          // 🚀 Navega a la ventana independiente del Historial
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HistorialFacturasScreen(),
            ),
          );
        },
      ),
      FacturaExpressScreen(
        onVolverAlInicio: () {
          setState(() => _currentIndex = 0);
        },
      ),
      const PagosScreen(),
      const ReportesScreen(),
      const AyudaScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF059669),
          unselectedItemColor: const Color(0xFF64748B),
          selectedIconTheme: const IconThemeData(color: Color(0xFF059669)),
          unselectedIconTheme: const IconThemeData(color: Color(0xFF64748B)),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Facturación',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet),
              label: 'Pagos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Reportes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.help_outline),
              label: 'Ayuda',
            ),
          ],
        ),
      ),
    );
  }
}
