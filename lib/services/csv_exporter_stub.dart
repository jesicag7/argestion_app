import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void exportCsv({
  required BuildContext context,
  required String csvContent,
  required String fileName,
}) {
  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      title: const Row(
        children: [
          Icon(Icons.description_outlined, color: Color(0xFF10B981)),
          SizedBox(width: 8),
          Text(
            'Resumen CSV',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Archivo generado: $fileName',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: SingleChildScrollView(
              child: Text(
                csvContent,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Podés copiar el contenido al portapapeles para compartirlo o pegarlo en Excel.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: csvContent));
            Navigator.of(dialogCtx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Contenido CSV copiado al portapapeles'),
                backgroundColor: Color(0xFF10B981),
                duration: Duration(seconds: 3),
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF6366F1)),
          label: const Text(
            'Copiar al Portapapeles',
            style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
        ),
      ],
    ),
  );

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Resumen "$fileName" generado con éxito'),
      backgroundColor: const Color(0xFF10B981),
      duration: const Duration(seconds: 3),
    ),
  );
}

