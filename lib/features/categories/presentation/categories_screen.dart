import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../accounts/data/accounts_repository.dart';
import '../data/categories_repository.dart';
import '../domain/finance_category.dart';
import 'category_visuals.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  CategoryType _type = CategoryType.expense;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            tooltip: 'Restaurar categorías iniciales',
            onPressed: () =>
                ref.read(categoriesRepositoryProvider)?.seedDefaultsIfEmpty(),
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<CategoryType>(
              segments: const [
                ButtonSegment(
                  value: CategoryType.expense,
                  label: Text('Gastos'),
                ),
                ButtonSegment(
                  value: CategoryType.income,
                  label: Text('Ingresos'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (value) =>
                  setState(() => _type = value.first),
            ),
          ),
          Expanded(
            child: categories.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (snapshot) {
                final items = snapshot.items
                    .where((item) => item.type == _type)
                    .toList();
                if (items.isEmpty) {
                  return Center(
                    child: FilledButton.icon(
                      onPressed: () => _showForm(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Crear categoría'),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final parent = item.parentId == null
                        ? null
                        : snapshot.items
                              .where(
                                (candidate) => candidate.id == item.parentId,
                              )
                              .firstOrNull;
                    final visual = categoryVisualStyle(
                      item,
                      fallbackIndex: index,
                    );
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: visual.color.withValues(alpha: .16),
                        child: Icon(visual.icon, color: visual.color),
                      ),
                      title: Text(item.name),
                      subtitle: Text(
                        parent == null
                            ? (item.active
                                  ? 'Categoría principal'
                                  : 'Archivada')
                            : 'Subcategoría de ${parent.name}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') {
                            _showForm(context, category: item);
                          }
                          if (action == 'archive') {
                            ref
                                .read(categoriesRepositoryProvider)
                                ?.archive(item);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar'),
                          ),
                          if (item.active)
                            const PopupMenuItem(
                              value: 'archive',
                              child: Text('Archivar'),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        tooltip: 'Nueva categoría',
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context, {
    FinanceCategory? category,
  }) async {
    final controller = TextEditingController(text: category?.name);
    var selectedType = category?.type ?? _type;
    var parentId = category?.parentId;
    final allCategories = ref.read(categoriesProvider).value?.items ?? const [];
    final initialVisual = category == null
        ? suggestedCategoryVisual(
            controller.text,
            selectedType,
            fallbackIndex: allCategories.length,
          )
        : categoryVisualStyle(
            category,
            fallbackIndex: allCategories.indexOf(category),
          );
    var selectedColor = initialVisual.color.toARGB32();
    var selectedIcon = initialVisual.icon.codePoint;
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(
            category == null ? 'Nueva categoría' : 'Editar categoría',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresa un nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CategoryType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                      value: CategoryType.expense,
                      child: Text('Gasto'),
                    ),
                    DropdownMenuItem(
                      value: CategoryType.income,
                      child: Text('Ingreso'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() {
                    selectedType = value!;
                    parentId = null;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: parentId,
                  decoration: const InputDecoration(
                    labelText: 'Categoría principal (opcional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Ninguna'),
                    ),
                    ...allCategories
                        .where(
                          (item) =>
                              item.id != category?.id &&
                              item.type == selectedType &&
                              item.parentId == null &&
                              item.active,
                        )
                        .map(
                          (item) => DropdownMenuItem<String?>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        ),
                  ],
                  onChanged: (value) => setDialogState(() => parentId = value),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Color',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categoryColorChoices.map((color) {
                    final value = color.toARGB32();
                    return ChoiceChip(
                      tooltip: 'Elegir color',
                      showCheckmark: false,
                      selected: selectedColor == value,
                      onSelected: (_) =>
                          setDialogState(() => selectedColor = value),
                      label: CircleAvatar(
                        radius: 10,
                        backgroundColor: color,
                        child: selectedColor == value
                            ? const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.black,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Icono',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categoryIconChoices.map((icon) {
                    return ChoiceChip(
                      tooltip: 'Elegir icono',
                      showCheckmark: false,
                      selected: selectedIcon == icon.codePoint,
                      selectedColor: Color(
                        selectedColor,
                      ).withValues(alpha: .24),
                      onSelected: (_) =>
                          setDialogState(() => selectedIcon = icon.codePoint),
                      label: Icon(
                        icon,
                        color: selectedIcon == icon.codePoint
                            ? Color(selectedColor)
                            : AppColors.textSecondary,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final repository = ref.read(categoriesRepositoryProvider);
                if (repository == null) return;
                final now = DateTime.now().toUtc();
                final value = FinanceCategory(
                  id: category?.id ?? ref.read(uuidProvider).v4(),
                  userId: repository.userId,
                  name: controller.text.trim(),
                  type: selectedType,
                  parentId: parentId,
                  iconCodePoint: selectedIcon,
                  colorValue: selectedColor,
                  order:
                      category?.order ?? DateTime.now().millisecondsSinceEpoch,
                  active: category?.active ?? true,
                  createdAt: category?.createdAt ?? now,
                  updatedAt: now,
                  version: (category?.version ?? 0) + 1,
                );
                category == null
                    ? await repository.create(value)
                    : await repository.update(value);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}
