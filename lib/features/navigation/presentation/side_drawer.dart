import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../dashboard/data/dashboard_providers.dart';

/// The BudgetBakers-inspired Side Drawer with 5 grouped sections,
/// silent dividers, live Inbox badge, and bottom quick toggles.
class AppSideDrawer extends ConsumerWidget {
  final String currentRoute;
  final ValueChanged<String>? onNavigate;

  const AppSideDrawer({
    super.key,
    required this.currentRoute,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final hideAmounts = ref.watch(hideAmountsProvider);
    final pendingCount = ref.watch(pendingQueueCountProvider);

    return Drawer(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightCard,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header - Clean App Identity Only
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: AppStyles.roundedM,
                      boxShadow: AppStyles.heroGlowShadow,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'My Wallet',
                    style: AppStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Menu List with 5 Groups and Silent Dividers
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // GROUP 1: Primary
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.home_rounded,
                    label: 'Home / Dashboard',
                    route: '/dashboard',
                    isSelected: currentRoute == '/dashboard',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.inbox_rounded,
                    label: 'Inbox',
                    route: '/inbox',
                    isSelected: currentRoute == '/inbox',
                    badgeCount: pendingCount,
                  ),

                  _buildDivider(isDark),

                  // GROUP 2: Core Finance
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.account_balance_rounded,
                    label: 'Accounts',
                    route: '/accounts',
                    isSelected: currentRoute == '/accounts',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.receipt_long_rounded,
                    label: 'Transactions',
                    route: '/transactions',
                    isSelected: currentRoute == '/transactions',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.event_repeat_rounded,
                    label: 'Recurring',
                    route: '/recurring',
                    isSelected: currentRoute == '/recurring',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.pie_chart_rounded,
                    label: 'Budgets',
                    route: '/budgets',
                    isSelected: currentRoute == '/budgets',
                  ),

                  _buildDivider(isDark),

                  // GROUP 3: Tracking
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.analytics_rounded,
                    label: 'Analytics & Reports',
                    route: '/analytics',
                    isSelected: currentRoute == '/analytics',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.handshake_rounded,
                    label: 'Debts & Loans',
                    route: '/debts',
                    isSelected: currentRoute == '/debts',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.track_changes_rounded,
                    label: 'Goals',
                    route: '/goals',
                    isSelected: currentRoute == '/goals',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.trending_up_rounded,
                    label: 'Investments',
                    route: '/investments',
                    isSelected: currentRoute == '/investments',
                  ),

                  _buildDivider(isDark),

                  // GROUP 4: Extras
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.group_rounded,
                    label: 'Split Expenses',
                    route: '/split_expenses',
                    isSelected: currentRoute == '/split_expenses',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.card_giftcard_rounded,
                    label: 'Gift Cards',
                    route: '/gift_cards',
                    isSelected: currentRoute == '/gift_cards',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.shopping_cart_rounded,
                    label: 'Shopping Lists',
                    route: '/shopping_lists',
                    isSelected: currentRoute == '/shopping_lists',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.verified_user_rounded,
                    label: 'Warranties',
                    route: '/warranties',
                    isSelected: currentRoute == '/warranties',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.family_restroom_rounded,
                    label: 'Family Mode',
                    route: '/family_mode',
                    isSelected: currentRoute == '/family_mode',
                  ),

                  _buildDivider(isDark),

                  // GROUP 5: System
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.auto_awesome_rounded,
                    label: 'AI Copilot',
                    route: '/copilot',
                    isSelected: currentRoute == '/copilot',
                    badgeText: '✨ AI',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    route: '/settings',
                    isSelected: currentRoute == '/settings',
                  ),
                ],
              ),
            ),

            // Bottom Fixed Quick Toggles
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            size: 18,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Dark Mode',
                            style: AppStyles.bodyMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      Switch.adaptive(
                        value: isDark,
                        activeTrackColor: AppColors.primary,
                        onChanged: (val) {
                          ref.read(themeModeProvider.notifier).state =
                              val ? ThemeMode.dark : ThemeMode.light;
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hideAmounts
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 18,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Hide Amounts',
                            style: AppStyles.bodyMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      Switch.adaptive(
                        value: hideAmounts,
                        activeTrackColor: AppColors.primary,
                        onChanged: (val) {
                          ref.read(hideAmountsProvider.notifier).state = val;
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Divider(
        height: 1,
        color: isDark ? AppColors.darkBorder : AppColors.lightDivider,
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String route,
    required bool isSelected,
    int? badgeCount,
    String? badgeText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: AppStyles.roundedM),
        tileColor: isSelected
            ? (isDark
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.primaryContainer)
            : Colors.transparent,
        leading: Icon(
          icon,
          size: 20,
          color: isSelected
              ? activeColor
              : (isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? activeColor
                : (isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary),
          ),
        ),
        trailing: badgeCount != null && badgeCount > 0
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.expense,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : badgeText != null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.aiBadgeContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: AppColors.aiBadge,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
        onTap: () {
          Navigator.of(context).pop(); // Close drawer
          if (onNavigate != null) {
            onNavigate!(route);
          }
        },
      ),
    );
  }
}
