import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/domain/financial_account.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/firebase_setup_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/plan/presentation/financial_plan_screen.dart';
import '../../features/reports/presentation/export_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/notifications/presentation/notification_settings_screen.dart';
import '../../features/security/presentation/security_settings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/data_management_screen.dart';
import '../../features/settings/presentation/appearance_settings_screen.dart';
import '../../features/settings/presentation/sync_status_screen.dart';
import '../../features/transactions/domain/financial_transaction.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../bootstrap/firebase_bootstrap.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final firebase = ref.watch(firebaseBootstrapProvider);
  final auth = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (!firebase.isReady) {
        return location == '/setup' ? null : '/setup';
      }
      if (auth.isLoading) return location == '/splash' ? null : '/splash';
      final signedIn = auth.value != null;
      if (!signedIn) return location == '/login' ? null : '/login';
      if (location == '/login' ||
          location == '/splash' ||
          location == '/setup') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/setup', builder: (_, _) => const FirebaseSetupScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/splash', builder: (_, _) => const _SplashScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (_, _) => const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plan',
                builder: (_, state) => FinancialPlanScreen(
                  initialTab: switch (state.uri.queryParameters['tab']) {
                    'goals' => 2,
                    'debts' => 3,
                    _ => 0,
                  },
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (_, _) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/accounts', builder: (_, _) => const AccountsScreen()),
      GoRoute(
        path: '/accounts/new',
        builder: (_, _) => const AccountFormScreen(),
      ),
      GoRoute(
        path: '/accounts/:id',
        builder: (_, state) =>
            AccountFormScreen(account: state.extra! as FinancialAccount),
      ),
      GoRoute(path: '/categories', builder: (_, _) => const CategoriesScreen()),
      GoRoute(path: '/export', builder: (_, _) => const ExportScreen()),
      GoRoute(
        path: '/security',
        builder: (_, _) => const SecuritySettingsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationSettingsScreen(),
      ),
      GoRoute(path: '/data', builder: (_, _) => const DataManagementScreen()),
      GoRoute(path: '/sync', builder: (_, _) => const SyncStatusScreen()),
      GoRoute(
        path: '/appearance',
        builder: (_, _) => const AppearanceSettingsScreen(),
      ),
      GoRoute(
        path: '/transactions/new',
        builder: (_, state) {
          final source = state.uri.queryParameters['kind'];
          final kind =
              TransactionKind.values
                  .where((item) => item.name == source)
                  .firstOrNull ??
              TransactionKind.expense;
          return TransactionFormScreen(
            initialKind: kind.requiresManagedTarget
                ? TransactionKind.expense
                : kind,
            transaction: state.extra as FinancialTransaction?,
            duplicate: state.uri.queryParameters['duplicate'] == 'true',
          );
        },
      ),
      GoRoute(
        path: '/transactions/:id',
        builder: (_, state) => TransactionFormScreen(
          initialKind: (state.extra! as FinancialTransaction).kind,
          transaction: state.extra! as FinancialTransaction,
        ),
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
