enum Currency { pen, usd }

class Money implements Comparable<Money> {
  const Money(this.minorUnits, this.currency);

  final int minorUnits;
  final Currency currency;

  static int? parseMinorUnits(String input) {
    final normalized = input.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.isEmpty ||
        !RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(normalized)) {
      return null;
    }
    final parts = normalized.split('.');
    final whole = int.parse(parts.first);
    final cents = parts.length == 1
        ? 0
        : int.parse(parts.last.padRight(2, '0'));
    return whole * 100 + cents;
  }

  Money operator +(Money other) {
    _ensureSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _ensureSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currency);
  }

  Money operator -() => Money(-minorUnits, currency);

  String format({String locale = 'es_PE'}) {
    final negative = minorUnits < 0;
    final absolute = minorUnits.abs();
    final whole = absolute ~/ 100;
    final cents = (absolute % 100).toString().padLeft(2, '0');
    final grouped = whole.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final symbol = currency == Currency.pen ? 'S/ ' : r'US$ ';
    return '${negative ? '-' : ''}$symbol$grouped.$cents';
  }

  @override
  int compareTo(Money other) {
    _ensureSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  void _ensureSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('No se pueden operar monedas diferentes.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);
}
