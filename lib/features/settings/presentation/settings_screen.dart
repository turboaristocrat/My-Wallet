import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/presentation/lock_screen.dart';
import '../../navigation/presentation/side_drawer.dart';
import '../../categories/presentation/manage_categories_dialog.dart';
import '../../sms/data/notification_listener_service.dart';
import '../../tags/presentation/manage_tags_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final void Function(String route) onNavigate;

  const SettingsScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedCurrency = 'INR (₹)';
  bool _biometricsEnabled = true;
  bool _notificationListenerEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadProfileName();
    _checkNotificationListener();
  }

  Future<void> _checkNotificationListener() async {
    final service = ref.read(notificationListenerServiceProvider);
    final granted = await service.isPermissionGranted();
    if (mounted) {
      setState(() => _notificationListenerEnabled = granted);
      if (granted) {
        service.startListening();
      }
    }
  }

  Future<void> _loadProfileName() async {
    final storage = ref.read(secureStorageProvider);
    final name = await storage.read(key: 'user_profile_name');
    if (name != null && name.isNotEmpty && mounted) {
      ref.read(userProfileNameProvider.notifier).state = name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final hideAmounts = ref.watch(hideAmountsProvider);
    final profileName = ref.watch(userProfileNameProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: AppSideDrawer(
        currentRoute: '/settings',
        onNavigate: widget.onNavigate,
      ),
      body: SafeArea(
        child: CustomScrollView(
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
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings & Security',
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
                            'App preferences, PIN, and appearance',
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

            // Content List
            SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // Section 0: Profile & Identity
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSectionTitle(isDark, 'Profile & Identity', Icons.person_rounded),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSettingsGroup(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.badge_rounded, color: AppColors.primary),
                        title: const Text('Display Name',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          profileName.isNotEmpty
                              ? profileName
                              : 'Set your name for personalized greetings',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.edit_rounded, size: 18),
                        onTap: () => _showEditProfileDialog(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 1: Security & Privacy
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSectionTitle(isDark, 'Security & Privacy', Icons.security_rounded),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSettingsGroup(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.pin_rounded, color: AppColors.primary),
                        title: const Text('Change 4-Digit Security PIN',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('PIN authentication required on launch',
                            style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showChangePinDialog(context),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.fingerprint_rounded, color: AppColors.primary),
                        title: const Text('Biometric Authentication',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Unlock using Fingerprint or Face ID',
                            style: TextStyle(fontSize: 12)),
                        value: _biometricsEnabled,
                        activeTrackColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() => _biometricsEnabled = val);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(val
                                  ? 'Biometric unlock enabled'
                                  : 'Biometric unlock disabled'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.visibility_off_rounded, color: AppColors.primary),
                        title: const Text('Privacy Mode (Hide Amounts)',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Mask account balances with ₹••••••',
                            style: TextStyle(fontSize: 12)),
                        value: hideAmounts,
                        activeTrackColor: AppColors.primary,
                        onChanged: (val) {
                          ref.read(hideAmountsProvider.notifier).state = val;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 2: Preferences
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSectionTitle(isDark, 'General Preferences', Icons.tune_rounded),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSettingsGroup(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.currency_rupee_rounded, color: AppColors.income),
                        title: const Text('Primary Currency',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text('Currently active: $_selectedCurrency',
                            style: const TextStyle(fontSize: 12)),
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCurrency,
                            dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                            items: ['INR (₹)', 'USD (\$)', 'EUR (€)', 'GBP (£)']
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCurrency = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 3: Appearance & Theme
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSectionTitle(isDark, 'Appearance & Theme', Icons.palette_rounded),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSettingsGroup(
                    isDark: isDark,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Interface Theme',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildThemeOption(
                                    label: 'Dark',
                                    icon: Icons.dark_mode_rounded,
                                    isSelected: themeMode == ThemeMode.dark,
                                    onTap: () => ref
                                        .read(themeModeProvider.notifier)
                                        .state = ThemeMode.dark,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildThemeOption(
                                    label: 'Light',
                                    icon: Icons.light_mode_rounded,
                                    isSelected: themeMode == ThemeMode.light,
                                    onTap: () => ref
                                        .read(themeModeProvider.notifier)
                                        .state = ThemeMode.light,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildThemeOption(
                                    label: 'System',
                                    icon: Icons.settings_brightness_rounded,
                                    isSelected: themeMode == ThemeMode.system,
                                    onTap: () => ref
                                        .read(themeModeProvider.notifier)
                                        .state = ThemeMode.system,
                                    isDark: isDark,
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
                // Section 4: Categories & Tags Management
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSectionTitle(isDark, 'Categories & Tags', Icons.category_rounded),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSettingsGroup(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.account_tree_rounded, color: AppColors.primary),
                        title: const Text('Categories & Subcategories',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Manage expense & income categories and subcategories',
                            style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => ManageCategoriesDialog.show(context),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.label_rounded, color: Color(0xFF26B2AB)),
                        title: const Text('Transaction Tags',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Add, edit, or remove custom tags and labels',
                            style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => ManageTagsDialog.show(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 5: Auto-Capture & Push Notifications (PennyWise Feature)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSectionTitle(isDark, 'Auto-Capture & Push Alerts', Icons.notifications_active_rounded),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSettingsGroup(
                    isDark: isDark,
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.mark_chat_unread_rounded, color: AppColors.primary),
                        title: const Text('Capture Bank & UPI Notifications',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Auto-detect transactions from GPay, PhonePe, Paytm, CRED & bank apps',
                            style: TextStyle(fontSize: 12)),
                        value: _notificationListenerEnabled,
                        activeTrackColor: AppColors.primary,
                        onChanged: (val) async {
                          final service = ref.read(notificationListenerServiceProvider);
                          if (val) {
                            final granted = await service.isPermissionGranted();
                            if (!granted) {
                              await service.openSettings();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enable "My Wallet" in Android Notification Access settings'),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              }
                            } else {
                              service.startListening();
                              setState(() => _notificationListenerEnabled = true);
                            }
                          } else {
                            service.stopListening();
                            setState(() => _notificationListenerEnabled = false);
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.bolt_rounded, color: AppColors.warning),
                        title: const Text('Automation Rules',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Auto-categorize, add tags, or drop blocked transactions',
                            style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => widget.onNavigate('/rules'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 6: Data Management & Portability
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSectionTitle(isDark, 'Data Management', Icons.folder_zip_rounded),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSettingsGroup(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.backup_rounded, color: AppColors.info),
                        title: const Text('Export & Local Backup',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Download CSV spreadsheets or JSON snapshots',
                            style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => widget.onNavigate('/backup'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_forever_rounded, color: AppColors.expense),
                        title: const Text('Reset All Local Data',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.expense)),
                        subtitle: const Text('Wipe all local accounts, transactions & rules',
                            style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => widget.onNavigate('/backup'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 5: App Information
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'My Wallet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version 1.0.0 • Local-First & Offline Architecture',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Zero cloud dependencies • 100% private financial tracking',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(bool isDark, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsGroup({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildThemeOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface : AppColors.lightBackground),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? Colors.white
                  : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePinDialog(BuildContext context) {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Security PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter new 4-digit PIN for device unlocking:'),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: InputDecoration(
                hintText: '••••',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.length != 4) return;

              final storage = ref.read(secureStorageProvider);
              await storage.write(key: 'app_pin', value: pin);

              if (context.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Security PIN successfully updated!'),
                    backgroundColor: AppColors.incomeGreen,
                  ),
                );
              }
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final nameController = TextEditingController(
      text: ref.read(userProfileNameProvider),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Display Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your name for dashboard greetings and reports:'),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Michaela, Rahul, Alex',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            onPressed: () async {
              final newName = nameController.text.trim();
              final storage = ref.read(secureStorageProvider);
              await storage.write(key: 'user_profile_name', value: newName);
              ref.read(userProfileNameProvider.notifier).state = newName;

              if (context.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Display name updated!'),
                    backgroundColor: AppColors.incomeGreen,
                  ),
                );
              }
            },
            child: const Text('Save Name'),
          ),
        ],
      ),
    );
  }
}
