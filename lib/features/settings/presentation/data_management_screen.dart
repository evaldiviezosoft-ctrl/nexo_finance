import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../reports/data/backup_import_service.dart';
import '../data/data_management_service.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool working = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Datos y privacidad')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
      children: [
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('Exportar información'),
          subtitle: const Text('CSV, PDF o copia completa JSON'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: working ? null : () => context.push('/export'),
        ),
        ListTile(
          leading: const Icon(Icons.settings_backup_restore_rounded),
          title: const Text('Importar copia JSON'),
          subtitle: const Text('Valida el archivo y combina sus registros.'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: working ? null : _importBackup,
        ),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('Borrar caché local'),
          subtitle: const Text(
            'Cierra la sesión y descarga nuevamente los datos al volver.',
          ),
          onTap: working ? null : _clearCache,
        ),
        const Divider(),
        ListTile(
          iconColor: AppColors.primary,
          textColor: AppColors.primary,
          leading: const Icon(Icons.delete_forever_outlined),
          title: const Text('Eliminar cuenta y todos los datos'),
          subtitle: const Text('Esta acción no se puede deshacer.'),
          onTap: working ? null : _deleteAccount,
        ),
        if (working)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    ),
  );

  Future<void> _importBackup() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Selecciona una copia de Nexo Finance',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null || !mounted) return;
    try {
      final bytes = await file.readAsBytes();
      final decoded = BackupImportService.decodeAndValidate(bytes);
      final summary = BackupImportService.summary(decoded);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Importar copia'),
          content: Text(
            'Se validaron ${summary.total} registros. Los identificadores iguales se actualizarán y los demás se agregarán. Nada se elimina.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Importar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => working = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('La sesión ya no está disponible.');
      await BackupImportService(
        FirebaseFirestore.instance,
        user.uid,
      ).restore(bytes);
      if (mounted) _message('${summary.total} registros importados.');
    } catch (error) {
      if (mounted) _message('No se pudo importar: $error');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await _confirm(
      title: '¿Borrar caché local?',
      message:
          'La app cerrará la sesión y se cerrará. Tus datos sincronizados permanecerán en Firebase.',
      action: 'Borrar caché',
    );
    if (!confirmed || !mounted) return;
    setState(() => working = true);
    await DataManagementService().clearLocalCache();
    await SystemNavigator.pop();
  }

  Future<void> _deleteAccount() async {
    final first = await _confirm(
      title: 'Eliminar cuenta',
      message:
          'Se eliminarán cuentas, movimientos, metas, deudas y configuraciones sincronizadas.',
      action: 'Continuar',
    );
    if (!first || !mounted) return;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmación final'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Escribe ELIMINAR',
            helperText: 'Esta acción es permanente.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text == 'ELIMINAR'),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => working = true);
    try {
      await DataManagementService().deleteAccountAndData();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _message(
          error.code == 'requires-recent-login'
              ? 'Por seguridad, cierra sesión, vuelve a ingresar y repite la eliminación.'
              : 'No se pudo eliminar la cuenta: ${error.message}',
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
