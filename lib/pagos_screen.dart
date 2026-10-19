import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/monotributo_category.dart';
import 'models/pagos_calculator.dart';

class PagosScreen extends StatelessWidget {
  const PagosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _buildScaffold(
        context,
        const Center(child: Text('Iniciá sesión para consultar tus pagos.')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .snapshots(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.hasError) {
          return _buildScaffold(
            context,
            _mensajeError(
              'No se pudo cargar tu perfil: ${profileSnapshot.error}',
            ),
          );
        }

        final profile = profileSnapshot.data?.data() ?? const {};
        final category = MonotributoCategory.normalizarCategoria(
          profile['categoria']?.toString(),
        );
        final cuit = profile['cuit']?.toString();

        return _buildScaffold(
          context,
          _buildBody(context, user.uid, category, cuit),
        );
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Widget body) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Estado de Cuenta y Vencimientos',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 40,
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    String uid,
    String category,
    String? cuit,
  ) {
    final now = DateTime.now();
    final dueDate = PagosCalculator.proximoVencimiento(now);
    final monthlyAmount = PagosCalculator.cuotasMensualesServicios[category]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTarjetaPrincipal(
          context,
          now: now,
          dueDate: dueDate,
          category: category,
          amount: monthlyAmount,
          cuit: cuit,
        ),
        const SizedBox(height: 16),
        if (now.month == DateTime.january || now.month == DateTime.july) ...[
          _buildAvisoRecategorizacion(),
          const SizedBox(height: 16),
        ],
        _buildAvisoDebitoAutomatico(dueDate),
        const SizedBox(height: 24),
        const Text(
          'Historial de pagos',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('pagos')
              .where('userId', isEqualTo: uid)
              .snapshots(),
          builder: (context, paymentsSnapshot) {
            if (paymentsSnapshot.hasError) {
              return _mensajeError(
                'No se pudo cargar el historial: ${paymentsSnapshot.error}',
              );
            }
            if (paymentsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final records = <String, Map<String, dynamic>>{};
            for (final document in paymentsSnapshot.data?.docs ?? []) {
              final data = document.data();
              final period = _periodoDelRegistro(data);
              if (period != null) records[period] = data;
            }

            return Column(
              children: List.generate(6, (index) {
                final period = DateTime(now.year, now.month - index - 1, 1);
                final key = PagosCalculator.periodoKey(period);
                final record = records[key];
                final paid = record != null && _registroPagado(record);
                final amount = _importeRegistro(record) ?? monthlyAmount;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildComprobante(
                    periodo: PagosCalculator.periodo(period),
                    monto: PagosCalculator.formatoImporte(amount),
                    pagado: paid,
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 4),
        const Text(
          'Los meses sin registro aparecen como pendientes. El estado se basa '
          'en los registros de la app; confirmá pagos y montos en ARCA.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildTarjetaPrincipal(
    BuildContext context, {
    required DateTime now,
    required DateTime dueDate,
    required String category,
    required double amount,
    required String? cuit,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF059669).withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '🟡 Período ${PagosCalculator.periodo(now)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              PagosCalculator.formatoImporte(amount),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cuota integrada Monotributo Cat. $category',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE0E7FF), fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Estimación para servicios • valores ARCA desde agosto de 2026',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 10),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event, color: Color(0xFFFDE68A), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Próximo vencimiento: ${_formatoFecha(dueDate)}',
                      style: const TextStyle(
                        color: Color(0xFFFDE68A),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            _buildBotonCopiar(context, cuit: cuit, period: now),
            const SizedBox(height: 10),
            _buildBotonPagar(context, cuit: cuit),
            const SizedBox(height: 8),
            const Text(
              'La referencia copiada no es un VEP oficial. Generá el VEP desde ARCA.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonCopiar(
    BuildContext context, {
    required String? cuit,
    required DateTime period,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF064E3B), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton(
          onPressed: () =>
              _copiarReferencia(context, cuit: cuit, period: period),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.copy, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Copiar Código de Pago / VEP',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotonPagar(BuildContext context, {required String? cuit}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: ElevatedButton(
          onPressed: () => _mostrarOpcionesPago(context, cuit: cuit),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: const Color(0xFF059669),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.payment, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Pagar con MP / Home Banking',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvisoRecategorizacion() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: const Row(
        children: [
          Icon(Icons.campaign, color: Color(0xFFB45309)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Período oficial de recategorización semestral abierto',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvisoDebitoAutomatico(DateTime dueDate) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
      child: Row(
        children: [
          const Icon(Icons.account_balance, color: Color(0xFF64748B), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Si estás adherido al débito automático, verificá la fecha de '
              'acreditación del pago: ${_formatoFecha(dueDate)}.',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComprobante({
    required String periodo,
    required String monto,
    required bool pagado,
  }) {
    final statusColor = pagado
        ? const Color(0xFF10B981)
        : const Color(0xFFD97706);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Color(0xFF10B981),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  periodo,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  monto,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            pagado ? 'Pagado' : 'Pendiente',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mensajeError(String mensaje) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        mensaje,
        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
      ),
    );
  }

  Future<void> _copiarReferencia(
    BuildContext context, {
    required String? cuit,
    required DateTime period,
  }) async {
    final code = PagosCalculator.referenciaPago(cuit: cuit, period: period);
    try {
      await Clipboard.setData(ClipboardData(text: code));
    } on PlatformException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo copiar la referencia: ${error.message}'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código de pago copiado: $code'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  Future<void> _mostrarOpcionesPago(
    BuildContext context, {
    required String? cuit,
  }) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Generar VEP en ARCA'),
        content: Text(
          'La app no puede emitir un VEP oficial. Generá el VEP en el servicio '
          'Monotributo de ARCA y luego elegí Mercado Pago o tu home banking '
          'para abonarlo.${cuit == null || cuit.trim().isEmpty ? '' : '\n\nCUIT registrado: $cuit'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: const Text('Cancelar'),
          ),
          if (cuit != null && cuit.trim().isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'copy'),
              child: const Text('Copiar CUIT'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'arca'),
            child: const Text('Abrir ARCA'),
          ),
        ],
      ),
    );

    if (!context.mounted || action == null || action == 'cancel') return;
    if (action == 'copy' && cuit != null) {
      try {
        await Clipboard.setData(ClipboardData(text: cuit));
      } on PlatformException catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo copiar el CUIT: ${error.message}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CUIT copiado al portapapeles')),
        );
      }
      return;
    }

    try {
      final opened = await launchUrl(
        Uri.parse('https://www.arca.gob.ar/monotributo/'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el portal de ARCA.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } on PlatformException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir ARCA: ${error.message}'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  String? _periodoDelRegistro(Map<String, dynamic> data) {
    final periodValue = data['periodo'] ?? data['period'];
    if (periodValue is String) {
      final match = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(periodValue);
      if (match != null) {
        final year = int.tryParse(match.group(1)!);
        final month = int.tryParse(match.group(2)!);
        if (year != null && month != null && month >= 1 && month <= 12) {
          return PagosCalculator.periodoKey(DateTime(year, month));
        }
      }
      final parsedPeriod = _parsePeriodoEnEspanol(periodValue);
      if (parsedPeriod != null) {
        return PagosCalculator.periodoKey(parsedPeriod);
      }
    }

    final year = int.tryParse('${data['anio'] ?? data['año'] ?? ''}');
    final month = int.tryParse('${data['mes'] ?? ''}');
    if (year != null && month != null && month >= 1 && month <= 12) {
      return PagosCalculator.periodoKey(DateTime(year, month));
    }

    for (final key in ['fecha', 'fechaPago', 'createdAt']) {
      final value = data[key];
      if (value is Timestamp) {
        return PagosCalculator.periodoKey(value.toDate());
      }
      if (value is DateTime) {
        return PagosCalculator.periodoKey(value);
      }
      if (value is String) {
        final date = DateTime.tryParse(value);
        if (date != null) return PagosCalculator.periodoKey(date);
      }
    }
    return null;
  }

  DateTime? _parsePeriodoEnEspanol(String value) {
    final parts = value.trim().toLowerCase().split(RegExp(r'\s+'));
    if (parts.length != 2) return null;
    const months = {
      'enero': 1,
      'febrero': 2,
      'marzo': 3,
      'abril': 4,
      'mayo': 5,
      'junio': 6,
      'julio': 7,
      'agosto': 8,
      'septiembre': 9,
      'setiembre': 9,
      'octubre': 10,
      'noviembre': 11,
      'diciembre': 12,
    };
    final month = months[parts.first];
    final year = int.tryParse(parts.last);
    if (month == null || year == null) return null;
    return DateTime(year, month);
  }

  bool _registroPagado(Map<String, dynamic> data) {
    final status = data['estado']?.toString().toLowerCase().trim();
    return data['pagado'] == true ||
        status == 'pagado' ||
        status == 'pagada' ||
        status == 'paid';
  }

  double? _importeRegistro(Map<String, dynamic>? data) {
    final amount = data?['monto'] ?? data?['importe'];
    if (amount is num) return amount.toDouble();
    if (amount is String) {
      final normalized = amount.replaceAll(RegExp(r'[^\d,.-]'), '');
      final parseable = normalized.contains(',')
          ? normalized.replaceAll('.', '').replaceAll(',', '.')
          : normalized;
      return double.tryParse(parseable);
    }
    return null;
  }

  String _formatoFecha(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
