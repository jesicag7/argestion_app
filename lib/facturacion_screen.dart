import 'package:flutter/material.dart';
import 'nueva_factura_screen.dart';

export 'nueva_factura_screen.dart';

/// Pantalla Unificada de Facturación Electrónica Oficial (ARCA / AFIP).
/// Carga directamente el formulario completo de comprobantes oficiales
/// con selección de comprobantes A, B, C, fechas editables, datos del receptor,
/// detalle, cálculo de impacto fiscal en vivo, autorización de CAE y compartir PDF.
class FacturaExpressScreen extends StatelessWidget {
  final VoidCallback? onVolverAlInicio;

  const FacturaExpressScreen({super.key, this.onVolverAlInicio});

  @override
  Widget build(BuildContext context) {
    return NuevaFacturaScreen(onVolverAlInicio: onVolverAlInicio);
  }
}
