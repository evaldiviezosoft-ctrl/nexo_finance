import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  Timestamp,
  writeBatch,
} from 'firebase/firestore';

let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'nexo-finance-rules-test',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

function account(id, uid, overrides = {}) {
  const now = Timestamp.now();
  return {
    id,
    userId: uid,
    name: 'Cuenta prueba',
    type: 'bank',
    currency: 'pen',
    initialBalanceMinor: 10000,
    active: true,
    createdAt: now,
    updatedAt: now,
    version: 1,
    deletedAt: null,
    ...overrides,
  };
}

function recurring(id, uid, overrides = {}) {
  const now = Timestamp.now();
  return {
    id,
    userId: uid,
    name: 'Internet',
    kind: 'expense',
    amountMinor: 1000,
    currency: 'pen',
    frequency: 'monthly',
    interval: 1,
    nextDueAt: now,
    active: true,
    createdAt: now,
    updatedAt: now,
    version: 1,
    deletedAt: null,
    ...overrides,
  };
}

function transaction(id, uid, overrides = {}) {
  const now = Timestamp.now();
  return {
    id,
    userId: uid,
    kind: 'expense',
    amountMinor: 1000,
    currency: 'pen',
    occurredAt: now,
    description: 'Internet',
    note: 'Creado desde una recurrencia confirmada.',
    createdAt: now,
    updatedAt: now,
    version: 1,
    deletedAt: null,
    ...overrides,
  };
}

test('cada usuario solo puede leer sus documentos', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const bob = environment.authenticatedContext('bob').firestore();
  const reference = doc(alice, 'users/alice/accounts/bank');
  await assertSucceeds(setDoc(reference, account('bank', 'alice')));
  await assertSucceeds(getDoc(reference));
  await assertFails(getDoc(doc(bob, 'users/alice/accounts/bank')));
});

test('rechaza propietario falso y días de tarjeta inválidos', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  await assertFails(
    setDoc(
      doc(alice, 'users/alice/accounts/foreign'),
      account('foreign', 'bob'),
    ),
  );
  await assertFails(
    setDoc(
      doc(alice, 'users/alice/accounts/card'),
      account('card', 'alice', {
        type: 'creditCard',
        closingDay: 32,
        paymentDay: 0,
      }),
    ),
  );
});

test('acepta metadatos cripto precisos y rechaza formatos inválidos', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  await assertSucceeds(
    setDoc(
      doc(alice, 'users/alice/accounts/binance-usdt'),
      account('binance-usdt', 'alice', {
        type: 'crypto',
        cryptoAssetSymbol: 'USDT',
        cryptoQuantity: '44.8311617483',
        cryptoAprBasisPoints: 647,
      }),
    ),
  );
  await assertFails(
    setDoc(
      doc(alice, 'users/alice/accounts/invalid-crypto'),
      account('invalid-crypto', 'alice', {
        type: 'crypto',
        cryptoAssetSymbol: 'USDT',
        cryptoQuantity: '44,83',
        cryptoAprBasisPoints: -1,
      }),
    ),
  );
});

test('el propietario puede borrar sus datos, otro usuario no', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const bob = environment.authenticatedContext('bob').firestore();
  const reference = doc(alice, 'users/alice/accounts/bank');
  await assertSucceeds(setDoc(reference, account('bank', 'alice')));
  await assertFails(deleteDoc(doc(bob, 'users/alice/accounts/bank')));
  await assertSucceeds(deleteDoc(reference));
  assert.equal((await getDoc(reference)).exists(), false);
});

test('una confirmaciÃ³n recurrente obsoleta no puede aplicarse dos veces', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const recurringRef = doc(
    alice,
    'users/alice/recurringTransactions/internet',
  );
  const occurrenceRef = doc(
    alice,
    'users/alice/transactions/deterministic-occurrence',
  );
  const initial = recurring('internet', 'alice');
  await assertSucceeds(setDoc(recurringRef, initial));

  const first = writeBatch(alice);
  first.set(
    occurrenceRef,
    transaction('deterministic-occurrence', 'alice'),
  );
  first.update(recurringRef, {
    nextDueAt: Timestamp.fromMillis(initial.nextDueAt.toMillis() + 86400000),
    updatedAt: Timestamp.now(),
    version: 2,
  });
  await assertSucceeds(first.commit());

  const staleRetry = writeBatch(alice);
  staleRetry.set(
    occurrenceRef,
    transaction('deterministic-occurrence', 'alice'),
  );
  staleRetry.update(recurringRef, {
    nextDueAt: Timestamp.fromMillis(initial.nextDueAt.toMillis() + 86400000),
    updatedAt: Timestamp.now(),
    version: 2,
  });
  await assertFails(staleRetry.commit());
});
