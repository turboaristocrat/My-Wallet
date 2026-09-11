import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/data/account_repository.dart';
import '../../navigation/presentation/side_drawer.dart';
import '../../transactions/presentation/add_transaction_sheet.dart';
import '../data/queue_repository.dart';

class InboxScreen extends ConsumerStatefulWidget {
  final ValueChanged<String> onNavigate;
  const InboxScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  String _filter = 'all'; // 'all', 'today', 'week'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hideAmounts = ref.watch(hideAmountsProvider);
    final queueAsync = ref.watch(pendingQueueStreamProvider);
    final queueRepo = ref.read(queueRepositoryProvider);
    final accountsAsync = ref.watch(activeAccountsStreamProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: AppSideDrawer(
        currentRoute: '/inbox',
        onNavigate: widget.onNavigate,
      ),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Inbox'),
            const SizedBox(width: 8),
            queueAsync.maybeWhen(
              data: (items) => items.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.expense,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const SizedBox(),
              orElse: () => const SizedBox(),
            ),
          ],
        ),
        actions: [
          queueAsync.maybeWhen(
            data: (items) => items.isNotEmpty
                ? TextButton(
                    onPressed: () async {
                      final accounts =
                          accountsAsync.value ?? [];
                      if (accounts.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please add an account first')),
                        );
                        return;
                      }
                      for (final item in items) {
                        await queueRepo.approveItem(
                          queueId: item.id,
                          accountId: item.suggestedAccountId ??
                              accounts.first.id,
                          amount: item.suggestedAmount ?? 0.0,
                          merchantName: item.suggestedMerchant,
                        );
                      }
                    },
                    child: const Text('Approve All',
                        style: TextStyle(color: AppColors.primary)),
                  )
                : const SizedBox(),
            orElse: () => const SizedBox(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Today', 'today'),
                const SizedBox(width: 8),
                _buildFilterChip('This Week', 'week'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Queue Items List
          Expanded(
            child: queueAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.incomeContainer.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.celebration_rounded,
                              color: AppColors.income,
                              size: 54,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'All Caught Up! 🎉',
                            style: AppStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your wallet is clean and serene. Sit back, relax, and enjoy your financial peace of mind!',
                            textAlign: TextAlign.center,
                            style: AppStyles.bodyMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];

                    return Dismissible(
                      key: Key(item.id),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.only(left: 20),
                        decoration: BoxDecoration(
                          color: AppColors.income,
                          borderRadius: AppStyles.roundedM,
                        ),
                        alignment: Alignment.centerLeft,
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Approve',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      secondaryBackground: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.expense,
                          borderRadius: AppStyles.roundedM,
                        ),
                        alignment: Alignment.centerRight,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Dismiss',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.cancel_rounded,
                                color: Colors.white, size: 28),
                          ],
                        ),
                      ),
                      onDismissed: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          // Approve
                          final accounts =
                              accountsAsync.value ?? [];
                          await queueRepo.approveItem(
                            queueId: item.id,
                            accountId: item.suggestedAccountId ??
                                (accounts.isNotEmpty ? accounts.first.id : ''),
                            amount: item.suggestedAmount ?? 0.0,
                            merchantName: item.suggestedMerchant,
                          );
                        } else {
                          // Dismiss
                          await queueRepo.dismissItem(item.id);
                        }
                      },
                      child: InkWell(
                        onTap: () {
                          // Open edit sheet with prefilled values
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (_) => const AddTransactionSheet(),
                          );
                        },
                        borderRadius: AppStyles.roundedM,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                            borderRadius: AppStyles.roundedM,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                            boxShadow: AppStyles.softShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.sms_outlined,
                                          size: 16,
                                          color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        item.sender,
                                        style: AppStyles.labelSmall.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    DateFormat('hh:mm a')
                                        .format(item.receivedAt),
                                    style: AppStyles.labelSmall.copyWith(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.suggestedMerchant ??
                                          'Transaction Alert',
                                      style: AppStyles.titleMedium.copyWith(
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.lightTextPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(
                                      item.suggestedAmount ?? 0.0,
                                      hideAmount: hideAmounts,
                                      showSign: true,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.expense,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: item.parserUsed == 'regex'
                                          ? AppColors.primaryContainer
                                          : AppColors.aiBadgeContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.parserUsed == 'regex'
                                          ? 'Regex ✓'
                                          : 'AI ${(item.confidenceScore! * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: item.parserUsed == 'regex'
                                            ? AppColors.primary
                                            : AppColors.aiBadge,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Swipe right to confirm',
                                    style: AppStyles.labelSmall.copyWith(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filter = value);
      },
      selectedColor: AppColors.primary,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
    );
  }
}
