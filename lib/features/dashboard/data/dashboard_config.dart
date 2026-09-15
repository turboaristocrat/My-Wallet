import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DashboardWidgetType {
  kpiCards,
  myAccounts,
  revenueAnalysis,
  goals,
  expenseDonut,
  quickTransfer,
  recentTransactions,
}

class DashboardConfig {
  final bool showKpiCards;
  final bool showMyAccounts;
  final bool showRevenueAnalysis;
  final bool showGoals;
  final bool showExpenseDonut;
  final bool showQuickTransfer;
  final bool showRecentTransactions;

  const DashboardConfig({
    this.showKpiCards = true,
    this.showMyAccounts = true,
    this.showRevenueAnalysis = true,
    this.showGoals = true,
    this.showExpenseDonut = true,
    this.showQuickTransfer = true,
    this.showRecentTransactions = true,
  });

  DashboardConfig copyWith({
    bool? showKpiCards,
    bool? showMyAccounts,
    bool? showRevenueAnalysis,
    bool? showGoals,
    bool? showExpenseDonut,
    bool? showQuickTransfer,
    bool? showRecentTransactions,
  }) {
    return DashboardConfig(
      showKpiCards: showKpiCards ?? this.showKpiCards,
      showMyAccounts: showMyAccounts ?? this.showMyAccounts,
      showRevenueAnalysis: showRevenueAnalysis ?? this.showRevenueAnalysis,
      showGoals: showGoals ?? this.showGoals,
      showExpenseDonut: showExpenseDonut ?? this.showExpenseDonut,
      showQuickTransfer: showQuickTransfer ?? this.showQuickTransfer,
      showRecentTransactions:
          showRecentTransactions ?? this.showRecentTransactions,
    );
  }
}

class DashboardConfigNotifier extends Notifier<DashboardConfig> {
  @override
  DashboardConfig build() => const DashboardConfig();

  void toggleWidget(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.kpiCards:
        state = state.copyWith(showKpiCards: !state.showKpiCards);
        break;
      case DashboardWidgetType.myAccounts:
        state = state.copyWith(showMyAccounts: !state.showMyAccounts);
        break;
      case DashboardWidgetType.revenueAnalysis:
        state = state.copyWith(showRevenueAnalysis: !state.showRevenueAnalysis);
        break;
      case DashboardWidgetType.goals:
        state = state.copyWith(showGoals: !state.showGoals);
        break;
      case DashboardWidgetType.expenseDonut:
        state = state.copyWith(showExpenseDonut: !state.showExpenseDonut);
        break;
      case DashboardWidgetType.quickTransfer:
        state = state.copyWith(showQuickTransfer: !state.showQuickTransfer);
        break;
      case DashboardWidgetType.recentTransactions:
        state = state.copyWith(
            showRecentTransactions: !state.showRecentTransactions);
        break;
    }
  }

  void resetDefaults() {
    state = const DashboardConfig();
  }
}

final dashboardConfigProvider =
    NotifierProvider<DashboardConfigNotifier, DashboardConfig>(
        DashboardConfigNotifier.new);

