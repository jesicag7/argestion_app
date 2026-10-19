import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfInvoiceService {
  /// Genera y comparte el comprobante fiscal en formato PDF estilo oficial AFIP/ARCA
  static Future<void> shareInvoicePdf(Map<String, dynamic> data) async {
    final pdfBytes = await generateInvoicePdf(data);
    final nro = (data['nro_factura'] ?? 'comprobante').toString().replaceAll(
      '/',
      '-',
    );
    final fileName = 'Factura_$nro.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  }

  /// Imprime o abre la vista previa nativa del PDF
  static Future<void> printInvoicePdf(Map<String, dynamic> data) async {
    final pdfBytes = await generateInvoicePdf(data);
    final nro = (data['nro_factura'] ?? 'comprobante').toString().replaceAll(
      '/',
      '-',
    );
    await Printing.layoutPdf(
      name: 'Factura_$nro.pdf',
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  /// Construye el documento PDF con formato oficial de Comprobante Electrónico AFIP / ARCA
  static Future<Uint8List> generateInvoicePdf(Map<String, dynamic> data) async {
    final cae = (data['cae'] ?? '').toString().trim();
    final resultado =
        (data['resultadoEmision'] ?? data['resultado_emision'] ?? '')
            .toString()
            .toLowerCase();
    final modoHomologacion = data['modoHomologacion'] == true;
    final qrContent =
        (data['qrUrl'] ?? data['qr_url'] ?? data['qrData'] ?? data['qr_data'])
            ?.toString();
    final vtoCae = _parseDate(data['fechaVtoCae'] ?? data['vto_cae']);
    if (resultado != 'aprobado' ||
        modoHomologacion ||
        cae.length != 14 ||
        vtoCae == null ||
        qrContent == null ||
        qrContent.isEmpty) {
      throw StateError(
        modoHomologacion
            ? 'No se puede generar un comprobante fiscal oficial en modo '
                  'homologación.'
            : 'No se puede generar el comprobante: falta una autorización '
                  'real de ARCA con CAE, vencimiento y QR.',
      );
    }

    final pdf = pw.Document();

    final tipoComprobante = (data['tipo_comprobante'] ?? 'Factura C')
        .toString();
    final letraComprobante = _obtenerLetra(tipoComprobante);
    final codigoComprobante = _obtenerCodigoAfip(tipoComprobante);
    final esNotaCredito =
        data['esNotaCredito'] == true ||
        data['es_nota_credito'] == true ||
        tipoComprobante.startsWith('Nota de Crédito');
    final comprobanteAsociadoTipo =
        (data['comprobanteAsociadoTipo'] ??
                data['comprobante_asociado_tipo'] ??
                'Factura C')
            .toString();
    final comprobanteAsociadoNumero =
        (data['comprobanteAsociadoNumero'] ??
                data['comprobante_asociado_numero'] ??
                '')
            .toString();

    final nroFactura = (data['nro_factura'] ?? '0001-00000001').toString();
    final fechaEmisionStr = _formatearFecha(data['fecha_emision']);
    final concepto = (data['concepto'] ?? 'Servicios').toString();

    // Fechas de período y vencimiento si aplica
    final periodoDesdeStr = _formatearFecha(data['periodo_desde']);
    final periodoHastaStr = _formatearFecha(data['periodo_hasta']);
    final vtoPagoStr = _formatearFecha(data['vencimiento_pago']);

    // Emisor
    final emisorNombre = (data['emisor_nombre'] ?? 'ARGestión Usuario')
        .toString();
    final emisorCuit = (data['emisor_cuit'] ?? '').toString();
    final emisorDomicilio =
        (data['emisor_domicilio'] ?? 'Buenos Aires, Argentina').toString();

    // Receptor / Cliente
    final nombreCliente =
        (data['nombre_cliente'] ?? data['nombreCliente'] ?? 'Consumidor Final')
            .toString();
    final docCliente =
        (data['cuit_cliente'] ?? data['cuitCliente'] ?? 'Sin identificar')
            .toString();
    final tipoDocCliente = (data['tipo_documento_cliente'] ?? 'DNI').toString();
    final condicionIva = (data['condicion_iva_cliente'] ?? 'Consumidor Final')
        .toString();
    final domicilioCliente = (data['domicilio_cliente'] ?? '-').toString();
    final condicionVenta = (data['condicion_venta'] ?? 'Transferencia / Débito')
        .toString();

    // Detalle
    final descripcionItem =
        (data['descripcion_item'] ??
                data['descripcion'] ??
                'Servicios Profesionales')
            .toString();
    final double monto = (data['monto'] is num)
        ? (data['monto'] as num).toDouble()
        : double.tryParse(data['monto']?.toString() ?? '0') ?? 0.0;

    final vtoCaeStr = _formatearFecha(vtoCae);

    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$ ',
      decimalDigits: 2,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // 1. CABECERA CON LETRA CENTRAL
                pw.Container(
                  height: 100,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.black, width: 1),
                    ),
                  ),
                  child: pw.Stack(
                    children: [
                      // Lado Izquierdo: Emisor
                      pw.Positioned(
                        left: 0,
                        top: 0,
                        child: pw.SizedBox(
                          width: 230,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                emisorNombre.toUpperCase(),
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                maxLines: 2,
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'Razón Social: $emisorNombre',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                              pw.Text(
                                'Domicilio Comercial: $emisorDomicilio',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                              pw.Text(
                                'Condición frente al IVA: Responsable Monotributo',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Centro: Letra del Comprobante
                      pw.Align(
                        alignment: pw.Alignment.topCenter,
                        child: pw.Container(
                          width: 44,
                          height: 48,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                              color: PdfColors.black,
                              width: 1,
                            ),
                            color: PdfColors.white,
                          ),
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text(
                                letraComprobante,
                                style: pw.TextStyle(
                                  fontSize: 22,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                'COD. $codigoComprobante',
                                style: const pw.TextStyle(fontSize: 6),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Lado Derecho: Datos de la Factura
                      pw.Positioned(
                        right: 0,
                        top: 0,
                        child: pw.SizedBox(
                          width: 230,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                tipoComprobante.toUpperCase(),
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'Punto de Venta - Comp. Nro: $nroFactura',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                'Fecha de Emisión: $fechaEmisionStr',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                              pw.Text(
                                'CUIT: $emisorCuit',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                              pw.Text(
                                'Ingresos Brutos: $emisorCuit',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                              pw.Text(
                                'Fecha Inicio de Actividades: 01/01/2024',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (esNotaCredito && comprobanteAsociadoNumero.isNotEmpty)
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 2,
                    ),
                    child: pw.Text(
                      'Comprobante Asociado: $comprobanteAsociadoTipo '
                      '$comprobanteAsociadoNumero',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),

                // 2. PERÍODO FACTURADO (SI CORRESPONDE)
                if (concepto.contains('Servicio') ||
                    concepto == 'Productos y Servicios') ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: PdfColors.black,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Período Facturado Desde: $periodoDesdeStr',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          'Hasta: $periodoHastaStr',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          'Vencimiento para el Pago: $vtoPagoStr',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                pw.SizedBox(height: 6),

                // 3. DATOS DEL CLIENTE / RECEPTOR
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '$tipoDocCliente: $docCliente',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Apellido y Nombre / Razón Social: $nombreCliente',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Condición frente al IVA: $condicionIva',
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                          pw.Text(
                            'Domicilio Comercial: $domicilioCliente',
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Condición de venta: $condicionVenta',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 10),

                // 4. TABLA DE ÍTEMS / DETALLE DE FACTURACIÓN
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.black,
                    width: 0.5,
                  ),
                  children: [
                    // Header de la tabla
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        _buildTableHeaderCell('Código', width: 45),
                        _buildTableHeaderCell(
                          'Producto / Servicio',
                          width: 230,
                        ),
                        _buildTableHeaderCell('Cantidad', width: 45),
                        _buildTableHeaderCell('U. Medida', width: 45),
                        _buildTableHeaderCell('Precio Unit.', width: 65),
                        _buildTableHeaderCell('Subtotal', width: 70),
                      ],
                    ),
                    // Fila con el ítem
                    pw.TableRow(
                      children: [
                        _buildTableCell('001', align: pw.TextAlign.center),
                        _buildTableCell(descripcionItem),
                        _buildTableCell('1', align: pw.TextAlign.center),
                        _buildTableCell('otras', align: pw.TextAlign.center),
                        _buildTableCell(
                          currencyFormat.format(monto),
                          align: pw.TextAlign.right,
                        ),
                        _buildTableCell(
                          currencyFormat.format(monto),
                          align: pw.TextAlign.right,
                          isBold: true,
                        ),
                      ],
                    ),
                  ],
                ),

                pw.Spacer(),

                // 5. RESUMEN DE TOTALES
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 0.5),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Subtotal: ${currencyFormat.format(monto)}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Text(
                            'Importe Otros Tributos: \$ 0,00',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Importe Total: ${currencyFormat.format(monto)}',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 10),

                // 6. PIE DE PÁGINA CON CAE Y QR/LEGALES AFIP
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.black, width: 1),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrContent,
                        width: 72,
                        height: 72,
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'ARCA / AFIP - Comprobante Autorizado Electrónicamente',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Esta Administración Federal de Ingresos Públicos no se responsabiliza por los datos consignados.',
                              style: const pw.TextStyle(
                                fontSize: 6.5,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 14),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text(
                                'CAE N°: ',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                cae,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 2),
                          pw.Row(
                            children: [
                              pw.Text(
                                'Fecha de Vto. de CAE: ',
                                style: const pw.TextStyle(fontSize: 8.5),
                              ),
                              pw.Text(
                                vtoCaeStr,
                                style: const pw.TextStyle(fontSize: 8.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableHeaderCell(String text, {double? width}) {
    return pw.Container(
      width: width,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _obtenerLetra(String tipo) {
    if (tipo.contains('Nota de Crédito') || tipo.contains('Nota de Débito')) {
      if (tipo.endsWith('A')) return 'A';
      if (tipo.endsWith('B')) return 'B';
      return 'C';
    }
    if (tipo.contains('Factura A')) return 'A';
    if (tipo.contains('Factura B')) return 'B';
    return 'C';
  }

  static String _obtenerCodigoAfip(String tipo) {
    if (tipo.contains('Factura A')) return '001';
    if (tipo.contains('Factura B')) return '006';
    if (tipo.contains('Factura C')) return '011';
    if (tipo.contains('Nota de Débito A')) return '002';
    if (tipo.contains('Nota de Débito B')) return '007';
    if (tipo.contains('Nota de Débito C')) return '012';
    if (tipo.contains('Nota de Crédito A')) return '003';
    if (tipo.contains('Nota de Crédito B')) return '008';
    if (tipo.contains('Nota de Crédito C')) return '013';
    return '011';
  }

  static String _formatearFecha(dynamic fecha) {
    if (fecha == null) return DateFormat('dd/MM/yyyy').format(DateTime.now());
    if (fecha is DateTime) return DateFormat('dd/MM/yyyy').format(fecha);
    try {
      final parsed = DateTime.parse(fecha.toString());
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return fecha.toString();
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
