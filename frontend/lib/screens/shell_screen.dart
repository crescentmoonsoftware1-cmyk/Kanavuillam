import 'dart:convert';
import 'dart:ui' as ui;
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
                        _switchTab(1);
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

class _FloatingCapsuleNavBarState extends State<_FloatingCapsuleNavBar> {
  int _tabForIndex(int index) {
    if (index == 6) return 1;
    if (index == 7) return 2;
    return 0;
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
    final activeTab = _tabForIndex(widget.selectedIndex);

    // Instagram Glass Pill geometry (Icon-only, matching reference image)
    const double barWidth = 230.0;
    const double barHeight = 56.0;
    const double innerPadding = 5.0;
    const double slotWidth = (barWidth - (innerPadding * 2)) / 3.0; // ~73.3px
    const double slotHeight = barHeight - (innerPadding * 2); // 46.0px

    final gliderLeft = innerPadding + (activeTab * slotWidth);

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SizedBox(
            width: barWidth,
            height: barHeight,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.45)
                      : const Color(0x1F0F172A),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF161B26).withValues(alpha: 0.72)
                        : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.90),
                      width: 1.2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Active Pill Glider (matching Instagram reference's soft capsule)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        left: gliderLeft,
                        top: innerPadding,
                        width: slotWidth,
                        height: slotHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.16)
                                : const Color(0x14000000),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : Colors.white.withValues(alpha: 0.60),
                              width: 1.0,
                            ),
                          ),
                        ),
                      ),

                      // Nav Items Row (Icons only: Home, History, Profile)
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: innerPadding),
                          child: Row(
                            children: [
                              _buildTabItem(
                                tabIndex: 0,
                                realIndex: 0,
                                activeTab: activeTab,
                                isDark: isDark,
                                activeIcon: Icons.home_rounded,
                                inactiveIcon: Icons.home_outlined,
                                width: slotWidth,
                              ),
                              _buildTabItem(
                                tabIndex: 1,
                                realIndex: 6,
                                activeTab: activeTab,
                                isDark: isDark,
                                activeIcon: Icons.history_rounded,
                                inactiveIcon: Icons.history_outlined,
                                width: slotWidth,
                              ),
                              _buildTabItem(
                                tabIndex: 2,
                                realIndex: 7,
                                activeTab: activeTab,
                                isDark: isDark,
                                activeIcon: Icons.person_rounded,
                                inactiveIcon: Icons.person_outline_rounded,
                                width: slotWidth,
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
      ),
    ),
  );
  }

  Widget _buildTabItem({
    required int tabIndex,
    required int realIndex,
    required int activeTab,
    required bool isDark,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required double width,
  }) {
    final isSelected = activeTab == tabIndex;
    final activeColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final inactiveColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SizedBox(
      width: width,
      height: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTap(realIndex),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isSelected ? activeIcon : inactiveIcon,
              key: ValueKey('$tabIndex$isSelected'),
              size: 24,
              color: isSelected ? activeColor : inactiveColor,
            ),
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
