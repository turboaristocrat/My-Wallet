import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../navigation/presentation/side_drawer.dart';

class FeatureHubScreen extends ConsumerStatefulWidget {
  final String route;
  final ValueChanged<String> onNavigate;

  const FeatureHubScreen({
    super.key,
    required this.route,
    required this.onNavigate,
  });

  @override
  ConsumerState<FeatureHubScreen> createState() => _FeatureHubScreenState();
}

class _FeatureHubScreenState extends ConsumerState<FeatureHubScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String get _title {
    switch (widget.route) {
      case '/gift_cards':
        return 'Gift Cards';
      case '/shopping_lists':
        return 'Shopping Lists';
      case '/warranties':
        return 'Warranties Vault';
      case '/family_mode':
        return 'Family Mode';
      default:
        return 'Feature Hub';
    }
  }

  IconData get _icon {
    switch (widget.route) {
      case '/gift_cards':
        return Icons.card_giftcard_rounded;
      case '/shopping_lists':
        return Icons.shopping_cart_rounded;
      case '/warranties':
        return Icons.verified_user_rounded;
      case '/family_mode':
        return Icons.family_restroom_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  Color get _accentColor {
    switch (widget.route) {
      case '/gift_cards':
        return const Color(0xFFEC4899);
      case '/shopping_lists':
        return const Color(0xFF00D2FF);
      case '/warranties':
        return const Color(0xFF10B981);
      case '/family_mode':
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.primary;
    }
  }

  String get _description {
    switch (widget.route) {
      case '/gift_cards':
        return 'Store and track your Amazon, Flipkart, Myntra, and retail gift card balances with barcode scan & expiry alerts.';
      case '/shopping_lists':
        return 'Create smart categorized shopping checklists that estimate costs in real-time and auto-convert to expense transactions.';
      case '/warranties':
        return 'Securely store appliance purchase receipts, serial numbers, warranty expiry dates, and AMC renewal reminders.';
      case '/family_mode':
        return 'Manage shared household budgets, track spouse/family member card spending, and maintain a combined family net worth.';
      default:
        return 'Advanced personal finance auxiliary tool.';
    }
  }

  List<Map<String, dynamic>> get _sampleItems {
    switch (widget.route) {
      case '/gift_cards':
        return [
          {
            'title': 'Amazon Pay E-Gift Card',
            'sub': 'Exp: Dec 2026 • Card: •••• 9821',
            'amount': '₹2,500',
            'badge': 'Active',
            'color': const Color(0xFFF59E0B),
          },
          {
            'title': 'Myntra Fashion Voucher',
            'sub': 'Exp: Oct 2026 • Card: •••• 4120',
            'amount': '₹1,000',
            'badge': 'Active',
            'color': const Color(0xFFEC4899),
          },
        ];
      case '/shopping_lists':
        return [
          {
            'title': 'Monthly Groceries & Staples',
            'sub': '8 of 12 items checked',
            'amount': 'Est. ₹4,200',
            'badge': 'In Progress',
            'color': const Color(0xFF00D2FF),
          },
          {
            'title': 'Home Office Tech Setup',
            'sub': '3 items • Monitor, Cable, Lamp',
            'amount': 'Est. ₹18,500',
            'badge': 'Planned',
            'color': const Color(0xFF8B5CF6),
          },
        ];
      case '/warranties':
        return [
          {
            'title': 'MacBook Pro 14" M3',
            'sub': 'AppleCare+ expires Nov 2026',
            'amount': 'Invoice Attached',
            'badge': 'Valid',
            'color': const Color(0xFF10B981),
          },
          {
            'title': 'LG 55" OLED Smart TV',
            'sub': 'Panel warranty expires Aug 2027',
            'amount': 'Invoice Attached',
            'badge': 'Valid',
            'color': const Color(0xFF38BDF8),
          },
        ];
      case '/family_mode':
        return [
          {
            'title': 'Household Joint Account',
            'sub': '2 active members (You & Sarah)',
            'amount': '₹64,200',
            'badge': 'Synced',
            'color': const Color(0xFF8B5CF6),
          },
          {
            'title': 'Kids Education & Sports Fund',
            'sub': 'Target: ₹1,50,000 / year',
            'amount': '₹45,000',
            'badge': 'Monthly SIP',
            'color': const Color(0xFF0D9488),
          },
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: AppSideDrawer(
        currentRoute: widget.route,
        onNavigate: (r) {
          Navigator.of(context).pop();
          widget.onNavigate(r);
        },
      ),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          _title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home_rounded),
            onPressed: () => widget.onNavigate('/dashboard'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Intro Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: AppStyles.roundedXL,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                boxShadow: AppStyles.softShadow,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_icon, color: _accentColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'VAULT',
                                style: TextStyle(
                                  color: _accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _description,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
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
            const SizedBox(height: 24),

            // Active Vault Records
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved Records',
                  style: AppStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Add $_title modal is ready!')),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('Add New'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sampleItems.length,
              itemBuilder: (context, index) {
                final item = _sampleItems[index];
                final color = item['color'] as Color;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: AppStyles.roundedL,
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    boxShadow: AppStyles.softShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item['sub'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item['amount'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['badge'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // On-Device Privacy Shield Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface.withValues(alpha: 0.5)
                    : AppColors.lightSurface,
                borderRadius: AppStyles.roundedL,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All ${_title.toLowerCase()} data is encrypted and stored 100% locally on your device.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
