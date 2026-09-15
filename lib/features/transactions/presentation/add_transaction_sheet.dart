import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/database/app_database.dart';
import '../../accounts/data/account_repository.dart';
import '../../receipts/data/receipt_scanner_service.dart';
import '../data/transaction_repository.dart';

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
  final List<String> _tags = [];
  bool _isDetailsExpanded = false;
  String? _attachedReceiptSummary;

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      final t = widget.initialTransaction!;
      _type = t.type;
      _amountStr = t.amount.toStringAsFixed(0);
      _selectedAccountId = t.accountId;
      _selectedToAccountId = t.toAccountId;
      _selectedCategoryId = t.categoryId;
      _payeeController.text = t.merchantName ?? '';
      _noteController.text = t.note ?? '';
      _selectedDate = t.transactionDate;
      _selectedTime = TimeOfDay.fromDateTime(t.transactionDate);
      _paymentType = t.paymentType;
      _status = t.status;
      _isDetailsExpanded = true;
    } else if (widget.preselectedAccountId != null) {
      _selectedAccountId = widget.preselectedAccountId;
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
      } else if (val == '.') {
        if (!_amountStr.contains('.')) {
          _amountStr += '.';
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

  Future<void> _saveTransaction({bool addAnother = false}) async {
    final amount = double.tryParse(_amountStr) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
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
    await repo.createTransaction(
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

    if (!mounted) return;

    if (addAnother) {
      setState(() {
        _amountStr = '0';
        _payeeController.clear();
        _noteController.clear();
        _tags.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved! Ready for next transaction')),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accountsAsync = ref.watch(activeAccountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.lightTextPrimary,
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
          IconButton(
            icon: const Icon(Icons.check_rounded),
            color: AppColors.income,
            onPressed: () => _saveTransaction(),
          ),
        ],
      ),
      body: Column(
        children: [
          // TOP HERO ZONE: Type Toggle, Dynamic Amount, Account & Category Selectors
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradientViolet,
              borderRadius: AppStyles.roundedL,
              boxShadow: AppStyles.heroGlowShadow,
            ),
            child: Column(
              children: [
                // Segmented Type Selector (Expense / Income / Transfer)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      _buildTypeTab('expense', 'EXPENSE', AppColors.expense),
                      _buildTypeTab('income', 'INCOME', AppColors.income),
                      _buildTypeTab('transfer', 'TRANSFER', AppColors.transfer),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Large Bold Amount Display
                Text(
                  '₹ $_amountStr',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.6,
                    shadows: [
                      Shadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Account & Category Selectors
                Row(
                  children: [
                    // Source Account Selector
                    Expanded(
                      child: accountsAsync.when(
                        data: (accounts) {
                          if (accounts.isNotEmpty &&
                              _selectedAccountId == null) {
                            _selectedAccountId = accounts.first.id;
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedAccountId,
                                dropdownColor: isDark
                                    ? AppColors.darkCard
                                    : Colors.white,
                                icon: const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: Colors.white),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                                isExpanded: true,
                                items: accounts.map((a) {
                                  return DropdownMenuItem(
                                    value: a.id,
                                    child: Text(
                                      a.name,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedAccountId = val),
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox(),
                        error: (_, _) => const SizedBox(),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Target Account (if transfer) OR Category (if expense/income)
                    Expanded(
                      child: _type == 'transfer'
                          ? accountsAsync.when(
                              data: (accounts) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedToAccountId,
                                      hint: const Text(
                                        'To Account',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      dropdownColor: isDark
                                          ? AppColors.darkCard
                                          : Colors.white,
                                      icon: const Icon(
                                          Icons.arrow_drop_down_rounded,
                                          color: Colors.white),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13),
                                      isExpanded: true,
                                      items: accounts.map((a) {
                                        return DropdownMenuItem(
                                          value: a.id,
                                          child: Text(
                                            a.name,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : AppColors.lightTextPrimary,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(
                                          () => _selectedToAccountId = val),
                                    ),
                                  ),
                                );
                              },
                              loading: () => const SizedBox(),
                              error: (_, _) => const SizedBox(),
                            )
                          : categoriesAsync.when(
                              data: (categories) {
                                if (categories.isNotEmpty &&
                                    _selectedCategoryId == null) {
                                  _selectedCategoryId = categories.first.id;
                                }
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCategoryId,
                                      dropdownColor: isDark
                                          ? AppColors.darkCard
                                          : Colors.white,
                                      icon: const Icon(
                                          Icons.arrow_drop_down_rounded,
                                          color: Colors.white),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13),
                                      isExpanded: true,
                                      items: categories.map((c) {
                                        return DropdownMenuItem(
                                          value: c.id,
                                          child: Text(
                                            c.name,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : AppColors.lightTextPrimary,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(
                                          () => _selectedCategoryId = val),
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

          // PULL-UP EXPANDER HANDLE
          InkWell(
            onTap: () =>
                setState(() => _isDetailsExpanded = !_isDetailsExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isDetailsExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 18,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isDetailsExpanded
                        ? 'Hide Details (Show Keypad)'
                        : 'Show Details & Notes',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM VIEW: Either Numpad (fast entry) OR Details Form (expanded)
          Expanded(
            child: _isDetailsExpanded
                ? _buildDetailsForm(isDark)
                : _buildCalculatorNumpad(isDark),
          ),
        ],
      ),
    );
  }

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
                      color: activeAccent.withValues(alpha: 0.35),
                      blurRadius: 8,
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
              color: isSelected ? activeAccent : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  // Calculator Keypad
  Widget _buildCalculatorNumpad(bool isDark) {
    final buttons = [
      ['7', '8', '9', 'C'],
      ['4', '5', '6', '⌫'],
      ['1', '2', '3', '.'],
      ['0', '00', '', '✓'],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: buttons.map((row) {
          return Expanded(
            child: Row(
              children: row.map((val) {
                if (val.isEmpty) return const Spacer();
                final isAction = val == '✓';
                final isClear = val == 'C' || val == '⌫';

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: InkWell(
                      onTap: () {
                        if (val == '✓') {
                          _saveTransaction();
                        } else {
                          _onNumpadPress(val);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isAction ? AppColors.primaryGradient : null,
                          color: isAction
                              ? null
                              : (isClear
                                  ? (isDark
                                      ? AppColors.darkSurface
                                      : AppColors.expenseContainer.withValues(alpha: 0.3))
                                  : (isDark
                                      ? AppColors.darkCard
                                      : Colors.white)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAction
                                ? Colors.transparent
                                : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder),
                          ),
                          boxShadow: isAction
                              ? AppStyles.heroGlowShadow
                              : AppStyles.softShadow,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          val,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: isAction
                                ? Colors.white
                                : (isClear
                                    ? AppColors.expense
                                    : (isDark
                                        ? Colors.white
                                        : AppColors.lightTextPrimary)),
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

  // Expanded Pull-up Details Form
  Widget _buildDetailsForm(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payee / Merchant
          TextField(
            controller: _payeeController,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Payee / Merchant',
              hintText: 'e.g. Swiggy, Starbucks, Uber',
              prefixIcon: const Icon(Icons.store_rounded, size: 20),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.white,
              border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppStyles.roundedM,
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Date & Time pickers side by side
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
                      fillColor: isDark ? AppColors.darkCard : Colors.white,
                      border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppStyles.roundedM,
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      prefixIcon:
                          const Icon(Icons.calendar_today_rounded, size: 18),
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
                      fillColor: isDark ? AppColors.darkCard : Colors.white,
                      border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppStyles.roundedM,
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
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

          // Payment Mode
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
              fillColor: isDark ? AppColors.darkCard : Colors.white,
              border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppStyles.roundedM,
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'upi', child: Text('UPI (Google Pay, PhonePe, Paytm)')),
              DropdownMenuItem(value: 'card', child: Text('Debit / Credit Card')),
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'net_banking', child: Text('Net Banking')),
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
              fillColor: isDark ? AppColors.darkCard : Colors.white,
              border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppStyles.roundedM,
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Receipt Attachment Widget
          if (_attachedReceiptSummary != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.incomeGreen.withValues(alpha: 0.15),
                borderRadius: AppStyles.roundedM,
                border: Border.all(color: AppColors.incomeGreen.withValues(alpha: 0.4)),
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
                    onPressed: () => setState(() => _attachedReceiptSummary = null),
                  ),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: AppStyles.roundedM),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              onPressed: () => _openReceiptScannerDialog(context),
              icon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
              label: Text(
                'Scan / Attach Receipt ✨',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Action Buttons: Save & Add Another and Save
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.roundedM),
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
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
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: AppStyles.roundedM,
                    gradient: AppColors.primaryGradient,
                    boxShadow: AppStyles.heroGlowShadow,
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppStyles.roundedM),
                    ),
                    onPressed: () => _saveTransaction(),
                    child: const Text(
                      'Save Transaction',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
                // Preset chips
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
                  _amountStr = parsed.totalAmount.toStringAsFixed(0);
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

