import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistorialFacturasScreen extends StatelessWidget {
  const HistorialFacturasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Fondo oscuro premium
      appBar: AppBar(
        title: const Text('Mis Facturas Emitidas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white), // Flecha para volver en blanco
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔄 Escucha a Firebase en tiempo real
        stream: FirebaseFirestore.instance.collection('facturas').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar datos', style: TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('No tenés facturas emitidas todavía.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              
              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Color(0xFF334155)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: Color(0xFF6366F1), size: 30),
                  title: Text(data['nombre_cliente'] ?? 'Sin nombre', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('CUIT: ${data['cuit_cliente']}\nFactura: ${data['nro_factura']}', style: const TextStyle(color: Color(0xFF94A3B8))),
                  trailing: Text('\$${data['monto']}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16)),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}