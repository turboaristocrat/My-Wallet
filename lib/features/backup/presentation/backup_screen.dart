import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../navigation/presentation/side_drawer.dart';
import '../data/backup_repository.dart';

class BackupScreen extends ConsumerStatefulWidget {
  final void Function(String route) onNavigate;

  const BackupScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: AppSideDrawer(
        currentRoute: '/backup',
        onNavigate: widget.onNavigate,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Top App Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.menu_rounded,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                              size: 26,
                            ),
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Backup & Export',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                                Text(
                                  'Data sovereignty & complete portability',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Body Content
                  SliverList(
                    delegate: SliverChildListDelegate([
                      // Hero Data Privacy Banner
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildPrivacyHeroBanner(isDark),
                      ),
                      const SizedBox(height: 24),

                      // Section 1: Spreadsheet / CSV Exports
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildSectionHeader(
                          isDark,
                          title: 'Spreadsheet Exports (CSV)',
                          subtitle: 'Open in Excel, Apple Numbers, or Google Sheets',
                          icon: Icons.table_chart_rounded,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildActionCard(
                          isDark: isDark,
                          title: 'Export Transactions (CSV)',
                          description:
                              'All expenses, income, transfers, merchants, categories, and payment types.',
                          icon: Icons.receipt_long_rounded,
                          buttonLabel: 'Export Transactions CSV',
                          buttonGradient: AppColors.cardGradientCyanPurple,
                          onTap: () => _handleExportTransactionsCsv(context),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildActionCard(
                          isDark: isDark,
                          title: 'Export Accounts & Balances (CSV)',
                          description:
                              'All bank accounts, credit cards, digital wallets, and current balances.',
                          icon: Icons.account_balance_rounded,
                          buttonLabel: 'Export Accounts CSV',
                          buttonGradient: AppColors.cardGradientCyanPurple,
                          onTap: () => _handleExportAccountsCsv(context),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Section 2: Complete Database Snapshots
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildSectionHeader(
                          isDark,
                          title: 'Database Backup & Restore',
                          subtitle:
                              'Full local snapshot including budgets, rules, goals & debts',
                          icon: Icons.save_rounded,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildActionCard(
                          isDark: isDark,
                          title: 'Create Full Database Backup (JSON)',
                          description:
                              'Complete portable snapshot of all 14 tables in structured JSON format.',
                          icon: Icons.backup_rounded,
                          buttonLabel: 'Generate Backup JSON',
                          buttonGradient: AppColors.cardGradientViolet,
                          onTap: () => _handleGenerateFullBackup(context),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildActionCard(
                          isDark: isDark,
                          title: 'Restore Database from Backup',
                          description:
                              'Paste or load a previously exported JSON backup to recover your records.',
                          icon: Icons.restore_page_rounded,
                          buttonLabel: 'Restore from Backup',
                          buttonGradient: AppColors.cardGradientViolet,
                          onTap: () => _handleRestoreBackup(context),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Section 3: Danger Zone
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildSectionHeader(
                          isDark,
                          title: 'Danger Zone',
                          subtitle: 'Permanent destructive operations',
                          icon: Icons.warning_amber_rounded,
                          isDanger: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildDangerCard(isDark, context),
                      ),
                      const SizedBox(height: 36),
                    ]),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPrivacyHeroBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradientViolet,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '100% Local Data Ownership',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Your financial transactions, accounts, and bank messages are stored exclusively on your device. You can export or migrate your data at any time with zero vendor lock-in.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    bool isDanger = false,
  }) {
    final color = isDanger
        ? AppColors.expense
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required bool isDark,
    required String title,
    required String description,
    required IconData icon,
    required String buttonLabel,
    required LinearGradient buttonGradient,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: buttonGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerCard(bool isDark, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.expense.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.delete_forever_rounded, color: AppColors.expense, size: 22),
              SizedBox(width: 10),
              Text(
                'Erase All Local Data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Permanently delete all accounts, transactions, rules, budgets, and debts from this device. This action cannot be undone.',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.expense),
                foregroundColor: AppColors.expense,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _confirmResetData(context),
              child: const Text(
                'Reset Database & Clear All',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExportTransactionsCsv(BuildContext context) async {
    setState(() => _isLoading = true);
    final csv =
        await ref.read(backupRepositoryProvider).exportTransactionsToCsv();
    setState(() => _isLoading = false);

    if (context.mounted) {
      _showDataPreviewDialog(
        context: context,
        title: 'Transactions CSV Export',
        content: csv,
        filename: 'my_wallet_transactions_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    }
  }

  Future<void> _handleExportAccountsCsv(BuildContext context) async {
    setState(() => _isLoading = true);
    final csv = await ref.read(backupRepositoryProvider).exportAccountsToCsv();
    setState(() => _isLoading = false);

    if (context.mounted) {
      _showDataPreviewDialog(
        context: context,
        title: 'Accounts & Balances CSV Export',
        content: csv,
        filename: 'my_wallet_accounts_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    }
  }

  Future<void> _handleGenerateFullBackup(BuildContext context) async {
    setState(() => _isLoading = true);
    final jsonStr =
        await ref.read(backupRepositoryProvider).generateFullBackupJson();
    setState(() => _isLoading = false);

    if (context.mounted) {
      _showDataPreviewDialog(
        context: context,
        title: 'Full Database Backup (JSON)',
        content: jsonStr,
        filename: 'my_wallet_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
      );
    }
  }

  void _showDataPreviewDialog({
    required BuildContext context,
    required String title,
    required String content,
    required String filename,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File: $filename (${content.length} bytes)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      content,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$title copied to clipboard!'),
                  backgroundColor: AppColors.incomeGreen,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  void _handleRestoreBackup(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Restore Database Backup',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the complete JSON backup string below to restore your records:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: '{\n  "metadata": ...,\n  "data": ...\n}',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;

              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);
              final result = await ref
                  .read(backupRepositoryProvider)
                  .restoreFromBackupJson(text);
              setState(() => _isLoading = false);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: result.isSuccess
                        ? AppColors.incomeGreen
                        : AppColors.expense,
                  ),
                );
              }
            },
            child: const Text('Restore Data'),
          ),
        ],
      ),
    );
  }

  void _confirmResetData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.expense),
            SizedBox(width: 8),
            Text('Reset All Data?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to erase all transactions, accounts, budgets, and debts? This action is permanent and cannot be undone.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);
              await ref.read(backupRepositoryProvider).clearAllUserData();
              setState(() => _isLoading = false);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All local user data has been cleared.'),
                    backgroundColor: AppColors.expense,
                  ),
                );
              }
            },
            child: const Text('Yes, Erase Everything'),
          ),
        ],
      ),
    );
  }
}
