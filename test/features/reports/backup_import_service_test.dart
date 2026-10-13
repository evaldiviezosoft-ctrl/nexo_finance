import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/features/reports/data/backup_import_service.dart';

void main() {
  Map<String, Object?> backup({bool anonymized = false}) => {
    'format': 'nexo-finance-backup',
    'version': 1,
    'anonymized': anonymized,
    'accounts': [
      {
        'id': 'bank',
        'name': 'Cuenta principal',
        'type': 'bank',
        'currency': 'pen',
        'initialBalanceMinor': 0,
      },
    ],
    'categories': <Object>[],
    'transactions': <Object>[],
    'budgets': <Object>[],
    'cardStatements': <Object>[],
    'recurring': <Object>[],
    'goals': <Object>[],
    'debts': <Object>[],
  };

  Uint8List bytes(Object value) =>
      Uint8List.fromList(utf8.encode(jsonEncode(value)));

  test('valida el formato y resume los registros antes de importar', () {
    final decoded = BackupImportService.decodeAndValidate(bytes(backup()));
    final summary = BackupImportService.summary(decoded);
    expect(summary.total, 1);
    expect(summary.byCollection['accounts'], 1);
  });

  test('rechaza copias anonimizadas para evitar restaurar datos ocultos', () {
    expect(
      () => BackupImportService.decodeAndValidate(
        bytes(backup(anonymized: true)),
      ),
      throwsFormatException,
    );
  });

  test('rechaza documentos sin identificador', () {
    final invalid = backup()..['accounts'] = [{}];
    expect(
      () => BackupImportService.decodeAndValidate(bytes(invalid)),
      throwsFormatException,
    );
  });

  test('valida todos los campos antes de iniciar la restauración', () {
    final invalid = backup()
      ..['debts'] = [
        {
          'id': 'debt',
          'name': 'Préstamo',
          'direction': 'owed',
          'type': 'personal',
          'party': '',
          'initialPrincipalMinor': 10000,
          'currency': 'pen',
          'annualRateBasisPoints': 0,
          'thirdPartyContributionMinor': 0,
          'status': 'active',
        },
      ];

    expect(
      () => BackupImportService.decodeAndValidate(bytes(invalid)),
      throwsFormatException,
    );
  });

  test('rechaza identificadores duplicados dentro de una colección', () {
    final account = (backup()['accounts'] as List).single;
    final invalid = backup()..['accounts'] = [account, account];

    expect(
      () => BackupImportService.decodeAndValidate(bytes(invalid)),
      throwsFormatException,
    );
  });

  test('limita la copia al tamaño de un batch atómico', () {
    final template = Map<String, Object?>.from(
      (backup()['accounts'] as List).single as Map,
    );
    final oversized = backup()
      ..['accounts'] = List.generate(
        501,
        (index) => {...template, 'id': 'account-$index'},
      );

    expect(
      () => BackupImportService.decodeAndValidate(bytes(oversized)),
      throwsFormatException,
    );
  });
}
