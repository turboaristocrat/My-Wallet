import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/theme_provider.dart';
import 'features/accounts/presentation/accounts_screen.dart';
import 'features/auth/presentation/lock_screen.dart';
import 'features/budgets/presentation/budgets_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/inbox/presentation/inbox_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/recurring/presentation/recurring_screen.dart';
import 'features/reports/presentation/reports_screen.dart';
import 'features/rules/presentation/rules_screen.dart';
import 'features/transactions/presentation/add_transaction_sheet.dart';
import 'features/transactions/presentation/transactions_screen.dart';

final appStateProvider = FutureProvider<String>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  final onboardingDone = await storage.read(key: 'onboarding_complete');
  if (onboardingDone != 'true') {
    return 'onboarding';
  }
  return 'locked';
});

class MyWalletApp extends ConsumerStatefulWidget {
  const MyWalletApp({super.key});

  @override
  ConsumerState<MyWalletApp> createState() => _MyWalletAppState();
}

class _MyWalletAppState extends ConsumerState<MyWalletApp> {
  String _currentRoute = '/dashboard';
  bool _isUnlocked = false;

  void _navigateTo(String route) {
    setState(() => _currentRoute = route);
  }

  void _openAddTransaction() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddTransactionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final appStateAsync = ref.watch(appStateProvider);

    return MaterialApp(
      title: 'My Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: appStateAsync.when(
        data: (state) {
          if (state == 'onboarding') {
            return OnboardingScreen(
              onComplete: () {
                ref.invalidate(appStateProvider);
                setState(() => _isUnlocked = true);
              },
            );
          }

          if (!_isUnlocked) {
            return LockScreen(
              onUnlocked: () {
                setState(() => _isUnlocked = true);
              },
            );
          }

          // Main Navigation Router
          switch (_currentRoute) {
            case '/inbox':
              return InboxScreen(onNavigate: _navigateTo);
            case '/accounts':
              return AccountsScreen(onNavigate: _navigateTo);
            case '/transactions':
              return TransactionsScreen(onNavigate: _navigateTo);
            case '/analytics':
              return ReportsScreen(onNavigate: _navigateTo);
            case '/budgets':
              return BudgetsScreen(onNavigate: _navigateTo, initialTab: 'budgets');
            case '/goals':
              return BudgetsScreen(onNavigate: _navigateTo, initialTab: 'goals');
            case '/rules':
              return RulesScreen(onNavigate: _navigateTo);
            case '/recurring':
              return RecurringScreen(onNavigate: _navigateTo);
            case '/dashboard':
            default:
              return DashboardScreen(
                onOpenAddTransaction: _openAddTransaction,
                onNavigate: _navigateTo,
              );
          }
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Scaffold(
          body: DashboardScreen(
            onOpenAddTransaction: _openAddTransaction,
            onNavigate: _navigateTo,
          ),
        ),
      ),
    );
  }
}
