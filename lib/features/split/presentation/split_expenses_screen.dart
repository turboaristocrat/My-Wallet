import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../debts/data/debt_repository.dart';

class SplitParticipant {
  String name;
  double customAmount;
  bool isPayer;

  SplitParticipant({
    required this.name,
    this.customAmount = 0.0,
    this.isPayer = false,
  });
}

class SplitExpensesScreen extends ConsumerStatefulWidget {
  final void Function(String route) onNavigate;

  const SplitExpensesScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<SplitExpensesScreen> createState() => _SplitExpensesScreenState();
}

class _SplitExpensesScreenState extends ConsumerState<SplitExpensesScreen> {
  final _titleController = TextEditingController(text: 'Group Dinner');
  final _totalController = TextEditingController(text: '1200');
  final DateTime _expenseDate = DateTime.now();
  int _payerIndex = 0; // 0 = 'You'

  final List<TextEditingController> _participantControllers = [
    TextEditingController(text: 'You'),
    TextEditingController(text: 'Rahul'),
    TextEditingController(text: 'Priya'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    for (final c in _participantControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addParticipant() {
    setState(() {
      _participantControllers.add(
        TextEditingController(text: 'Friend ${_participantControllers.length}'),
      );
    });
  }

  void _removeParticipant(int index) {
    if (_participantControllers.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 participants required for splitting.')),
      );
      return;
    }
    setState(() {
      _participantControllers[index].dispose();
      _participantControllers.removeAt(index);
      if (_payerIndex >= _participantControllers.length) {
        _payerIndex = 0;
      }
    });
  }

  double get _totalAmount => double.tryParse(_totalController.text) ?? 0.0;
  double get _equalShare =>
      _participantControllers.isNotEmpty ? _totalAmount / _participantControllers.length : 0.0;

  String _generateShareText() {
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final buffer = StringBuffer();
    final title = _titleController.text.trim().isEmpty ? 'Group Expense' : _titleController.text.trim();
    final payerName = _participantControllers[_payerIndex].text.trim();

    buffer.writeln("🧾 *Bill Split: $title*");
    buffer.writeln("📅 Date: ${DateFormat('dd MMM yyyy').format(_expenseDate)}");
    buffer.writeln("💰 Total: ${fmt.format(_totalAmount)}");
    buffer.writeln("💳 Paid by: $payerName\n");
    buffer.writeln("*Breakdown:*");

    for (int i = 0; i < _participantControllers.length; i++) {
      final name = _participantControllers[i].text.trim();
      final isMe = (i == 0);
      final share = _equalShare;
      final label = isMe ? '$name (Your share)' : name;
      buffer.writeln("• $label: ${fmt.format(share)}");
    }

    if (_payerIndex == 0) {
      buffer.writeln("\nPlease send your share via UPI when you get a chance! 🙌");
    }

    return buffer.toString();
  }

  Future<void> _syncToDebts() async {
    final total = _totalAmount;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid total bill amount.')),
      );
      return;
    }

    final title = _titleController.text.trim().isEmpty ? 'Split Expense' : _titleController.text.trim();
    final debtRepo = ref.read(debtRepositoryProvider);
    final share = _equalShare;
    int syncedCount = 0;

    try {
      if (_payerIndex == 0) {
        // You paid: Other participants owe you
        for (int i = 1; i < _participantControllers.length; i++) {
          final friendName = _participantControllers[i].text.trim();
          if (friendName.isNotEmpty && share > 0) {
            await debtRepo.createDebt(
              debtType: 'i_lent',
              contactName: friendName,
              purpose: 'Split: $title',
              principalAmount: share,
            );
            syncedCount++;
          }
        }
      } else {
        // Someone else paid: You owe that person your share
        final payerName = _participantControllers[_payerIndex].text.trim();
        if (share > 0) {
          await debtRepo.createDebt(
            debtType: 'i_borrowed',
            contactName: payerName,
            purpose: 'Split: $title',
            principalAmount: share,
          );
          syncedCount = 1;
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.incomeGreen),
                SizedBox(width: 8),
                Text('Synced to Debts!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Created $syncedCount debt records in your Debts Tracker.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _generateShareText(),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy Breakdown'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _generateShareText()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Split breakdown copied to clipboard!')),
                  );
                },
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onNavigate('/debts');
                },
                child: const Text('View Debts'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing to debts: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => widget.onNavigate('/dashboard'),
        ),
        title: const Text('Split Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Copy Breakdown',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _generateShareText()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Breakdown copied to clipboard!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.primaryLight.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_split, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Group Bill Splitter',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Divide group dining, trips, or house bills and automatically sync balances to your Debts tracker.',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bill Title & Amount
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Expense Description',
                      hintText: 'e.g. Dinner, Airbnb',
                      prefixIcon: Icon(Icons.receipt_long),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _totalController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Total Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Who Paid Selector
            Text(
              'Who Paid the Bill?',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(_participantControllers.length, (index) {
                final isSelected = _payerIndex == index;
                final name = _participantControllers[index].text;
                return ChoiceChip(
                  label: Text(name.isEmpty ? 'Friend $index' : name),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  onSelected: (val) {
                    if (val) setState(() => _payerIndex = index);
                  },
                );
              }),
            ),
            const SizedBox(height: 20),

            // Participants Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Participants (${_participantControllers.length})',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Person'),
                  onPressed: _addParticipant,
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...List.generate(_participantControllers.length, (index) {
              final isMe = (index == 0);
              final share = _equalShare;
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isMe
                            ? AppColors.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        foregroundColor: isMe ? Colors.white : theme.colorScheme.onSurface,
                        child: Text(
                          isMe ? 'Me' : '${index + 1}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: isMe
                            ? const Text(
                                'You',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              )
                            : TextField(
                                controller: _participantControllers[index],
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: 'Enter name',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                      ),
                      Text(
                        fmt.format(share),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (!isMe)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _removeParticipant(index),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),

            // Summary Breakdown Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Equal Share Per Person:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        fmt.format(_equalShare),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _payerIndex == 0
                        ? '🎉 You paid the total bill. Each friend will owe you ${fmt.format(_equalShare)}.'
                        : 'ℹ️ ${_participantControllers[_payerIndex].text} paid the total bill. You will owe them ${fmt.format(_equalShare)}.',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.sync_alt),
                label: const Text(
                  'Record & Sync to Debts Tracker',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: _syncToDebts,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share Breakdown via WhatsApp / Text'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _generateShareText()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Breakdown copied to clipboard! Ready to paste.')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
