import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class ItemFactura {
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

  void _emitirLote() {
    if (_formKey.currentState!.validate()) {
      int cantidad = _listaFacturas.length;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Procesando lote de $cantidad facturas correctamente!'),
          backgroundColor: const Color(0xFF0052CC),
        ),
      );

      setState(() {
        // Reseteamos el estado visual del formulario anterior
        _formKey.currentState!.reset();
        
        // Reemplazamos la lista directamente por una nueva con un único renglón limpio.
        // Flutter se encarga de redibujar la pantalla de forma segura.
        _listaFacturas = [ItemFactura()];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Hacer Facturación', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0052CC),
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _listaFacturas.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 16.0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
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
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0052CC)),
                              ),
                              if (_listaFacturas.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
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
                                  controller: _listaFacturas[index].dniController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'DNI / CUIT',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _listaFacturas[index].nombreController,
                                  decoration: InputDecoration(
                                    labelText: 'Nombre',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _listaFacturas[index].montoController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Monto',
                                    prefixText: '\$',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Monto';
                                    if (double.tryParse(v) == null) return 'Inválido';
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
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
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
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black87,
                          elevation: 0,
                        ),
                      ),
                      Text(
                        'Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _emitirLote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0052CC),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: const Text('Hacer Factura', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  int _currentIndex = 1;

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