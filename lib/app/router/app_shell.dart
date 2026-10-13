import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _openQuickEntry(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _QuickEntrySheet(),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    floatingActionButton: FloatingActionButton(
      heroTag: null,
      tooltip: 'Registrar movimiento',
      onPressed: () => _openQuickEntry(context),
      child: const Icon(Icons.add_rounded, size: 30),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.swap_horiz_rounded),
          label: 'Movimientos',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          label: 'Plan',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          label: 'Reportes',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: 'Ajustes',
        ),
      ],
    ),
  );
}

class _QuickEntrySheet extends StatelessWidget {
  const _QuickEntrySheet();

  static const items = [
    (Icons.north_east_rounded, 'Gasto', AppColors.primary, 'expense'),
    (Icons.south_west_rounded, 'Ingreso', AppColors.positive, 'income'),
    (Icons.swap_horiz_rounded, 'Transferencia', AppColors.info, 'transfer'),
    (
      Icons.credit_card_rounded,
      'Compra con tarjeta',
      AppColors.warning,
      'creditPurchase',
    ),
    (Icons.payment_rounded, 'Pago de tarjeta', AppColors.info, 'creditPayment'),
    (
      Icons.person_add_alt_rounded,
      'Préstamo entregado',
      AppColors.warning,
      'loanGiven',
    ),
    (
      Icons.handshake_outlined,
      'Cobro de préstamo',
      AppColors.positive,
      'loanRepayment',
    ),
    (Icons.flag_outlined, 'Aporte a meta', AppColors.info, 'goalContribution'),
    (
      Icons.price_check_rounded,
      'Pago de deuda',
      AppColors.primary,
      'debtPayment',
    ),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nuevo movimiento',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: .95,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  final path = switch (item.$4) {
                    'goalContribution' => '/plan?tab=goals',
                    'debtPayment' || 'loanRepayment' => '/plan?tab=debts',
                    _ => '/transactions/new?kind=${item.$4}',
                  };
                  if (path.startsWith('/plan')) {
                    router.go(path);
                  } else {
                    router.push(path);
                  }
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.$1, color: item.$3),
                        const SizedBox(height: 8),
                        Text(
                          item.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}
