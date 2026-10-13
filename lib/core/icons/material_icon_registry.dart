import 'package:flutter/material.dart';

/// Material icons that may be persisted by the application as code points.
///
/// Keeping the concrete [IconData] values statically reachable allows Flutter
/// to tree-shake the Material font in release builds. Unknown values use the
/// caller-provided fallback instead of constructing IconData at runtime.
const persistedMaterialIcons = <IconData>[
  Icons.restaurant_rounded,
  Icons.free_breakfast_rounded,
  Icons.directions_bus_rounded,
  Icons.local_taxi_rounded,
  Icons.two_wheeler_rounded,
  Icons.local_gas_station_rounded,
  Icons.fitness_center_rounded,
  Icons.medical_services_rounded,
  Icons.soap_rounded,
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
  Icons.category_outlined,
  Icons.settings,
  Icons.chat,
  Icons.south_west_rounded,
];

IconData materialIconForCodePoint(int codePoint, {required IconData fallback}) {
  for (final icon in persistedMaterialIcons) {
    if (icon.codePoint == codePoint) return icon;
  }
  return fallback;
}
