import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/monotributo_category.dart';
import 'services/csv_exporter.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  String _formatCurrency(num value) {
    final roundedValue = value.round();
    final formatted = roundedValue.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match.group(1)}.',
    );

    return '\$$formatted';
  }

  String _formatDate(dynamic value) {
    final fecha = _parseDate(value);

    if (fecha == null) {
      return '';
    }

    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  String _monthLabel(DateTime date) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isWithinPeriod(DateTime? date, DateTime start, DateTime end) =>
      date != null && !date.isBefore(start) && date.isBefore(end);

  bool _isCobrada(Map<String, dynamic> data) {
    final estado =
        (data['estadoCobro'] ?? data['estado_cobro'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final cobrada =
        data['cobrada']?.toString().trim().toLowerCase();
    return estado == 'cobrada' || cobrada == 'true' || cobrada == 'cobrada';
  }

  bool _esNotaCredito(Map<String, dynamic> data) {
    final tipo = (data['tipo_comprobante'] ?? data['tipo_factura'] ?? '')
        .toString()
        .toLowerCase();
    return data['esNotaCredito'] == true ||
        data['es_nota_credito'] == true ||
        tipo.startsWith('nota de crédito');
  }

  bool _estaAnulada(Map<String, dynamic> data) =>
      data['anulada'] == true || data['es_anulada'] == true;

  double _impactoFiscal(Map<String, dynamic> data) =>
      MonotributoCategory.impactoFiscal(
        monto: _parseAmount(data['monto']),
        esNotaCredito: _esNotaCredito(data),
        anulada: _estaAnulada(data),
        tieneNotaCreditoAsociada:
            (data['anuladaPorNcId'] ?? data['anulada_por_nc_id'])
                ?.toString()
                .isNotEmpty ==
            true,
      );

  double _sumarFacturadoUltimos12Meses(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    DateTime now,
  ) {
    final start = DateTime(now.year, now.month - 11, 1);
    var total = 0.0;
    for (final doc in docs) {
      final data = doc.data();
      final rawDate =
          data['fecha_emision'] ??
          data['fechaEmision'] ??
          data['fecha'] ??
          data['created_at'] ??
          data['createdAt'];
      final invoiceDate = _parseDate(rawDate);
      if (invoiceDate == null ||
          invoiceDate.isBefore(start) ||
          invoiceDate.isAfter(now)) {
        continue;
      }
      total += _impactoFiscal(data);
    }
    return total;
  }

  String _conceptoFromData(Map<String, dynamic> data) {
    return (data['concepto'] ??
            data['detalle'] ??
            data['descripcion'] ??
            data['observacion'] ??
            'Sin detalle')
        .toString();
  }

  String _buildCsvContent(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> gastosDocs,
    double totalFacturado,
    int cantidadFacturas,
    double ingresosCobrados,
    double totalGastos,
    double gananciaNeta,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Tipo,Fecha,Concepto/Detalle,Estado,Monto');

    for (final doc in docs) {
      final data = doc.data();
      final monto = _impactoFiscal(data);

      final fecha = _formatDate(
        data['fecha_emision'] ??
            data['fechaEmision'] ??
            data['fecha'] ??
            data['created_at'] ??
            data['createdAt'],
      );

      final concepto = _conceptoFromData(data).replaceAll('"', '""');
      final tipo = _esNotaCredito(data) ? 'Nota de Crédito C' : 'Factura';
      final estado = _estaAnulada(data)
          ? 'Anulada por Nota de Crédito'
          : _isCobrada(data)
          ? 'Cobrada'
          : 'Pendiente';

      buffer.writeln(
        '$tipo,$fecha,"$concepto",$estado,${monto.toStringAsFixed(2)}',
      );
    }

    for (final doc in gastosDocs) {
      final data = doc.data();
      final fecha = _formatDate(data['fecha_gasto']);
      final concepto = (data['concepto'] ?? 'Gasto')
          .toString()
          .replaceAll('"', '""');
      buffer.writeln(
        'Gasto,$fecha,"$concepto",Registrado,${_parseAmount(data['monto']).toStringAsFixed(2)}',
      );
    }

    buffer.writeln(
      'Resumen,,"Total facturado ($cantidadFacturas facturas)",,${totalFacturado.toStringAsFixed(2)}',
    );
    buffer.writeln('Resumen,,"Período: ${_monthLabel(DateTime.now())}",,');
    buffer.writeln(
      'Resumen,,"Ingresos cobrados",,${ingresosCobrados.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Resumen,,"Gastos totales",,${totalGastos.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Resumen,,"Ganancia neta",,${gananciaNeta.toStringAsFixed(2)}',
    );

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    const darkBackground = Colors.transparent;
    const darkCard = Color(0xFFFFFFFF);
    const darkBorder = Color(0xFFE2E8F0);
    const emeraldAccent = Color(0xFF059669);
    const greenSuccess = Color(0xFF10B981);
    const alertColor = Color(0xFFEF4444);
    const textPrimary = Color(0xFF0F172A);
    const textSecondary = Color(0xFF64748B);

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: darkBackground,
        body: Center(
          child: Text(
            'Iniciá sesión para ver tus reportes',
            style: TextStyle(color: textSecondary, fontSize: 16),
          ),
        ),
      );
    }

    final userFuture = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();

    final facturasStream = FirebaseFirestore.instance
        .collection('facturas')
        .where('userId', isEqualTo: uid)
        .snapshots();
    final gastosStream = FirebaseFirestore.instance
        .collection('gastos')
        .where('id_usuario', isEqualTo: uid)
        .snapshots();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: userFuture,
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return const Scaffold(
            backgroundColor: darkBackground,
            body: Center(
              child: Text(
                'Error al cargar la información del usuario',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: darkBackground,
            body: Center(child: CircularProgressIndicator(color: greenSuccess)),
          );
        }

        final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
        final categoriaActual = MonotributoCategory.normalizarCategoria(
          userData['categoria']?.toString(),
        );

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: facturasStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Scaffold(
                backgroundColor: darkBackground,
                body: Center(
                  child: Text(
                    'Error al cargar los reportes',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: darkBackground,
                body: Center(
                  child: CircularProgressIndicator(color: greenSuccess),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            double totalFacturado = 0;
            var cantidadFacturas = 0;

            for (final doc in docs) {
              final data = doc.data();
              totalFacturado += _impactoFiscal(data);
              if (!_esNotaCredito(data) && !_estaAnulada(data)) {
                cantidadFacturas++;
              }
            }

            final promedio = cantidadFacturas == 0
                ? 0.0
                : totalFacturado / cantidadFacturas;
            final facturado12Meses = _sumarFacturadoUltimos12Meses(
              docs,
              DateTime.now(),
            );
            final proyeccion =
                MonotributoCategory.determinarCategoriaProyectada(
                  facturado12Meses,
                );
            final currentIndex = MonotributoCategory.categories.indexOf(
              categoriaActual,
            );
            final projectedIndex = MonotributoCategory.categories.indexOf(
              proyeccion.category,
            );
            final subeCategoria = projectedIndex > currentIndex;
            final estadoColor = proyeccion.exclusionAlert
                ? alertColor
                : subeCategoria
                ? const Color(0xFFD97706)
                : greenSuccess;
            final estadoBadgeColor = estadoColor.withValues(alpha: 0.14);
            final progreso = proyeccion.categoryCeiling <= 0
                ? 0.0
                : (facturado12Meses / proyeccion.categoryCeiling).clamp(
                    0.0,
                    1.0,
                  );
            final porcentaje = proyeccion.categoryCeiling <= 0
                ? 0.0
                : facturado12Meses / proyeccion.categoryCeiling * 100;
            final estadoIcon = proyeccion.exclusionAlert
                ? Icons.error_rounded
                : subeCategoria
                ? Icons.trending_up_rounded
                : Icons.check_circle_rounded;
            final estadoTexto = proyeccion.exclusionAlert
                ? 'Alerta de Exclusión: superás el tope de Categoría K'
                : subeCategoria
                ? 'Proyección: Subirías a Categoría ${proyeccion.category}'
                : 'Te mantenés en Categoría ${proyeccion.category}';

            return Scaffold(
              backgroundColor: darkBackground,
              appBar: AppBar(
                backgroundColor: darkBackground,
                elevation: 0,
                title: const Text(
                  'Reportes',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: darkCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: darkBorder),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0F172A,
                            ).withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Simulador de Recategorización Semestral',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: estadoBadgeColor,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    estadoTexto,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: estadoColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _CategoryValue(
                                  label: 'Categoría Actual',
                                  value: categoriaActual,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CategoryValue(
                                  label: 'Categoría Proyectada',
                                  value: proyeccion.category,
                                  valueColor: estadoColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Facturación acumulada últimos 12 meses',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progreso,
                              minHeight: 12,
                              backgroundColor: darkBorder,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                estadoColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                facturado12Meses == 0
                                    ? '0%'
                                    : '${porcentaje.round()}% del tope proyectado',
                                style: const TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_formatCurrency(facturado12Meses)} de ${_formatCurrency(proyeccion.categoryCeiling)}',
                                style: const TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: estadoBadgeColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: estadoColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(estadoIcon, color: estadoColor, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    proyeccion.exclusionAlert
                                        ? '$estadoTexto. Superás el máximo de '
                                              '${_formatCurrency(proyeccion.categoryCeiling)} '
                                              'por ${_formatCurrency(proyeccion.amountAboveTopCategory)}.'
                                        : proyeccion.nextCategory == null
                                        ? 'Estás en la categoría máxima. '
                                              'Margen hasta el tope K: '
                                              '${_formatCurrency(proyeccion.marginToNextCategory)}.'
                                        : 'Margen antes de pasar a Categoría '
                                              '${proyeccion.nextCategory}: '
                                              '${_formatCurrency(proyeccion.marginToNextCategory)}.',
                                    style: TextStyle(
                                      color: estadoColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'La proyección considera los ingresos de los últimos '
                            '12 meses y es orientativa. La recategorización oficial '
                            'se realiza en las ventanas de enero/julio '
                            '(referencia habitual: vencimientos en febrero/agosto); '
                            'confirmá el calendario vigente en ARCA.',
                            style: const TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Facturado',
                              value: _formatCurrency(totalFacturado),
                              accentColor: emeraldAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              title: 'Facturas',
                              value: cantidadFacturas.toString(),
                              accentColor: greenSuccess,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              title: 'Promedio',
                              value: _formatCurrency(promedio),
                              accentColor: const Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: gastosStream,
                      builder: (context, gastosSnapshot) {
                        if (gastosSnapshot.hasError) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: darkCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: darkBorder),
                            ),
                            child: const Text(
                              'No se pudieron cargar los gastos. Revisá tu conexión e intentá nuevamente.',
                              style: TextStyle(color: alertColor),
                            ),
                          );
                        }

                        if (gastosSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: greenSuccess,
                              ),
                            ),
                          );
                        }

                        final gastosDocs = gastosSnapshot.data?.docs ?? [];
                        final now = DateTime.now();
                        final inicioPeriodo = DateTime(now.year, now.month);
                        final finPeriodo = DateTime(now.year, now.month + 1);
                        var ingresosCobrados = 0.0;
                        for (final doc in docs) {
                          final data = doc.data();
                          final fecha = _parseDate(
                            data['fecha_emision'] ??
                                data['fechaEmision'] ??
                                data['fecha'] ??
                                data['created_at'] ??
                                data['createdAt'],
                          );
                          if (_isCobrada(data) &&
                              _isWithinPeriod(
                                fecha,
                                inicioPeriodo,
                                finPeriodo,
                              )) {
                            ingresosCobrados += _impactoFiscal(data);
                          } else if (_esNotaCredito(data) &&
                              !_estaAnulada(data) &&
                              _isWithinPeriod(
                                fecha,
                                inicioPeriodo,
                                finPeriodo,
                              )) {
                            ingresosCobrados += _impactoFiscal(data);
                          }
                        }

                        var totalGastos = 0.0;
                        for (final doc in gastosDocs) {
                          final data = doc.data();
                          final fecha = _parseDate(data['fecha_gasto']);
                          if (_isWithinPeriod(
                            fecha,
                            inicioPeriodo,
                            finPeriodo,
                          )) {
                            totalGastos += _parseAmount(data['monto']);
                          }
                        }

                        final gananciaNeta = ingresosCobrados - totalGastos;
                        final balancePositivo = gananciaNeta >= 0;
                        final balanceColor = balancePositivo
                            ? const Color(0xFF047857)
                            : const Color(0xFFB91C1C);
                        final balanceBackground = balancePositivo
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF2F2);

                        return Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: darkCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: darkBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF0F172A,
                                    ).withValues(alpha: 0.06),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Rentabilidad y Balance Financiero',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Período: ${_monthLabel(now)}',
                                    style: const TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _BalanceRow(
                                    label: 'Ingresos cobrados',
                                    value: _formatCurrency(ingresosCobrados),
                                    icon: Icons.south_west_rounded,
                                    color: const Color(0xFF059669),
                                  ),
                                  const SizedBox(height: 12),
                                  _BalanceRow(
                                    label: 'Gastos totales',
                                    value: _formatCurrency(totalGastos),
                                    icon: Icons.north_east_rounded,
                                    color: const Color(0xFFD97706),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: balanceBackground,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Ganancia neta',
                                            style: TextStyle(
                                              color: balanceColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(gananciaNeta),
                                          style: TextStyle(
                                            color: balanceColor,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  final csv = _buildCsvContent(
                                    docs,
                                    gastosDocs,
                                    totalFacturado,
                                    cantidadFacturas,
                                    ingresosCobrados,
                                    totalGastos,
                                    gananciaNeta,
                                  );

                                  const fileName =
                                      'resumen_facturacion_argestion.csv';
                                  exportCsv(
                                    context: context,
                                    csvContent: csv,
                                    fileName: fileName,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: emeraldAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Exportar Resumen para Contador',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accentColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: accentColor,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CategoryValue extends StatelessWidget {
  const _CategoryValue({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF0F172A),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
