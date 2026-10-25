import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'historial_facturas_screen.dart';
import 'facturacion_screen.dart';
import 'pagos_screen.dart';
import 'reportes_screen.dart';
import 'ayuda_screen.dart';

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
