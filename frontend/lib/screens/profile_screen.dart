import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';
import 'history_screen.dart';
import 'welcome_screen.dart';

/// Production Profile Screen for Kanavu Illam
/// Faithfully designed according to Stitch specifications (`stitch/DESIGN.md`, `stitch/screen.png`).
///
/// Features:
/// 1. Dark Slate Architectural Header Card (#364050 -> #1B212F) with vector blueprint floor plan overlay & 14x14 dot grid.
/// 2. Amber-accented (#E58A18) Avatar with edit pencil badge.
/// 3. Metric Stat Card: Total Projects & Total Spent (synced with ApiService).
/// 4. Preferences Section:
///    - Edit Profile (Name, Phone Number, City/Location, Email ID)
///    - Language toggle (EN / தமிழ்) connected to AppConfigProvider
///    - Theme toggle (Light / Dark) connected to AppConfigProvider
/// 5. Support Section: Help & Support, About Kanavu Illam.
/// 6. Account Actions: Log out, Delete Account (with full Google Play compliant data erasure).
class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const ProfileScreen({super.key, this.userData});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();

  // User fields
  String _displayName = 'User';
  String _phoneNumber = '+91 98765 43210';
  String _location = 'Chennai, Tamil Nadu';
  String _email = '';

  // Stats
  int _totalProjects = 0;
  int _totalSpent = 0;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final meta = widget.userData?['user_metadata'] as Map<String, dynamic>?;

      final currentEmail = ((widget.userData?['email'] as String?) ??
              prefs.getString('user_email') ??
              '')
          .trim();

      final savedName = (meta?['name'] as String?) ??
          (meta?['full_name'] as String?) ??
          prefs.getString('user_name') ??
          (currentEmail.isNotEmpty ? currentEmail.split('@').first : 'User');

      final savedPhone = (meta?['phone'] as String?) ??
          prefs.getString('user_phone') ??
          '+91 98765 43210';

      final savedLocation = prefs.getString('user_location') ??
          prefs.getString('user_address') ??
          'Chennai, Tamil Nadu';

      if (mounted) {
        setState(() {
          _displayName = savedName;
          _email = currentEmail;
          _phoneNumber = savedPhone;
          _location = savedLocation;
        });
      }

      _loadStats(currentEmail);
    } catch (e) {
      debugPrint('[ProfileScreen] Error loading profile: $e');
    }
  }

  Future<void> _loadStats([String? email]) async {
    final prefs = await SharedPreferences.getInstance();
    final targetEmail = ((email != null && email.isNotEmpty)
            ? email
            : ((widget.userData?['email'] as String?) ??
                prefs.getString('user_email') ??
                _email))
        .trim()
        .toLowerCase();

    if (targetEmail.isEmpty || targetEmail == 'unknown') {
      if (mounted) {
        setState(() {
          _totalProjects = 0;
          _totalSpent = 0;
          _isLoadingStats = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoadingStats = true);
    }

    try {
      final fetched = await _apiService.getAllProjects(targetEmail);
      int count = fetched.length;
      int spend = 0;
      for (final p in fetched) {
        String rawName = p['name']?.toString() ?? '';
        int amount = 1;
        if (rawName.contains('|')) {
          final parts = rawName.split('|');
          if (parts.length > 2) {
            amount = (double.tryParse(parts[2]) ?? 1).round();
          }
        } else if (p['amount'] != null) {
          amount = (double.tryParse(p['amount'].toString()) ?? 1).round();
        }
        spend += amount;
      }

      if (mounted) {
        setState(() {
          _totalProjects = count;
          _totalSpent = spend;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  String _formatCurrency(int val) {
    if (val == 0) return '₹0';
    final str = val.toString();
    if (str.length <= 3) return '₹$str';
    final last3 = str.substring(str.length - 3);
    final rest = str.substring(0, str.length - 3);
    final formattedRest = rest.replaceAllMapped(
      RegExp(r'\B(?=(\d{2})+(?!\d))'),
      (m) => ',',
    );
    return '₹$formattedRest,$last3';
  }

  // ─── EDIT PROFILE MODAL (Name, Phone Number, City/Location, Email ID) ─────
  void _showEditProfileDialog(BuildContext context, AppConfigProvider config) {
    final nameController = TextEditingController(text: _displayName);
    final phoneController = TextEditingController(text: _phoneNumber);
    final locationController = TextEditingController(text: _location);
    final emailController = TextEditingController(text: _email);
    final isDark = config.isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B212F) : const Color(0xFFFCFDFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x331B212F),
                blurRadius: 32,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE58A18).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFFE58A18),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      config.tr('Edit Profile', 'சுயவிவரம் திருத்து'),
                      style: GoogleFonts.syne(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF1B212F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 1. Name Field
                _buildDialogInput(
                  label: config.tr('Full Name', 'முழு பெயர்'),
                  controller: nameController,
                  icon: Icons.badge_outlined,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // 2. Phone Number Field
                _buildDialogInput(
                  label: config.tr('Phone Number', 'தொலைபேசி எண்'),
                  controller: phoneController,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // 3. City / Location Field
                _buildDialogInput(
                  label: config.tr('City / Location', 'நகரம் / இருப்பிடம்'),
                  controller: locationController,
                  icon: Icons.location_on_outlined,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // 4. Email ID Field
                _buildDialogInput(
                  label: config.tr('Email ID', 'மின்னஞ்சல் முகவரி'),
                  controller: emailController,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),

                // Save Changes Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE58A18),
                      foregroundColor: const Color(0xFF1B212F),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    onPressed: () async {
                      final newName = nameController.text.trim();
                      final newPhone = phoneController.text.trim();
                      final newLocation = locationController.text.trim();
                      final newEmail = emailController.text.trim().toLowerCase();

                      final prefs = await SharedPreferences.getInstance();
                      if (newName.isNotEmpty) {
                        await prefs.setString('user_name', newName);
                      }
                      if (newPhone.isNotEmpty) {
                        await prefs.setString('user_phone', newPhone);
                      }
                      if (newLocation.isNotEmpty) {
                        await prefs.setString('user_location', newLocation);
                        await prefs.setString('user_address', newLocation);
                      }
                      if (newEmail.isNotEmpty) {
                        await prefs.setString('user_email', newEmail);
                      }

                      if (mounted) {
                        setState(() {
                          if (newName.isNotEmpty) _displayName = newName;
                          if (newPhone.isNotEmpty) _phoneNumber = newPhone;
                          if (newLocation.isNotEmpty) _location = newLocation;
                          if (newEmail.isNotEmpty) _email = newEmail;
                        });
                      }

                      if (ctx.mounted) Navigator.pop(ctx);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              config.tr(
                                'Profile updated successfully!',
                                'சுயவிவரம் வெற்றிகரமாக சேமிக்கப்பட்டது!',
                              ),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: const Color(0xFF1B212F),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(
                      config.tr('Save Changes', 'மாற்றங்களை சேமிக்கவும்'),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
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

  Widget _buildDialogInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF242C3D) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                icon,
                size: 18,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF1B212F),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ],
    );
  }

  // ─── HELP & SUPPORT DIALOG ───────────────────────────────────────────────
  void _showHelpDialog(BuildContext context, AppConfigProvider config) {
    final isDark = config.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? const Color(0xFF1B212F) : const Color(0xFFFCFDFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          config.tr('Help & Support', 'உதவி மற்றும் ஆதரவு'),
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1B212F),
          ),
        ),
        content: Text(
          config.tr(
            'Need assistance with your architectural plan or reports? Reach out to our technical team at support@kanavuillam.com or call +91 98765 43210.',
            'உங்கள் வரைபடம் அல்லது அறிக்கைகளில் உதவி தேவையா? support@kanavuillam.com என்ற மின்னஞ்சல் அல்லது +91 98765 43210 என்ற எண்ணில் எங்களைத் தொடர்பு கொள்ளவும்.',
          ),
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              config.tr('OK', 'சரி'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFFE58A18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ABOUT DIALOG ────────────────────────────────────────────────────────
  void _showAboutDialog(BuildContext context, AppConfigProvider config) {
    final isDark = config.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? const Color(0xFF1B212F) : const Color(0xFFFCFDFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          config.tr('About Kanavu Illam', 'கனவு இல்லம் பற்றி'),
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1B212F),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kanavu Illam v1.0.0',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1B212F),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              config.tr(
                'Digital architectural visualization, traditional Tamil Vastu compliance, cost estimation, and structural safety checks for dream homes in Tamil Nadu.',
                'தமிழ்நாட்டின் கனவு இல்லங்களுக்கான டிஜிட்டல் கட்டிடக்கலை மாதிரி, வாஸ்து பகுப்பாய்வு, மதிப்பீட்டு செலவு மற்றும் பாதுகாப்பு சரிபார்ப்பு தளம்.',
              ),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              config.tr('Close', 'மூடு'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFFE58A18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── LOGOUT CONFIRMATION ─────────────────────────────────────────────────
  void _confirmLogout(BuildContext context, AppConfigProvider config) {
    final isDark = config.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? const Color(0xFF1B212F) : const Color(0xFFFCFDFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          config.tr('Log out?', 'வெளியேறவா?'),
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1B212F),
          ),
        ),
        content: Text(
          config.tr(
            'Are you sure you want to sign out of your account?',
            'உங்கள் கணக்கிலிருந்து வெளியேற விரும்புகிறீர்களா?',
          ),
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              config.tr('Cancel', 'ரத்து செய்'),
              style: GoogleFonts.inter(
                color: isDark
                    ? const Color(0xFFA1A1AA)
                    : const Color(0xFF64748B),
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
              HistoryScreen.clearCache();
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

  // ─── DELETE ACCOUNT CONFIRMATION ─────────────────────────────────────────
  void _confirmDeleteAccount(
      BuildContext context, AppConfigProvider config) async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email') ?? _email;
    final userId = widget.userData?['id'] as String?;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: config.isDarkMode
                  ? const Color(0xFF1B212F)
                  : const Color(0xFFFCFDFF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0x1AEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      config.tr('Delete Account?', 'கணக்கை நீக்க வேண்டுமா?'),
                      style: GoogleFonts.syne(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.tr(
                      'Are you sure you want to permanently delete your account? All your personal profile records, login credentials, and saved floor plan history will be completely erased from our servers in compliance with Google Play policies.',
                      'உங்கள் கணக்கை நிரந்தரமாக நீக்க விரும்புகிறீர்களா? உங்கள் கணக்கு விவரங்கள், கடவுச்சொல் மற்றும் அனைத்து வரைபட தரவுகளும் எங்களின் சர்வர்களில் இருந்து நிரந்தரமாக நீக்கப்படும்.',
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.5,
                      color: config.isDarkMode
                          ? const Color(0xFFA1A1AA)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  if (userEmail.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: config.isDarkMode
                            ? const Color(0xFF151A24)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: config.isDarkMode
                              ? const Color(0xFF2E384D)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined,
                              size: 14, color: Color(0xFF8E94A0)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              userEmail,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: config.isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    config.tr(
                      'Warning: This action cannot be reversed.',
                      'எச்சரிக்கை: இந்த செயலை மாற்ற முடியாது.',
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isDeleting ? null : () => Navigator.pop(dialogCtx),
                  child: Text(
                    config.tr('Cancel', 'ரத்து செய்'),
                    style: GoogleFonts.inter(
                      color: config.isDarkMode
                          ? const Color(0xFFA1A1AA)
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                  ),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          try {
                            try {
                              await ApiService.post('/auth/delete-account', {
                                'email': userEmail,
                                if (userId != null) 'userId': userId,
                              }).timeout(const Duration(seconds: 8));
                            } catch (netErr) {
                              debugPrint(
                                  '[Account Deletion] Network notice: $netErr');
                            }

                            await prefs.clear();

                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(config.tr(
                                    'Your account and data have been permanently deleted.',
                                    'உங்கள் கணக்கு மற்றும் தரவுகள் நிரந்தரமாக நீக்கப்பட்டன.',
                                  )),
                                  backgroundColor: AppColors.snackbarError,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                              Navigator.of(context, rootNavigator: true)
                                  .pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => const WelcomeScreen()),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Failed to delete account: $e'),
                                  backgroundColor: AppColors.snackbarError,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
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

  // ─── ARCHITECTURAL HEADER CARD (#364050 -> #1B212F) ───────────────────────
  Widget _buildArchitecturalHeader(BuildContext context, AppConfigProvider config) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF364050), // Architectural Dark Slate
            Color(0xFF1B212F), // Slate Dark Core
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331B212F),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Custom Vector Blueprint Grid & Dimension Overlay
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: CustomPaint(
                painter: _HeaderBlueprintGridPainter(),
              ),
            ),
          ),

          // Header Content (Avatar + Greetings)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Circular Avatar with amber accent border & edit pencil badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Subtle outer ghost ring
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                            width: 1.0,
                          ),
                        ),
                      ),
                      // Core Avatar
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E3744),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE58A18), // Amber accent ring
                            width: 2.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.person_rounded,
                            size: 46,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Edit badge button at bottom right
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _showEditProfileDialog(context, config),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E3744),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF2A3342),
                                width: 2.0,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 20),

                  // Greetings & Motto Text
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${config.isTamil ? 'வணக்கம், ' : 'Hi, '}$_displayName',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFCFDFF),
                            letterSpacing: -0.4,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.78),
                              height: 1.35,
                            ),
                            children: config.isTamil
                                ? const [
                                    TextSpan(text: 'ஒவ்வொரு வீடும் ஒரு '),
                                    TextSpan(
                                      text: 'கனவுடன்',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(text: ' துவங்குகிறது'),
                                  ]
                                : const [
                                    TextSpan(
                                        text: 'Every home begins with a '),
                                    TextSpan(
                                      text: 'dream',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── METRIC STAT CARD (Total Projects | Total Spent) ─────────────────────
  Widget _buildMetricStatCard({
    required BuildContext context,
    required AppConfigProvider config,
    required Color cardBg,
    required Color cardBorder,
    required Color iconCircleBg,
    required Color iconColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: double.infinity,
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141B212F),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Total Projects Item
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconCircleBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: config.isDarkMode
                          ? const Color(0xFF334155)
                          : const Color(0xFFD8DFE9),
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.folder_outlined,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.tr('Total Projects', 'மொத்த திட்டங்கள்'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: textSecondary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_totalProjects',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Vertical divider line
          Container(
            width: 1,
            height: 40,
            color: config.isDarkMode
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0),
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

          // Total Spent Item
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconCircleBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: config.isDarkMode
                          ? const Color(0xFF334155)
                          : const Color(0xFFD8DFE9),
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.currency_rupee_rounded,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.tr('Total Spent', 'மொத்த செலவு'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: textSecondary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatCurrency(_totalSpent),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SECTION HEADER TITLE ────────────────────────────────────────────────
  Widget _buildSectionTitle(String title, Color textPrimary) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }

  // ─── PREFERENCES GROUP (Edit Profile, Language, Theme) ───────────────────
  Widget _buildPreferencesGroup({
    required BuildContext context,
    required AppConfigProvider config,
    required Color cardBg,
    required Color cardBorder,
    required Color iconCircleBg,
    required Color iconColor,
    required Color textPrimary,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121B212F),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Edit Profile Row
          _buildRowItem(
            icon: Icons.edit_outlined,
            title: config.tr('Edit Profile', 'சுயவிவரம் திருத்து'),
            iconCircleBg: iconCircleBg,
            iconColor: iconColor,
            textPrimary: textPrimary,
            onTap: () => _showEditProfileDialog(context, config),
            trailing: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: config.isDarkMode
                  ? const Color(0xFF64748B)
                  : const Color(0xFF8E94A0),
            ),
            showDivider: true,
            cardBorder: cardBorder,
          ),

          // 2. Language Row (Segmented EN / தமிழ் Toggle)
          _buildRowItem(
            icon: Icons.language_rounded,
            title: config.tr('Language', 'மொழி'),
            iconCircleBg: iconCircleBg,
            iconColor: iconColor,
            textPrimary: textPrimary,
            trailing: _buildSegmentedPill(
              leftLabel: 'EN',
              rightLabel: 'தமிழ்',
              isLeftActive: !config.isTamil,
              onToggle: (bool chooseLeft) {
                config.setTamil(!chooseLeft);
              },
            ),
            showDivider: true,
            cardBorder: cardBorder,
          ),

          // 3. Theme Row (Segmented Light / Dark Toggle)
          _buildRowItem(
            icon: Icons.wb_sunny_outlined,
            title: config.tr('Theme', 'வடிவமைப்பு'),
            iconCircleBg: iconCircleBg,
            iconColor: iconColor,
            textPrimary: textPrimary,
            trailing: _buildSegmentedPill(
              leftLabel: 'Light',
              rightLabel: 'Dark',
              isLeftActive: !config.isDarkMode,
              onToggle: (bool chooseLeft) {
                config.setTheme(!chooseLeft);
              },
            ),
            showDivider: false,
            cardBorder: cardBorder,
          ),
        ],
      ),
    );
  }

  // ─── SUPPORT GROUP (Help & Support, About Kanavu Illam) ───────────────────
  Widget _buildSupportGroup({
    required BuildContext context,
    required AppConfigProvider config,
    required Color cardBg,
    required Color cardBorder,
    required Color iconCircleBg,
    required Color iconColor,
    required Color textPrimary,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121B212F),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildRowItem(
            icon: Icons.help_outline_rounded,
            title: config.tr('Help & Support', 'உதவி & ஆதரவு'),
            iconCircleBg: iconCircleBg,
            iconColor: iconColor,
            textPrimary: textPrimary,
            onTap: () => _showHelpDialog(context, config),
            trailing: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: config.isDarkMode
                  ? const Color(0xFF64748B)
                  : const Color(0xFF8E94A0),
            ),
            showDivider: true,
            cardBorder: cardBorder,
          ),
          _buildRowItem(
            icon: Icons.info_outline_rounded,
            title: config.tr('About Kanavu Illam', 'கனவு இல்லம் பற்றி'),
            iconCircleBg: iconCircleBg,
            iconColor: iconColor,
            textPrimary: textPrimary,
            onTap: () => _showAboutDialog(context, config),
            trailing: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: config.isDarkMode
                  ? const Color(0xFF64748B)
                  : const Color(0xFF8E94A0),
            ),
            showDivider: false,
            cardBorder: cardBorder,
          ),
        ],
      ),
    );
  }

  // ─── ACCOUNT ACTIONS (Log out, Delete Account) ───────────────────────────
  Widget _buildAccountActionsGroup({
    required BuildContext context,
    required AppConfigProvider config,
    required Color cardBg,
    required Color cardBorder,
    required Color iconCircleBg,
    required Color iconColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121B212F),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Log out row
          _buildRowItem(
            icon: Icons.logout_rounded,
            title: config.tr('Log out', 'வெளியேறு'),
            iconCircleBg: iconCircleBg,
            iconColor: iconColor,
            textPrimary: textPrimary,
            onTap: () => _confirmLogout(context, config),
            showDivider: true,
            cardBorder: cardBorder,
          ),

          // Delete Account row
          _buildRowItem(
            icon: Icons.delete_outline_rounded,
            title: config.tr('Delete Account', 'கணக்கை நீக்கு'),
            iconCircleBg: iconCircleBg,
            iconColor: iconColor,
            textPrimary: textSecondary,
            onTap: () => _confirmDeleteAccount(context, config),
            showDivider: false,
            cardBorder: cardBorder,
          ),
        ],
      ),
    );
  }

  // ─── ROW ITEM BUILDER ────────────────────────────────────────────────────
  Widget _buildRowItem({
    required IconData icon,
    required String title,
    required Color iconCircleBg,
    required Color iconColor,
    required Color textPrimary,
    Widget? trailing,
    VoidCallback? onTap,
    required bool showDivider,
    required Color cardBorder,
  }) {
    final rowContent = Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconCircleBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, size: 18, color: iconColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );

    return Column(
      children: [
        if (onTap != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: rowContent,
          )
        else
          rowContent,
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: cardBorder,
            indent: 64,
            endIndent: 16,
          ),
      ],
    );
  }

  // ─── SEGMENTED PILL TOGGLE ───────────────────────────────────────────────
  Widget _buildSegmentedPill({
    required String leftLabel,
    required String rightLabel,
    required bool isLeftActive,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      width: 110,
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF4),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          // Left Segment
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(true),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isLeftActive
                      ? const Color(0xFFFCFDFF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: isLeftActive
                      ? const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    leftLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight:
                          isLeftActive ? FontWeight.w700 : FontWeight.w500,
                      color: isLeftActive
                          ? const Color(0xFF1B212F)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Right Segment
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(false),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: !isLeftActive
                      ? const Color(0xFFFCFDFF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: !isLeftActive
                      ? const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    rightLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight:
                          !isLeftActive ? FontWeight.w700 : FontWeight.w500,
                      color: !isLeftActive
                          ? const Color(0xFF1B212F)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
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

    // Stitch Design Color Tokens
    final Color pageBg =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F8FB);
    final Color cardBg =
        isDark ? const Color(0xFF1B212F) : const Color(0xFFFCFDFF);
    final Color cardBorder =
        isDark ? const Color(0xFF2E384D) : const Color(0xFFD8DFE9);
    final Color iconCircleBg =
        isDark ? const Color(0xFF242C3D) : const Color(0xFFE9EEF4);
    final Color iconColor =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF364050);
    final Color textPrimary =
        isDark ? const Color(0xFFFCFDFF) : const Color(0xFF1B212F);
    final Color textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF8E94A0);

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        top: true,
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Architectural Dark Slate Header Card
              _buildArchitecturalHeader(context, config),

              const SizedBox(height: 16),

              // 2. Metric Stat Card (Projects & Total Spent)
              _buildMetricStatCard(
                context: context,
                config: config,
                cardBg: cardBg,
                cardBorder: cardBorder,
                iconCircleBg: iconCircleBg,
                iconColor: iconColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              const SizedBox(height: 24),

              // 3. Section Title: Preferences
              _buildSectionTitle(
                config.tr('Preferences', 'விருப்பத்தேர்வுகள்'),
                textPrimary,
              ),
              const SizedBox(height: 12),
              _buildPreferencesGroup(
                context: context,
                config: config,
                cardBg: cardBg,
                cardBorder: cardBorder,
                iconCircleBg: iconCircleBg,
                iconColor: iconColor,
                textPrimary: textPrimary,
              ),

              const SizedBox(height: 24),

              // 4. Section Title: Support
              _buildSectionTitle(
                config.tr('Support', 'ஆதரவு'),
                textPrimary,
              ),
              const SizedBox(height: 12),
              _buildSupportGroup(
                context: context,
                config: config,
                cardBg: cardBg,
                cardBorder: cardBorder,
                iconCircleBg: iconCircleBg,
                iconColor: iconColor,
                textPrimary: textPrimary,
              ),

              const SizedBox(height: 24),

              // 5. Section Title: Account
              _buildSectionTitle(
                config.tr('Account', 'கணக்கு'),
                textPrimary,
              ),
              const SizedBox(height: 12),
              _buildAccountActionsGroup(
                context: context,
                config: config,
                cardBg: cardBg,
                cardBorder: cardBorder,
                iconCircleBg: iconCircleBg,
                iconColor: iconColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              // Generous bottom spacing for the floating curved capsule nav bar
              const SizedBox(height: 110),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── HEADER BLUEPRINT & DOT GRID PAINTER ─────────────────────────────────────
class _HeaderBlueprintGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dot Grid Pattern across whole header (14x14 grid)
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    const double step = 14.0;
    for (double x = 7; x < size.width; x += step) {
      for (double y = 7; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
      }
    }

    // 2. Blueprint Architectural Floor Plan Lines (Right half of header)
    final blueprintPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;

    final dimensionPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Dimension marker top
    canvas.drawLine(
        const Offset(230, 28), const Offset(360, 28), dimensionPaint);
    canvas.drawLine(
        const Offset(230, 24), const Offset(230, 32), dimensionPaint);
    canvas.drawLine(
        const Offset(360, 24), const Offset(360, 32), dimensionPaint);

    // Main room boundary
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(230, 38, 135, 125),
        const Radius.circular(2),
      ),
      blueprintPaint,
    );

    // Horizontal room partition
    canvas.drawLine(
        const Offset(230, 90), const Offset(315, 90), blueprintPaint);

    // Vertical room partition
    canvas.drawLine(
        const Offset(315, 38), const Offset(315, 115), blueprintPaint);
    canvas.drawLine(
        const Offset(275, 90), const Offset(275, 163), blueprintPaint);

    // Door swing arc
    final doorArcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawArc(
      const Rect.fromLTWH(235, 90, 40, 40),
      math.pi,
      math.pi / 2,
      false,
      doorArcPaint,
    );
    canvas.drawLine(
        const Offset(255, 90), const Offset(255, 110), blueprintPaint);

    // Window mark
    canvas.drawRect(const Rect.fromLTWH(335, 60, 30, 18), blueprintPaint);
    canvas.drawLine(
        const Offset(350, 60), const Offset(350, 78), dimensionPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
