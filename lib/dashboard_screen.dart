import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';

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
    if (_uid == null) {
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
        ),
        body: const Center(
          child: Text('Iniciá sesión para ver tu panel',
              style: TextStyle(color: Color(0xFF94A3B8))),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_uid)
          .snapshots(),
      builder: (context, userSnap) {
        Map<String, dynamic>? userData;
        try {
          userData = userSnap.data?.data() as Map<String, dynamic>?;
        } catch (_) {
          userData = null;
        }

        final authUser = FirebaseAuth.instance.currentUser;
        final firestoreName = userData?['nombre'] as String?;
        final authName = authUser?.displayName;
        final resolvedName = (firestoreName != null && firestoreName.trim().isNotEmpty)
            ? firestoreName.trim()
            : ((authName != null && authName.trim().isNotEmpty)
                ? authName.trim()
                : 'Usuario');
        final email =
            authUser?.email ?? (userData?['email'] as String? ?? 'Sin correo');
        final cuit = userData?['cuit'] as String?;
        final categoria =
            _normalizarCategoria(userData?['categoria'] as String?);
        final primerNombre = resolvedName.split(' ').first;
        final inicial =
            resolvedName.isNotEmpty ? resolvedName[0].toUpperCase() : 'U';

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            title: const Text(
              'ARGestión',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 24),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                tooltip: 'Notificaciones',
                onPressed: () => _mostrarNotificaciones(context),
              ),
              const SizedBox(width: 4),
              _buildMenuUsuario(
                context: context,
                inicial: inicial,
                primerNombre: primerNombre,
                resolvedName: resolvedName,
                email: email,
                cuit: cuit,
                categoria: categoria,
              ),
            ],
          ),
          body: _buildFacturasBody(
            context: context,
            uid: _uid!,
            userData: userData,
            categoria: categoria,
          ),
        );
      },
    );
  }

  Widget _buildMenuUsuario({
    required BuildContext context,
    required String inicial,
    required String primerNombre,
    required String resolvedName,
    required String email,
    String? cuit,
    required String categoria,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Menú de usuario',
      color: const Color(0xFF1E293B),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      offset: const Offset(0, 52),
      onSelected: (value) {
        if (value == 'perfil') {
          _mostrarPerfil(context);
        } else if (value == 'cerrar_sesion') {
          _cerrarSesion(context);
        }
      },
      itemBuilder: (context) => [
        // Header no cliqueable con avatar, nombre, CUIT/email y badge
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        inicial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resolvedName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (cuit != null && cuit.trim().isNotEmpty)
                              ? 'CUIT: ${cuit.trim()} • $email'
                              : email,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cat. $categoria - Al día',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<String>(
          value: 'perfil',
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.person_rounded, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mi Perfil',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      'Datos fiscales y categoría de monotributo',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<String>(
          value: 'cerrar_sesion',
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFFF3366), size: 20),
              SizedBox(width: 12),
              Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Color(0xFFFF3366),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  inicial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                primerNombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF94A3B8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacturasBody({
    required BuildContext context,
    required String uid,
    required Map<String, dynamic>? userData,
    required String categoria,
  }) {
    final tienePerfil = userData != null;
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
                  // Saludo de bienvenida con estilo y nombre del usuario
                  _buildSaludoBienvenida(userData),
                  const SizedBox(height: 16),
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

  Widget _buildSaludoBienvenida(Map<String, dynamic>? userData) {
    final authUser = FirebaseAuth.instance.currentUser;
    final firestoreName = userData?['nombre'] as String?;
    final authName = authUser?.displayName;

    String resolvedName = 'Usuario';
    if (firestoreName != null && firestoreName.trim().isNotEmpty) {
      resolvedName = firestoreName.trim();
    } else if (authName != null && authName.trim().isNotEmpty) {
      resolvedName = authName.trim();
    }

    final ahora = DateTime.now();
    final meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final mesActual = meses[ahora.month - 1];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 460;

        final etiquetaFiscal = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Estado: Al día',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Período $mesActual ${ahora.year}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.waving_hand_rounded,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '¡Bienvenido a ARGestión, $resolvedName!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Panel de control fiscal y estado de monotributo',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    etiquetaFiscal,
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.waving_hand_rounded,
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Bienvenido a ARGestión, $resolvedName!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Panel de control fiscal y estado de monotributo',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    etiquetaFiscal,
                  ],
                ),
        );
      },
    );
  }

  void _mostrarPerfil(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final email = user?.email ?? 'Sin correo registrado';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StreamBuilder<DocumentSnapshot>(
          stream: uid != null
              ? FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots()
              : null,
          builder: (context, snapshot) {
            Map<String, dynamic>? data;
            if (snapshot.hasData && snapshot.data!.exists) {
              try {
                data = snapshot.data!.data() as Map<String, dynamic>?;
              } catch (_) {
                data = null;
              }
            }

            final firestoreName = data?['nombre'] as String?;
            final authName = user?.displayName;
            final nombre = (firestoreName != null && firestoreName.trim().isNotEmpty)
                ? firestoreName.trim()
                : ((authName != null && authName.trim().isNotEmpty)
                    ? authName.trim()
                    : 'Usuario');

            final categoria = _normalizarCategoria(data?['categoria'] as String?);
            final cuit = data?['cuit'] as String? ?? 'No registrado';

            return Dialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF10B981)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        children: [
                          _buildPerfilRow(
                            icon: Icons.category_rounded,
                            iconColor: const Color(0xFF10B981),
                            label: 'Categoría Monotributo',
                            value: 'Categoría $categoria',
                          ),
                          const Divider(color: Color(0xFF1E293B), height: 16),
                          _buildPerfilRow(
                            icon: Icons.badge_outlined,
                            iconColor: const Color(0xFF6366F1),
                            label: 'CUIT / Identificación',
                            value: cuit,
                          ),
                          const Divider(color: Color(0xFF1E293B), height: 16),
                          _buildPerfilRow(
                            icon: Icons.mail_outline_rounded,
                            iconColor: const Color(0xFF38BDF8),
                            label: 'Correo Electrónico',
                            value: email,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF334155),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cerrar',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
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

  Widget _buildPerfilRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFFF3366), size: 22),
            SizedBox(width: 10),
            Text('Cerrar Sesión',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas salir de tu cuenta?',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Salir',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _mostrarNotificaciones(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Notificaciones y Avisos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildNotificationItem(
                  icon: Icons.calendar_month_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  titulo: 'Vencimiento Monotributo',
                  descripcion:
                      'La cuota mensual vence el día 20 de cada mes. Podés generar tu VEP o revisar el estado en la pestaña Pagos.',
                ),
                const SizedBox(height: 10),
                _buildNotificationItem(
                  icon: Icons.sync_alt_rounded,
                  iconColor: const Color(0xFF6366F1),
                  titulo: 'Recategorización Semestral',
                  descripcion:
                      'ARCA evalúa los ingresos en enero y julio. Verificá tu semáforo fiscal en Reportes.',
                ),
                const SizedBox(height: 10),
                _buildNotificationItem(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF10B981),
                  titulo: 'Estado de cuenta al día',
                  descripcion:
                      'No tenés alertas urgentes de exclusión en este momento.',
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Entendido',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconColor,
    required String titulo,
    required String descripcion,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  descripcion,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}