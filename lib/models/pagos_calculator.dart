class PagosCalculator {
  const PagosCalculator._();

  static const Map<String, double> cuotasMensualesServicios = {
    'A': 49527.18,
    'B': 56379.08,
    'C': 66020.12,
    'D': 84612.93,
    'E': 119811.45,
    'F': 150784.21,
    'G': 230312.94,
    'H': 522706.68,
    'I': 963747.86,
    'J': 1167299.76,
    'K': 1614446.04,
  };

  static DateTime proximoVencimiento(DateTime today) {
    var dueDate = DateTime(today.year, today.month, 20);
    if (today.day > 20) {
      dueDate = DateTime(today.year, today.month + 1, 20);
    }

    while (dueDate.weekday == DateTime.saturday ||
        dueDate.weekday == DateTime.sunday) {
      dueDate = dueDate.add(const Duration(days: 1));
    }
    return dueDate;
  }

  static String periodo(DateTime date) {
    final monthName = _monthNames[date.month - 1];
    return '$monthName ${date.year}';
  }

  static String periodoKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  static String referenciaPago({
    required String? cuit,
    required DateTime period,
  }) {
    final cuitDigits = (cuit ?? '').replaceAll(RegExp(r'\D'), '');
    final identifier = cuitDigits.isEmpty ? 'SIN-CUIT' : cuitDigits;
    return 'MONOTRIBUTO-$identifier-${periodoKey(period)}';
  }

  static String formatoImporte(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final integer = parts.first;
    final formattedInteger = integer.replaceAllMapped(
      RegExp(r'(?<=\d)(?=(\d{3})+$)'),
      (_) => '.',
    );
    return '\$ $formattedInteger,${parts.last}';
  }

  static const List<String> _monthNames = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
}
