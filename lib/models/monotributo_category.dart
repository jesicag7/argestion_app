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
