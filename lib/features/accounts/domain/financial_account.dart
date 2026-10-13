import '../../../core/firebase/firestore_converters.dart';
import '../../../core/money/money.dart';

enum AccountType {
  cash,
  bank,
  debitCard,
  creditCard,
  savings,
  fixedDeposit,
  digitalWallet,
  crypto,
  custom,
}

extension AccountTypeLabel on AccountType {
  String get label => switch (this) {
    AccountType.cash => 'Efectivo',
    AccountType.bank => 'Cuenta bancaria',
    AccountType.debitCard => 'Tarjeta de débito',
    AccountType.creditCard => 'Tarjeta de crédito',
    AccountType.savings => 'Cuenta de ahorros',
    AccountType.fixedDeposit => 'Plazo fijo',
    AccountType.digitalWallet => 'Billetera digital',
    AccountType.crypto => 'Criptomonedas',
    AccountType.custom => 'Cuenta personalizada',
  };

  bool get isLiability => this == AccountType.creditCard;
}

class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.currency,
    required this.initialBalanceMinor,
    required this.createdAt,
    required this.updatedAt,
    this.institution,
    this.active = true,
    this.creditLimitMinor,
    this.closingDay,
    this.paymentDay,
    this.cryptoAssetSymbol,
    this.cryptoQuantity,
    this.cryptoAprBasisPoints,
    this.version = 1,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String name;
  final AccountType type;
  final Currency currency;
  final int initialBalanceMinor;
  final String? institution;
  final bool active;
  final int? creditLimitMinor;
  final int? closingDay;
  final int? paymentDay;
  final String? cryptoAssetSymbol;
  final String? cryptoQuantity;
  final int? cryptoAprBasisPoints;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final DateTime? deletedAt;

  bool get isCreditCard => type == AccountType.creditCard;

  FinancialAccount copyWith({
    String? name,
    AccountType? type,
    Currency? currency,
    int? initialBalanceMinor,
    String? institution,
    bool? active,
    int? creditLimitMinor,
    int? closingDay,
    int? paymentDay,
    String? cryptoAssetSymbol,
    String? cryptoQuantity,
    int? cryptoAprBasisPoints,
    DateTime? updatedAt,
    int? version,
    DateTime? deletedAt,
  }) => FinancialAccount(
    id: id,
    userId: userId,
    name: name ?? this.name,
    type: type ?? this.type,
    currency: currency ?? this.currency,
    initialBalanceMinor: initialBalanceMinor ?? this.initialBalanceMinor,
    institution: institution ?? this.institution,
    active: active ?? this.active,
    creditLimitMinor: creditLimitMinor ?? this.creditLimitMinor,
    closingDay: closingDay ?? this.closingDay,
    paymentDay: paymentDay ?? this.paymentDay,
    cryptoAssetSymbol: cryptoAssetSymbol ?? this.cryptoAssetSymbol,
    cryptoQuantity: cryptoQuantity ?? this.cryptoQuantity,
    cryptoAprBasisPoints: cryptoAprBasisPoints ?? this.cryptoAprBasisPoints,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  factory FinancialAccount.fromMap(Map<String, Object?> map) =>
      FinancialAccount(
        id: map['id']! as String,
        userId: map['userId']! as String,
        name: map['name']! as String,
        type: AccountType.values.byName(map['type']! as String),
        currency: Currency.values.byName(map['currency']! as String),
        initialBalanceMinor: map['initialBalanceMinor']! as int,
        institution: map['institution'] as String?,
        active: map['active'] as bool? ?? true,
        creditLimitMinor: map['creditLimitMinor'] as int?,
        closingDay: map['closingDay'] as int?,
        paymentDay: map['paymentDay'] as int?,
        cryptoAssetSymbol: map['cryptoAssetSymbol'] as String?,
        cryptoQuantity: map['cryptoQuantity'] as String?,
        cryptoAprBasisPoints: map['cryptoAprBasisPoints'] as int?,
        createdAt: dateTimeFromFirestore(map['createdAt']),
        updatedAt: dateTimeFromFirestore(map['updatedAt']),
        version: map['version'] as int? ?? 1,
        deletedAt: nullableDateTimeFromFirestore(map['deletedAt']),
      );
}
