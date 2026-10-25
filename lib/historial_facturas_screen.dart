import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'models/factura_model.dart';
import 'services/pdf_invoice_service.dart';
import 'nueva_factura_screen.dart';

class HistorialFacturasScreen extends StatelessWidget {
  const HistorialFacturasScreen({super.key});

  static final NumberFormat _formatoMonto = NumberFormat.currency(
    locale: 'es_AR',
    symbol: '\$',
    decimalDigits: 2,
  );

  Future<void> _actualizarEstadoCobro(
    BuildContext context,
    String facturaId,
    bool estaCobrada,
  ) async {
    final nuevoEstado = estaCobrada ? 'Pendiente' : 'Cobrada';
    try {
      await FirebaseFirestore.instance
          .collection('facturas')
          .doc(facturaId)
          .update({
            'estadoCobro': nuevoEstado,
            'estado_cobro': nuevoEstado,
            'cobrada': !estaCobrada,
          });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Factura marcada como $nuevoEstado')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar el cobro: $error')),
        );
      }
    }
  }

  Future<void> _confirmarAnulacion(
    BuildContext context,
    FacturaModel factura,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        title: const Text(
          'Anular Factura C',
          style: TextStyle(color: Color(0xFF0F172A)),
        ),
        content: Text(
          'Se emitirá una Nota de Crédito C por el monto total '
          '\$${factura.monto.toStringAsFixed(2)} para anular la factura '
          '${factura.nroFactura}. Esta nota quedará vinculada al comprobante original.',
          style: const TextStyle(color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NuevaFacturaScreen(comprobanteAAnular: factura),
      ),
    );
  }

  bool _puedeAnular(FacturaModel factura) =>
      !factura.anulada &&
      !factura.esNotaCredito &&
      factura.tipoComprobante == 'Factura C' &&
      factura.resultadoEmision.toLowerCase() == 'aprobado' &&
      !factura.modoHomologacion &&
      factura.cae != null &&
      factura.cae!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Mis Facturas Emitidas',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFFFFFF),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF10B981),
            ),
            tooltip: 'Emitir Nueva Factura',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NuevaFacturaScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NuevaFacturaScreen()),
          );
        },
        backgroundColor: const Color(0xFF059669),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Nueva Factura',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: currentUser == null
            ? const Center(
                child: Text(
                  'Iniciá sesión para ver tus facturas.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                ),
              )
            : StreamBuilder<QuerySnapshot>(
                // 🔄 Escucha a Firebase en tiempo real
                stream: FirebaseFirestore.instance
                    .collection('facturas')
                    .where(
                      Filter.or(
                        Filter('userId', isEqualTo: currentUser.uid),
                        Filter('id_usuario', isEqualTo: currentUser.uid),
                      ),
                    )
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Error al cargar datos',
                        style: TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF10B981),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 54,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Aún no has emitido facturas.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NuevaFacturaScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Emitir Primera Factura'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 80,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final facturaDocument = docs[index];
                      final data =
                          facturaDocument.data() as Map<String, dynamic>;
                      final factura = FacturaModel.fromMap(
                        data,
                        facturaDocument.id,
                      );
                      final estaCobrada = factura.estaCobrada;
                      final nombreCliente =
                          data['nombre_cliente'] ?? data['nombreCliente'];
                      final cuitRaw = data['cuit_cliente']?.toString().trim();
                      final cuitTexto = (cuitRaw != null && cuitRaw.isNotEmpty)
                          ? cuitRaw
                          : 'Consumidor Final';
                      final nroFactura = data['nro_factura']?.toString().trim();
                      final tipoComp =
                          data['tipo_comprobante']?.toString() ?? 'Factura C';
                      final nombreMostrar =
                          (nombreCliente != null &&
                              nombreCliente.toString().trim().isNotEmpty)
                          ? nombreCliente.toString()
                          : cuitTexto;

                      return Card(
                        color: const Color(0xFFFFFFFF),
                        margin: const EdgeInsets.only(bottom: 12),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF059669,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.receipt_long,
                                  color: Color(0xFF059669),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF059669,
                                            ).withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            tipoComp,
                                            style: const TextStyle(
                                              color: Color(0xFF059669),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            nombreMostrar,
                                            style: const TextStyle(
                                              color: Color(0xFF0F172A),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'CUIT / DNI: $cuitTexto',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (nroFactura != null &&
                                        nroFactura.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Comp: $nroFactura',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 7),
                                    _EstadoCobroBadge(estaCobrada: estaCobrada),
                                    if (factura.anulada) ...[
                                      const SizedBox(height: 5),
                                      _FacturaAnuladaBadge(
                                        numeroNotaCredito:
                                            factura.anuladaPorNcNumero,
                                      ),
                                    ] else if (_puedeAnular(factura)) ...[
                                      const SizedBox(height: 2),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: () => _confirmarAnulacion(
                                            context,
                                            factura,
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFF047857,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 2,
                                              vertical: 2,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          icon: const Icon(
                                            Icons.assignment_return_outlined,
                                            size: 15,
                                          ),
                                          label: const Text(
                                            'Anular con Nota de Crédito',
                                            style: TextStyle(fontSize: 10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _formatoMonto.format(factura.monto),
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton.icon(
                                    onPressed: () => _actualizarEstadoCobro(
                                      context,
                                      facturaDocument.id,
                                      estaCobrada,
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: estaCobrada
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF047857),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: Icon(
                                      estaCobrada
                                          ? Icons.undo_rounded
                                          : Icons.check_circle_outline_rounded,
                                      size: 15,
                                    ),
                                    label: Text(
                                      estaCobrada
                                          ? 'Marcar pendiente'
                                          : 'Marcar cobrada',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      try {
                                        await PdfInvoiceService.shareInvoicePdf(
                                          data,
                                        );
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Error al compartir PDF: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF059669,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF059669,
                                          ).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.picture_as_pdf_rounded,
                                            size: 14,
                                            color: Color(0xFF059669),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'PDF',
                                            style: TextStyle(
                                              color: Color(0xFF059669),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _EstadoCobroBadge extends StatelessWidget {
  const _EstadoCobroBadge({required this.estaCobrada});

  final bool estaCobrada;

  @override
  Widget build(BuildContext context) {
    final color = estaCobrada
        ? const Color(0xFF047857)
        : const Color(0xFFB45309);
    final background = estaCobrada
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEF3C7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estaCobrada ? 'Cobrada' : 'Pendiente',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FacturaAnuladaBadge extends StatelessWidget {
  const _FacturaAnuladaBadge({required this.numeroNotaCredito});

  final String? numeroNotaCredito;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDD5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        numeroNotaCredito == null || numeroNotaCredito!.isEmpty
            ? 'Anulada'
            : 'Anulada por NC N° $numeroNotaCredito',
        style: const TextStyle(
          color: Color(0xFF9A3412),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
