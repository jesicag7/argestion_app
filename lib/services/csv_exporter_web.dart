// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';

void exportCsv({
  required BuildContext context,
  required String csvContent,
  required String fileName,
}) {
  final blob = html.Blob([csvContent], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();

  html.Url.revokeObjectUrl(url);
  anchor.remove();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Archivo $fileName descargado con éxito'),
      backgroundColor: const Color(0xFF10B981),
    ),
  );
}

