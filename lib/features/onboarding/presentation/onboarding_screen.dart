import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../auth/presentation/lock_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _selectedMode = 'auto'; // 'auto' (hybrid) or 'manual'
  String _pin = '';
  String _confirmPin = '';
  bool _enableBiometrics = true;
  String? _pinError;

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() async {
    if (_pin.length != 4) {
      setState(() => _pinError = 'Please enter a 4-digit PIN');
      return;
    }
    if (_pin != _confirmPin) {
      setState(() => _pinError = 'PINs do not match');
      return;
    }

    final storage = ref.read(secureStorageProvider);
    await storage.write(key: 'app_pin', value: _pin);
    await storage.write(
        key: 'biometrics_enabled', value: _enableBiometrics ? 'true' : 'false');
    await storage.write(key: 'input_mode', value: _selectedMode);
    await storage.write(key: 'onboarding_complete', value: 'true');

    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(4, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  if (_currentPage < 3)
                    TextButton(
                      onPressed: () {
                        _pageController.animateToPage(
                          3,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Animated Slide Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomeSlide(isDark),
                  _buildModeSelectionSlide(isDark),
                  _buildPermissionsSlide(isDark),
                  _buildPinSetupSlide(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Slide 1: Welcome
  Widget _buildWelcomeSlide(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppStyles.heroGlowShadow,
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to My Wallet',
            textAlign: TextAlign.center,
            style: AppStyles.displayMedium.copyWith(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your 100% private, offline-first personal finance companion designed for seamless tracking.',
            textAlign: TextAlign.center,
            style: AppStyles.bodyLarge.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.roundedM,
                ),
                elevation: 0,
              ),
              onPressed: _nextPage,
              child: const Text(
                'Get Started',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Slide 2: Mode Selection (Auto Hybrid vs Manual)
  Widget _buildModeSelectionSlide(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Your Experience',
            style: AppStyles.displayMedium.copyWith(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select how you want to track your transactions. You can always change this later in Settings.',
            style: AppStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Option A: Auto Mode (Hybrid)
          _buildModeCard(
            id: 'auto',
            title: 'Auto Mode (Hybrid)',
            badge: 'Recommended',
            description:
                'Bank SMS & notifications auto-sync into an Inbox Review Queue + full manual logging anytime.',
            icon: Icons.sync_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Option B: Manual Mode
          _buildModeCard(
            id: 'manual',
            title: 'Manual Mode',
            description:
                'Zero permissions requested. Log expenses, incomes, and transfers manually using the calculator.',
            icon: Icons.edit_note_rounded,
            isDark: isDark,
          ),

          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.roundedM,
                ),
                elevation: 0,
              ),
              onPressed: () {
                if (_selectedMode == 'manual') {
                  // Skip permissions slide directly to PIN setup
                  _pageController.animateToPage(
                    3,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                  );
                } else {
                  _nextPage();
                }
              },
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String id,
    required String title,
    String? badge,
    required String description,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedMode == id;
    return InkWell(
      onTap: () => setState(() => _selectedMode = id),
      borderRadius: AppStyles.roundedL,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: AppStyles.roundedL,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppStyles.heroGlowShadow : AppStyles.softShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryContainer
                    : (isDark ? AppColors.darkBackground : AppColors.lightBackground),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.lightTextSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: AppStyles.titleMedium.copyWith(
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.incomeContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Recommended',
                            style: TextStyle(
                              color: AppColors.income,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
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
          ],
        ),
      ),
    );
  }

  // Slide 3: Permissions & Scanner
  Widget _buildPermissionsSlide(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Permissions',
            style: AppStyles.displayMedium.copyWith(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'To automatically detect transactions, My Wallet reads incoming bank SMS on-device. No data ever leaves your phone.',
            style: AppStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 32),
          _buildPermissionItem(
            icon: Icons.sms_rounded,
            title: 'SMS Access',
            description: 'Reads banking debit/credit alerts to prepare review queue.',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildPermissionItem(
            icon: Icons.notifications_active_rounded,
            title: 'Notification Access',
            description: 'Captures instant UPI payment alerts from GPay, PhonePe, Cred.',
            isDark: isDark,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.roundedM,
                ),
                elevation: 0,
              ),
              onPressed: _nextPage,
              child: const Text(
                'Grant & Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppStyles.roundedL,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppStyles.titleMedium.copyWith(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppStyles.bodyMedium.copyWith(
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
    );
  }

  // Slide 4: Set Security PIN
  Widget _buildPinSetupSlide(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Secure Your Wallet',
            style: AppStyles.displayMedium.copyWith(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a 4-digit PIN to lock your financial records.',
            style: AppStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Create 4-Digit PIN',
              border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
            ),
            onChanged: (val) => _pin = val,
          ),
          const SizedBox(height: 14),
          TextField(
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Confirm PIN',
              border: OutlineInputBorder(borderRadius: AppStyles.roundedM),
              errorText: _pinError,
            ),
            onChanged: (val) => _confirmPin = val,
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable Fingerprint / Biometrics'),
            value: _enableBiometrics,
            activeTrackColor: AppColors.primary,
            onChanged: (val) => setState(() => _enableBiometrics = val),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.roundedM,
                ),
                elevation: 0,
              ),
              onPressed: _finishOnboarding,
              child: const Text(
                'Complete Setup & Open App',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
