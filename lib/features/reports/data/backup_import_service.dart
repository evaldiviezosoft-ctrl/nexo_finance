import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

class BackupSummary {
  const BackupSummary({required this.total, required this.byCollection});
  final int total;
  final Map<String, int> byCollection;
}

class _PreparedBackupRecord {
  const _PreparedBackupRecord({
    required this.collectionName,
    required this.id,
    required this.data,
  });

  final String collectionName;
  final String id;
  final Map<String, Object?> data;
}

class BackupImportService {
  BackupImportService(this.firestore, this.userId);
  final FirebaseFirestore firestore;
  final String userId;

  static const _maxAtomicRecords = 500;

  static const _sections = <String, String>{
    'accounts': 'accounts',
    'categories': 'categories',
    'transactions': 'transactions',
    'budgets': 'budgets',
    'cardStatements': 'cardStatements',
    'recurring': 'recurringTransactions',
    'goals': 'goals',
    'debts': 'debts',
  };

  static Map<String, dynamic> decodeAndValidate(Uint8List bytes) {
    if (bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('La copia supera el límite de 20 MB.');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'nexo-finance-backup' ||
        decoded['version'] != 1) {
      throw const FormatException('El archivo no es una copia válida de Nexo.');
    }
    if (decoded['anonymized'] == true) {
      throw const FormatException(
        'Una copia anonimizada sirve para compartir, no para restaurar.',
      );
    }
    var total = 0;
    for (final section in _sections.keys) {
      final items = decoded[section];
      if (items is! List) {
        throw FormatException('Falta la sección $section.');
      }
      total += items.length;
    }
    if (total > _maxAtomicRecords) {
      throw const FormatException(
        'La copia supera el límite de 500 registros para una restauración '
        'atómica.',
      );
    }
    _prepareRecords(decoded);
    return decoded;
  }

  static BackupSummary summary(Map<String, dynamic> backup) {
    final counts = {
      for (final section in _sections.keys)
        section: (backup[section] as List).length,
    };
    return BackupSummary(
      total: counts.values.fold(0, (total, value) => total + value),
      byCollection: counts,
    );
  }

  Future<BackupSummary> restore(Uint8List bytes) async {
    final backup = decodeAndValidate(bytes);
    final records = _prepareRecords(backup);
    final references = records
        .map(
          (record) => firestore
              .collection('users')
              .doc(userId)
              .collection(record.collectionName)
              .doc(record.id),
        )
        .toList(growable: false);

    // Resolve every version before creating the batch. A read or validation
    // failure therefore cannot leave a partially restored backup.
    final currentDocuments = await Future.wait(
      references.map((reference) => reference.get()),
    );
    final batch = firestore.batch();
    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      final currentData = currentDocuments[index].data();
      final normalized = Map<String, Object?>.from(record.data)
        ..['id'] = record.id
        ..['userId'] = userId
        ..['createdAt'] =
            currentData?['createdAt'] ?? FieldValue.serverTimestamp()
        ..['updatedAt'] = FieldValue.serverTimestamp()
        ..['version'] = (currentData?['version'] as int? ?? 0) + 1;
      batch.set(references[index], normalized, SetOptions(merge: false));
    }
    await batch.commit();
    return summary(backup);
  }

  static List<_PreparedBackupRecord> _prepareRecords(
    Map<String, dynamic> backup,
  ) {
    final records = <_PreparedBackupRecord>[];
    for (final entry in _sections.entries) {
      final seenIds = <String>{};
      final items = backup[entry.key] as List;
      for (final item in items) {
        if (item is! Map) {
          throw FormatException('Hay un registro inválido en ${entry.key}.');
        }
        try {
          final raw = Map<String, dynamic>.from(item);
          final id = raw['id'];
          if (id is! String || !_isSafeDocumentId(id)) {
            throw FormatException(
              'Hay un identificador inválido en ${entry.key}.',
            );
          }
          if (!seenIds.add(id)) {
            throw FormatException(
              'El identificador $id está duplicado en ${entry.key}.',
            );
          }
          final normalized = _normalize(entry.value, raw)
            ..['deletedAt'] = _timestamp(raw['deletedAt']);
          records.add(
            _PreparedBackupRecord(
              collectionName: entry.value,
              id: id,
              data: normalized,
            ),
          );
        } on FormatException {
          rethrow;
        } catch (_) {
          throw FormatException('Hay un registro inválido en ${entry.key}.');
        }
      }
    }
    return records;
  }

  static bool _isSafeDocumentId(String id) =>
      id.trim().isNotEmpty &&
      utf8.encode(id).length <= 1500 &&
      id != '.' &&
      id != '..' &&
      !id.contains('/') &&
      !RegExp(r'^__.*__$').hasMatch(id);

  static Map<String, Object?> _normalize(
    String collection,
    Map<String, dynamic> value,
  ) => switch (collection) {
    'accounts' => {
      'name': _text(value, 'name', max: 80),
      'type': _choice(value, 'type', const {
        'cash',
        'bank',
        'debitCard',
        'creditCard',
        'savings',
        'fixedDeposit',
        'digitalWallet',
        'crypto',
        'custom',
      }),
      'currency': _currency(value),
      'initialBalanceMinor': _integer(value, 'initialBalanceMinor'),
      'institution': value['institution'] as String?,
      'active': value['active'] as bool? ?? true,
      'creditLimitMinor': value['creditLimitMinor'] as int?,
      'closingDay': value['closingDay'] as int?,
      'paymentDay': value['paymentDay'] as int?,
      'cryptoAssetSymbol': _optionalText(value, 'cryptoAssetSymbol', max: 12),
      'cryptoQuantity': _optionalDecimal(value, 'cryptoQuantity'),
      'cryptoAprBasisPoints': _optionalNonNegativeInteger(
        value,
        'cryptoAprBasisPoints',
      ),
    },
    'categories' => {
      'name': _text(value, 'name', max: 60),
      'type': _choice(value, 'type', const {'expense', 'income'}),
      'parentId': value['parentId'] as String?,
      'iconCodePoint': value['iconCodePoint'] as int? ?? 0xe57f,
      'colorValue': value['colorValue'] as int? ?? 0xffff1744,
      'order': value['order'] as int? ?? 0,
      'active': value['active'] as bool? ?? true,
    },
    'transactions' => {
      'kind': _choice(value, 'kind', const {
        'expense',
        'income',
        'transfer',
        'creditPurchase',
        'creditPayment',
        'loanGiven',
        'loanRepayment',
        'goalContribution',
        'goalWithdrawal',
        'debtPayment',
        'refund',
      }),
      'amountMinor': _positive(value, 'amountMinor'),
      'thirdPartyAmountMinor': value['thirdPartyAmountMinor'] as int?,
      'currency': _currency(value),
      'sourceAccountId': value['sourceAccountId'] as String?,
      'destinationAccountId': value['destinationAccountId'] as String?,
      'categoryId': value['categoryId'] as String?,
      'goalId': value['goalId'] as String?,
      'debtId': value['debtId'] as String?,
      'relatedTransactionId': value['relatedTransactionId'] as String?,
      'exchangeRateMicros': value['exchangeRateMicros'] as int?,
      'destinationAmountMinor': value['destinationAmountMinor'] as int?,
      'description': (value['description'] as String? ?? '').substring(
        0,
        (value['description'] as String? ?? '').length.clamp(0, 160),
      ),
      'note': (value['note'] as String? ?? '').substring(
        0,
        (value['note'] as String? ?? '').length.clamp(0, 1000),
      ),
      'occurredAt': _requiredTimestamp(value, 'occurredAt'),
    },
    'budgets' => {
      'name': _text(value, 'name', max: 80),
      'period': _choice(value, 'period', const {
        'daily',
        'weekly',
        'monthly',
        'custom',
      }),
      'amountMinor': _positive(value, 'amountMinor'),
      'currency': _currency(value),
      'categoryId': value['categoryId'] as String?,
      'customStart': _timestamp(value['customStart']),
      'customEnd': _timestamp(value['customEnd']),
      'rollover': value['rollover'] as bool? ?? false,
      'active': value['active'] as bool? ?? true,
    },
    'cardStatements' => {
      'cardAccountId': _text(value, 'cardAccountId', max: 100),
      'cycleStart': _requiredTimestamp(value, 'cycleStart'),
      'cycleEnd': _requiredTimestamp(value, 'cycleEnd'),
      'dueDate': _requiredTimestamp(value, 'dueDate'),
      'amountDuePenMinor': _nonNegative(value, 'amountDuePenMinor'),
      'amountDueUsdMinor': _nonNegative(value, 'amountDueUsdMinor'),
      'reservedPenMinor': _nonNegative(value, 'reservedPenMinor'),
      'reservedUsdMinor': _nonNegative(value, 'reservedUsdMinor'),
      'status': _choice(value, 'status', const {'projected', 'open', 'paid'}),
    },
    'recurringTransactions' => {
      'name': _text(value, 'name', max: 160),
      'kind': _choice(value, 'kind', const {'expense', 'income'}),
      'amountMinor': _positive(value, 'amountMinor'),
      'currency': _currency(value),
      'frequency': _choice(value, 'frequency', const {
        'weekly',
        'monthly',
        'yearly',
      }),
      'interval': _positive(value, 'interval'),
      'nextDueAt': _requiredTimestamp(value, 'nextDueAt'),
      'sourceAccountId': value['sourceAccountId'] as String?,
      'destinationAccountId': value['destinationAccountId'] as String?,
      'categoryId': value['categoryId'] as String?,
      'active': value['active'] as bool? ?? true,
    },
    'goals' => {
      'name': _text(value, 'name', max: 80),
      'targetMinor': _positive(value, 'targetMinor'),
      'openingAmountMinor': _nonNegative(value, 'openingAmountMinor'),
      'currency': _currency(value),
      'deadline': _timestamp(value['deadline']),
      'priority': _choice(value, 'priority', const {'low', 'medium', 'high'}),
      'accountId': value['accountId'] as String?,
      'iconCodePoint': value['iconCodePoint'] as int? ?? 0xe153,
      'colorValue': value['colorValue'] as int? ?? 0xffff1744,
      'automaticContributionMinor': value['automaticContributionMinor'] as int?,
      'allowWithdrawals': value['allowWithdrawals'] as bool? ?? false,
      'notes': value['notes'] as String? ?? '',
      'active': value['active'] as bool? ?? true,
    },
    'debts' => {
      'name': _text(value, 'name', max: 100),
      'direction': _choice(value, 'direction', const {'owed', 'receivable'}),
      'type': _choice(value, 'type', const {
        'personal',
        'bankLoan',
        'financedPurchase',
        'vehicle',
        'shared',
        'custom',
      }),
      'party': _text(value, 'party', max: 100),
      'initialPrincipalMinor': _positive(value, 'initialPrincipalMinor'),
      'currency': _currency(value),
      'annualRateBasisPoints': _nonNegative(value, 'annualRateBasisPoints'),
      'installments': value['installments'] as int?,
      'installmentMinor': value['installmentMinor'] as int?,
      'nextDueDate': _timestamp(value['nextDueDate']),
      'paymentDay': value['paymentDay'] as int?,
      'thirdPartyContributionMinor':
          value['thirdPartyContributionMinor'] as int? ?? 0,
      'status': _choice(value, 'status', const {'active', 'paid', 'paused'}),
      'notes': value['notes'] as String? ?? '',
    },
    _ => throw FormatException('Colección no permitida: $collection'),
  };

  static String _currency(Map<String, dynamic> value) =>
      _choice(value, 'currency', const {'pen', 'usd'});
  static String _choice(
    Map<String, dynamic> value,
    String key,
    Set<String> allowed,
  ) {
    final item = value[key];
    if (item is! String || !allowed.contains(item)) {
      throw FormatException('Valor inválido en $key.');
    }
    return item;
  }

  static String _text(Map<String, dynamic> value, String key, {int? max}) {
    final item = value[key];
    if (item is! String ||
        item.trim().isEmpty ||
        (max != null && item.length > max)) {
      throw FormatException('Texto inválido en $key.');
    }
    return item;
  }

  static String? _optionalText(
    Map<String, dynamic> value,
    String key, {
    int? max,
  }) {
    final item = value[key];
    if (item == null) return null;
    if (item is! String ||
        item.trim().isEmpty ||
        (max != null && item.length > max)) {
      throw FormatException('Texto inválido en $key.');
    }
    return item;
  }

  static String? _optionalDecimal(Map<String, dynamic> value, String key) {
    final item = value[key];
    if (item == null) return null;
    if (item is! String || !RegExp(r'^\d+(\.\d+)?$').hasMatch(item)) {
      throw FormatException('Decimal inválido en $key.');
    }
    return item;
  }

  static int? _optionalNonNegativeInteger(
    Map<String, dynamic> value,
    String key,
  ) {
    final item = value[key];
    if (item == null) return null;
    if (item is! int || item < 0) {
      throw FormatException('$key no puede ser negativo.');
    }
    return item;
  }

  static int _integer(Map<String, dynamic> value, String key) {
    final item = value[key];
    if (item is! int) throw FormatException('Número inválido en $key.');
    return item;
  }

  static int _positive(Map<String, dynamic> value, String key) {
    final item = _integer(value, key);
    if (item <= 0) throw FormatException('$key debe ser positivo.');
    return item;
  }

  static int _nonNegative(Map<String, dynamic> value, String key) {
    final item = _integer(value, key);
    if (item < 0) throw FormatException('$key no puede ser negativo.');
    return item;
  }

  static Timestamp _requiredTimestamp(Map<String, dynamic> value, String key) {
    final item = _timestamp(value[key]);
    if (item == null) throw FormatException('Fecha inválida en $key.');
    return item;
  }

  static Timestamp? _timestamp(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Fecha inválida.');
    return Timestamp.fromDate(DateTime.parse(value).toUtc());
  }
}
