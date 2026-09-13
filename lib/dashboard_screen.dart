import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback? onNuevaFacturaPressed;
  final VoidCallback? onVerHistorialPressed;

  const DashboardScreen({
    super.key,
    this.onNuevaFacturaPressed,
    this.onVerHistorialPressed,
  });

  // Topes anuales de facturación por categoría de monotributo general (AFIP 2026)
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

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

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

  ({double pct, Color color, IconData icono, String mensaje}) _semaforo(double pct) {
    if (pct < 0.70) {
      return (
        pct: pct,
        color: const Color(0xFF10B981),
        icono: Icons.check_circle_outline,
        mensaje: 'Tranquilo, estás lejos del límite',
      );
    }
    if (pct < 0.90) {
      return (
        pct: pct,
        color: const Color(0xFFF59E0B),
        icono: Icons.warning_amber_rounded,
        mensaje: 'Atención, te estás acercando al tope anual',
      );
    }
    return (
      pct: pct,
      color: const Color(0xFFFF3366),
      icono: Icons.error_outline,
      mensaje: 'Cuidado, riesgo de cambiar de categoría o exclusión',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'ARGestión',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: const [
          Icon(Icons.notifications, color: Colors.white),
          SizedBox(width: 15),
          Icon(Icons.person, color: Colors.white),
          SizedBox(width: 15),
        ],
      ),
      body: _uid == null
          ? const Center(
              child: Text('Iniciá sesión para ver tu panel',
                  style: TextStyle(color: Color(0xFF94A3B8))))
          : _buildContenido(context, _uid!),
    );
  }

  Widget _buildContenido(BuildContext context, String uid) {
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

        final tienePerfil = userData != null;
        final categoria = _normalizarCategoria(userData?['categoria'] as String?);
        final tope = _topesMonotributo[categoria] ?? _topesMonotributo['A']!;
        final nombreUsuario = userData?['nombre'] as String? ?? '';

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

            if (facSnap.hasError) {
              return const Center(
                  child: Text('Error al cargar los datos',
                      style: TextStyle(color: Color(0xFFFF3366))));
            }

            final facturasDocs = facSnap.data?.docs;
            final ahora = DateTime.now();
            final facturado12M = _sumarUltimos12Meses(facturasDocs, ahora);

            final saldoDisponible = (tope - facturado12M).clamp(0.0, double.infinity);
            final mesesRestantes = (12 - ahora.month + 1).clamp(1, 12);
            final cupoMensual = saldoDisponible > 0
                ? saldoDisponible / mesesRestantes
                : 0.0;

            final pct = tope > 0 ? facturado12M / tope : 0.0;
            final semaforo = _semaforo(pct);
            final formato =
                NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (nombreUsuario.isNotEmpty) ...[
                    Text('Hola, $nombreUsuario',
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 13)),
                    const SizedBox(height: 8),
                  ],
                  if (!tienePerfil) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFFF59E0B), size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No encontramos tu perfil de monotributo en Firestore '
                              '(usuarios/{uid}). Si ya te registraste, tus datos podrían '
                              'estar guardados con otro usuario. Mientras tanto se usa '
                              'Categoría A por defecto.',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                          child: _buildStatusCard('Categoría Actual', categoria)),
                      const SizedBox(width: 12),
                      Expanded(
                          child:
                              _buildStatusCard('Tope Anual', formato.format(tope))),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ⭐ Tarjeta principal destacada
                  Container(
                    width: double.infinity,
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
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Podés facturar este mes hasta:',
                            style: TextStyle(
                                fontSize: 14, color: Color(0xFFA5B4FC)),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formato.format(cupoMensual.round()),
                              style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Cupo estimado: tu categoría $categoria permite '
                            '${formato.format(tope)} por año.',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 18),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: semaforo.pct.clamp(0.0, 1.0),
                              minHeight: 12,
                              backgroundColor: const Color(0xFF1E293B),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(semaforo.color),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: semaforo.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: semaforo.color.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                Icon(semaforo.icono,
                                    color: semaforo.color, size: 26),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    semaforo.mensaje,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniDato(
                                  'Facturado (12 meses)',
                                  formato.format(facturado12M.round())),
                              _buildMiniDato(
                                  'Saldo anual',
                                  formato.format(saldoDisponible.round())),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ⚡ Acciones rápidas
                  _buildBotonPrimario(
                    icon: Icons.add_circle_outline,
                    text: 'Nueva Factura',
                    onTap: onNuevaFacturaPressed,
                  ),
                  const SizedBox(height: 12),
                  _buildBotonSecundario(
                    icon: Icons.history,
                    text: 'Ver Historial',
                    onTap: onVerHistorialPressed,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMiniDato(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildStatusCard(String title, String value) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(
                    color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonPrimario(
      {required IconData icon, required String text, VoidCallback? onTap}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonSecundario(
      {required IconData icon, required String text, VoidCallback? onTap}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: const Color(0xFF6366F1)),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}