import 'package:flutter/material.dart';

import '../../../core/icons/material_icon_registry.dart';
import '../domain/finance_category.dart';

const categoryColorChoices = <Color>[
  Color(0xFFFF5A7A),
  Color(0xFFFFA726),
  Color(0xFFFFD54F),
  Color(0xFF66BB6A),
  Color(0xFF26C6DA),
  Color(0xFF42A5F5),
  Color(0xFF7E57C2),
  Color(0xFFEC407A),
];

const categoryIconChoices = <IconData>[
  Icons.restaurant_rounded,
  Icons.directions_bus_rounded,
  Icons.two_wheeler_rounded,
  Icons.local_gas_station_rounded,
  Icons.fitness_center_rounded,
  Icons.medical_services_rounded,
  Icons.checkroom_rounded,
  Icons.movie_rounded,
  Icons.flight_rounded,
  Icons.home_rounded,
  Icons.credit_card_rounded,
  Icons.savings_rounded,
  Icons.trending_up_rounded,
  Icons.payments_rounded,
  Icons.wifi_rounded,
  Icons.category_rounded,
];

class CategoryVisualStyle {
  const CategoryVisualStyle({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}

CategoryVisualStyle categoryVisualStyle(
  FinanceCategory category, {
  int fallbackIndex = 0,
}) {
  const legacyColor = 0xffff1744;
  const seededLegacyIcon = 0xe57f;
  final usesLegacyVisual =
      category.colorValue == legacyColor &&
      (category.iconCodePoint == seededLegacyIcon ||
          category.iconCodePoint == Icons.category_outlined.codePoint);
  if (!usesLegacyVisual) {
    return CategoryVisualStyle(
      color: Color(category.colorValue),
      icon: materialIconForCodePoint(
        category.iconCodePoint,
        fallback: category.type == CategoryType.income
            ? Icons.south_west_rounded
            : Icons.category_rounded,
      ),
    );
  }
  return suggestedCategoryVisual(
    category.name,
    category.type,
    fallbackIndex: fallbackIndex,
  );
}

CategoryVisualStyle suggestedCategoryVisual(
  String name,
  CategoryType type, {
  int fallbackIndex = 0,
}) {
  final normalized = _normalize(name);

  if (_contains(normalized, ['aliment', 'almuerzo', 'cena'])) {
    return const CategoryVisualStyle(
      color: Color(0xFFFFA726),
      icon: Icons.restaurant_rounded,
    );
  }
  if (normalized.contains('desayuno')) {
    return const CategoryVisualStyle(
      color: Color(0xFFFFD54F),
      icon: Icons.free_breakfast_rounded,
    );
  }
  if (_contains(normalized, ['transporte', 'taxi'])) {
    return CategoryVisualStyle(
      color: const Color(0xFF42A5F5),
      icon: normalized.contains('taxi')
          ? Icons.local_taxi_rounded
          : Icons.directions_bus_rounded,
    );
  }
  if (normalized.contains('moto')) {
    return const CategoryVisualStyle(
      color: Color(0xFF26C6DA),
      icon: Icons.two_wheeler_rounded,
    );
  }
  if (normalized.contains('combustible')) {
    return const CategoryVisualStyle(
      color: Color(0xFFFF7043),
      icon: Icons.local_gas_station_rounded,
    );
  }
  if (normalized.contains('deporte')) {
    return const CategoryVisualStyle(
      color: Color(0xFF66BB6A),
      icon: Icons.fitness_center_rounded,
    );
  }
  if (_contains(normalized, ['telefono', 'internet'])) {
    return const CategoryVisualStyle(
      color: Color(0xFF42A5F5),
      icon: Icons.wifi_rounded,
    );
  }
  if (normalized.contains('higiene')) {
    return const CategoryVisualStyle(
      color: Color(0xFF26C6DA),
      icon: Icons.soap_rounded,
    );
  }
  if (normalized.contains('salud')) {
    return const CategoryVisualStyle(
      color: Color(0xFFEC407A),
      icon: Icons.medical_services_rounded,
    );
  }
  if (_contains(normalized, ['ropa', 'calzado'])) {
    return const CategoryVisualStyle(
      color: Color(0xFF7E57C2),
      icon: Icons.checkroom_rounded,
    );
  }
  if (normalized.contains('entretenimiento')) {
    return const CategoryVisualStyle(
      color: Color(0xFFAB47BC),
      icon: Icons.movie_rounded,
    );
  }
  if (normalized.contains('viaje')) {
    return const CategoryVisualStyle(
      color: Color(0xFF26A69A),
      icon: Icons.flight_rounded,
    );
  }
  if (normalized.contains('hogar')) {
    return const CategoryVisualStyle(
      color: Color(0xFF8D6E63),
      icon: Icons.home_rounded,
    );
  }
  if (_contains(normalized, ['deuda', 'tarjeta'])) {
    return const CategoryVisualStyle(
      color: Color(0xFFFF5A7A),
      icon: Icons.credit_card_rounded,
    );
  }
  if (normalized.contains('ahorro')) {
    return const CategoryVisualStyle(
      color: Color(0xFF2EE6A6),
      icon: Icons.savings_rounded,
    );
  }
  if (normalized.contains('inversion')) {
    return const CategoryVisualStyle(
      color: Color(0xFF66BB6A),
      icon: Icons.trending_up_rounded,
    );
  }
  if (_contains(normalized, ['sueldo', 'ingreso'])) {
    return const CategoryVisualStyle(
      color: Color(0xFF2EE6A6),
      icon: Icons.payments_rounded,
    );
  }

  final color =
      categoryColorChoices[fallbackIndex.abs() % categoryColorChoices.length];
  return CategoryVisualStyle(
    color: color,
    icon: type == CategoryType.income
        ? Icons.south_west_rounded
        : Icons.category_rounded,
  );
}

bool _contains(String value, List<String> fragments) =>
    fragments.any(value.contains);

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàä]'), 'a')
    .replaceAll(RegExp('[éèë]'), 'e')
    .replaceAll(RegExp('[íìï]'), 'i')
    .replaceAll(RegExp('[óòö]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u')
    .replaceAll('ñ', 'n');
