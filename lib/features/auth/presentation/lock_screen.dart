import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

class LockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _enteredPin = '';
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final biometricsEnabled = await storage.read(key: 'biometrics_enabled');
      if (biometricsEnabled == 'true') {
        final canCheck = await _localAuth.canCheckBiometrics;
        if (canCheck) {
          final authenticated = await _localAuth.authenticate(
            localizedReason: 'Scan fingerprint to unlock My Wallet',
            persistAcrossBackgrounding: true,
          );
          if (authenticated && mounted) {
            widget.onUnlocked();
          }
        }
      }
    } catch (_) {}
  }

  void _onDigitPress(String digit) async {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _isError = false;
        _errorMessage = null;
      });

      if (_enteredPin.length == 4) {
        final storage = ref.read(secureStorageProvider);
        final savedPin = await storage.read(key: 'app_pin') ?? '1234'; // default fallback for initial run

        if (_enteredPin == savedPin) {
          widget.onUnlocked();
        } else {
          setState(() {
            _isError = true;
            _errorMessage = 'Incorrect PIN. Try again.';
            _enteredPin = '';
          });
        }
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _isError = false;
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Logo & Title
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppStyles.roundedL,
                boxShadow: AppStyles.heroGlowShadow,
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Enter PIN',
              style: AppStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Enter your 4-digit security PIN',
              style: AppStyles.bodyMedium.copyWith(
                color: _isError
                    ? AppColors.expense
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
            const SizedBox(height: 32),

            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _enteredPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isError
                        ? AppColors.expense
                        : (isFilled
                            ? AppColors.primary
                            : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                  ),
                );
              }),
            ),
            const Spacer(),

            // Numpad Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3'], isDark),
                  const SizedBox(height: 16),
                  _buildRow(['4', '5', '6'], isDark),
                  const SizedBox(height: 16),
                  _buildRow(['7', '8', '9'], isDark),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Biometric button
                      IconButton(
                        onPressed: _checkBiometrics,
                        icon: const Icon(Icons.fingerprint_rounded, size: 28),
                        color: AppColors.primary,
                      ),
                      _buildKey('0', isDark),
                      // Backspace button
                      IconButton(
                        onPressed: _onBackspace,
                        icon: const Icon(Icons.backspace_outlined, size: 24),
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ],
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

  Widget _buildRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKey(d, isDark)).toList(),
    );
  }

  Widget _buildKey(String digit, bool isDark) {
    return InkWell(
      onTap: () => _onDigitPress(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 68,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          boxShadow: AppStyles.softShadow,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
        ),
      ),
    );
  }
}
