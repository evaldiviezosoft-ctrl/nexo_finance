import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/features/categories/domain/finance_category.dart';
import 'package:nexo_finance/features/categories/presentation/category_visuals.dart';

void main() {
  test('legacy categories receive distinct semantic visuals', () {
    final food = categoryVisualStyle(_category('Alimentación'));
    final motorcycle = categoryVisualStyle(_category('Moto'));

    expect(food.icon, Icons.restaurant_rounded);
    expect(motorcycle.icon, Icons.two_wheeler_rounded);
    expect(food.color, isNot(motorcycle.color));
  });

  test('seeded legacy categories also receive semantic visuals', () {
    final food = categoryVisualStyle(
      _category('Alimentación', iconCodePoint: Icons.settings.codePoint),
    );

    expect(food.icon, Icons.restaurant_rounded);
  });

  test('a user-selected persisted icon is resolved statically', () {
    final travel = categoryVisualStyle(
      _category(
        'Personalizada',
        iconCodePoint: Icons.flight_rounded.codePoint,
        colorValue: 0xff26a69a,
      ),
    );

    expect(travel.icon, Icons.flight_rounded);
  });

  test('a persisted semantic suggestion is resolved statically', () {
    final breakfast = categoryVisualStyle(
      _category(
        'Desayuno',
        iconCodePoint: Icons.free_breakfast_rounded.codePoint,
        colorValue: 0xffffd54f,
      ),
    );

    expect(breakfast.icon, Icons.free_breakfast_rounded);
  });
}

FinanceCategory _category(
  String name, {
  int? iconCodePoint,
  int colorValue = 0xffff1744,
}) {
  final now = DateTime.utc(2026, 9, 14);
  return FinanceCategory(
    id: name,
    userId: 'user',
    name: name,
    type: CategoryType.expense,
    createdAt: now,
    updatedAt: now,
    iconCodePoint: iconCodePoint ?? Icons.category_outlined.codePoint,
    colorValue: colorValue,
  );
}
