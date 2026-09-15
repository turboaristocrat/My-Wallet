import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/theme_provider.dart';
import 'features/accounts/presentation/accounts_screen.dart';
import 'features/auth/presentation/lock_screen.dart';
import 'features/backup/presentation/backup_screen.dart';
import 'features/budgets/presentation/budgets_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/debts/presentation/debts_screen.dart';
import 'features/inbox/presentation/inbox_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/recurring/presentation/recurring_screen.dart';
import 'features/reports/presentation/reports_screen.dart';
import 'features/rules/presentation/rules_screen.dart';
import 'features/copilot/presentation/copilot_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/split/presentation/split_expenses_screen.dart';
import 'features/extras/presentation/feature_hub_screen.dart';
import 'features/investments/presentation/investments_screen.dart';
import 'features/navigation/presentation/app_bottom_nav_bar.dart';
import 'features/transactions/presentation/add_transaction_sheet.dart';
import 'features/transactions/presentation/transactions_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

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
    final navContext = rootNavigatorKey.currentContext;
    if (navContext != null) {
      showModalBottomSheet(
        context: navContext,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const AddTransactionSheet(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final appStateAsync = ref.watch(appStateProvider);

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
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
          Widget screenWidget;
          switch (_currentRoute) {
            case '/inbox':
              screenWidget = InboxScreen(onNavigate: _navigateTo);
              break;
            case '/accounts':
              screenWidget = AccountsScreen(onNavigate: _navigateTo);
              break;
            case '/transactions':
              screenWidget = TransactionsScreen(onNavigate: _navigateTo);
              break;
            case '/analytics':
              screenWidget = ReportsScreen(onNavigate: _navigateTo);
              break;
            case '/budgets':
              screenWidget = BudgetsScreen(onNavigate: _navigateTo, initialTab: 'budgets');
              break;
            case '/goals':
              screenWidget = BudgetsScreen(onNavigate: _navigateTo, initialTab: 'goals');
              break;
            case '/rules':
              screenWidget = RulesScreen(onNavigate: _navigateTo);
              break;
            case '/recurring':
              screenWidget = RecurringScreen(onNavigate: _navigateTo);
              break;
            case '/debts':
              screenWidget = DebtsScreen(onNavigate: _navigateTo);
              break;
            case '/copilot':
              screenWidget = CopilotScreen(onNavigate: _navigateTo);
              break;
            case '/split_expenses':
              screenWidget = SplitExpensesScreen(onNavigate: _navigateTo);
              break;
            case '/investments':
              screenWidget = InvestmentsScreen(onNavigate: _navigateTo);
              break;
            case '/gift_cards':
            case '/shopping_lists':
            case '/warranties':
            case '/family_mode':
              screenWidget = FeatureHubScreen(
                route: _currentRoute,
                onNavigate: _navigateTo,
              );
              break;
            case '/settings':
              screenWidget = SettingsScreen(onNavigate: _navigateTo);
              break;
            case '/backup':
              screenWidget = BackupScreen(onNavigate: _navigateTo);
              break;
            case '/dashboard':
            default:
              screenWidget = DashboardScreen(
                onOpenAddTransaction: _openAddTransaction,
                onNavigate: _navigateTo,
              );
              break;
          }

          final showBottomNav = [
            '/dashboard',
            '/accounts',
            '/transactions',
            '/analytics',
            '/settings',
          ].contains(_currentRoute);

          return Scaffold(
            body: screenWidget,
            bottomNavigationBar: showBottomNav
                ? AppBottomNavBar(
                    currentRoute: _currentRoute,
                    onNavigate: _navigateTo,
                  )
                : null,
          );
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
