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
  // User fields
  String _name = 'Thomas';
  String _phone = '+91 98765 43210';
  String _email = 'thomas.arch@kanavuillam.com';
  String _city = 'Erode, Tamil Nadu';

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _name);
    _phoneController = TextEditingController(text: _phone);
    _cityController = TextEditingController(text: _city);
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
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
        (currentEmail.isNotEmpty ? currentEmail.split('@').first : 'Thomas');

    final savedEmail = currentEmail.isNotEmpty ? currentEmail : 'thomas.arch@kanavuillam.com';
    final savedPhone = (meta?['phone'] as String?) ??
        prefs.getString('user_phone') ??
        '+91 98765 43210';
    final savedCity = prefs.getString('user_address') ?? 'Tamil Nadu, India';

    if (mounted) {
      setState(() {
        _name = savedName;
        _email = savedEmail;
        _phone = savedPhone;
        _city = savedCity;

        _nameController.text = _name;
        _phoneController.text = _phone;
        _cityController.text = _city;
      });
    }
  }

  Future<void> _saveProfileDetails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setString('user_phone', _phoneController.text.trim());
    await prefs.setString('user_address', _cityController.text.trim());

    if (mounted) {
      setState(() {
        _name = _nameController.text.trim();
        _phone = _phoneController.text.trim();
        _city = _cityController.text.trim();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Color(0xFF1B212F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showEditProfileDialog(BuildContext context, AppConfigProvider config) {
    _nameController.text = _name;
    _phoneController.text = _phone;
    _cityController.text = _city;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = config.isDarkMode;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C2230) : const Color(0xFFFCFDFF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E1B212F),
                  blurRadius: 32,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF364050) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  config.tr('Edit Profile', 'சுயவிவரத்தை மாற்றவும்'),
                  style: GoogleFonts.syne(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF18191D),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSheetTextField('Name', _nameController, isDark),
                const SizedBox(height: 12),
                _buildSheetTextField('Phone', _phoneController, isDark),
                const SizedBox(height: 12),
                _buildSheetTextField('City / Location', _cityController, isDark),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _saveProfileDetails();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBA73B), Color(0xFFE58A18)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40E58A18),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        config.tr('Save Changes', 'சேமிக்கவும்'),
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E252D),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetTextField(String label, TextEditingController controller, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF242C3D) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF18191D),
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context, AppConfigProvider config) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: config.isDarkMode ? const Color(0xFF1C2230) : const Color(0xFFFCFDFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          config.tr('Help & Support', 'உதவி மற்றும் ஆதரவு'),
          style: GoogleFonts.syne(fontWeight: FontWeight.w700),
        ),
        content: Text(
          config.tr(
            'Need assistance with your architectural plan or reports? Reach out to our technical team at support@kanavuillam.com or call +91 98765 43210.',
            'உங்கள் வரைபடம் அல்லது அறிக்கைகளில் உதவி தேவையா? support@kanavuillam.com என்ற மின்னஞ்சல் அல்லது +91 98765 43210 என்ற எண்ணில் எங்களைத் தொடர்பு கொள்ளவும்.',
          ),
          style: GoogleFonts.inter(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context, AppConfigProvider config) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: config.isDarkMode ? const Color(0xFF1C2230) : const Color(0xFFFCFDFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          config.tr('About Kanavu Illam', 'கனவு இல்லம் பற்றி'),
          style: GoogleFonts.syne(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kanavu Illam v1.0.0',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              config.tr(
                'Digital architectural visualization, traditional Tamil Vastu compliance, cost estimation, and structural safety checks for dream homes in Tamil Nadu.',
                'தமிழ்நாட்டின் கனவு இல்லங்களுக்கான டிஜிட்டல் கட்டிடக்கலை மாதிரி, வாஸ்து பகுப்பாய்வு, மதிப்பீட்டு செலவு மற்றும் பாதுகாப்பு சரிபார்ப்பு தளம்.',
              ),
              style: GoogleFonts.inter(fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppConfigProvider config) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: config.isDarkMode ? const Color(0xFF1C2230) : const Color(0xFFFCFDFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          config.tr('Log out?', 'வெளியேறவா?'),
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: config.isDarkMode ? Colors.white : const Color(0xFF18191D),
          ),
        ),
        content: Text(
          config.tr(
            'Are you sure you want to sign out of your account?',
            'உங்கள் கணக்கிலிருந்து வெளியேற விரும்புகிறீர்களா?',
          ),
          style: GoogleFonts.inter(
            fontSize: 13,
            color: config.isDarkMode ? const Color(0xFFA1A1AA) : const Color(0xFF8E94A0),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              config.tr('Cancel', 'ரத்து செய்'),
              style: GoogleFonts.inter(
                color: config.isDarkMode ? const Color(0xFFA1A1AA) : const Color(0xFF8E94A0),
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
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, AppConfigProvider config) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: config.isDarkMode ? const Color(0xFF1C2230) : const Color(0xFFFCFDFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                config.tr('Delete Account?', 'கணக்கை நீக்க வேண்டுமா?'),
                style: GoogleFonts.syne(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEF4444),
                ),
              ),
              content: Text(
                config.tr(
                  'Are you sure you want to permanently delete your account, login credentials, and all uploaded design files? This action cannot be undone.',
                  'உங்கள் கணக்கு மற்றும் அனைத்து வரைபட தரவுகளையும் நிரந்தரமாக நீக்க விரும்புகிறீர்களா? இந்த செயலை மாற்ற முடியாது.',
                ),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: config.isDarkMode ? const Color(0xFFA1A1AA) : const Color(0xFF8E94A0),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                  child: Text(
                    config.tr('Cancel', 'ரத்து செய்'),
                    style: GoogleFonts.inter(
                      color: config.isDarkMode ? const Color(0xFFA1A1AA) : const Color(0xFF8E94A0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            final email = prefs.getString('user_email') ?? _email;
                            final userId = widget.userData?['id'] as String?;

                            await ApiService.post('/auth/delete-account', {
                              'email': email,
                              if (userId != null) 'userId': userId,
                            });

                            await prefs.clear();
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            if (context.mounted) {
                              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to delete account: $e'),
                                  backgroundColor: const Color(0xFFEF4444),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          config.tr('Delete Forever', 'நிரந்தரமாக நீக்கு'),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            );
          },
        );
      },
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF14171F) : AppColors.canvasGradientTop,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.canvasGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 12.0,
                  bottom: 110.0, // Breathing space for floating bottom nav
                ),
                child: Column(
                  children: [
                    // 1. TOP DARK HEADER (236px tall, 32px radius, gradient #364050 -> #1B212F)
                    Container(
                      width: double.infinity,
                      height: 236,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF364050), Color(0xFF1B212F)],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x381B212F),
                            blurRadius: 40,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Avatar with Amber Ring (88x88)
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E3744),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFBA73B),
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x2E000000),
                                  blurRadius: 14,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.person_rounded,
                                size: 44,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // User Name
                          Text(
                            _name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 4),

                          // Email
                          Text(
                            _email,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2. SETTINGS LIST CARD (28px radius, border #E9EAEC, shadow-sm)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C2230) : const Color(0xFFFCFDFF),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE9EAEC),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A1B212F),
                            blurRadius: 32,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Row 1: Edit Profile
                          _buildSettingRow(
                            icon: Icons.person_outline_rounded,
                            title: config.tr('Edit Profile', 'சுயவிவரம் திருத்து'),
                            isDark: isDark,
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: Color(0xFF8E94A0),
                            ),
                            onTap: () => _showEditProfileDialog(context, config),
                            showDivider: true,
                          ),

                          // Row 2: Language
                          _buildSettingRow(
                            icon: Icons.language_rounded,
                            title: config.tr('Language', 'மொழி'),
                            isDark: isDark,
                            trailing: Container(
                              height: 32,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF242C3D) : const Color(0xFFE9EEF4),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildLanguageTab('EN', !config.isTamil, () => config.setTamil(false), isDark),
                                  _buildLanguageTab('தமிழ்', config.isTamil, () => config.setTamil(true), isDark),
                                ],
                              ),
                            ),
                            showDivider: true,
                          ),

                          // Row 3: Theme
                          _buildSettingRow(
                            icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                            title: config.tr('Theme', 'தோற்றம்'),
                            isDark: isDark,
                            trailing: Container(
                              height: 32,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF242C3D) : const Color(0xFFE9EEF4),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildLanguageTab(
                                    config.tr('Light', 'வெளிச்சம்'),
                                    !isDark,
                                    () => config.setTheme(false),
                                    isDark,
                                  ),
                                  _buildLanguageTab(
                                    config.tr('Dark', 'இருள்'),
                                    isDark,
                                    () => config.setTheme(true),
                                    isDark,
                                  ),
                                ],
                              ),
                            ),
                            showDivider: true,
                          ),

                          // Row 4: Help & Support
                          _buildSettingRow(
                            icon: Icons.help_outline_rounded,
                            title: config.tr('Help & Support', 'உதவி மற்றும் ஆதரவு'),
                            isDark: isDark,
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: Color(0xFF8E94A0),
                            ),
                            onTap: () => _showHelpDialog(context, config),
                            showDivider: true,
                          ),

                          // Row 5: About
                          _buildSettingRow(
                            icon: Icons.info_outline_rounded,
                            title: config.tr('About & Privacy', 'பற்றி & கொள்கை'),
                            isDark: isDark,
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: Color(0xFF8E94A0),
                            ),
                            onTap: () => _showAboutDialog(context, config),
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. LOG OUT BUTTON (Pill Button 54px)
                    GestureDetector(
                      onTap: () => _confirmLogout(context, config),
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C2230) : const Color(0xFFFCFDFF),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.logout_rounded,
                              size: 18,
                              color: Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              config.tr('Log Out', 'வெளியேறு'),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 4. PERMANENT ACCOUNT DELETION LINK
                    GestureDetector(
                      onTap: () => _confirmDeleteAccount(context, config),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              config.tr('Delete Account', 'கணக்கை நிரந்தரமாக நீக்கு'),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                decoration: TextDecoration.underline,
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
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required bool isDark,
    required Widget trailing,
    VoidCallback? onTap,
    required bool showDivider,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E3744) : const Color(0xFFE9EEF4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: isDark ? Colors.white : const Color(0xFF364050),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF18191D),
                      ),
                    ),
                  ],
                ),
                trailing,
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
            indent: 70,
            endIndent: 16,
          ),
      ],
    );
  }

  Widget _buildLanguageTab(String text, bool isSelected, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF364050) : const Color(0xFF1B212F))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF364050)),
          ),
        ),
      ),
    );
  }
}
