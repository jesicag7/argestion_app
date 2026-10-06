import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/pdf_invoice_service.dart';
import 'nueva_factura_screen.dart';

class HistorialFacturasScreen extends StatelessWidget {
  const HistorialFacturasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fondo oscuro premium
      appBar: AppBar(
        title: const Text('Mis Facturas Emitidas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
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
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nueva Factura', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        bottom: true,
        child: currentUser == null
            ? const Center(
                child: Text(
                  'Iniciá sesión para ver tus facturas.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                ),
              )
            : StreamBuilder<QuerySnapshot>(
                // 🔄 Escucha a Firebase en tiempo real
                stream: FirebaseFirestore.instance
                    .collection('facturas')
                    .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error al cargar datos', style: TextStyle(color: Colors.red)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 54, color: Color(0xFF64748B)),
                            const SizedBox(height: 12),
                            const Text(
                              'No tenés facturas emitidas todavía.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const NuevaFacturaScreen()),
                                );
                              },
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Emitir Primera Factura'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final nombreCliente = data['nombre_cliente'] ?? data['nombreCliente'];
                      final cuitRaw = data['cuit_cliente']?.toString().trim();
                      final cuitTexto = (cuitRaw != null && cuitRaw.isNotEmpty) ? cuitRaw : 'Consumidor Final';
                      final nroFactura = data['nro_factura']?.toString().trim();
                      final tipoComp = data['tipo_comprobante']?.toString() ?? 'Factura C';
                      final nombreMostrar = (nombreCliente != null && nombreCliente.toString().trim().isNotEmpty)
                          ? nombreCliente.toString()
                          : cuitTexto;

                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: Color(0xFF334155)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.receipt_long, color: Color(0xFF6366F1), size: 24),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            tipoComp,
                                            style: const TextStyle(
                                              color: Color(0xFFA5B4FC),
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
                                              color: Colors.white,
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
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (nroFactura != null && nroFactura.isNotEmpty) ...[
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
                                      '\$${data['monto']}',
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () async {
                                      try {
                                        await PdfInvoiceService.shareInvoicePdf(data);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error al compartir PDF: $e')),
                                          );
                                        }
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.picture_as_pdf_rounded, size: 14, color: Color(0xFF818CF8)),
                                          SizedBox(width: 4),
                                          Text(
                                            'PDF',
                                            style: TextStyle(
                                              color: Color(0xFFA5B4FC),
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