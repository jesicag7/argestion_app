class MonotributoProjection {
  const MonotributoProjection({
    required this.category,
    required this.categoryCeiling,
    required this.marginToNextCategory,
    required this.nextCategory,
    required this.exclusionAlert,
    required this.amountAboveTopCategory,
  });

  final String category;
  final double categoryCeiling;
  final double marginToNextCategory;
  final String? nextCategory;
  final bool exclusionAlert;
  final double amountAboveTopCategory;
}

class MonotributoCategory {
  const MonotributoCategory._();

  static double impactoFiscal({
    required double monto,
    bool esNotaCredito = false,
    bool anulada = false,
    bool tieneNotaCreditoAsociada = false,
  }) {
    if (!monto.isFinite) return 0;
    if (esNotaCredito) return anulada ? 0 : -monto.abs();
    if (anulada && !tieneNotaCreditoAsociada) return 0;
    return monto;
  }

  /// Impacto fiscal de un documento guardado en `facturas` (ver [impactoFiscal]).
  /// Es la única fuente de verdad para tope, cupo y reportes: la NC resta.
  static double impactoFiscalDocumento(Map<String, dynamic> data) {
    final rawMonto = data['monto'];
    final monto = rawMonto is num
        ? rawMonto.toDouble()
        : double.tryParse(rawMonto?.toString() ?? '') ?? 0.0;
    return impactoFiscal(
      monto: monto,
      esNotaCredito: esNotaCredito(data),
      anulada: estaAnulada(data),
      tieneNotaCreditoAsociada: _idNotaCreditoAsociada(data).isNotEmpty,
    );
  }

  static bool esNotaCredito(Map<String, dynamic> data) {
    final tipo = (data['tipo_comprobante'] ?? data['tipo_factura'] ?? '')
        .toString()
        .toLowerCase();
    return data['esNotaCredito'] == true ||
        data['es_nota_credito'] == true ||
        tipo.startsWith('nota de crédito');
  }

  static bool estaAnulada(Map<String, dynamic> data) =>
      data['anulada'] == true || data['es_anulada'] == true;

  static bool estaCobrada(Map<String, dynamic> data) {
    final estado = (data['estadoCobro'] ?? data['estado_cobro'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final cobrada = data['cobrada']?.toString().trim().toLowerCase();
    return estado == 'cobrada' || cobrada == 'true' || cobrada == 'cobrada';
  }

  static String _idNotaCreditoAsociada(Map<String, dynamic> data) =>
      (data['anuladaPorNcId'] ?? data['anulada_por_nc_id'])?.toString() ?? '';

  /// Neto cobrado de un conjunto de documentos dentro de un período.
  ///
  /// - Una factura cobrada suma su impacto fiscal.
  /// - Una Nota de Crédito resta solo si la factura que anula
  ///   (`comprobanteAsociadoId`) está marcada como cobrada. Si la factura
  ///   estaba pendiente, la NC no mueve el neto cobrado (no genera saldo
  ///   negativo).
  /// [enPeriodo] indica si el documento cae en el período analizado.
  static double netoCobrado(
    List<({String id, Map<String, dynamic> data})> docs, {
    required bool Function(Map<String, dynamic> data) enPeriodo,
  }) {
    final idsCobrados = {
      for (final doc in docs)
        if (estaCobrada(doc.data)) doc.id,
    };
    var total = 0.0;
    for (final doc in docs) {
      final data = doc.data;
      if (!enPeriodo(data)) continue;
      if (esNotaCredito(data)) {
        if (estaAnulada(data)) continue;
        final asociada =
            (data['comprobanteAsociadoId'] ?? data['comprobante_asociado_id'])
                ?.toString();
        if (asociada != null && idsCobrados.contains(asociada)) {
          total += impactoFiscalDocumento(data);
        }
      } else if (estaCobrada(data)) {
        total += impactoFiscalDocumento(data);
      }
    }
    return total;
  }

  // Existing application scale values, centralized for all fiscal projections.
  static const Map<String, double> annualIncomeLimits = {
    'A': 7720000,
    'B': 11450000,
    'C': 16050000,
    'D': 19950000,
    'E': 23500000,
    'F': 29400000,
    'G': 35250000,
    'H': 53400000,
    'I': 59850000,
    'J': 68600000,
    'K': 82300000,
  };

  static const List<String> categories = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
  ];

  static MonotributoProjection determinarCategoriaProyectada(
    double facturado12Meses,
  ) {
    final amount = facturado12Meses.isFinite && facturado12Meses > 0
        ? facturado12Meses
        : 0.0;
    final topCategory = categories.last;
    final topLimit = annualIncomeLimits[topCategory]!;

    if (amount > topLimit) {
      return MonotributoProjection(
        category: topCategory,
        categoryCeiling: topLimit,
        marginToNextCategory: 0,
        nextCategory: null,
        exclusionAlert: true,
        amountAboveTopCategory: amount - topLimit,
      );
    }

    final category = categories.firstWhere(
      (letter) => amount <= annualIncomeLimits[letter]!,
    );
    final categoryIndex = categories.indexOf(category);
    final nextCategory = categoryIndex < categories.length - 1
        ? categories[categoryIndex + 1]
        : null;
    final nextLimit = nextCategory == null
        ? annualIncomeLimits[category]!
        : annualIncomeLimits[nextCategory]!;

    return MonotributoProjection(
      category: category,
      categoryCeiling: annualIncomeLimits[category]!,
      marginToNextCategory: (nextLimit - amount).clamp(0, double.infinity),
      nextCategory: nextCategory,
      exclusionAlert: false,
      amountAboveTopCategory: 0,
    );
  }

  static String normalizarCategoria(String? value) {
    if (value == null || value.trim().isEmpty) return 'A';
    final normalized = value
        .trim()
        .replaceAll(
          RegExp(r'^(Categoria|Categoría)\s*', caseSensitive: false),
          '',
        )
        .toUpperCase();
    return annualIncomeLimits.containsKey(normalized) ? normalized : 'A';
  }
}
