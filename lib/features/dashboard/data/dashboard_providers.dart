import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../accounts/data/account_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../inbox/data/queue_repository.dart';

/// Display mode for My Accounts section (swiping card carousel vs tiles grid)
enum AccountsDisplayMode { carousel, tiles }

final accountsDisplayModeProvider =
    StateProvider<AccountsDisplayMode>((ref) => AccountsDisplayMode.carousel);

/// Computed Total Balance across all active accounts
final totalBalanceProvider = Provider<double>((ref) {
  final accountsAsync = ref.watch(activeAccountsStreamProvider);
  return accountsAsync.maybeWhen(
    data: (accounts) =>
        accounts.fold(0.0, (sum, acc) => sum + acc.balance),
    orElse: () => 0.0,
  );
});

/// Computed Monthly Income & Expense totals
class MonthlyFlow {
  final double income;
  final double expense;
  const MonthlyFlow({this.income = 0.0, this.expense = 0.0});
}

final monthlyFlowProvider = StreamProvider<MonthlyFlow>((ref) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  return ref
      .watch(transactionRepositoryProvider)
      .watchFilteredTransactions(
        startDate: startOfMonth,
        endDate: endOfMonth,
      )
      .map((txns) {
    double inc = 0.0;
    double exp = 0.0;
    for (final t in txns) {
      if (t.type == 'income') {
        inc += t.amount;
      } else if (t.type == 'expense') {
        exp += t.amount;
      }
    }
    return MonthlyFlow(income: inc, expense: exp);
  });
});

/// Live pending queue count for the Inbox badge in side drawer
final pendingQueueCountProvider = Provider<int>((ref) {
  final queueAsync = ref.watch(pendingQueueStreamProvider);
  return queueAsync.maybeWhen(
    data: (items) => items.length,
    orElse: () => 0,
  );
});
