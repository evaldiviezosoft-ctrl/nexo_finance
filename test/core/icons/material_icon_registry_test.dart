import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo_finance/core/icons/material_icon_registry.dart';

void main() {
  test('resolves a persisted code point to a static icon', () {
    expect(
      materialIconForCodePoint(
        Icons.flight_rounded.codePoint,
        fallback: Icons.category_rounded,
      ),
      Icons.flight_rounded,
    );
  });

  test('uses a static fallback for unknown code points', () {
    expect(
      materialIconForCodePoint(0x10ffff, fallback: Icons.chat),
      Icons.chat,
    );
  });
}
