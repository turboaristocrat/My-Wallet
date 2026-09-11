import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/database/app_database.dart';
import '../../accounts/data/account_repository.dart';
import '../data/transaction_repository.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final Transaction? initialTransaction;
  const AddTransactionSheet({super.key, this.initialTransaction});

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
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.initialTransaction != null
              ? 'Edit Transaction'
              : 'Add Transaction',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: () => _saveTransaction(),
          ),
        ],
      ),
      body: Column(
        children: [
          // TOP EMERALD ZONE: Toggle, Amount, Account/Category Selectors
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                // Segmented Type Selector (Expense / Income / Transfer)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      _buildTypeTab('expense', 'EXPENSE', AppColors.expense),
                      _buildTypeTab('income', 'INCOME', AppColors.income),
                      _buildTypeTab('transfer', 'TRANSFER', AppColors.transfer),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Large Amount Display
                Text(
                  '₹ $_amountStr',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),

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
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: AppStyles.roundedM,
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
                                    fontWeight: FontWeight.w600),
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
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: AppStyles.roundedM,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedToAccountId,
                                      hint: const Text(
                                        'To Account',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      dropdownColor: isDark
                                          ? AppColors.darkCard
                                          : Colors.white,
                                      icon: const Icon(
                                          Icons.arrow_drop_down_rounded,
                                          color: Colors.white),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
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
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: AppStyles.roundedM,
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
                                          fontWeight: FontWeight.w600),
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
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isDetailsExpanded
                        ? 'Hide Details'
                        : '↑ Swipe / Tap for more details',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM VIEW: Either Numpad (fast) OR Details Form (expanded)
          Expanded(
            child: _isDetailsExpanded
                ? _buildDetailsForm(isDark)
                : _buildCalculatorNumpad(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab(String typeVal, String label, Color activeIndicator) {
    final isSelected = _type == typeVal;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = typeVal),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.primaryDark : Colors.white70,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: buttons.map((row) {
          return Expanded(
            child: Row(
              children: row.map((val) {
                if (val.isEmpty) return const Spacer();
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
                      borderRadius: AppStyles.roundedM,
                      child: Container(
                        decoration: BoxDecoration(
                          color: val == '✓'
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightBackground),
                          borderRadius: AppStyles.roundedM,
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          val,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: val == '✓'
                                ? Colors.white
                                : (isDark
                                    ? Colors.white
                                    : AppColors.lightTextPrimary),
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payee / Merchant
          TextField(
            controller: _payeeController,
            decoration: InputDecoration(
              labelText: 'Payee / Merchant',
              hintText: 'e.g. Swiggy, Starbucks, Uber',
              prefixIcon: const Icon(Icons.store_rounded, size: 20),
              border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
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
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      border:
                          OutlineInputBorder(borderRadius: AppStyles.roundedM),
                      prefixIcon:
                          const Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                    child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
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
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Time',
                      border:
                          OutlineInputBorder(borderRadius: AppStyles.roundedM),
                      prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
                    ),
                    child: Text(_selectedTime.format(context)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Payment Mode
          DropdownButtonFormField<String>(
            initialValue: _paymentType,
            decoration: InputDecoration(
              labelText: 'Payment Mode',
              prefixIcon: const Icon(Icons.payment_rounded, size: 20),
              border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
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
            decoration: InputDecoration(
              labelText: 'Note',
              hintText: 'Add an optional description...',
              prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
            ),
          ),
          const SizedBox(height: 14),

          // Receipt Attachment placeholder
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: AppStyles.roundedM),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI Receipt Scanning available in Phase 2')),
              );
            },
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Attach Receipt (AI Scanning) ✨'),
          ),
          const SizedBox(height: 24),

          // Action Buttons: Save & Add Another and Save
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.roundedM),
                  ),
                  onPressed: () => _saveTransaction(addAnother: true),
                  child: const Text('Save & Add Another'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppStyles.roundedM),
                  ),
                  onPressed: () => _saveTransaction(),
                  child: const Text(
                    'Save Transaction',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
