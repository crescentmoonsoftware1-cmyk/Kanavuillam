import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/api_service.dart';
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
const _sidebar = Color.fromARGB(255, 255, 255, 255); // Pure white sidebar
const _accent = Color(0xFF2979FF); // Professional blue
const _accentDim = Color(0x152979FF);
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
  Uint8List? _stored3DScreenshot;
  final bool _hasShownLogin = false;

  // GlobalKey to access ViewerScreen's state for screenshot capture
  final GlobalKey<ViewerScreenState> _viewerKey =
      GlobalKey<ViewerScreenState>();

  void _onProjectLoaded(Map<String, dynamic> project, Set<String> selectedIds) {
    setState(() {
      _projectData = project;
      _selectedReportIds = selectedIds;
      _stored3DScreenshot = null; // Reset screenshot when new project loaded
      // Navigate to the first selected report if available, else 3D View
      if (selectedIds.contains('3d')) {
        _selectedIndex = 1;
      } else if (selectedIds.isNotEmpty) {
        // Map first selected ID to index
        _selectedIndex = _getMappedIndex(selectedIds.first);
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
          'Project ${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}|${selectedIds.join(",")}|$totalAmount';

      final res = await apiService.uploadPlan(
        groundFile,
        firstFile,
        secondFile,
        projectName,
        orientation: orientation,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Generation failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ));
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
            ? VastuScreen(projectData: _projectData!)
            : _EmptyState(
                icon: Icons.self_improvement_outlined,
                title: 'Vastu Report',
                subtitle:
                    'Generate a project first to view\nyour Vastu analysis.',
                accentColor: _accent,
              ),
        _projectData != null
            ? EstimationScreen(projectData: _projectData!)
            : _EmptyState(
                icon: Icons.calculate_outlined,
                title: 'Estimation',
                subtitle:
                    'Generate a project first to view\nyour cost estimate.',
                accentColor: _accent,
              ),
        _projectData != null
            ? StructuralScreen(projectData: _projectData!)
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
        const HistoryScreen(),
        ProfileScreen(userData: widget.userData),
      ],
    );
  }

  Widget _buildNavigationHeader() {
    if (_selectedIndex == 0 || _projectData == null) {
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
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF090D16),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
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
      bottomNavigationBar: _isGenerating
          ? null
          : _FloatingCapsuleNavBar(
              selectedIndex: _selectedIndex,
              onTap: (index) {
                if (index == 99) {
                  _scaffoldKey.currentState?.openDrawer();
                } else {
                  setState(() => _selectedIndex = index);
                }
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
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xD91E293B), // Dark frosted glass like Instagram Reels bottom bar
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              spreadRadius: 4,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    index: 0,
                    icon: Icons.home_rounded,
                    label: 'Home',
                    isSelected: selectedIndex == 0,
                  ),
                  _buildNavItem(
                    index: 6,
                    icon: Icons.history_rounded,
                    label: 'History',
                    isSelected: selectedIndex == 6,
                  ),
                  _buildNavItem(
                    index: 7,
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    isSelected: selectedIndex == 7,
                  ),
                  _buildNavItem(
                    index: 99,
                    icon: Icons.menu_rounded,
                    label: 'Menu',
                    isSelected: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFBBF24) // Active Amber capsule pill
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.40),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : Colors.white.withValues(alpha: 0.75),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(duration: 150.ms),
            ],
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
