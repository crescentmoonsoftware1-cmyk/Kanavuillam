import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../core/providers/app_config_provider.dart';
import 'upload_screen.dart';
import 'viewer_screen.dart';
import 'vastu_screen.dart';
import 'estimation_screen.dart';
import 'structural_screen.dart';
import 'download_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

import '../core/theme/app_colors.dart';

// ─── Nav Item Model ───────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

const _navItems = [
  _NavItem(Icons.home_outlined, 'Home Map'),
  _NavItem(Icons.view_in_ar_rounded, '3D View'),
  _NavItem(Icons.self_improvement_outlined, 'Vastu Report'),
  _NavItem(Icons.calculate_outlined, 'Cost Estimation'),
  _NavItem(Icons.foundation_outlined, 'Structural Report'),
  _NavItem(Icons.download_outlined, 'Download Report'),
  _NavItem(Icons.history_rounded, 'History'),
  _NavItem(Icons.person_outline_rounded, 'Profile'),
];

// ─── Color Palette (Professional Theme) ──────────────────────────────────
const _bgDark = AppColors.bgGradientTop;
const _accent = AppColors.amber;
const _textPri = AppColors.deepInk;
const _textSec = AppColors.readingSlate;
const _divider = AppColors.cardBorder;

class ShellScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const ShellScreen({super.key, this.userData});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _isGenerating = false;
  Map<String, dynamic>? _projectData;
  Set<String> _selectedReportIds = {};
  DateTime? _lastBackPressTime;

  // GlobalKey to access ViewerScreen's state for screenshot capture
  final GlobalKey<ViewerScreenState> _viewerKey =
      GlobalKey<ViewerScreenState>();

  @override
  void initState() {
    super.initState();
    _syncUserToPrefs();
    _restoreActiveProject();
  }

  Future<void> _syncUserToPrefs() async {
    if (widget.userData != null) {
      final prefs = await SharedPreferences.getInstance();
      final email = widget.userData?['email'] as String?;
      final meta = widget.userData?['user_metadata'] as Map<String, dynamic>?;
      final name =
          (meta?['name'] as String?) ?? (meta?['full_name'] as String?);
      final phone = (meta?['phone'] as String?);
      if (email != null && email.isNotEmpty) {
        await prefs.setString('user_email', email);
      }
      if (name != null && name.isNotEmpty) {
        await prefs.setString('user_name', name);
      }
      if (phone != null && phone.isNotEmpty) {
        await prefs.setString('user_phone', phone);
      }
    }
  }

  Future<void> _restoreActiveProject() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('last_active_project_data');
      final savedIds = prefs.getStringList('last_active_selected_ids');
      if (savedJson != null && savedJson.isNotEmpty) {
        final decoded = json.decode(savedJson) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _projectData = decoded;
            if (savedIds != null && savedIds.isNotEmpty) {
              _selectedReportIds = savedIds.toSet();
            } else {
              _selectedReportIds = {'3d', 'vastu', 'cost', 'structural'};
            }
          });
          debugPrint('[ShellScreen] Restored last active project from phone storage');
        }
      }
    } catch (e) {
      debugPrint('[ShellScreen] Restore active project notice: $e');
    }
  }

  Future<void> _saveActiveProjectToStorage() async {
    try {
      if (_projectData != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'last_active_project_data', json.encode(_projectData));
        await prefs.setStringList(
            'last_active_selected_ids', _selectedReportIds.toList());
        debugPrint('[ShellScreen] Active project auto-saved to phone storage');
      }
    } catch (e) {
      debugPrint('[ShellScreen] Auto-save notice: $e');
    }
  }

  void _onProjectLoaded(Map<String, dynamic> project, Set<String> selectedIds) {
    setState(() {
      _projectData = Map<String, dynamic>.from(project);
      if (_projectData!['name'] == null ||
          _projectData!['name'].toString().isEmpty) {
        _projectData!['name'] = 'KI_Project';
      }
      _selectedReportIds = selectedIds.map((e) => e.toLowerCase()).toSet();
      // Navigate to the first selected report if available, else 3D View
      if (_selectedReportIds.contains('3d')) {
        _selectedIndex = 1;
      } else if (_selectedReportIds.isNotEmpty) {
        // Map first selected ID to index
        _selectedIndex = _getMappedIndex(_selectedReportIds.first);
      } else {
        _selectedIndex = 1;
      }
    });

    _saveActiveProjectToStorage();
  }

  Future<void> _startAIGeneration(
      XFile groundFile,
      XFile? firstFile,
      XFile? secondFile,
      int floors,
      Set<String> selectedIds,
      String orientation) async {
    setState(() => _isGenerating = true);
    debugPrint('SHELL: Starting AI Generation pipeline...');

    // Prevent phone from sleeping during long AI API calls (4 mins)
    WakelockPlus.enable();

    try {
      final apiService = ApiService();

      const totalAmount = 500.0;

      final projectName =
          'kanavuillam_report|${selectedIds.join(",")}|$totalAmount';

      final prefs = await SharedPreferences.getInstance();
      final currentEmail = (widget.userData?['email'] as String?) ??
          prefs.getString('user_email') ??
          'unknown';

      final res = await apiService.uploadPlan(
        groundFile,
        firstFile,
        secondFile,
        projectName,
        orientation: orientation,
        userEmail: currentEmail,
      );

      debugPrint('SHELL: Upload successful, processing results...');

      if (mounted) {
        _onProjectLoaded(res['project'] as Map<String, dynamic>, selectedIds);
        setState(() => _isGenerating = false);
      }
    } catch (e) {
      debugPrint('SHELL: Upload error: $e');
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan Analysis Error: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: () => _startAIGeneration(
                groundFile,
                firstFile,
                secondFile,
                floors,
                selectedIds,
                orientation,
              ),
            ),
          ),
        );
      }
    } finally {
      WakelockPlus.disable();
    }
  }

  int _getMappedIndex(String id) {
    switch (id) {
      case '3d':
        return 1;
      case 'vastu':
        return 2;
      case 'cost':
      case 'boq':
        return 3;
      case 'structural':
        return 4;
      default:
        return 1;
    }
  }

  List<int> get _visibleIndices {
    List<int> indices = [0]; // Always include Home Map
    if (_selectedReportIds.contains('3d')) indices.add(1);
    if (_selectedReportIds.contains('vastu')) indices.add(2);
    if (_selectedReportIds.contains('cost') ||
        _selectedReportIds.contains('boq')) {
      indices.add(3);
    }
    if (_selectedReportIds.contains('structural')) indices.add(4);
    if (_projectData != null) indices.add(5); // Download Report
    indices.add(6); // History
    indices.add(7); // Profile
    return indices;
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        UploadScreen(
          onProjectLoaded: _onProjectLoaded,
          onStartGeneration: _startAIGeneration,
          isExternalLoading: _isGenerating,
        ),
        _projectData != null
            ? ViewerScreen(
                key: _viewerKey,
                projectData: _projectData!,
                onNavigateToTab: (index) =>
                    setState(() => _selectedIndex = index),
                onNavigateToVastu: () => setState(() => _selectedIndex = 2),
              )
            : _EmptyState(
                icon: Icons.view_in_ar_rounded,
                title: '3D View',
                subtitle:
                    'Upload a floor plan on the Home Map screen\nto generate your 3D model.',
                accentColor: _accent,
              ),
        _projectData != null
            ? VastuScreen(
                projectData: _projectData!,
                onNavigateToTab: (index) =>
                    setState(() => _selectedIndex = index),
                onNavigateToNext: () => setState(() => _selectedIndex = 3),
                onBack: () => setState(() => _selectedIndex = 1),
              )
            : _EmptyState(
                icon: Icons.self_improvement_outlined,
                title: 'Vastu Report',
                subtitle:
                    'Generate a project first to view\nyour Vastu analysis.',
                accentColor: _accent,
              ),
        _projectData != null
            ? EstimationScreen(
                projectData: _projectData!,
                onNavigateToTab: (index) =>
                    setState(() => _selectedIndex = index),
                onNavigateToNext: () => setState(() => _selectedIndex = 4),
                onBack: () => setState(() => _selectedIndex = 2),
              )
            : _EmptyState(
                icon: Icons.calculate_outlined,
                title: 'Estimation',
                subtitle:
                    'Generate a project first to view\nyour cost estimate.',
                accentColor: _accent,
              ),
        _projectData != null
            ? StructuralScreen(
                projectData: _projectData!,
                onNavigateToTab: (index) =>
                    setState(() => _selectedIndex = index),
                onNavigateToNext: () => setState(() => _selectedIndex = 5),
                onBack: () => setState(() => _selectedIndex = 3),
              )
            : _EmptyState(
                icon: Icons.foundation_outlined,
                title: 'Structural Report',
                subtitle:
                    'Generate a project first to view\nthe structural analysis.',
                accentColor: _accent,
              ),
        _projectData != null
            ? DownloadScreen(
                projectData: _projectData!,
                selectedReportIds: _selectedReportIds,
                onNavigateToTab: (index) =>
                    setState(() => _selectedIndex = index),
                onNavigateTo3D: () => setState(() => _selectedIndex = 1),
                userData: widget.userData,
                capture3DScreenshots: () async {
                  return await _viewerKey.currentState
                          ?.captureAllFloorScreenshots() ??
                      {};
                },
              )
            : _EmptyState(
                icon: Icons.download_outlined,
                title: 'Download Report',
                subtitle:
                    'Generate a project first to\ndownload your full report.',
                accentColor: _accent,
              ),
        HistoryScreen(userData: widget.userData),
        ProfileScreen(userData: widget.userData),
      ],
    );
  }

  Widget _buildNavigationHeader() {
    if (_selectedIndex == 0 ||
        _selectedIndex == 1 ||
        _selectedIndex == 2 ||
        _selectedIndex == 3 ||
        _selectedIndex == 4 ||
        _selectedIndex == 5 ||
        _projectData == null) {
      return const SizedBox.shrink();
    }

    final visible = _visibleIndices;
    final currentIndexInVisible = visible.indexOf(_selectedIndex);

    if (currentIndexInVisible == -1) return const SizedBox.shrink();

    final hasPrevious = currentIndexInVisible > 0;
    final hasNext = currentIndexInVisible < visible.length - 1;

    if (!hasPrevious && !hasNext) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.transparent, // Blends with background
      ),
      child: Row(
        children: [
          if (hasPrevious)
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = visible[currentIndexInVisible - 1];
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _textPri,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: _divider, width: 1.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_back_rounded, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _navItems[visible[currentIndexInVisible - 1]].label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
            ),
          if (hasPrevious && hasNext) const SizedBox(width: 16),
          if (hasNext)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.orangeGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.orangeGlow,
                ),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedIndex = visible[currentIndexInVisible + 1];
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _navItems[visible[currentIndexInVisible + 1]].label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0),
            ),
        ],
      ),
    );
  }

  void _handleBackNavigation() {
    // 1. If Drawer is open, close it
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }

    // 2. Report Back-Stack flow:
    // Download (5) -> Structure (4)
    if (_selectedIndex == 5) {
      setState(() => _selectedIndex = 4);
      return;
    }
    // Structure (4) -> Cost (3)
    if (_selectedIndex == 4) {
      setState(() => _selectedIndex = 3);
      return;
    }
    // Cost (3) -> Vastu (2)
    if (_selectedIndex == 3) {
      setState(() => _selectedIndex = 2);
      return;
    }
    // Vastu (2) -> 3D View (1)
    if (_selectedIndex == 2) {
      setState(() => _selectedIndex = 1);
      return;
    }

    // 3. In 3D View (Tab 1): APP MUST NOT CLOSE!
    // Show Safety Dialog
    if (_selectedIndex == 1) {
      _show3DPreventExitDialog();
      return;
    }

    // 4. In History (6) or Profile (7): Go back to Home (0)
    if (_selectedIndex == 6 || _selectedIndex == 7) {
      setState(() => _selectedIndex = 0);
      return;
    }

    // 5. In Home (0): Double-Tap to Exit
    if (_selectedIndex == 0) {
      final now = DateTime.now();
      if (_lastBackPressTime == null ||
          now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
        _lastBackPressTime = now;
        AppConfigProvider config;
        try {
          config = context.read<AppConfigProvider>();
        } catch (_) {
          config = AppConfigProvider();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              config.tr(
                'Press back again to exit Kanavu Illam',
                'வெளியேற மீண்டும் அழுத்தவும்',
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF1E252D),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      // If pressed twice within 2 seconds: Allow app close
      Navigator.of(context).pop();
    }
  }

  void _show3DPreventExitDialog() {
    AppConfigProvider config;
    try {
      config = context.read<AppConfigProvider>();
    } catch (_) {
      config = AppConfigProvider();
    }
    final isDark = config.isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor:
            isDark ? const Color(0xFF1B212F) : const Color(0xFFFCFDFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE58A18).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE58A18),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              config.tr('Report Safety Alert', 'அறிக்கை பாதுகாப்பு எச்சரிக்கை'),
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E252D),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              config.tr(
                'You have paid for this plan! Please download your full PDF report before leaving so your data is safely saved on your device.',
                'நீங்கள் இந்த வரைபடத்திற்கு கட்டணம் செலுத்தியுள்ளீர்கள்! உங்கள் சாதனத்தில் அறிக்கை பத்திரமாக இருக்க, வெளியேறும் முன் PDF அறிக்கையை பதிவிறக்கம் செய்யவும்.',
              ),
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: isDark
                    ? const Color(0xFFA1A1AA)
                    : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            // Button 1: Download PDF Now (Primary Amber)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amberDefault,
                  foregroundColor: AppColors.onAmberInk,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  config.tr('Download PDF Now', 'PDF-ஐ பதிவிறக்கு'),
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  setState(() => _selectedIndex = 5);
                },
              ),
            ),
            const SizedBox(height: 10),
            // Button 2: Stay on 3D View
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? Colors.white : const Color(0xFF1E252D),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF2E384D)
                        : const Color(0xFFE2E8F0),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100)),
                ),
                child: Text(
                  config.tr('Stay on 3D View', '3D-லேயே தொடரவும்'),
                  style: GoogleFonts.inter(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ),
          ],
        ),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        key: _scaffoldKey,
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor: config.bgColor,
        drawer: Drawer(
          backgroundColor: config.cardColor,
          child: _Sidebar(
            selectedIndex: _selectedIndex,
            visibleIndices: _visibleIndices,
            onTap: (i) {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) setState(() => _selectedIndex = i);
              });
            },
          ),
        ),
        appBar: null,
        body: Stack(
          children: [
            Column(
              children: [
                _buildNavigationHeader(),
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
            if (_isGenerating)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 32),
                      decoration: BoxDecoration(
                        color: config.cardColor,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 56,
                            height: 56,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFE58A18)),
                              backgroundColor: Color(0x33E58A18),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            config.isTamil
                                ? '3D வில்லா & அறிக்கைகள் உருவாகிறது...\nதயவுசெய்து காத்திருக்கவும்'
                                : 'Generating 3D Villa & Reports...\nPlease wait a moment',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: config.isDarkMode
                                  ? Colors.white
                                  : AppColors.deepInk,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Floating "Resume Active Plan" Banner on Home Screen when active project exists
            if (_selectedIndex == 0 && _projectData != null && !_isGenerating)
              Positioned(
                left: 20,
                right: 20,
                bottom: 84, // Cleanly above the floating capsule nav bar
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: config.isDarkMode
                          ? const Color(0xFF1E2430)
                          : const Color(0xFF1B212F),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFE58A18),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0x2EE58A18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.view_in_ar_rounded,
                            size: 18,
                            color: Color(0xFFE58A18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                config.tr('Resume Active Plan',
                                    'நடப்பு வரைபடம் தொடரவும்'),
                                style: GoogleFonts.syne(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                config.tr('Tap to view 3D, Vastu & Reports',
                                    '3D, வாஸ்து மற்றும் அறிக்கைகளை காண்க'),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.amberDefault,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                config.tr('View', 'காண்க'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onAmberInk,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: AppColors.onAmberInk,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: (_isGenerating ||
                (_selectedIndex != 0 &&
                    _selectedIndex != 6 &&
                    _selectedIndex != 7))
            ? null
            : _FloatingCapsuleNavBar(
                selectedIndex: _selectedIndex,
                onTap: (index) {
                  setState(() => _selectedIndex = index);
                },
              ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final List<int> visibleIndices;
  final ValueChanged<int> onTap;

  const _Sidebar({
    required this.selectedIndex,
    required this.visibleIndices,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 44,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              const Text(
                'Kanavu Illam',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.2),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.separated(
              itemCount: visibleIndices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final realIndex = visibleIndices[i];
                final item = _navItems[realIndex];
                final isActive = realIndex == selectedIndex;
                return _SidebarItem(
                  icon: item.icon,
                  label: item.label,
                  isActive: isActive,
                  onTap: () => onTap(realIndex),
                  delay: i * 50,
                );
              },
            ),
          ),
          const Divider(color: Colors.white24, thickness: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFFBBF24),
                child: Text(
                  'Ki',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Kanavu Illam v1.0',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int delay;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFBBF24).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
                  width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: isActive ? const Color(0xFFFCD34D) : Colors.white70),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? Colors.white : Colors.white70,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideX(begin: -0.1, end: 0);
  }
}

class _FloatingCapsuleNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _FloatingCapsuleNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  State<_FloatingCapsuleNavBar> createState() => _FloatingCapsuleNavBarState();
}

class _FloatingCapsuleNavBarState extends State<_FloatingCapsuleNavBar>
    with TickerProviderStateMixin {
  late AnimationController _glideController;
  late Animation<double> _glideCurved;

  late AnimationController _squashController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  AnimationController? _rippleController;
  Offset? _rippleCenter;

  int _currentTab = 0;
  int _fromTab = 0;
  int _toTab = 0;
  int _direction = 0;

  int _tabForIndex(int index) {
    if (index == 6) return 1;
    if (index == 7) return 2;
    return 0;
  }

  // Exact slot coordinates matching code.html
  // Nav bar width = 320, padding = 10, inner width = 300
  // Tab 0: Home (left: 10, width: 84)
  // Tab 1: History (left: 114, width: 92)
  // Tab 2: Profile (left: 226, width: 84)
  double _getSlotLeft(int tab) {
    switch (tab) {
      case 1:
        return 114.0;
      case 2:
        return 226.0;
      default:
        return 10.0;
    }
  }

  double _getSlotWidth(int tab) {
    switch (tab) {
      case 1:
        return 92.0;
      default:
        return 84.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentTab = _tabForIndex(widget.selectedIndex);
    _fromTab = _currentTab;
    _toTab = _currentTab;

    // Matches transition: transform 550ms cubic-bezier(0.34, 1.56, 0.64, 1) in code.html
    _glideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _glideCurved = CurvedAnimation(
      parent: _glideController,
      curve: const Cubic(0.34, 1.56, 0.64, 1.0),
    );

    // Matches liquid-squash 380ms transition in code.html
    _squashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    // Matches waterShimmer 3.8s infinite in code.html
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();

    // Matches organicPulse 3.5s infinite in code.html
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _FloatingCapsuleNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _tabForIndex(widget.selectedIndex);
    if (target != _currentTab) {
      _triggerFlow(target);
    }
  }

  @override
  void dispose() {
    _glideController.dispose();
    _squashController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    _rippleController?.dispose();
    super.dispose();
  }

  void _triggerFlow(int targetTab, [Offset? tapLocal]) {
    if (_currentTab == targetTab && !_glideController.isAnimating) return;
    _fromTab = _currentTab;
    _toTab = targetTab;
    _direction = _toTab - _fromTab;
    _currentTab = targetTab;

    if (tapLocal != null) {
      _rippleCenter = tapLocal;
      _rippleController?.dispose();
      _rippleController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..forward();
    }

    _glideController.forward(from: 0.0);
    _squashController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 76,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: 320,
          height: 64,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.cardBorder, width: 1.0),
              boxShadow: AppColors.floatingNavShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // 1. Ambient Fluid Backdrop Glow (matches .nav-bar-fluid-backdrop in code.html)
                AnimatedBuilder(
                  animation: _glideCurved,
                  builder: (context, _) {
                    final t = _glideCurved.value;
                    final fromLeft = _getSlotLeft(_fromTab);
                    final toLeft = _getSlotLeft(_toTab);
                    final fromW = _getSlotWidth(_fromTab);
                    final toW = _getSlotWidth(_toTab);

                    final curLeft = fromLeft + (toLeft - fromLeft) * t;
                    final curW = fromW + (toW - fromW) * t;
                    final percentage =
                        ((curLeft + curW / 2) / 320.0).clamp(0.0, 1.0);

                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 24,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(32)),
                            gradient: RadialGradient(
                              center: Alignment((percentage * 2.0) - 1.0, 1.0),
                              radius: 0.85,
                              colors: [
                                AppColors.amberHighlight
                                    .withValues(alpha: 0.22),
                                AppColors.amber.withValues(alpha: 0.05),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 0.8],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 2. Glider with Water Flow, Organic Waves, Squashing & Skew (matches #navGlider)
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _glideCurved,
                    _squashController,
                    _shimmerController,
                    _pulseController,
                  ]),
                  builder: (context, _) {
                    final t = _glideCurved.value;
                    final fromLeft = _getSlotLeft(_fromTab);
                    final toLeft = _getSlotLeft(_toTab);
                    final fromW = _getSlotWidth(_fromTab);
                    final toW = _getSlotWidth(_toTab);

                    final curLeft = fromLeft + (toLeft - fromLeft) * t;
                    final curWidth = fromW + (toW - fromW) * t;

                    // Squash & Skew calculation matching .liquid-squash-right / .liquid-squash-left
                    final squashFactor =
                        math.sin(_squashController.value * math.pi);
                    final scaleX = 1.0 + (0.18 * squashFactor);
                    final scaleY = 1.0 - (0.14 * squashFactor);
                    final skewDeg =
                        (_direction > 0 ? -4.0 : (_direction < 0 ? 4.0 : 0.0)) *
                            squashFactor;
                    final skewRad = skewDeg * (math.pi / 180.0);

                    final transformMatrix =
                        Matrix4.diagonal3Values(scaleX, scaleY, 1.0)
                          ..setEntry(0, 1, math.tan(skewRad));

                    final shimmerT = _shimmerController.value;
                    final pulseT = _pulseController.value;

                    return Positioned(
                      left: curLeft,
                      top: 10,
                      width: curWidth,
                      height: 44,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // A. .nav-water-flow (soft blurred ambient glow aura)
                          Positioned(
                            left: -6,
                            top: -6,
                            right: -6,
                            bottom: -6,
                            child: Transform.scale(
                              scale:
                                  1.0 + (0.06 * math.sin(pulseT * 2 * math.pi)),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  gradient: RadialGradient(
                                    center: const Alignment(-0.3, -0.3),
                                    colors: [
                                      AppColors.amberHighlight
                                          .withValues(alpha: 0.45),
                                      AppColors.amber.withValues(alpha: 0.15),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.6, 0.85],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // B. .nav-water-ripple (organic border expanding pulse)
                          Positioned(
                            left: -2,
                            top: -2,
                            right: -2,
                            bottom: -2,
                            child: Transform.scale(
                              scale: 1.0 + (0.18 * pulseT),
                              child: Opacity(
                                opacity: (1.0 - pulseT).clamp(0.0, 0.35),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: AppColors.amberHighlight
                                          .withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // C. .glider-liquid-body (Liquid body with squash & skew)
                          Transform(
                            transform: transformMatrix,
                            alignment: Alignment.center,
                            child: Container(
                              width: curWidth,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: AppColors.amberGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.amber.withValues(alpha: 0.38),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  // Top specular light highlight
                                  Positioned(
                                    top: 1,
                                    left: 8,
                                    right: 8,
                                    height: 1.5,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withValues(alpha: 0.1),
                                            Colors.white.withValues(alpha: 0.6),
                                            Colors.white.withValues(alpha: 0.1),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // .nav-shimmer-sweep (Angled water shimmer line)
                                  Positioned.fill(
                                    child: Transform.translate(
                                      offset: Offset(
                                          (shimmerT * 2.8 - 1.4) * curWidth, 0),
                                      child: Transform(
                                        transform: Matrix4.identity()
                                          ..setEntry(0, 1,
                                              math.tan(-15 * math.pi / 180)),
                                        alignment: Alignment.center,
                                        child: Container(
                                          width: curWidth * 0.6,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white
                                                    .withValues(alpha: 0.0),
                                                Colors.white
                                                    .withValues(alpha: 0.55),
                                                Colors.white
                                                    .withValues(alpha: 0.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // .liquid-wave-strip (Bottom radial liquid wave glow)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: -2,
                                    height: 14,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          center: const Alignment(0.0, 1.2),
                                          radius: 0.8,
                                          colors: [
                                            Colors.white
                                                .withValues(alpha: 0.35),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // 3. Water Click Ripple (.water-click-ripple in code.html)
                if (_rippleCenter != null && _rippleController != null)
                  AnimatedBuilder(
                    animation: _rippleController!,
                    builder: (context, _) {
                      final val = _rippleController!.value;
                      if (val >= 1.0) return const SizedBox.shrink();
                      final radius = 8.0 + (val * 44.0); // Expands to ~52px
                      final opacity = (1.0 - val).clamp(0.0, 1.0);

                      return Positioned(
                        left: _rippleCenter!.dx - radius,
                        top: _rippleCenter!.dy - radius,
                        width: radius * 2,
                        height: radius * 2,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.amber
                                    .withValues(alpha: opacity * 0.65),
                                width: 2.0,
                              ),
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.amberHighlight
                                      .withValues(alpha: opacity * 0.30),
                                  AppColors.amber
                                      .withValues(alpha: opacity * 0.05),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.6, 1.0],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // 4. Interactive Tabs Layer (Home, History, Profile)
                // Both icon and label always present, exactly matching code.html & screen.png
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildNavItem(
                          tabIndex: 0,
                          realIndex: 0,
                          label: 'Home',
                          icon: Icons.home_rounded,
                          width: 84,
                        ),
                        _buildNavItem(
                          tabIndex: 1,
                          realIndex: 6,
                          label: 'History',
                          icon: Icons.history_rounded,
                          width: 92,
                        ),
                        _buildNavItem(
                          tabIndex: 2,
                          realIndex: 7,
                          label: 'Profile',
                          icon: Icons.person_rounded,
                          width: 84,
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
    );
  }

  Widget _buildNavItem({
    required int tabIndex,
    required int realIndex,
    required String label,
    required IconData icon,
    required double width,
  }) {
    final isSelected = _currentTab == tabIndex;

    return SizedBox(
      width: width,
      height: 44,
      child: GestureDetector(
        onTapDown: (details) {
          final slotLeft = _getSlotLeft(tabIndex);
          final tapInBar = Offset(slotLeft + details.localPosition.dx,
              10 + details.localPosition.dy);
          _triggerFlow(tabIndex, tapInBar);
          widget.onTap(realIndex);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isSelected ? 1.0 : 0.8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  icon,
                  key: ValueKey('${tabIndex}_$isSelected'),
                  size: 20,
                  color:
                      isSelected ? AppColors.onAmberInk : AppColors.quietGrey,
                ),
              ),
              const SizedBox(width: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: isSelected ? 13 : 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isSelected ? AppColors.onAmberInk : AppColors.quietGrey,
                  letterSpacing: -0.2,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgDark,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 56),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: const TextStyle(
                color: _textPri,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textSec,
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(begin: const Offset(0.9, 0.9)),
      ),
    );
  }
}
