import 'dart:math' as math;
import 'dart:convert';
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

class ShellScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const ShellScreen({super.key, this.userData});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  final Set<int> _loadedTabs = {0};
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
      _loadedTabs.clear();
      _loadedTabs.add(0);
      _loadedTabs.add(_selectedIndex);
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

      const totalAmount = 1.0;

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

  void _switchTab(int newIndex) {
    if (_selectedIndex == 1 && newIndex != 1) {
      _viewerKey.currentState?.pauseRenderer();
    } else if (newIndex == 1) {
      _viewerKey.currentState?.resumeRenderer();
    }
    setState(() {
      _selectedIndex = newIndex;
      _loadedTabs.add(newIndex);
    });
  }

  Widget _buildBody() {
    _loadedTabs.add(_selectedIndex);
    return IndexedStack(
      index: _selectedIndex,
      children: [
        UploadScreen(
          onProjectLoaded: _onProjectLoaded,
          onStartGeneration: _startAIGeneration,
          isExternalLoading: _isGenerating,
        ),
        _loadedTabs.contains(1)
            ? (_projectData != null
                ? ViewerScreen(
                    key: _viewerKey,
                    projectData: _projectData!,
                    onNavigateToTab: _switchTab,
                    onNavigateToVastu: () => _switchTab(2),
                  )
                : _EmptyState(
                    icon: Icons.view_in_ar_rounded,
                    title: '3D View',
                    subtitle:
                        'Upload a floor plan on the Home Map screen\nto generate your 3D model.',
                    accentColor: _accent,
                  ))
            : const SizedBox.shrink(),
        _loadedTabs.contains(2)
            ? (_projectData != null
                ? VastuScreen(
                    projectData: _projectData!,
                    onNavigateToTab: _switchTab,
                    onNavigateToNext: () => _switchTab(3),
                    onBack: () => _switchTab(1),
                  )
                : _EmptyState(
                    icon: Icons.self_improvement_outlined,
                    title: 'Vastu Report',
                    subtitle:
                        'Generate a project first to view\nyour Vastu analysis.',
                    accentColor: _accent,
                  ))
            : const SizedBox.shrink(),
        _loadedTabs.contains(3)
            ? (_projectData != null
                ? EstimationScreen(
                    projectData: _projectData!,
                    onNavigateToTab: _switchTab,
                    onNavigateToNext: () => _switchTab(4),
                    onBack: () => _switchTab(2),
                  )
                : _EmptyState(
                    icon: Icons.calculate_outlined,
                    title: 'Estimation',
                    subtitle:
                        'Generate a project first to view\nyour cost estimate.',
                    accentColor: _accent,
                  ))
            : const SizedBox.shrink(),
        _loadedTabs.contains(4)
            ? (_projectData != null
                ? StructuralScreen(
                    projectData: _projectData!,
                    onNavigateToTab: _switchTab,
                    onNavigateToNext: () => _switchTab(5),
                    onBack: () => _switchTab(3),
                  )
                : _EmptyState(
                    icon: Icons.foundation_outlined,
                    title: 'Structural Report',
                    subtitle:
                        'Generate a project first to view\nthe structural analysis.',
                    accentColor: _accent,
                  ))
            : const SizedBox.shrink(),
        _loadedTabs.contains(5)
            ? (_projectData != null
                ? DownloadScreen(
                    projectData: _projectData!,
                    selectedReportIds: _selectedReportIds,
                    onNavigateToTab: _switchTab,
                    onNavigateTo3D: () => _switchTab(1),
                    userData: widget.userData,
                    capture3DScreenshots: () async {
                      if (!_loadedTabs.contains(1)) {
                        setState(() {
                          _loadedTabs.add(1);
                        });
                        // Wait for Flutter to mount ViewerScreen and attach GlobalKey
                        for (int i = 0; i < 40; i++) {
                          await Future.delayed(const Duration(milliseconds: 100));
                          if (_viewerKey.currentState != null) break;
                        }
                      }
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
                  ))
            : const SizedBox.shrink(),
        _loadedTabs.contains(6)
            ? HistoryScreen(userData: widget.userData)
            : const SizedBox.shrink(),
        _loadedTabs.contains(7)
            ? ProfileScreen(userData: widget.userData)
            : const SizedBox.shrink(),
      ],
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
      _switchTab(4);
      return;
    }
    // Structure (4) -> Cost (3)
    if (_selectedIndex == 4) {
      _switchTab(3);
      return;
    }
    // Cost (3) -> Vastu (2)
    if (_selectedIndex == 3) {
      _switchTab(2);
      return;
    }
    // Vastu (2) -> 3D View (1)
    if (_selectedIndex == 2) {
      _switchTab(1);
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
      _switchTab(0);
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
                if (mounted) _switchTab(i);
              });
            },
          ),
        ),
        appBar: null,
        body: Stack(
          children: [
            _buildBody(),
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

            if (!_isGenerating &&
                (_selectedIndex == 0 ||
                    _selectedIndex == 6 ||
                    _selectedIndex == 7))
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _FloatingCapsuleNavBar(
                  selectedIndex: _selectedIndex,
                  onTap: _switchTab,
                ),
              ),
          ],
        ),
        bottomNavigationBar: null,
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
    AppConfigProvider config;
    try {
      config = context.watch<AppConfigProvider>();
    } catch (_) {
      config = AppConfigProvider();
    }
    final isDark = config.isDarkMode;

    return Container(
      width: 280,
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFCFDFF),
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
              Text(
                'Kanavu Illam',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                  isDark: isDark,
                );
              },
            ),
          ),
          Divider(
            color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
            thickness: 1,
          ),
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
              Text(
                'Kanavu Illam v1.0',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
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
  final bool isDark;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.delay,
    this.isDark = true,
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
              ? (isDark
                  ? const Color(0xFFFBBF24).withValues(alpha: 0.15)
                  : const Color(0xFFE58A18).withValues(alpha: 0.12))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(
                  color: isDark
                      ? const Color(0xFFFBBF24).withValues(alpha: 0.35)
                      : const Color(0xFFE58A18).withValues(alpha: 0.30),
                  width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive
                  ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706))
                  : (isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? Colors.white70 : const Color(0xFF64748B)),
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
  late AnimationController _posController;
  late AnimationController _buttonController;
  late Animation<double> _posAnim;
  late Animation<double> _buttonScaleAnim;
  late int _activeTabIndex;
  bool _isAnimating = false;

  static int _getTabIndex(int shellIndex) {
    if (shellIndex == 6) return 0; // History
    if (shellIndex == 7) return 2; // Profile
    return 1; // Home (default)
  }

  static int _getShellIndex(int tabIndex) {
    if (tabIndex == 0) return 6;
    if (tabIndex == 2) return 7;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _activeTabIndex = _getTabIndex(widget.selectedIndex);

    _posController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _posAnim = Tween<double>(
      begin: _activeTabIndex.toDouble(),
      end: _activeTabIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _posController,
      curve: Curves.easeInOutCubic,
    ));

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _buttonScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOutBack,
    ));
    _buttonController.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _FloatingCapsuleNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetTab = _getTabIndex(widget.selectedIndex);
    if (targetTab != _activeTabIndex && !_isAnimating) {
      _animateToTab(targetTab, notify: false);
    }
  }

  void _animateToTab(int targetTab, {bool notify = true}) async {
    if (targetTab == _activeTabIndex && !_isAnimating) return;
    _isAnimating = true;

    // Phase 1: Button dives down into the scoop
    await _buttonController.reverse(from: 1.0);

    // Phase 2: Empty scoop notch glides across to the target tab
    final startVal = _posAnim.value;
    _posAnim = Tween<double>(
      begin: startVal,
      end: targetTab.toDouble(),
    ).animate(CurvedAnimation(
      parent: _posController,
      curve: Curves.easeInOutCubic,
    ));
    setState(() {
      _activeTabIndex = targetTab;
    });
    await _posController.forward(from: 0.0);

    // Phase 3: Button pops up out of the scoop at destination
    await _buttonController.forward(from: 0.0);

    _isAnimating = false;
    if (notify) {
      widget.onTap(_getShellIndex(targetTab));
    }
  }

  @override
  void dispose() {
    _posController.dispose();
    _buttonController.dispose();
    super.dispose();
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

    final barColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : const Color(0x281B212F);

    final tabIcons = [
      Icons.history_rounded,
      Icons.home_rounded,
      Icons.person_outline_rounded,
    ];

    const tabCount = 3;
    const barHeight = 75.0;
    const buttonDiam = 54.0;
    const buttonTop = -17.0;

    return SizedBox(
      width: double.infinity,
      height: barHeight,
      child: AnimatedBuilder(
        animation: Listenable.merge([_posController, _buttonController]),
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final tabWidth = w / tabCount;
              final currentCx = (0.5 + _posAnim.value) * tabWidth;

              final buttonBgColor = isDark ? const Color(0xFF283548) : Colors.white;
              final activeIconColor = isDark
                  ? const Color(0xFFE58A18)
                  : const Color(0xFF1E293B);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Authentic Curved Scoop Painter (exact cubic bezier cradle)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CurvedScoopedNavBarPainter(
                        pos: _posAnim.value,
                        itemsLength: tabCount,
                        color: barColor,
                        shadowColor: shadowColor,
                      ),
                    ),
                  ),

                  // 2. Inactive icons centered inside the bar
                  ...List.generate(tabCount, (i) {
                    final dist = (_posAnim.value - i).abs().clamp(0.0, 1.0);
                    final buttonImpact = i == _activeTabIndex ? _buttonScaleAnim.value : 0.0;
                    final iconOpacity = ((1.0 - buttonImpact) * dist).clamp(0.0, 1.0);

                    return Positioned(
                      left: i * tabWidth,
                      width: tabWidth,
                      top: 15,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () => _animateToTab(i),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Opacity(
                            opacity: iconOpacity,
                            child: Icon(
                              tabIcons[i],
                              size: 25,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // 3. Floating Circular Button nestled snugly in the scoop
                  Positioned(
                    left: currentCx - (buttonDiam / 2),
                    top: buttonTop,
                    width: buttonDiam,
                    height: buttonDiam,
                    child: GestureDetector(
                      onTap: () => _animateToTab(_activeTabIndex),
                      behavior: HitTestBehavior.opaque,
                      child: ScaleTransition(
                        scale: _buttonScaleAnim,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: buttonBgColor,
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.50)
                                    : Colors.black.withValues(alpha: 0.16),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              tabIcons[_activeTabIndex],
                              key: ValueKey<int>(_activeTabIndex),
                              size: 26,
                              color: activeIconColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Custom Painter creating the authentic curved navigation bar scoop
/// with smooth cubic bezier shoulders and cradle matching the reference exactly
class _CurvedScoopedNavBarPainter extends CustomPainter {
  final double pos;
  final int itemsLength;
  final Color color;
  final Color shadowColor;

  _CurvedScoopedNavBarPainter({
    required this.pos,
    required this.itemsLength,
    required this.color,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final span = 1.0 / itemsLength;
    final s = 80.0 / w;
    final startingLoc = pos * span;
    final loc = startingLoc + (span - s) / 2;

    final p0x = (loc - 0.1) * w;
    final c1x = (loc + s * 0.20) * w;
    final c2x = loc * w;
    final midx = (loc + s * 0.50) * w;
    final c3x = (loc + s) * w;
    final c4x = (loc + s - s * 0.20) * w;
    final p1x = (loc + s * 1.10) * w;
    final dipY = h * 0.60;

    final path = Path();
    final p0xClamped = p0x.clamp(0.0, w);
    if (p0xClamped > 0) {
      path.lineTo(p0xClamped, 0);
    }
    path.cubicTo(c1x, 0, c2x, dipY, midx, dipY);
    path.cubicTo(c3x, dipY, c4x, 0, p1x, 0);
    final p1xClamped = p1x.clamp(0.0, w);
    if (p1xClamped < w) {
      path.lineTo(w, 0);
    }
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    // Ambient diffuse shadow along top contour
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path.shift(const Offset(0, -2)), shadowPaint);

    // Solid bar surface
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _CurvedScoopedNavBarPainter oldDelegate) =>
      oldDelegate.pos != pos ||
      oldDelegate.color != color ||
      oldDelegate.shadowColor != shadowColor;
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
