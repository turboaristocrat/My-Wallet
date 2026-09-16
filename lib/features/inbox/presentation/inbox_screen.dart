import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/data/account_repository.dart';
import '../../auth/presentation/lock_screen.dart';
import '../../navigation/presentation/side_drawer.dart';
import '../../sms/data/sms_scanner_service.dart';
import '../data/queue_repository.dart';

class InboxScreen extends ConsumerStatefulWidget {
  final ValueChanged<String> onNavigate;
  const InboxScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  String _filter = 'all'; // 'all', 'today', 'week'
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadSmsScanDays();
  }

  Future<void> _loadSmsScanDays() async {
    final storage = ref.read(secureStorageProvider);
    final val = await storage.read(key: 'sms_scan_days');
    if (val != null) {
      final parsed = int.tryParse(val);
      if (parsed != null && mounted) {
        ref.read(smsScanDaysProvider.notifier).state = parsed;
      }
    }
  }

  Future<void> _scanSmsInbox() async {
    setState(() => _isScanning = true);
    final scanner = ref.read(smsScannerServiceProvider);
    final accounts = ref.read(activeAccountsStreamProvider).value ?? [];
    final scanDays = ref.read(smsScanDaysProvider);
    final windowLabel = formatScanDaysLabel(scanDays);

    try {
      final report = await scanner.scanInbox(
        days: scanDays,
        activeAccounts: accounts,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            report.importedCount > 0
                ? 'Scanned $windowLabel (${report.totalScanned} SMS) • Found & staged ${report.importedCount} transactions!'
                : report.totalScanned > 0
                    ? 'Scanned $windowLabel (${report.totalScanned} SMS) • No new bank transactions found (${report.skippedDuplicates} duplicates skipped).'
                    : 'SMS permission not granted or no SMS found in $windowLabel.',
          ),
          backgroundColor: report.importedCount > 0 ? AppColors.income : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning SMS: $e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _injectDemoSms() async {
    setState(() => _isScanning = true);
    final scanner = ref.read(smsScannerServiceProvider);
    final accounts = ref.read(activeAccountsStreamProvider).value ?? [];
    try {
      final count = await scanner.injectDemoTransactions(accounts);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Injected $count demo bank transactions into Inbox!'),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

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
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Text(
              'Inbox',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(width: 10),
            queueAsync.maybeWhen(
              data: (items) => items.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.expense,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.expense.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
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
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppStyles.heroGlowShadow,
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () async {
                          final accounts = accountsAsync.value ?? [];
                          if (accounts.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please add an account first in Accounts screen'),
                              ),
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
                        icon: const Icon(Icons.done_all_rounded, size: 16, color: Colors.white),
                        label: const Text(
                          'Approve All',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(),
            orElse: () => const SizedBox(),
          ),
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: 'Scan SMS',
            onPressed: _isScanning ? null : _scanSmsInbox,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'scan') _scanSmsInbox();
              if (val == 'demo') _injectDemoSms();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'scan',
                child: Row(
                  children: [
                    Icon(Icons.sms_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Scan SMS Inbox'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'demo',
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 20, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text('Inject Demo SMS'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterPill('All', 'all', isDark),
                const SizedBox(width: 8),
                _buildFilterPill('Today', 'today', isDark),
                const SizedBox(width: 8),
                _buildFilterPill('This Week', 'week', isDark),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
          ),

          // Queue Items List
          Expanded(
            child: queueAsync.when(
              data: (allItems) {
                // Apply filter
                final now = DateTime.now();
                final items = allItems.where((item) {
                  if (_filter == 'today') {
                    return item.receivedAt.year == now.year &&
                        item.receivedAt.month == now.month &&
                        item.receivedAt.day == now.day;
                  } else if (_filter == 'week') {
                    final diff = now.difference(item.receivedAt).inDays;
                    return diff <= 7;
                  }
                  return true;
                }).toList();

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              color: AppColors.income.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.income.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.celebration_rounded,
                              color: AppColors.income,
                              size: 52,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Inbox Zero! 🎉',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'All incoming transactions have been verified and processed. Your wallet records are pristine!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton.icon(
                            onPressed: _isScanning ? null : _scanSmsInbox,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: _isScanning
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.sms_rounded),
                            label: Text(
                              'Scan SMS Inbox (${formatScanDaysLabel(ref.watch(smsScanDaysProvider))})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: () => widget.onNavigate('/settings'),
                            icon: const Icon(Icons.tune_rounded, size: 14),
                            label: Text(
                              'Range: ${formatScanDaysLabel(ref.watch(smsScanDaysProvider))} • Change in Settings',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _isScanning ? null : _injectDemoSms,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.bolt_rounded,
                                color: AppColors.primary, size: 20),
                            label: Text(
                              'Test with Demo SMS',
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
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
                          borderRadius: AppStyles.roundedL,
                        ),
                        alignment: Alignment.centerLeft,
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 26),
                            SizedBox(width: 10),
                            Text(
                              'Approve',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
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
                          borderRadius: AppStyles.roundedL,
                        ),
                        alignment: Alignment.centerRight,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Dismiss',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.cancel_rounded,
                                color: Colors.white, size: 26),
                          ],
                        ),
                      ),
                      onDismissed: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          // Approve
                          final accounts = accountsAsync.value ?? [];
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
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkCard
                              : AppColors.lightCard,
                          borderRadius: AppStyles.roundedL,
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
                            // Top strip: Sender + Time
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.sms_rounded,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item.sender,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  DateFormat('dd MMM • hh:mm a')
                                      .format(item.receivedAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkTextTertiary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Center: Merchant name + Amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.suggestedMerchant ??
                                        'Transaction Alert',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.lightTextPrimary,
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
                                    letterSpacing: -0.3,
                                    color: AppColors.expense,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Bottom Strip: AI Confidence Tag + One-tap buttons for Desktop/Web convenience
                            Row(
                              children: [
                                // AI or Regex Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: item.parserUsed == 'regex'
                                        ? AppColors.primary.withValues(alpha: 0.16)
                                        : AppColors.aiBadge.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: item.parserUsed == 'regex'
                                          ? AppColors.primary.withValues(alpha: 0.3)
                                          : AppColors.aiBadge.withValues(alpha: 0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        item.parserUsed == 'regex'
                                            ? Icons.check_circle_outline_rounded
                                            : Icons.auto_awesome_rounded,
                                        size: 11,
                                        color: item.parserUsed == 'regex'
                                            ? AppColors.primaryLight
                                            : AppColors.aiBadge,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.parserUsed == 'regex'
                                            ? 'Regex 100%'
                                            : 'AI ${(item.confidenceScore! * 100).toInt()}%',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: item.parserUsed == 'regex'
                                              ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                              : AppColors.aiBadge,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),

                                // Dismiss button
                                InkWell(
                                  onTap: () async {
                                    await queueRepo.dismissItem(item.id);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.expense.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.close_rounded,
                                            size: 14, color: AppColors.expense),
                                        SizedBox(width: 4),
                                        Text(
                                          'Dismiss',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.expense,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Approve button
                                InkWell(
                                  onTap: () async {
                                    final accounts = accountsAsync.value ?? [];
                                    if (accounts.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please add an account first in Accounts'),
                                        ),
                                      );
                                      return;
                                    }
                                    await queueRepo.approveItem(
                                      queueId: item.id,
                                      accountId: item.suggestedAccountId ?? accounts.first.id,
                                      amount: item.suggestedAmount ?? 0.0,
                                      merchantName: item.suggestedMerchant,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: AppStyles.heroGlowShadow,
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_rounded,
                                            size: 14, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          'Approve',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  Widget _buildFilterPill(String label, String value, bool isDark) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected
              ? null
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
          boxShadow: isSelected ? AppStyles.heroGlowShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}

