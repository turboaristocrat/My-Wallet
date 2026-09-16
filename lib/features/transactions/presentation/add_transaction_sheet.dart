import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../accounts/data/account_repository.dart';
import '../../receipts/data/receipt_scanner_service.dart';
import '../data/transaction_repository.dart';
import '../../categories/presentation/category_picker_sheet.dart';

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
  String _type = 'expense'; // 'income', 'expense', 'transfer'
  String _amountStr = '0';
  String? _selectedAccountId;
  String? _selectedToAccountId;
  String? _selectedCategoryId;
  final TextEditingController _payeeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _paymentType = 'cash';
  String _status = 'cleared';
  final List<String> _selectedTagIds = [];
  bool _isDetailsOpen = false;
  String? _attachedReceiptSummary;

  // Colors matching media_1789475202193.png
  static const Color _heroBgLight = Color(0xFF455A64);
  static const Color _heroBgDark = Color(0xFF263238);
  static const Color _inactiveTabLight = Color(0xFF37474F);
  static const Color _inactiveTabDark = Color(0xFF1E272C);
  static const Color _templatesBg = Color(0xFF546E7A);
  static const Color _keypadOperatorBgLight = Color(0xFFF8FAFC);
  static const Color _keypadOperatorBgDark = Color(0xFF1E293B);

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
    if (val == '=') {
      HapticFeedback.mediumImpact();
    } else if (val == '+' || val == '-' || val == '—' || val == '*' || val == '÷') {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.lightImpact();
    }
    setState(() {
      if (val == 'C') {
        _amountStr = '0';
      } else if (val == '⌫' || val == '←') {
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
      } else if (val == '+' || val == '-' || val == '—' || val == '*' || val == '÷') {
        final opChar = val == '—' ? '-' : val;
        final lastChar = _amountStr.isNotEmpty
            ? _amountStr[_amountStr.length - 1]
            : '';
        if (['+', '-', '*', '÷'].contains(lastChar)) {
          _amountStr =
              _amountStr.substring(0, _amountStr.length - 1) + opChar;
        } else {
          _amountStr += opChar;
        }
      } else if (val == '.') {
        final parts = _amountStr.split(RegExp(r'[\+\-\*÷]'));
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
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            prefixText: '₹ ',
            labelText: 'Enter amount or math',
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

  // --- Category Picker (calls CategoryPickerSheet) ---
  Future<void> _pickCategory() async {
    final selected = await CategoryPickerSheet.show(
      context,
      initialCategoryId: _selectedCategoryId,
    );
    if (selected != null && mounted) {
      setState(() => _selectedCategoryId = selected.id);
    }
  }

  // --- Add Tag Dialog on the fly ---
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
            title: const Text('New Tag / Label'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Label Name',
                    hintText: 'e.g. Desin, Mom, Trip, Fuel',
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

    final heroColor = isDark ? _heroBgDark : _heroBgLight;
    final inactiveTabColor = isDark ? _inactiveTabDark : _inactiveTabLight;

    return PopScope(
      canPop: !_isDetailsOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isDetailsOpen) {
          setState(() => _isDetailsOpen = false);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
        body: SafeArea(
        child: GestureDetector(
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
              // ==========================================
              // VIEW 1: HERO CANVAS & CALCULATOR KEYPAD
              // ==========================================
              Column(
                children: [
                  // Top App Bar
                  Container(
                    color: inactiveTabColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        if (widget.initialTransaction != null)
                          Text(
                            'Edit Transaction',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
                          onPressed: () => _saveTransaction(),
                        ),
                      ],
                    ),
                  ),

                  // Segmented Tabs (INCOME | EXPENSE | TRANSFER)
                  Container(
                    color: inactiveTabColor,
                    child: Row(
                      children: [
                        _buildTopTab('income', 'INCOME', heroColor, inactiveTabColor),
                        _buildTopTab('expense', 'EXPENSE', heroColor, inactiveTabColor),
                        _buildTopTab('transfer', 'TRANSFER', heroColor, inactiveTabColor),
                      ],
                    ),
                  ),

                  // Slate Blue Hero Canvas (media_1789475202193.png)
                  Expanded(
                    flex: 4,
                    child: Container(
                      width: double.infinity,
                      color: heroColor,
                      child: Stack(
                        children: [
                          // Curved White Pull-Tab on Right Edge
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: () => setState(() => _isDetailsOpen = true),
                                child: Container(
                                  width: 26,
                                  height: 64,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(32),
                                      bottomLeft: Radius.circular(32),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 6,
                                        offset: Offset(-2, 1),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.chevron_left_rounded,
                                    size: 22,
                                    color: Color(0xFF455A64),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Center Content
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 16, 36, 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const SizedBox(height: 10),

                                // Left sign + Big Amount + Currency (media_1789475202193.png)
                                GestureDetector(
                                  onTap: _showDirectAmountEditor,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        _type == 'expense'
                                            ? '—'
                                            : (_type == 'income' ? '+' : '⇄'),
                                        style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w300,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const Spacer(),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _amountStr,
                                          style: const TextStyle(
                                            fontSize: 72,
                                            fontWeight: FontWeight.w200,
                                            color: Colors.white,
                                            letterSpacing: -1,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'INR',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 24,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Bottom Row: Account on left, Category on right
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Account Selector
                                    accountsAsync.when(
                                      data: (accounts) {
                                        final currentAcc = accounts
                                            .where((a) => a.id == _selectedAccountId)
                                            .firstOrNull;
                                        return PopupMenuButton<String>(
                                          onSelected: (val) =>
                                              setState(() => _selectedAccountId = val),
                                          itemBuilder: (_) => accounts.map((a) {
                                            return PopupMenuItem(
                                              value: a.id,
                                              child: Text(a.name),
                                            );
                                          }).toList(),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Account',
                                                style: TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                currentAcc?.name.toUpperCase() ??
                                                    'CASH',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      loading: () => const SizedBox(),
                                      error: (_, _) => const SizedBox(),
                                    ),

                                    // Category or Target Account Selector
                                    _type == 'transfer'
                                        ? accountsAsync.when(
                                            data: (accounts) {
                                              final targetAcc = accounts
                                                  .where((a) =>
                                                      a.id == _selectedToAccountId)
                                                  .firstOrNull;
                                              return PopupMenuButton<String>(
                                                onSelected: (val) => setState(
                                                    () => _selectedToAccountId = val),
                                                itemBuilder: (_) => accounts
                                                    .where((a) =>
                                                        a.id != _selectedAccountId)
                                                    .map((a) {
                                                  return PopupMenuItem(
                                                    value: a.id,
                                                    child: Text(a.name),
                                                  );
                                                }).toList(),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    const Text(
                                                      'To Account',
                                                      style: TextStyle(
                                                        color: Colors.white60,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    Text(
                                                      targetAcc?.name.toUpperCase() ??
                                                          'SELECT TARGET',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            loading: () => const SizedBox(),
                                            error: (_, _) => const SizedBox(),
                                          )
                                        : categoriesAsync.when(
                                            data: (categories) {
                                              final cat = categories
                                                  .where((c) =>
                                                      c.id == _selectedCategoryId)
                                                  .firstOrNull;
                                              final parentCat = (cat != null && cat.parentId != null)
                                                  ? categories
                                                      .where((c) => c.id == cat.parentId)
                                                      .firstOrNull
                                                  : null;
                                              final displayName = parentCat != null
                                                  ? '${parentCat.name.toUpperCase()} > ${cat!.name.toUpperCase()}'
                                                  : (cat?.name.toUpperCase() ?? 'SELECT CATEGORY');
                                              return GestureDetector(
                                                onTap: _pickCategory,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    const Text(
                                                      'Category',
                                                      style: TextStyle(
                                                        color: Colors.white60,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    Text(
                                                      displayName,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            loading: () => const SizedBox(),
                                            error: (_, _) => const SizedBox(),
                                          ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Interactive Quick-Fill TEMPLATES Strip
                  _buildTemplatesBar(categoriesAsync.value ?? []),

                  // 4-COLUMN CALCULATOR KEYPAD (media_1789475202193.png)
                  Expanded(
                    flex: 5,
                    child: _buildCleanKeypad(isDark),
                  ),
                ],
              ),

              // ==========================================
              // VIEW 2: SLIDE-IN "ADD DETAILS" PANEL
              // (Matching media_1789475215918.png)
              // ==========================================
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                top: 0,
                bottom: 0,
                left: _isDetailsOpen ? 0 : MediaQuery.of(context).size.width,
                right: _isDetailsOpen ? 0 : -MediaQuery.of(context).size.width,
                child: Material(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  child: Column(
                    children: [
                      // Top Bar matching media_1789475215918.png
                      Container(
                        color: heroColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white, size: 24),
                              onPressed: () =>
                                  setState(() => _isDetailsOpen = false),
                            ),
                            Text(
                              '₹$_amountStr',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 24),
                              onPressed: () => _saveTransaction(),
                            ),
                          ],
                        ),
                      ),

                      // Details List
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          children: [
                            // 1. Note
                            Text(
                              'Note',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                  fontWeight: FontWeight.w600),
                            ),
                            TextField(
                              controller: _noteController,
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.lightTextPrimary),
                              decoration: InputDecoration(
                                hintText: 'Description',
                                hintStyle: TextStyle(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : Colors.grey),
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? AppColors.darkBorder
                                          : Colors.black12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // 2. Labels
                            Text(
                              'Labels',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            tagsAsync.when(
                              data: (tags) {
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        side: BorderSide(
                                            color: isDark
                                                ? AppColors.darkBorder
                                                : Colors.black26),
                                      ),
                                      onPressed: _openAddTagDialog,
                                      icon: const Icon(
                                          Icons.add_circle_rounded,
                                          color: AppColors.primary,
                                          size: 18),
                                      label: Text('Add label',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.white70
                                                  : AppColors.lightTextPrimary)),
                                    ),
                                    ...tags.map((tag) {
                                      final isSelected =
                                          _selectedTagIds.contains(tag.id);
                                      final color = Color(
                                          int.tryParse(tag.colorHex) ??
                                              0xFF26B2AB);

                                      return FilterChip(
                                        label: Text(tag.name),
                                        selected: isSelected,
                                        selectedColor:
                                            color.withValues(alpha: 0.3),
                                        checkmarkColor: color,
                                        labelStyle: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? color
                                              : (isDark
                                                  ? Colors.white70
                                                  : Colors.black87),
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
                                  ],
                                );
                              },
                              loading: () => const SizedBox(),
                              error: (_, _) => const SizedBox(),
                            ),
                            const SizedBox(height: 18),

                            // 3. Payee
                            Text(
                              'Payee',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                  fontWeight: FontWeight.w600),
                            ),
                            TextField(
                              controller: _payeeController,
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.lightTextPrimary),
                              decoration: InputDecoration(
                                hintText: 'Enter payee or merchant',
                                hintStyle: TextStyle(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : Colors.grey),
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? AppColors.darkBorder
                                          : Colors.black12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // 4. Date & Time side by side
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Date',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: () async {
                                          final d = await showDatePicker(
                                            context: context,
                                            initialDate: _selectedDate,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2030),
                                          );
                                          if (d != null) {
                                            setState(() => _selectedDate = d);
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            Text(
                                              DateFormat('d MMM yyyy')
                                                  .format(_selectedDate),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                                Icons.arrow_drop_down_rounded,
                                                color: Colors.grey),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Time',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: () async {
                                          final t = await showTimePicker(
                                            context: context,
                                            initialTime: _selectedTime,
                                          );
                                          if (t != null) {
                                            setState(() => _selectedTime = t);
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            Text(
                                              _selectedTime.format(context),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                                Icons.arrow_drop_down_rounded,
                                                color: Colors.grey),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // 5. Payment Type
                            const Text(
                              'Payment Type',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600),
                            ),
                            DropdownButton<String>(
                              value: _paymentType,
                              isExpanded: true,
                              underline: Container(
                                  height: 1, color: Colors.black12),
                              items: const [
                                DropdownMenuItem(
                                    value: 'cash', child: Text('Cash')),
                                DropdownMenuItem(
                                    value: 'upi',
                                    child: Text('UPI / Online')),
                                DropdownMenuItem(
                                    value: 'card',
                                    child: Text('Debit / Credit Card')),
                                DropdownMenuItem(
                                    value: 'net_banking',
                                    child: Text('Net Banking')),
                              ],
                              onChanged: (val) =>
                                  setState(() => _paymentType = val!),
                            ),
                            const SizedBox(height: 18),

                            // 6. Status
                            const Text(
                              'Status',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600),
                            ),
                            DropdownButton<String>(
                              value: _status,
                              isExpanded: true,
                              underline: Container(
                                  height: 1, color: Colors.black12),
                              items: const [
                                DropdownMenuItem(
                                    value: 'cleared',
                                    child: Text('Cleared')),
                                DropdownMenuItem(
                                    value: 'pending',
                                    child: Text('Pending')),
                                DropdownMenuItem(
                                    value: 'reconciled',
                                    child: Text('Reconciled')),
                              ],
                              onChanged: (val) =>
                                  setState(() => _status = val!),
                            ),
                            const SizedBox(height: 18),

                            // 7. Attachments
                            const Text(
                              'Attachments',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            if (_attachedReceiptSummary != null)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.incomeGreen
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.receipt_long_rounded,
                                        color: AppColors.incomeGreen),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(_attachedReceiptSummary!)),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () => setState(
                                          () => _attachedReceiptSummary = null),
                                    ),
                                  ],
                                ),
                              )
                            else
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  side: const BorderSide(color: Colors.black26),
                                ),
                                onPressed: () =>
                                    _openReceiptScannerDialog(context),
                                icon: const Icon(Icons.add_circle_rounded,
                                    color: Colors.blue, size: 18),
                                label: const Text('Add receipt',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.black87)),
                              ),

                            if (widget.initialTransaction != null) ...[
                              const SizedBox(height: 32),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.expense,
                                  side: const BorderSide(
                                      color: AppColors.expense),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _deleteTransaction,
                                icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18),
                                label: const Text('Delete Transaction',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  // --- Interactive Quick-Fill Templates Strip ---
  Widget _buildTemplatesBar(List<Category> categories) {
    final templates = [
      {'emoji': '☕', 'title': 'Coffee', 'amount': '150', 'kw': 'food'},
      {'emoji': '🛒', 'title': 'Groceries', 'amount': '500', 'kw': 'shopping'},
      {'emoji': '⛽', 'title': 'Fuel', 'amount': '1000', 'kw': 'transport'},
      {'emoji': '🍔', 'title': 'Dining', 'amount': '350', 'kw': 'food'},
      {'emoji': '⚡', 'title': 'Electricity', 'amount': '1500', 'kw': 'bills'},
      {'emoji': '🎬', 'title': 'Cinema', 'amount': '400', 'kw': 'entertainment'},
      {'emoji': '💊', 'title': 'Pharmacy', 'amount': '250', 'kw': 'health'},
    ];

    return Container(
      width: double.infinity,
      color: _templatesBg,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(right: 8),
              child: const Text(
                'TEMPLATES',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            ...templates.map((tpl) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _amountStr = tpl['amount']!;
                      _payeeController.text = tpl['title']!;
                      _noteController.text = '${tpl['title']} quick-entry';
                      final kw = tpl['kw']!;
                      final matchedCat = categories.where((c) {
                        final n = c.name.toLowerCase();
                        return n.contains(kw) ||
                            (kw == 'food' && (n.contains('restaurant') || n.contains('dining') || n.contains('cafe'))) ||
                            (kw == 'transport' && (n.contains('travel') || n.contains('vehicle') || n.contains('fuel'))) ||
                            (kw == 'bills' && (n.contains('utilit') || n.contains('recharge')));
                      }).firstOrNull;
                      if (matchedCat != null) {
                        _selectedCategoryId = matchedCat.id;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tpl['emoji']!, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          '${tpl['title']} ₹${tpl['amount']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // --- Top Tab Segment Button ---
  Widget _buildTopTab(
    String typeVal,
    String label,
    Color activeBg,
    Color inactiveBg,
  ) {
    final isSelected = _type == typeVal;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _type = typeVal);
        },
        child: Container(
          color: isSelected ? activeBg : inactiveBg,
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isSelected ? Colors.white : Colors.white60,
            ),
          ),
        ),
      ),
    );
  }

  // --- Clean Keypad (media_1789475202193.png) ---
  Widget _buildCleanKeypad(bool isDark) {
    // 4 Columns:
    // Left 3 columns:
    // [7, 8, 9]
    // [4, 5, 6]
    // [1, 2, 3]
    // [., 0, ⌫]
    // Right 4th column (shaded background):
    // [÷, *, -, +, =]
    final leftRows = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      ['.', '0', '⌫'],
    ];
    final operators = ['÷', '*', '-', '+', '='];

    final opBg = isDark ? _keypadOperatorBgDark : _keypadOperatorBgLight;

    return Row(
      children: [
        // Digits (3 columns)
        Expanded(
          flex: 3,
          child: Column(
            children: leftRows.map((row) {
              return Expanded(
                child: Row(
                  children: row.map((val) {
                    return Expanded(
                      child: InkWell(
                        onTap: () => _onNumpadPress(val),
                        child: Center(
                          child: Text(
                            val == '⌫' ? '←' : val,
                            style: TextStyle(
                              fontSize: val == '⌫' ? 24 : 32,
                              fontWeight: FontWeight.w300,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF334155),
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
        ),

        // Operators (1 shaded column)
        Expanded(
          flex: 1,
          child: Container(
            color: opBg,
            child: Column(
              children: operators.map((op) {
                return Expanded(
                  child: InkWell(
                    onTap: () => _onNumpadPress(op),
                    child: Center(
                      child: Text(
                        op,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF64748B),
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
    );
  }

  // Receipt Scanner Dialog
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('☕ Starbucks (₹350)'),
                  onPressed: () {
                    controller.text =
                        'STARBUCKS COFFEE\nDate: 15/09/2026\nLatte: 280\nCroissant: 70\nTOTAL: Rs. 350.00';
                  },
                ),
                ActionChip(
                  label: const Text('🛒 D-Mart (₹2,450)'),
                  onPressed: () {
                    controller.text =
                        'DMART SUPERMARKET\nDate: 15/09/2026\nGroceries: 2450.00\nGRAND TOTAL: Rs. 2450.00';
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Paste receipt text...',
                border: OutlineInputBorder(),
              ),
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
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
