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
  final List<String> _navigationHistory = ['/dashboard'];
  bool _isUnlocked = false;

  void _navigateTo(String route) {
    if (route == _currentRoute) return;
    setState(() {
      if (route == '/dashboard') {
        _navigationHistory.clear();
        _navigationHistory.add('/dashboard');
      } else {
        _navigationHistory.remove(route);
        _navigationHistory.add(route);
      }
      _currentRoute = route;
    });
  }

  void _pop() {
    if (_navigationHistory.length > 1) {
      setState(() {
        _navigationHistory.removeLast();
        _currentRoute = _navigationHistory.last;
      });
    } else if (_currentRoute != '/dashboard') {
      setState(() {
        _currentRoute = '/dashboard';
        _navigationHistory.clear();
        _navigationHistory.add('/dashboard');
      });
    }
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

          final primaryRoutes = [
            '/dashboard',
            '/accounts',
            '/transactions',
            '/analytics',
            '/settings',
          ];

          final primaryIndex = primaryRoutes.indexOf(_currentRoute);
          final isPrimaryTab = primaryIndex != -1;

          // Sub-screens router
          Widget subScreenWidget;
          switch (_currentRoute) {
            case '/inbox':
              subScreenWidget = InboxScreen(onNavigate: _navigateTo);
              break;
            case '/budgets':
              subScreenWidget = BudgetsScreen(onNavigate: _navigateTo, initialTab: 'budgets');
              break;
            case '/goals':
              subScreenWidget = BudgetsScreen(onNavigate: _navigateTo, initialTab: 'goals');
              break;
            case '/rules':
              subScreenWidget = RulesScreen(onNavigate: _navigateTo);
              break;
            case '/recurring':
              subScreenWidget = RecurringScreen(onNavigate: _navigateTo);
              break;
            case '/debts':
              subScreenWidget = DebtsScreen(onNavigate: _navigateTo);
              break;
            case '/copilot':
              subScreenWidget = CopilotScreen(onNavigate: _navigateTo);
              break;
            case '/split_expenses':
              subScreenWidget = SplitExpensesScreen(onNavigate: _navigateTo);
              break;
            case '/investments':
              subScreenWidget = InvestmentsScreen(onNavigate: _navigateTo);
              break;
            case '/gift_cards':
            case '/shopping_lists':
            case '/warranties':
            case '/family_mode':
              subScreenWidget = FeatureHubScreen(
                route: _currentRoute,
                onNavigate: _navigateTo,
              );
              break;
            case '/backup':
              subScreenWidget = BackupScreen(onNavigate: _navigateTo);
              break;
            default:
              subScreenWidget = const SizedBox.shrink();
              break;
          }

          return PopScope(
            canPop: _navigationHistory.length <= 1 && _currentRoute == '/dashboard',
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                _pop();
              }
            },
            child: Scaffold(
              body: isPrimaryTab
                  ? IndexedStack(
                      index: primaryIndex,
                      children: [
                        DashboardScreen(
                          onOpenAddTransaction: _openAddTransaction,
                          onNavigate: _navigateTo,
                        ),
                        AccountsScreen(onNavigate: _navigateTo),
                        TransactionsScreen(onNavigate: _navigateTo),
                        ReportsScreen(onNavigate: _navigateTo),
                        SettingsScreen(onNavigate: _navigateTo),
                      ],
                    )
                  : subScreenWidget,
              bottomNavigationBar: isPrimaryTab
                  ? AppBottomNavBar(
                      currentRoute: _currentRoute,
                      onNavigate: _navigateTo,
                    )
                  : null,
            ),
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
