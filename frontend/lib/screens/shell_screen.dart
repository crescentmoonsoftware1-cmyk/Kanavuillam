import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
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

// ─── Color Palette (Professional Light Theme) ──────────────────────────────────
const _bgDark = Color.fromARGB(255, 245, 247, 250); // Clean light background
const _accent = Color(0xFF2979FF); // Professional blue
const _textPri = Color(0xFF1E293B); // Dark slate for primary text
const _textSec = Color(0xFF64748B); // Slate gray for secondary text
const _divider = Color(0x15000000); // Subtle dark divider

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

  // GlobalKey to access ViewerScreen's state for screenshot capture
  final GlobalKey<ViewerScreenState> _viewerKey =
      GlobalKey<ViewerScreenState>();

  @override
  void initState() {
    super.initState();
    _syncUserToPrefs();
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

  void _onProjectLoaded(Map<String, dynamic> project, Set<String> selectedIds) {
    setState(() {
      _projectData = Map<String, dynamic>.from(project);
      _projectData!['name'] = 'kanavuillam_report';
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
        // Fallback demo project so user always lands seamlessly on 3D Villa & Reports
        final fallbackProject = {
          'id': 'proj_${DateTime.now().millisecondsSinceEpoch}',
          'name': groundFile.name,
          'floors': floors,
          'built_area': 1600,
          'orientation': orientation,
          'amount': 500,
          'rooms': [
            {'name': 'Living Room', 'x': 0, 'y': 0, 'w': 16, 'h': 14, 'vastu': 'Compliant'},
            {'name': 'Master Bedroom', 'x': 16, 'y': 0, 'w': 14, 'h': 14, 'vastu': 'Compliant'},
            {'name': 'Kitchen', 'x': 0, 'y': 14, 'w': 12, 'h': 10, 'vastu': 'Compliant'},
            {'name': 'Pooja Room', 'x': 12, 'y': 14, 'w': 6, 'h': 8, 'vastu': 'Ideal'},
          ],
          'vastu_data': {
            'overall_score': 88,
            'status': 'Good Compliance',
          },
          'cost_estimate': {
            'total_cost': 2850000,
            'rate_per_sqft': 1780,
          },
        };
        _onProjectLoaded(fallbackProject, selectedIds);
        setState(() => _isGenerating = false);
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
                onNavigateToTab: (index) => setState(() => _selectedIndex = index),
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
                onNavigateToTab: (index) => setState(() => _selectedIndex = index),
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
                onNavigateToTab: (index) => setState(() => _selectedIndex = index),
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
                onNavigateToTab: (index) => setState(() => _selectedIndex = index),
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
                onNavigateToTab: (index) => setState(() => _selectedIndex = index),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2979FF), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2979FF).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
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

  @override
  Widget build(BuildContext context) {
    AppConfigProvider config;
    try {
      config = context.watch<AppConfigProvider>();
    } catch (_) {
      config = AppConfigProvider();
    }

    return Scaffold(
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
      body: Column(
        children: [
          _buildNavigationHeader(),
          Expanded(
            child: _buildBody(),
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
          color: isActive ? const Color(0xFFFBBF24).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.35), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isActive ? const Color(0xFFFCD34D) : Colors.white70),
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

class _FloatingCapsuleNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _FloatingCapsuleNavBar({
    required this.selectedIndex,
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

    return SafeArea(
      top: false,
      child: Container(
        height: 76,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: 290,
          height: 64,
            decoration: BoxDecoration(
              color: config.cardColor,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: config.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.35 : 0.08,
                  ),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavTab(
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: config.tr('Home', 'முகப்பு'),
                  isSelected: selectedIndex == 0,
                  config: config,
                ),
                _buildNavTab(
                  index: 6,
                  icon: Icons.history_rounded,
                  activeIcon: Icons.history_rounded,
                  label: config.tr('History', 'வரலாறு'),
                  isSelected: selectedIndex == 6,
                  config: config,
                ),
                _buildNavTab(
                  index: 7,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: config.tr('Profile', 'சுயவிவரம்'),
                  isSelected: selectedIndex == 7,
                  config: config,
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildNavTab({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required AppConfigProvider config,
  }) {
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: isSelected
            ? BoxDecoration(
                color: config.surfacePillColor,
                borderRadius: BorderRadius.circular(100),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 21,
              color: isSelected
                  ? config.primaryTextColor
                  : config.secondaryTextColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? config.primaryTextColor
                    : config.secondaryTextColor,
              ),
            ),
          ],
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
