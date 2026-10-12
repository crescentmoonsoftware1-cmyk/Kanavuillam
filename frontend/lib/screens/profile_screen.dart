import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const ProfileScreen({super.key, this.userData});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  bool _isSettingsOpen = false;
  bool _notificationsEnabled = true;

  // Editable user fields
  String _name = 'Thomas';
  String _phone = '+91 98765 43210';
  String _email = 'thomas@kanavuillam.com';
  String _city = 'Erode, Tamil Nadu';

  int _runCount = 0;
  int _amountSpent = 0;

  // Active inline editing field: null, 'name', 'phone', 'email', 'city'
  String? _editingField;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _name);
    _phoneController = TextEditingController(text: _phone);
    _emailController = TextEditingController(text: _email);
    _cityController = TextEditingController(text: _city);
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final meta = widget.userData?['user_metadata'] as Map<String, dynamic>?;

    final currentEmail = (widget.userData?['email'] as String?) ??
        prefs.getString('user_email') ??
        '';

    final savedName = (meta?['name'] as String?) ??
        (meta?['full_name'] as String?) ??
        prefs.getString('user_name') ??
        (currentEmail.isNotEmpty ? currentEmail.split('@').first : 'User');

    final savedEmail = currentEmail;
    final savedPhone = (meta?['phone'] as String?) ??
        prefs.getString('user_phone') ??
        '';
    final savedCity = prefs.getString('user_address') ?? 'Tamil Nadu, India';

    if (mounted) {
      setState(() {
        _name = savedName;
        _email = savedEmail;
        _phone = savedPhone;
        _city = savedCity;

        _nameController.text = _name;
        _phoneController.text = _phone;
        _emailController.text = _email;
        _cityController.text = _city;
      });
    }

    if (savedEmail.isEmpty || savedEmail == 'unknown') {
      if (mounted) {
        setState(() {
          _runCount = 0;
          _amountSpent = 0;
        });
      }
      return;
    }

    try {
      final projects = await _apiService.getAllProjects(savedEmail);
      if (mounted) {
        int total = 0;
        for (var p in projects) {
          String pName = p['name'] ?? '';
          if (pName.contains('|')) {
            var parts = pName.split('|');
            if (parts.length > 2) {
              total += (double.tryParse(parts[2]) ?? 500.0).round();
            } else {
              total += 500;
            }
          } else {
            total += 500;
          }
        }
        setState(() {
          _runCount = projects.length;
          _amountSpent = total;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _runCount = 0;
          _amountSpent = 0;
        });
      }
    }
  }

  Future<void> _saveField(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == 'name') {
      await prefs.setString('user_name', value);
      setState(() => _name = value);
    } else if (key == 'phone') {
      await prefs.setString('user_phone', value);
      setState(() => _phone = value);
    } else if (key == 'email') {
      await prefs.setString('user_email', value);
      setState(() => _email = value);
    } else if (key == 'city') {
      await prefs.setString('user_address', value);
      setState(() => _city = value);
    }
    setState(() => _editingField = null);
  }

  void _confirmLogout(BuildContext context, AppConfigProvider config) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: config.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          config.tr('Log out?', 'வெளியேறவா?'),
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w600,
            color: config.primaryTextColor,
          ),
        ),
        content: Text(
          config.tr(
            'Are you sure you want to sign out of your account?',
            'உங்கள் கணக்கிலிருந்து வெளியேற விரும்புகிறீர்களா?',
          ),
          style: GoogleFonts.inter(
            fontSize: 13,
            color: config.secondaryTextColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              config.tr('Cancel', 'ரத்து செய்'),
              style: GoogleFonts.inter(
                color: config.secondaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(
              config.tr('Log out', 'வெளியேறு'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppConfigProvider config;
    try {
      config = context.watch<AppConfigProvider>();
    } catch (_) {
      config = AppConfigProvider();
    }

    final isDark = config.isDarkMode;
    final bgColor = config.bgColor;
    final cardColor = config.cardColor;
    final primaryTextColor = config.primaryTextColor;
    final secondaryTextColor = config.secondaryTextColor;
    final borderColor = config.borderColor;
    final surfacePillColor = config.surfacePillColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 16.0,
                bottom: 120.0, // Space for bottom nav
              ),
              child: Column(
                children: [
                  // 1. TOP HEADER
                  SizedBox(
                    height: 40,
                    child: Center(
                      child: Text(
                        config.tr('Profile', 'சுயவிவரம்'),
                        style: GoogleFonts.syne(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. AVATAR BLOCK & INLINE EDITABLE NAME
                  Column(
                    children: [
                      SizedBox(
                        width: 84,
                        height: 84,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: borderColor, width: 2),
                                color: surfacePillColor,
                              ),
                              child: ClipOval(
                                child: Center(
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 44,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.primary,
                                  border: Border.all(
                                    color: bgColor,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.3 : 0.15,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.edit,
                                  size: 13,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Inline Editable Name
                      if (_editingField == 'name')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 150,
                              height: 36,
                              child: TextField(
                                controller: _nameController,
                                autofocus: true,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.syne(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: primaryTextColor,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  border: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: primaryTextColor,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                onSubmitted: (val) {
                                  if (val.trim().isNotEmpty) {
                                    _saveField('name', val.trim());
                                  } else {
                                    setState(() => _editingField = null);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                if (_nameController.text.trim().isNotEmpty) {
                                  _saveField('name', _nameController.text.trim());
                                } else {
                                  setState(() => _editingField = null);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 13,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                _nameController.text = _name;
                                setState(() => _editingField = null);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: surfacePillColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 13,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        GestureDetector(
                          onTap: () {
                            _nameController.text = _name;
                            setState(() => _editingField = 'name');
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _name,
                                style: GoogleFonts.syne(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: primaryTextColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: secondaryTextColor,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 3. COMBINED PROFILE MEGA CARD
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.06,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // --- STATS ROW ---
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 18.0,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      config.tr('PROJECTS', 'திட்டங்கள்'),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: secondaryTextColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$_runCount',
                                      style: GoogleFonts.syne(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 36,
                                color: borderColor,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      config.tr('TOTAL SPENT', 'மொத்த செலவு'),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: secondaryTextColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹$_amountSpent',
                                      style: GoogleFonts.syne(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        Divider(color: borderColor, height: 1, thickness: 1),

                        // --- USER CONTACT DETAILS (INLINE EDITABLE) ---
                        _buildInlineInfoRow(
                          fieldKey: 'phone',
                          icon: Icons.phone_outlined,
                          label: config.tr('PHONE', 'தொலைபேசி'),
                          value: _phone,
                          controller: _phoneController,
                          config: config,
                          onSave: (v) => _saveField('phone', v),
                        ),
                        Divider(
                          color: borderColor,
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        _buildInlineInfoRow(
                          fieldKey: 'email',
                          icon: Icons.email_outlined,
                          label: config.tr('EMAIL', 'மின்னஞ்சல்'),
                          value: _email,
                          controller: _emailController,
                          config: config,
                          onSave: (v) => _saveField('email', v),
                        ),
                        Divider(
                          color: borderColor,
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        _buildInlineInfoRow(
                          fieldKey: 'city',
                          icon: Icons.location_on_outlined,
                          label: config.tr('CITY', 'இருப்பிடம்'),
                          value: _city,
                          controller: _cityController,
                          config: config,
                          onSave: (v) => _saveField('city', v),
                        ),

                        Divider(color: borderColor, height: 1, thickness: 1),

                        // --- SETTINGS ACCORDION ---
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isSettingsOpen = !_isSettingsOpen;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18.0,
                              vertical: 14.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: surfacePillColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.settings_outlined,
                                        size: 18,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      config.tr('Settings', 'அமைப்புகள்'),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                                AnimatedRotation(
                                  turns: _isSettingsOpen ? 0.5 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 22,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_isSettingsOpen) ...[
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 18.0,
                              right: 18.0,
                              bottom: 16.0,
                              top: 4.0,
                            ),
                            child: Column(
                              children: [
                                // Theme Toggle
                                _buildSettingRow(
                                  icon: isDark
                                      ? Icons.dark_mode_outlined
                                      : Icons.light_mode_outlined,
                                  label: config.tr('Theme', 'தோற்றம்'),
                                  trailing: _buildSegmentedPill(
                                    options: [
                                      config.tr('Light', 'வெளிச்சம்'),
                                      config.tr('Dark', 'இருள்'),
                                    ],
                                    selectedIndex: isDark ? 1 : 0,
                                    onSelect: (idx) {
                                      config.setTheme(idx == 1);
                                    },
                                    config: config,
                                  ),
                                  config: config,
                                ),
                                const SizedBox(height: 12),

                                // Language Toggle
                                _buildSettingRow(
                                  icon: Icons.language_rounded,
                                  label: config.tr('Language', 'மொழி'),
                                  trailing: _buildSegmentedPill(
                                    options: const ['English', 'தமிழ்'],
                                    selectedIndex: config.isTamil ? 1 : 0,
                                    onSelect: (idx) {
                                      config.setTamil(idx == 1);
                                    },
                                    config: config,
                                  ),
                                  config: config,
                                ),
                                const SizedBox(height: 12),

                                // Notification Switch
                                _buildSettingRow(
                                  icon: Icons.notifications_none_rounded,
                                  label: config.tr(
                                    'Notifications',
                                    'அறிவிப்புகள்',
                                  ),
                                  trailing: Switch.adaptive(
                                    value: _notificationsEnabled,
                                    activeThumbColor: isDark
                                        ? Colors.white
                                        : AppColors.primary,
                                    activeTrackColor: (isDark
                                            ? Colors.white
                                            : AppColors.primary)
                                        .withValues(alpha: 0.5),
                                    onChanged: (val) {
                                      setState(() {
                                        _notificationsEnabled = val;
                                      });
                                    },
                                  ),
                                  config: config,
                                ),
                              ],
                            ),
                          ),
                        ],

                        Divider(color: borderColor, height: 1, thickness: 1),

                        // --- LOGOUT BUTTON ---
                        InkWell(
                          onTap: () => _confirmLogout(context, config),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(28),
                            bottomRight: Radius.circular(28),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18.0,
                              vertical: 16.0,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.logout_rounded,
                                    size: 17,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  config.tr('Log out', 'வெளியேறு'),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineInfoRow({
    required String fieldKey,
    required IconData icon,
    required String label,
    required String value,
    required TextEditingController controller,
    required AppConfigProvider config,
    required Function(String) onSave,
  }) {
    final isEditing = _editingField == fieldKey;
    final isDark = config.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: config.surfacePillColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: config.primaryTextColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: config.secondaryTextColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                if (isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: config.primaryTextColor,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 4),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: config.primaryTextColor,
                              ),
                            ),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) onSave(val.trim());
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, size: 18),
                        color: isDark ? Colors.white : AppColors.primary,
                        onPressed: () {
                          if (controller.text.trim().isNotEmpty) {
                            onSave(controller.text.trim());
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: config.secondaryTextColor,
                        onPressed: () {
                          setState(() => _editingField = null);
                        },
                      ),
                    ],
                  )
                else
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: config.primaryTextColor,
                    ),
                  ),
              ],
            ),
          ),
          if (!isEditing)
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 16,
                color: config.secondaryTextColor,
              ),
              onPressed: () {
                controller.text = value;
                setState(() => _editingField = fieldKey);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    required Widget trailing,
    required AppConfigProvider config,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: config.secondaryTextColor),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: config.primaryTextColor,
              ),
            ),
          ],
        ),
        trailing,
      ],
    );
  }

  Widget _buildSegmentedPill({
    required List<String> options,
    required int selectedIndex,
    required Function(int) onSelect,
    required AppConfigProvider config,
  }) {
    final isDark = config.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: config.surfacePillColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (idx) {
          final isSelected = idx == selectedIndex;
          return GestureDetector(
            onTap: () => onSelect(idx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.primary)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                options[idx],
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : config.secondaryTextColor,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
