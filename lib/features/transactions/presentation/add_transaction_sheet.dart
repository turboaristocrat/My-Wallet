import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/database/app_database.dart';
import '../../accounts/data/account_repository.dart';
import '../../receipts/data/receipt_scanner_service.dart';
import '../data/transaction_repository.dart';
import '../../categories/presentation/manage_categories_dialog.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final Transaction? initialTransaction;
  final String? preselectedAccountId;

  const AddTransactionSheet({
    super.key,
    this.initialTransaction,
    this.preselectedAccountId,
  });

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  String _type = 'expense'; // 'expense', 'income', 'transfer'
  String _amountStr = '0';
  String? _selectedAccountId;
  String? _selectedToAccountId;
  String? _selectedCategoryId;
  final TextEditingController _payeeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _paymentType = 'upi';
  String _status = 'cleared';
  final List<String> _selectedTagIds = [];
  bool _isDetailsOpen = false;
  String? _attachedReceiptSummary;

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      final t = widget.initialTransaction!;
      _type = t.type;
      _amountStr = t.amount % 1 == 0
          ? t.amount.toInt().toString()
          : t.amount.toStringAsFixed(2);
      _selectedAccountId = t.accountId;
      _selectedToAccountId = t.toAccountId;
      _selectedCategoryId = t.categoryId;
      _payeeController.text = t.merchantName ?? '';
      _noteController.text = t.note ?? '';
      _selectedDate = t.transactionDate;
      _selectedTime = TimeOfDay.fromDateTime(t.transactionDate);
      _paymentType = t.paymentType;
      _status = t.status;
      _loadTransactionTags(t.id);
    } else if (widget.preselectedAccountId != null) {
      _selectedAccountId = widget.preselectedAccountId;
    }
  }

  Future<void> _loadTransactionTags(String transactionId) async {
    final tagIds = await ref
        .read(transactionRepositoryProvider)
        .getTransactionTags(transactionId);
    if (mounted) {
      setState(() {
        _selectedTagIds.clear();
        _selectedTagIds.addAll(tagIds);
      });
    }
  }

  @override
  void dispose() {
    _payeeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // --- Calculator & Expression Logic ---
  double? _evaluateExpression(String expr) {
    String clean = expr
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('—', '-')
        .trim();
    clean = clean.replaceAll(RegExp(r'[\+\-\*/]+$'), '');
    if (clean.isEmpty) return 0.0;

    try {
      final tokens = <String>[];
      final buffer = StringBuffer();
      for (int i = 0; i < clean.length; i++) {
        final ch = clean[i];
        if (ch == '+' || ch == '-' || ch == '*' || ch == '/') {
          if (buffer.isNotEmpty) {
            tokens.add(buffer.toString());
            buffer.clear();
          } else if (ch == '-' &&
              (tokens.isEmpty ||
                  ['+', '-', '*', '/'].contains(tokens.last))) {
            buffer.write(ch);
            continue;
          }
          tokens.add(ch);
        } else {
          buffer.write(ch);
        }
      }
      if (buffer.isNotEmpty) tokens.add(buffer.toString());
      if (tokens.isEmpty) return 0.0;

      // Pass 1: * and /
      final intermediate = <String>[];
      int i = 0;
      while (i < tokens.length) {
        final token = tokens[i];
        if (token == '*' || token == '/') {
          final left = double.parse(intermediate.removeLast());
          final right = double.parse(tokens[i + 1]);
          final res =
              token == '*' ? left * right : (right != 0 ? left / right : 0.0);
          intermediate.add(res.toString());
          i += 2;
        } else {
          intermediate.add(token);
          i++;
        }
      }

      // Pass 2: + and -
      double total = double.parse(intermediate[0]);
      int j = 1;
      while (j < intermediate.length) {
        final op = intermediate[j];
        final right = double.parse(intermediate[j + 1]);
        if (op == '+') {
          total += right;
        } else if (op == '-') {
          total -= right;
        }
        j += 2;
      }
      return total;
    } catch (_) {
      return null;
    }
  }

  void _onNumpadPress(String val) {
    setState(() {
      if (val == 'C') {
        _amountStr = '0';
      } else if (val == '⌫') {
        if (_amountStr.length > 1) {
          _amountStr = _amountStr.substring(0, _amountStr.length - 1);
        } else {
          _amountStr = '0';
        }
      } else if (val == '=') {
        final result = _evaluateExpression(_amountStr);
        if (result != null) {
          _amountStr = result % 1 == 0
              ? result.toInt().toString()
              : result.toStringAsFixed(2);
        }
      } else if (val == '+' || val == '—' || val == '×' || val == '÷') {
        final lastChar = _amountStr.isNotEmpty
            ? _amountStr[_amountStr.length - 1]
            : '';
        if (['+', '—', '×', '÷', '-'].contains(lastChar)) {
          _amountStr =
              _amountStr.substring(0, _amountStr.length - 1) + val;
        } else {
          _amountStr += val;
        }
      } else if (val == '.') {
        // Allow dot if current operand doesn't have one
        final parts = _amountStr.split(RegExp(r'[\+\—\×\÷\-]'));
        final currentOperand = parts.isNotEmpty ? parts.last : '';
        if (!currentOperand.contains('.')) {
          _amountStr += '.';
        }
      } else if (val == '00') {
        if (_amountStr != '0') {
          _amountStr += '00';
        }
      } else {
        if (_amountStr == '0') {
          _amountStr = val;
        } else {
          _amountStr += val;
        }
      }
    });
  }

  void _showDirectAmountEditor() {
    final controller = TextEditingController(text: _amountStr);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Amount'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            prefixText: '₹ ',
            labelText: 'Enter amount or expression',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                setState(() => _amountStr = text);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction() async {
    if (widget.initialTransaction == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text(
            'Are you sure you want to delete this transaction? Account balance will be restored automatically.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(transactionRepositoryProvider)
          .deleteTransaction(widget.initialTransaction!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _saveTransaction({bool addAnother = false}) async {
    // If expression is active, evaluate it
    final evaluated = _evaluateExpression(_amountStr);
    final amount = evaluated ?? double.tryParse(_amountStr) ?? 0.0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount greater than 0')),
      );
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }

    if (_type == 'transfer' && _selectedToAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select target transfer account')),
      );
      return;
    }

    final fullDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final repo = ref.read(transactionRepositoryProvider);

    if (widget.initialTransaction != null) {
      await repo.updateTransaction(
        id: widget.initialTransaction!.id,
        accountId: _selectedAccountId!,
        toAccountId: _type == 'transfer' ? _selectedToAccountId : null,
        categoryId: _type != 'transfer' ? _selectedCategoryId : null,
        type: _type,
        amount: amount,
        transactionDate: fullDate,
        merchantName: _payeeController.text.trim().isNotEmpty
            ? _payeeController.text.trim()
            : null,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
        paymentType: _paymentType,
        status: _status,
      );

      // Save tags
      await repo.setTransactionTags(
          widget.initialTransaction!.id, _selectedTagIds);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction updated successfully')),
      );
    } else {
      final newId = await repo.createTransaction(
        accountId: _selectedAccountId!,
        toAccountId: _type == 'transfer' ? _selectedToAccountId : null,
        categoryId: _type != 'transfer' ? _selectedCategoryId : null,
        type: _type,
        amount: amount,
        transactionDate: fullDate,
        merchantName: _payeeController.text.trim().isNotEmpty
            ? _payeeController.text.trim()
            : null,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
        paymentType: _paymentType,
        status: _status,
      );

      // Save tags
      if (_selectedTagIds.isNotEmpty) {
        await repo.setTransactionTags(newId, _selectedTagIds);
      }

      if (!mounted) return;

      if (addAnother) {
        setState(() {
          _amountStr = '0';
          _payeeController.clear();
          _noteController.clear();
          _selectedTagIds.clear();
          _isDetailsOpen = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved! Ready for next transaction')),
        );
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  // --- Category Selector Modal with Subcategories & On-the-fly add ---
  void _openCategoryPicker(List<Category> allCategories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final parents =
            allCategories.where((c) => c.parentId == null).toList();

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ManageCategoriesDialog.show(context);
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('+ Add New'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: parents.length,
                  itemBuilder: (context, i) {
                    final p = parents[i];
                    final subs = allCategories
                        .where((c) => c.parentId == p.id)
                        .toList();
                    final color =
                        Color(int.tryParse(p.colorHex) ?? 0xFF008080);

                    return ExpansionTile(
                      key: PageStorageKey(p.id),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withValues(alpha: 0.2),
                        child: Icon(Icons.category_rounded,
                            color: color, size: 16),
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() => _selectedCategoryId = p.id);
                              Navigator.of(ctx).pop();
                            },
                            child: const Text('Select',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                          const Icon(Icons.expand_more_rounded),
                        ],
                      ),
                      children: subs.map((sub) {
                        final subColor =
                            Color(int.tryParse(sub.colorHex) ?? 0xFF3B82F6);
                        final isSelected = _selectedCategoryId == sub.id;

                        return ListTile(
                          contentPadding: const EdgeInsets.only(left: 36, right: 16),
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor:
                                subColor.withValues(alpha: 0.2),
                            child: Icon(Icons.subdirectory_arrow_right_rounded,
                                color: subColor, size: 14),
                          ),
                          title: Text(
                            sub.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                      ? Colors.white
                                      : AppColors.lightTextPrimary),
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_rounded,
                                  color: AppColors.primary, size: 18)
                              : null,
                          onTap: () {
                            setState(() => _selectedCategoryId = sub.id);
                            Navigator.of(ctx).pop();
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Quick Add Tag Modal on the fly ---
  void _openAddTagDialog() {
    final nameCtrl = TextEditingController();
    Color selectedColor = const Color(0xFF26B2AB);
    final colors = [
      const Color(0xFF26B2AB),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFFEF4444),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('New Tag'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tag Name',
                    hintText: 'e.g. Travel, Personal, Office',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  children: colors.map((c) {
                    final isSel = selectedColor.toARGB32() == c.toARGB32();
                    return GestureDetector(
                      onTap: () => setDlgState(() => selectedColor = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: isSel
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final hex =
                      '0x${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
                  final id = await ref
                      .read(transactionRepositoryProvider)
                      .createTag(name: name, colorHex: hex);
                  setState(() {
                    if (!_selectedTagIds.contains(id)) _selectedTagIds.add(id);
                  });
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accountsAsync = ref.watch(activeAccountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);

    // Auto-select first account if unselected
    accountsAsync.whenData((accounts) {
      if (accounts.isNotEmpty && _selectedAccountId == null) {
        _selectedAccountId = accounts.first.id;
      }
    });

    final evaluatedVal = _evaluateExpression(_amountStr);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.initialTransaction != null
              ? 'Edit Transaction'
              : 'Add Transaction',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          if (widget.initialTransaction != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
              tooltip: 'Delete Transaction',
              onPressed: _deleteTransaction,
            ),
          IconButton(
            icon: const Icon(Icons.check_rounded),
            color: AppColors.income,
            onPressed: () => _saveTransaction(),
          ),
        ],
      ),
      body: GestureDetector(
        // Swipe left to open details, swipe right to close details
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -250 && !_isDetailsOpen) {
              setState(() => _isDetailsOpen = true);
            } else if (details.primaryVelocity! > 250 && _isDetailsOpen) {
              setState(() => _isDetailsOpen = false);
            }
          }
        },
        child: Stack(
          children: [
            // MAIN VIEW: Tabs, Slate Blue Hero Canvas, and 4-Column Calculator Numpad
            Column(
              children: [
                // Top Segmented Type Selector (INCOME | EXPENSE | TRANSFER)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightBorder,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        _buildTypeTab('income', 'INCOME', AppColors.income),
                        _buildTypeTab('expense', 'EXPENSE', AppColors.expense),
                        _buildTypeTab('transfer', 'TRANSFER', AppColors.transfer),
                      ],
                    ),
                  ),
                ),

                // SLATE BLUE HERO CANVAS (Matching media_1789471147550.png)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C3E50)
                        : const Color(0xFF455A64),
                    borderRadius: AppStyles.roundedL,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Curved Pull-Tab on the right edge
                      Positioned(
                        right: 0,
                        top: 24,
                        bottom: 24,
                        child: GestureDetector(
                          onTap: () => setState(() => _isDetailsOpen = true),
                          child: Container(
                            width: 28,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.white,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(-1, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.chevron_left_rounded,
                              size: 24,
                              color: isDark ? Colors.white : const Color(0xFF455A64),
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 32, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sign indicator & Editable Amount
                            GestureDetector(
                              onTap: _showDirectAmountEditor,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Left symbol: — for expense, + for income, ⇄ for transfer
                                  Text(
                                    _type == 'expense'
                                        ? '—'
                                        : (_type == 'income' ? '+' : '⇄'),
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Amount Display
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _amountStr,
                                            style: const TextStyle(
                                              fontSize: 42,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                        ),
                                        if (evaluatedVal != null &&
                                            _amountStr.contains(RegExp(r'[\+\—\×\÷\-]')))
                                          Text(
                                            '= ₹ ${evaluatedVal.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white70,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Currency Label
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'INR',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Inside Hero: Source Account + Category / Target Account
                            Row(
                              children: [
                                // Source Account Dropdown
                                Expanded(
                                  child: accountsAsync.when(
                                    data: (accounts) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.2)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedAccountId,
                                          dropdownColor: const Color(0xFF37474F),
                                          icon: const Icon(
                                              Icons.arrow_drop_down_rounded,
                                              color: Colors.white),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12),
                                          isExpanded: true,
                                          items: accounts.map((a) {
                                            return DropdownMenuItem(
                                              value: a.id,
                                              child: Text(
                                                'Account: ${a.name}',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) =>
                                              setState(() => _selectedAccountId = val),
                                        ),
                                      ),
                                    ),
                                    loading: () => const SizedBox(),
                                    error: (_, _) => const SizedBox(),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Category or Target Account Dropdown
                                Expanded(
                                  child: _type == 'transfer'
                                      ? accountsAsync.when(
                                          data: (accounts) => Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.22),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2)),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: _selectedToAccountId,
                                                hint: const Text('To Account',
                                                    style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 12)),
                                                dropdownColor:
                                                    const Color(0xFF37474F),
                                                icon: const Icon(
                                                    Icons.arrow_drop_down_rounded,
                                                    color: Colors.white),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12),
                                                isExpanded: true,
                                                items: accounts.map((a) {
                                                  return DropdownMenuItem(
                                                    value: a.id,
                                                    child: Text(a.name,
                                                        style: const TextStyle(
                                                            color: Colors.white)),
                                                  );
                                                }).toList(),
                                                onChanged: (val) => setState(
                                                    () => _selectedToAccountId = val),
                                              ),
                                            ),
                                          ),
                                          loading: () => const SizedBox(),
                                          error: (_, _) => const SizedBox(),
                                        )
                                      : categoriesAsync.when(
                                          data: (categories) {
                                            final selectedCat =
                                                categories.where((c) => c.id == _selectedCategoryId).firstOrNull;
                                            return InkWell(
                                              onTap: () =>
                                                  _openCategoryPicker(categories),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.22),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: Colors.white
                                                          .withValues(alpha: 0.2)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        selectedCat != null
                                                            ? 'Category: ${selectedCat.name}'
                                                            : 'SELECT CATEGORY',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const Icon(
                                                      Icons.arrow_drop_down_rounded,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                          loading: () => const SizedBox(),
                                          error: (_, _) => const SizedBox(),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick templates strip
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'QUICK ADD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['+50', '+100', '+500', '+1000', '+2000'].map((chip) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () {
                                    final addVal = double.tryParse(chip.substring(1)) ?? 0;
                                    final cur = double.tryParse(_amountStr) ?? 0;
                                    setState(() {
                                      _amountStr = (cur + addVal).toStringAsFixed(0);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkSurface
                                          : AppColors.lightBorder.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder,
                                      ),
                                    ),
                                    child: Text(
                                      chip,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4-COLUMN CALCULATOR NUMPAD (with ÷, ×, —, +, =)
                Expanded(
                  child: _buildCalculatorNumpad(isDark),
                ),
              ],
            ),

            // SLIDE-IN "ADD DETAILS" PANEL (Opens on `<` tap or swipe left)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              left: _isDetailsOpen ? 0 : MediaQuery.of(context).size.width,
              right: _isDetailsOpen ? 0 : -MediaQuery.of(context).size.width,
              child: Material(
                elevation: 16,
                color: isDark ? AppColors.darkCard : Colors.white,
                child: SafeArea(
                  child: Column(
                    children: [
                      // Details Panel Header with Back Button
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_rounded),
                              onPressed: () =>
                                  setState(() => _isDetailsOpen = false),
                            ),
                            const Text(
                              'Transaction Details',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.check_rounded,
                                  color: AppColors.income),
                              onPressed: () => _saveTransaction(),
                            ),
                          ],
                        ),
                      ),

                      // Details Form Scrollable Content
                      Expanded(
                        child: _buildDetailsContent(
                            isDark, categoriesAsync, tagsAsync),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Segmented Type Tab Button
  Widget _buildTypeTab(String typeVal, String label, Color activeAccent) {
    final isSelected = _type == typeVal;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = typeVal),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeAccent.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: isSelected ? activeAccent : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  // 4-Column Calculator Keypad
  Widget _buildCalculatorNumpad(bool isDark) {
    final rows = [
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '—'],
      ['.', '0', '⌫', '+'],
      ['C', '00', '=', '✓'],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
      child: Column(
        children: rows.map((row) {
          return Expanded(
            child: Row(
              children: row.map((val) {
                final isOp = ['÷', '×', '—', '+', '='].contains(val);
                final isSave = val == '✓';
                final isClear = val == 'C' || val == '⌫';

                Color btnBg;
                Color textColor;

                if (isSave) {
                  btnBg = AppColors.primary;
                  textColor = Colors.white;
                } else if (isOp) {
                  btnBg = isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0);
                  textColor = AppColors.primary;
                } else if (isClear) {
                  btnBg = isDark
                      ? AppColors.darkSurface
                      : AppColors.expenseContainer.withValues(alpha: 0.3);
                  textColor = AppColors.expense;
                } else {
                  btnBg = isDark ? AppColors.darkCard : Colors.white;
                  textColor =
                      isDark ? Colors.white : AppColors.lightTextPrimary;
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: InkWell(
                      onTap: () {
                        if (isSave) {
                          _saveTransaction();
                        } else {
                          _onNumpadPress(val);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: btnBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSave
                                ? Colors.transparent
                                : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder),
                          ),
                          boxShadow: isSave
                              ? AppStyles.heroGlowShadow
                              : AppStyles.softShadow,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          val,
                          style: TextStyle(
                            fontSize: isOp ? 22 : 20,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Details Content Form
  Widget _buildDetailsContent(
    bool isDark,
    AsyncValue<List<Category>> categoriesAsync,
    AsyncValue<List<Tag>> tagsAsync,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payee / Merchant
          TextField(
            controller: _payeeController,
            style: TextStyle(
                color: isDark ? Colors.white : AppColors.lightTextPrimary),
            decoration: InputDecoration(
              labelText: 'Payee / Merchant',
              hintText: 'e.g. Swiggy, Starbucks, Uber, Rent',
              prefixIcon: const Icon(Icons.store_rounded, size: 20),
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
              border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
            ),
          ),
          const SizedBox(height: 14),

          // Category & Subcategory selection chip
          categoriesAsync.when(
            data: (cats) {
              final selectedCat =
                  cats.where((c) => c.id == _selectedCategoryId).firstOrNull;
              Category? parentCat;
              if (selectedCat != null && selectedCat.parentId != null) {
                parentCat =
                    cats.where((c) => c.id == selectedCat.parentId).firstOrNull;
              }

              return InkWell(
                onTap: () => _openCategoryPicker(cats),
                borderRadius: AppStyles.roundedM,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                    borderRadius: AppStyles.roundedM,
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.category_rounded,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Category & Subcategory',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            Text(
                              selectedCat != null
                                  ? (parentCat != null
                                      ? '${parentCat.name} › ${selectedCat.name}'
                                      : selectedCat.name)
                                  : 'Tap to select category',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox(),
            error: (_, _) => const SizedBox(),
          ),
          const SizedBox(height: 16),

          // Tags Selection with "+ Add Tag"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tags',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              InkWell(
                onTap: _openAddTagDialog,
                child: const Text(
                  '+ New Tag',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          tagsAsync.when(
            data: (allTags) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...allTags.map((tag) {
                    final isSelected = _selectedTagIds.contains(tag.id);
                    final tagColor =
                        Color(int.tryParse(tag.colorHex) ?? 0xFF26B2AB);

                    return FilterChip(
                      label: Text('#${tag.name}'),
                      selected: isSelected,
                      selectedColor: tagColor.withValues(alpha: 0.25),
                      checkmarkColor: tagColor,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? tagColor
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                      ),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedTagIds.add(tag.id);
                          } else {
                            _selectedTagIds.remove(tag.id);
                          }
                        });
                      },
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Tag'),
                    onPressed: _openAddTagDialog,
                  ),
                ],
              );
            },
            loading: () => const SizedBox(),
            error: (_, _) => const SizedBox(),
          ),
          const SizedBox(height: 16),

          // Date & Time pickers
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setState(() => _selectedDate = d);
                  },
                  borderRadius: AppStyles.roundedM,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightBackground,
                      border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                      prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );
                    if (t != null) setState(() => _selectedTime = t);
                  },
                  borderRadius: AppStyles.roundedM,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Time',
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightBackground,
                      border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                      prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
                    ),
                    child: Text(
                      _selectedTime.format(context),
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Payment Mode Dropdown
          DropdownButtonFormField<String>(
            initialValue: _paymentType,
            dropdownColor: isDark ? AppColors.darkCard : Colors.white,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'Payment Mode',
              prefixIcon: const Icon(Icons.payment_rounded, size: 20),
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
              border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'upi',
                  child: Text('UPI (Google Pay, PhonePe, Paytm)')),
              DropdownMenuItem(
                  value: 'card', child: Text('Debit / Credit Card')),
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(
                  value: 'net_banking', child: Text('Net Banking')),
            ],
            onChanged: (val) => setState(() => _paymentType = val!),
          ),
          const SizedBox(height: 14),

          // Note
          TextField(
            controller: _noteController,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Note',
              hintText: 'Add an optional description...',
              prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
              border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
            ),
          ),
          const SizedBox(height: 14),

          // Receipt Attachment
          if (_attachedReceiptSummary != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.incomeGreen.withValues(alpha: 0.15),
                borderRadius: AppStyles.roundedM,
                border: Border.all(
                    color: AppColors.incomeGreen.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_rounded,
                      color: AppColors.incomeGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Attached: $_attachedReceiptSummary',
                      style: const TextStyle(
                        color: AppColors.incomeGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.incomeGreen),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () =>
                        setState(() => _attachedReceiptSummary = null),
                  ),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: AppStyles.roundedM),
              ),
              onPressed: () => _openReceiptScannerDialog(context),
              icon: const Icon(Icons.receipt_long_rounded,
                  color: AppColors.primary),
              label: Text(
                'Scan / Attach Receipt ✨',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.roundedM),
                  ),
                  onPressed: () => _saveTransaction(addAnother: true),
                  child: Text(
                    'Save & Add Another',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.roundedM),
                  ),
                  onPressed: () => _saveTransaction(),
                  child: Text(
                    widget.initialTransaction != null
                        ? 'Update Transaction'
                        : 'Save Transaction',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (widget.initialTransaction != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.expense,
                  side: const BorderSide(color: AppColors.expense),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape:
                      RoundedRectangleBorder(borderRadius: AppStyles.roundedM),
                ),
                onPressed: _deleteTransaction,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete Transaction',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Receipt Scanner Preset Dialog
  void _openReceiptScannerDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Scan / Paste Receipt'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste raw OCR receipt text or pick a sample receipt to auto-fill transaction details:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('☕ Starbucks (₹350)',
                          style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        controller.text =
                            'STARBUCKS COFFEE INDIRANAGAR\nDate: 12/09/2026\n1x Caffe Latte: 280.00\n1x Croissant: 70.00\nTOTAL AMOUNT: Rs. 350.00';
                      },
                    ),
                    ActionChip(
                      label: const Text('🛒 D-Mart (₹2,450)',
                          style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        controller.text =
                            'DMART RETAIL SUPERMARKET\nDate: 11/09/2026\nGrocery items: 2450.00\nGRAND TOTAL: Rs. 2450.00';
                      },
                    ),
                    ActionChip(
                      label: const Text('⛽ Shell Fuel (₹1,200)',
                          style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        controller.text =
                            'SHELL PETROL STATION\nDate: 10/09/2026\nPower Petrol: 1200.00\nNET AMOUNT: Rs. 1200.00';
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Paste receipt text here...',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
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
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;

              final parsed = ref
                  .read(receiptScannerServiceProvider)
                  .parseReceiptText(text);

              setState(() {
                if (parsed.totalAmount > 0) {
                  _amountStr = parsed.totalAmount % 1 == 0
                      ? parsed.totalAmount.toInt().toString()
                      : parsed.totalAmount.toStringAsFixed(2);
                }
                if (parsed.merchantName.isNotEmpty) {
                  _payeeController.text = parsed.merchantName;
                }
                _selectedDate = parsed.date;
                _attachedReceiptSummary =
                    '${parsed.merchantName} (₹${parsed.totalAmount.toStringAsFixed(0)})';
              });

              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Receipt scanned! Auto-filled ${parsed.merchantName} - ₹${parsed.totalAmount.toStringAsFixed(0)}',
                  ),
                  backgroundColor: AppColors.incomeGreen,
                ),
              );
            },
            child: const Text('Parse & Apply'),
          ),
        ],
      ),
    );
  }
}
