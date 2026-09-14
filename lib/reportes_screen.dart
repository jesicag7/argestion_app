import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  static const double _defaultTopeAnual = 7_720_000;

  String _formatCurrency(num value) {
    final roundedValue = value.round();
    final formatted = roundedValue
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match.group(1)}.',
        );

    return '\$${formatted}';
  }

  double _getTopeAnual(Map<String, dynamic>? data) {
    final rawValue = data?['topeAnual'] ?? data?['tope_anual'] ?? _defaultTopeAnual;

    if (rawValue is num) {
      return rawValue.toDouble();
    }

    if (rawValue is String) {
      return double.tryParse(rawValue) ?? _defaultTopeAnual;
    }

    return _defaultTopeAnual;
  }

  String _formatDate(dynamic value) {
    DateTime? fecha;

    if (value is Timestamp) {
      fecha = value.toDate();
    } else if (value is DateTime) {
      fecha = value;
    } else if (value is String) {
      fecha = DateTime.tryParse(value);
    }

    if (fecha == null) {
      return '';
    }

    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
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
    double totalFacturado,
    int cantidadFacturas,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Fecha,Concepto/Detalle,Monto');

    for (final doc in docs) {
      final data = doc.data();
      final rawMonto = data['monto'];
      final monto = rawMonto is num
          ? rawMonto.toDouble()
          : double.tryParse(rawMonto.toString()) ?? 0;

      final fecha = _formatDate(
        data['fechaEmision'] ??
            data['fecha_emision'] ??
            data['fecha'] ??
            data['createdAt'],
      );

      final concepto = _conceptoFromData(data).replaceAll('"', '""');

      buffer.writeln('$fecha,"$concepto",${monto.toStringAsFixed(2)}');
    }

    buffer.writeln('Total Facturado,${cantidadFacturas} facturas,${totalFacturado.toStringAsFixed(2)}');

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    const darkBackground = Color(0xFF0F172A);
    const darkCard = Color(0xFF1E293B);
    const darkBorder = Color(0xFF334155);
    const indigoAccent = Color(0xFF6366F1);
    const greenSuccess = Color(0xFF10B981);
    const warningColor = Color(0xFFFBBF24);
    const alertColor = Color(0xFFEF4444);
    const textPrimary = Colors.white;
    const textSecondary = Color(0xFF94A3B8);

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
            body: Center(
              child: CircularProgressIndicator(color: greenSuccess),
            ),
          );
        }

        final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
        final categoriaActual = (userData['categoria'] as String?) ?? 'A';
        final topeAnual = _getTopeAnual(userData);

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

            for (final doc in docs) {
              final data = doc.data();
              final rawMonto = data['monto'];

              if (rawMonto is num) {
                totalFacturado += rawMonto.toDouble();
              } else if (rawMonto is String) {
                totalFacturado += double.tryParse(rawMonto) ?? 0;
              }
            }

            final cantidadFacturas = docs.length;
            final promedio = cantidadFacturas == 0 ? 0.0 : totalFacturado / cantidadFacturas;
            final porcentaje = totalFacturado == 0 ? 0.0 : (totalFacturado / topeAnual) * 100;
            final progreso = totalFacturado == 0 ? 0.0 : (totalFacturado / topeAnual).clamp(0.0, 1.0);

            Color estadoColor;
            Color estadoBadgeColor;
            IconData estadoIcon;
            String estadoTexto;

            if (porcentaje < 80) {
              estadoColor = greenSuccess;
              estadoBadgeColor = greenSuccess.withOpacity(0.14);
              estadoIcon = Icons.check_circle_rounded;
              estadoTexto = 'Te mantenés en tu Categoría';
            } else if (porcentaje < 100) {
              estadoColor = warningColor;
              estadoBadgeColor = warningColor.withOpacity(0.14);
              estadoIcon = Icons.warning_amber_rounded;
              estadoTexto = 'Atención: Cerca de recategorizar';
            } else {
              estadoColor = alertColor;
              estadoBadgeColor = alertColor.withOpacity(0.14);
              estadoIcon = Icons.error_rounded;
              estadoTexto = 'Alerta: Tope anual alcanzado / Riesgo de exclusión';
            }

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
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Semáforo de Recategorización Semestral (ARCA)',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: estadoColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  categoriaActual,
                                  style: TextStyle(
                                    color: estadoColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Categoría Actual: $categoriaActual',
                            style: const TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tope Anual: ${_formatCurrency(topeAnual)}',
                            style: const TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Consumo anual',
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
                              valueColor: AlwaysStoppedAnimation<Color>(estadoColor),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                totalFacturado == 0 ? '0%' : '${porcentaje.round()}%',
                                style: const TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_formatCurrency(totalFacturado)} de ${_formatCurrency(topeAnual)}',
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
                                color: estadoColor.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  estadoIcon,
                                  color: estadoColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  estadoTexto,
                                  style: TextStyle(
                                    color: estadoColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            title: 'Facturado',
                            value: _formatCurrency(totalFacturado),
                            accentColor: indigoAccent,
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
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final csv = _buildCsvContent(
                            docs,
                            totalFacturado,
                            cantidadFacturas,
                          );

                          final fileName = 'resumen_facturacion_argestion.csv';
                          final blob = html.Blob([csv], 'text/csv;charset=utf-8');
                          final url = html.Url.createObjectUrlFromBlob(blob);
                          final anchor = html.AnchorElement(href: url)
                            ..setAttribute('download', fileName)
                            ..click();

                          html.Url.revokeObjectUrl(url);
                          anchor.remove();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Archivo $fileName descargado con éxito'),
                              backgroundColor: greenSuccess,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: indigoAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
