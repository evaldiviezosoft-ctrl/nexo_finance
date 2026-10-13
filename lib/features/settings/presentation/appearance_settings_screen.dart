import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Apariencia')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
      children: [
        const SwitchListTile(
          secondary: Icon(Icons.dark_mode_outlined),
          title: Text('Tema negro AMOLED'),
          subtitle: Text('Activo para máxima legibilidad y menor brillo.'),
          value: true,
          onChanged: null,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(color: Color(0x22FF1744), blurRadius: 22),
              ],
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text(
                    'Negro puro · Rojo de acento',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
