import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';

/// Production History Screen for Kanavu Illam
/// Incorporates the physical folder dispensing architecture:
/// 1. Folder card appears at center (fades & scales in)
/// 2. Holds briefly at center
/// 3. Glides smoothly up to top resting position (top: 52px)
/// 4. Floor plan cards emerge 1-by-1 from top pocket and glide down in slow-mo
class HistoryScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final void Function(int tab)? onNavigateToTab;
  final void Function(Map<String, dynamic> project)? onSelectProject;

  const HistoryScreen({
    super.key,
    this.userData,
    this.onNavigateToTab,
    this.onSelectProject,
  });

  static void clearCache() => _HistoryScreenState.clearCache();

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late AnimationController _controller;

  static List<_FloorPlanModel>? _cachedPlans;
  static String? _cachedEmail;

  bool _isLoading = false;

  // Default demo plans as fallback
  static const List<_FloorPlanModel> _defaultDemoPlans = [
    _FloorPlanModel(
      title: 'Floor Plan 01',
      date: '12 Oct 2026',
      price: '₹1',
      iconVariant: 1,
      features: ['3D', 'Vastu', 'Cost', 'Structural'],
    ),
    _FloorPlanModel(
      title: 'Floor Plan 02',
      date: '28 Sep 2026',
      price: '₹1',
      iconVariant: 2,
      features: ['3D', 'Vastu', 'Cost'],
    ),
    _FloorPlanModel(
      title: 'Floor Plan 03',
      date: '15 Sep 2026',
      price: '₹1',
      iconVariant: 3,
      features: ['3D', 'Vastu'],
    ),
    _FloorPlanModel(
      title: 'Floor Plan 04',
      date: '02 Aug 2026',
      price: '₹1',
      iconVariant: 1,
      features: ['3D', 'Vastu', 'Cost', 'Structural'],
    ),
    _FloorPlanModel(
      title: 'Floor Plan 05',
      date: '19 Jul 2026',
      price: '₹1',
      iconVariant: 2,
      features: ['3D', 'Vastu'],
    ),
    _FloorPlanModel(
      title: 'Floor Plan 06',
      date: '04 Jun 2026',
      price: '₹1',
      iconVariant: 3,
      features: ['3D', 'Cost'],
    ),
  ];

  List<_FloorPlanModel> _floorPlans = [];

  static void clearCache() {
    _cachedPlans = null;
    _cachedEmail = null;
  }

  @override
  void initState() {
    super.initState();
    // 4.8 seconds total sequence:
    // 1. Folder appears at center (0 - 580ms)
    // 2. Folder micro-hold (580 - 770ms)
    // 3. Folder glides UP to top position (770 - 1340ms)
    // 4. Cards emerge from top pocket 1-by-1 and glide down (1340 - 4800ms)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    );

    final userEmail =
        (widget.userData?['email'] as String?)?.trim().toLowerCase();
    if (_cachedPlans != null &&
        _cachedEmail != null &&
        _cachedEmail == userEmail) {
      _floorPlans = _cachedPlans!;
      _isLoading = false;
    } else {
      _loadUserHistory();
    }

    // Auto-play the sequence on load after initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _controller.forward(from: 0.0);
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadUserHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fetches real user projects and maps them to _FloorPlanModel
  Future<void> _loadUserHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = ((widget.userData?['email'] as String?) ??
              prefs.getString('user_email') ??
              '')
          .trim()
          .toLowerCase();

      // Check if Google Play Store reviewer account
      final isReviewer = email == 'playstore@kanavuillam.com' ||
          email == 'reviewer@kanavuillam.com';

      if (email.isNotEmpty && email != 'unknown') {
        if (_cachedEmail != null && _cachedEmail != email) {
          _cachedPlans = null;
        }

        final fetched = await _apiService.getAllProjects(email);
        if (fetched.isNotEmpty && mounted) {
          int index = 1;
          final mapped = fetched.map<_FloorPlanModel>((p) {
            String rawName = p['name'] ?? 'KI_Project';
            String displayName = rawName;
            List<String> features = ['3D', 'Vastu', 'Cost', 'Structural'];
            int amountVal = 1; // Standard plan package price

            if (rawName.contains('|')) {
              final parts = rawName.split('|');
              displayName = parts[0];
              if (parts.length > 1 && parts[1].isNotEmpty) {
                features = parts[1]
                    .split(',')
                    .map((e) => e.trim().toUpperCase())
                    .toList();
              }
              if (parts.length > 2) {
                final parsed = double.tryParse(parts[2]);
                if (parsed != null && parsed > 0) {
                  amountVal = parsed.toInt();
                }
              }
            } else if (p['amount'] != null) {
              final parsed = double.tryParse(p['amount'].toString());
              if (parsed != null && parsed > 0) {
                amountVal = parsed.toInt();
              }
            }

            final lower = displayName.toLowerCase().trim();
            if (lower == 'kanavuillam_report' ||
                lower == 'new project' ||
                lower == 'project' ||
                lower.isEmpty) {
              final has3d = features.contains('3D');
              final hasVastu = features.contains('VASTU');
              if (has3d && hasVastu) {
                displayName =
                    '3D & Vastu Plan ${index.toString().padLeft(2, '0')}';
              } else {
                displayName =
                    'Architectural Plan ${index.toString().padLeft(2, '0')}';
              }
            }

            String dateStr = 'Recent';
            if (p['created_at'] != null) {
              dateStr = _formatDate(p['created_at'].toString());
            }

            final int variant = ((index - 1) % 3) + 1;
            index++;

            return _FloorPlanModel(
              title: displayName,
              date: dateStr,
              price: '₹$amountVal',
              iconVariant: variant,
              features: features,
              raw: p,
            );
          }).toList();

          _cachedPlans = mapped;
          _cachedEmail = email;

          if (mounted) {
            setState(() {
              _floorPlans = mapped;
              _isLoading = false;
            });
          }
          return;
        } else if (isReviewer) {
          // Provide sample plans only for Google Play Reviewer demo account
          if (mounted) {
            setState(() {
              _floorPlans = List.from(_defaultDemoPlans);
              _cachedPlans = _floorPlans;
              _cachedEmail = email;
              _isLoading = false;
            });
          }
          return;
        } else if (mounted) {
          // Real fresh user with 0 projects in database:
          _cachedPlans = [];
          _cachedEmail = email;
          setState(() {
            _floorPlans = [];
            _isLoading = false;
          });
          return;
        }
      } else if (mounted) {
        setState(() {
          _floorPlans = [];
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(String rawDate) {
    try {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
      }
    } catch (_) {}
    return rawDate.split('T').first;
  }

  void _replaySequence() {
    _controller.reset();
    _controller.forward(from: 0.0);
  }

  void _showProjectDetails(_FloorPlanModel item) {
    AppConfigProvider config;
    try {
      config = context.read<AppConfigProvider>();
    } catch (_) {
      config = AppConfigProvider();
    }
    final isDark = config.isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
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
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF18191D),
                  ),
                ),
                Text(
                  item.price,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE58A18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              config.tr(
                  'Created on ${item.date}', 'உருவாக்கப்பட்டது: ${item.date}'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF8E94A0),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              config.tr(
                  'Included Reports & Analysis', 'சேர்க்கப்பட்ட அறிக்கைகள்'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1B212F),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.features.map((feat) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF242E3E)
                        : const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: Color(0xFFE58A18),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        feat,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E252D),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? Colors.white : const Color(0xFF1B212F),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  config.tr('Close', 'மூடு'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
    final isDark = config.isDarkMode;

    final int planCount = _floorPlans.length;
    final String countSubtitle = config.tr(
      '$planCount ${planCount == 1 ? "floor plan" : "floor plans"}',
      '$planCount வரைபடங்கள்',
    );

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF14171F) : const Color(0xFFE2E8F0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = math.min(constraints.maxWidth, 420.0);
          final double cardLeft =
              math.max(16.0, (constraints.maxWidth - 350.0) / 2.0);

          return Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Container(
                    width: 390,
                    height: 844,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                const Color(0xFF1B212F),
                                const Color(0xFF11151E),
                              ]
                            : [
                                const Color(0xFFE9EEF4),
                                const Color(0xFFD8DFE9),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2C3545)
                            : const Color(0xFFCBD5E1),
                        width: 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x331B212F),
                          blurRadius: 36,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final double progress = _controller.value;

                        // ─── STAGE 1, 2, 3: FOLDER ENTRANCE & GLIDE TO TOP ────────
                        const double centerTop = (844.0 - 190.0) / 2.0; // 327.0
                        const double finalTop = 52.0; // Header resting position

                        double folderTop;
                        double folderOpacity;
                        double folderScale;

                        if (progress <= 0.12) {
                          final t = (progress / 0.12).clamp(0.0, 1.0);
                          final curve = Curves.easeOutCubic.transform(t);
                          folderTop = centerTop;
                          folderOpacity = curve;
                          folderScale = 0.92 + (0.08 * curve);
                        } else if (progress <= 0.16) {
                          folderTop = centerTop;
                          folderOpacity = 1.0;
                          folderScale = 1.0;
                        } else if (progress <= 0.28) {
                          final t = ((progress - 0.16) / (0.28 - 0.16))
                              .clamp(0.0, 1.0);
                          final curve =
                              const Cubic(0.20, 1.0, 0.30, 1.0).transform(t);
                          folderTop =
                              centerTop - ((centerTop - finalTop) * curve);
                          folderOpacity = 1.0;
                          folderScale = 1.0;
                        } else {
                          folderTop = finalTop;
                          folderOpacity = 1.0;
                          folderScale = 1.0;
                        }

                        final int displayCount =
                            math.min(_floorPlans.length, 6);

                        // ─── STAGE 4: 1-BY-1 CARDS DISPENSE (AFTER FOLDER REACHES TOP) ───
                        final List<Widget> dockedCardWidgets = [];
                        final List<Widget> pocketCardWidgets = [];
                        final List<Widget> descendingCardWidgets = [];

                        for (int index = 0; index < displayCount; index++) {
                          final item = _floorPlans[index];
                          final double restingTop = 256.0 + (index * 64.0);

                          // Sequential 1-by-1 cadence with zero overlap:
                          final double cardStart = 0.28 + (index * 0.115);
                          const double riseDuration =
                              0.040; // ~192ms: Rises UP out of pocket
                          const double descendDuration =
                              0.075; // ~360ms: Glides DOWN in slow-mo
                          final double riseEnd = cardStart + riseDuration;
                          final double cardEnd = riseEnd + descendDuration;

                          if (progress < cardStart) {
                            continue;
                          } else if (progress < riseEnd) {
                            // ─── PHASE 1: RISING UP OUT OF FOLDER POCKET ───
                            // Layer 3 (BEHIND Front Panel) -> "History" is NEVER covered!
                            final double t =
                                ((progress - cardStart) / riseDuration)
                                    .clamp(0.0, 1.0);
                            final double curve =
                                Curves.easeOutCubic.transform(t);

                            final double insideTop = folderTop + 30.0;
                            final double peakTop = folderTop - 34.0;

                            final double cardTop =
                                insideTop - ((insideTop - peakTop) * curve);
                            final double cardScale = 0.93 + (0.07 * curve);
                            final double cardOpacity =
                                (t / 0.20).clamp(0.0, 1.0);

                            pocketCardWidgets.add(
                              Positioned(
                                top: cardTop,
                                left: 20,
                                width: 350,
                                height: 58,
                                child: Opacity(
                                  opacity: cardOpacity,
                                  child: Transform.scale(
                                    scale: cardScale,
                                    child: _buildFloorPlanCard(item,
                                        isDark: isDark),
                                  ),
                                ),
                              ),
                            );
                          } else if (progress < cardEnd) {
                            // ─── PHASE 2: GLIDING DOWN IN FRONT OF FOLDER ───
                            // Layer 5 (IN FRONT OF Front Panel) -> Glides down over front
                            final double t =
                                ((progress - riseEnd) / descendDuration)
                                    .clamp(0.0, 1.0);
                            final double curve =
                                Curves.easeOutCubic.transform(t);

                            final double peakTop = folderTop - 34.0;
                            final double cardTop =
                                peakTop + ((restingTop - peakTop) * curve);
                            final double cardScale = 1.02 - (0.02 * curve);

                            descendingCardWidgets.add(
                              Positioned(
                                top: cardTop,
                                left: 20,
                                width: 350,
                                height: 58,
                                child: Transform.scale(
                                  scale: cardScale,
                                  child: GestureDetector(
                                    onTap: () => _showProjectDetails(item),
                                    behavior: HitTestBehavior.opaque,
                                    child: _buildFloorPlanCard(
                                      item,
                                      isElevated: true,
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            // ─── PHASE 3: DOCKED AT DESIGNATED ROW ───
                            dockedCardWidgets.add(
                              Positioned(
                                top: restingTop,
                                left: 20,
                                width: 350,
                                height: 58,
                                child: GestureDetector(
                                  onTap: () => _showProjectDetails(item),
                                  behavior: HitTestBehavior.opaque,
                                  child:
                                      _buildFloorPlanCard(item, isDark: isDark),
                                ),
                              ),
                            );
                          }
                        }

                        return Stack(
                          children: [
                            // ─── 1. DOCKED CARDS (Resting below folder) ─────────
                            ...dockedCardWidgets,

                            // ─── 2. FOLDER BACK PANEL + BLUEPRINT PAPERS ───────
                            Positioned(
                              top: folderTop,
                              left: 20,
                              width: 350,
                              height: 190,
                              child: Opacity(
                                opacity: folderOpacity,
                                child: Transform.scale(
                                  scale: folderScale,
                                  child: _buildFolderBack(isDark: isDark),
                                ),
                              ),
                            ),

                            // ─── 3. CARDS RISING INSIDE POCKET (BEHIND Front Flap!)
                            ...pocketCardWidgets,

                            // ─── 4. FOLDER FRONT PANEL (The Slate Flap) ─────────
                            Positioned(
                              top: folderTop,
                              left: 20,
                              width: 350,
                              height: 190,
                              child: Opacity(
                                opacity: folderOpacity,
                                child: Transform.scale(
                                  scale: folderScale,
                                  child: _buildFolderFront(
                                    countSubtitle,
                                    config: config,
                                    isDark: isDark,
                                  ),
                                ),
                              ),
                            ),

                            // ─── 5. EMPTY STATE (When user has 0 floor plans) ───
                            if (_floorPlans.isEmpty && progress > 0.25)
                              Positioned(
                                top: folderTop + 205,
                                left: 20,
                                width: 350,
                                child: _buildEmptyHistoryState(config, isDark),
                              ),

                            // ─── 6. ACTIVE DESCENDING CARDS (IN FRONT OF Front Flap!)
                            ...descendingCardWidgets,
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── EMPTY STATE (When user has 0 floor plans) ─────────────────────────
  Widget _buildEmptyHistoryState(AppConfigProvider config, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B212F) : const Color(0xFFFCFDFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2C3545) : const Color(0xFFD8DFE9),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141B212F),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE58A18).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.folder_open_rounded,
                color: Color(0xFFE58A18),
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            config.tr('No Floor Plans Yet', 'வரைபடங்கள் இன்னும் இல்லை'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFFCFDFF) : const Color(0xFF1B212F),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            config.tr(
              'Upload your first floor plan on the Home Map screen to generate 3D models, Vastu analysis, and cost reports.',
              'உங்கள் முதல் வரைபடத்தை முகப்புத் திரையில் பதிவேற்றி 3D மாதிரி, வாஸ்து பகுப்பாய்வு மற்றும் அறிக்கைகளைப் பெறுங்கள்.',
            ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF8E94A0),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE58A18),
                foregroundColor: const Color(0xFF1B212F),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                config.tr('Upload Floor Plan', 'வரைபடத்தை பதிவேற்று'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () {
                if (widget.onNavigateToTab != null) {
                  widget.onNavigateToTab!(0);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── FOLDER BACK PANEL (Back Sheet + Peeking Blueprint Papers) ───────
  Widget _buildFolderBack({required bool isDark}) {
    return SizedBox(
      width: 350,
      height: 190,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Layer 1: Back panel (taller by 14px at top)
          Positioned(
            left: 0,
            right: 0,
            top: -14,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF242E3E).withValues(alpha: 0.70)
                    : const Color(0xFF64748B).withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.20),
                  width: 1.0,
                ),
              ),
            ),
          ),

          // Layer 2a: Left Paper Sheet (Rotated -4 deg, peeking -34px)
          Positioned(
            left: 26,
            top: -34,
            child: Transform.rotate(
              angle: -4 * math.pi / 180,
              alignment: Alignment.bottomCenter,
              child: _buildBlueprintPaperSheet(isLeft: true, isDark: isDark),
            ),
          ),

          // Layer 2b: Right Paper Sheet (Rotated +4 deg, peeking -32px)
          Positioned(
            right: 24,
            top: -32,
            child: Transform.rotate(
              angle: 4 * math.pi / 180,
              alignment: Alignment.bottomCenter,
              child: _buildBlueprintPaperSheet(isLeft: false, isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }

  // ─── FOLDER FRONT PANEL (Dark Frosted Slate Flap with Sloped Tab) ────
  Widget _buildFolderFront(
    String countSubtitle, {
    required AppConfigProvider config,
    required bool isDark,
  }) {
    return Container(
      width: 350,
      height: 190,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF242E3E), // Dark Binder
                  Color(0xFF131822), // Deep Slate
                ]
              : const [
                  Color(0xFF364050), // Steel Binder
                  Color(0xFF1B212F), // Structural Slate
                ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x381B212F),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Sloped folder tab notch profile along top edge
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 28,
            child: CustomPaint(
              painter: _FolderTabPainter(),
            ),
          ),

          // Front Panel Interior Content ("History" is always pristine & visible)
          Positioned(
            bottom: 22,
            left: 22,
            right: 22,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      config.tr('History', 'வரலாறு'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.48,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      countSubtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.70),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: Color(0xFFE58A18),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          _loadUserHistory();
                          _replaySequence();
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
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

  // ─── BLUEPRINT PAPER SHEET HELPER ────────────────────────────────────
  Widget _buildBlueprintPaperSheet(
      {required bool isLeft, required bool isDark}) {
    final Color paperBg =
        isDark ? const Color(0xFF1E2634) : const Color(0xFFFCFDFF);
    final Color lineCol =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color borderCol =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    if (isLeft) {
      return Container(
        width: 180,
        height: 96,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: paperBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderCol, width: 1.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F1B212F),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: lineCol.withValues(alpha: 0.40),
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 80,
                  height: 4,
                  decoration: BoxDecoration(
                    color: lineCol.withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: borderCol),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: lineCol.withValues(alpha: 0.35),
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 64,
                  height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: lineCol.withValues(alpha: 0.35),
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: 170,
        height: 96,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: paperBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderCol, width: 1.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F1B212F),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 56,
                  height: 6,
                  decoration: BoxDecoration(
                    color: lineCol.withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: lineCol.withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: borderCol),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: lineCol.withValues(alpha: 0.35),
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: lineCol.withValues(alpha: 0.35),
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  // ─── SINGLE FLOOR PLAN CARD WIDGET ───────────────────────────────────
  Widget _buildFloorPlanCard(
    _FloorPlanModel item, {
    bool isElevated = false,
    required bool isDark,
  }) {
    return Container(
      width: 350,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B212F) : const Color(0xFFFCFDFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2C3545)
              : Colors.white.withValues(alpha: 0.90),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x001b212f)
                .withValues(alpha: isElevated ? 0.22 : 0.08),
            blurRadius: isElevated ? 24 : 16,
            offset: Offset(0, isElevated ? 12 : 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF242E3E)
                      : const Color(0xFF2E3744),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(18, 18),
                    painter:
                        _BlueprintLayoutIconPainter(variant: item.iconVariant),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF18191D),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.date,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF8E94A0),
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            item.price,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF18191D),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── MODEL CLASS ─────────────────────────────────────────────────────────────
class _FloorPlanModel {
  final String title;
  final String date;
  final String price;
  final int iconVariant;
  final List<String> features;
  final Map<String, dynamic>? raw;

  const _FloorPlanModel({
    required this.title,
    required this.date,
    required this.price,
    required this.iconVariant,
    required this.features,
    this.raw,
  });
}

// ─── FOLDER TAB PAINTER ──────────────────────────────────────────────────────
class _FolderTabPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, 28)
      ..lineTo(0, 16)
      ..cubicTo(0, 8, 8, 0, 20, 0)
      ..lineTo(110, 0)
      ..cubicTo(126, 0, 138, 12, 152, 12)
      ..lineTo(size.width - 20, 12)
      ..cubicTo(size.width - 8, 12, size.width, 18, size.width, 28);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── BLUEPRINT ICONS PAINTER ─────────────────────────────────────────────────
class _BlueprintLayoutIconPainter extends CustomPainter {
  final int variant;

  _BlueprintLayoutIconPainter({required this.variant});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = const Color(0xFFE58A18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double w = size.width;
    final double h = size.height;

    switch (variant) {
      case 1:
        // Outer room boundary
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(1, 1, w - 2, h - 2),
            const Radius.circular(2.5),
          ),
          strokePaint,
        );
        // Vertical dividing partition
        canvas.drawLine(
          Offset(w * 0.45, 1),
          Offset(w * 0.45, h - 1),
          strokePaint,
        );
        // Horizontal interior wall
        canvas.drawLine(
          Offset(w * 0.45, h * 0.55),
          Offset(w - 1, h * 0.55),
          strokePaint,
        );
        break;

      case 2:
        // L-shaped floor layout
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(1, 1, w - 2, h - 2),
            const Radius.circular(2.5),
          ),
          strokePaint,
        );
        // Horizontal hall split
        canvas.drawLine(
          Offset(1, h * 0.5),
          Offset(w - 1, h * 0.5),
          strokePaint,
        );
        // Vertical room partition in top half
        canvas.drawLine(
          Offset(w * 0.5, 1),
          Offset(w * 0.5, h * 0.5),
          strokePaint,
        );
        break;

      case 3:
      default:
        // 4-Quadrant architectural grid
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(1, 1, w - 2, h - 2),
            const Radius.circular(2.5),
          ),
          strokePaint,
        );
        canvas.drawLine(
          Offset(w * 0.5, 1),
          Offset(w * 0.5, h - 1),
          strokePaint,
        );
        canvas.drawLine(
          Offset(1, h * 0.5),
          Offset(w - 1, h * 0.5),
          strokePaint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintLayoutIconPainter oldDelegate) =>
      oldDelegate.variant != variant;
}
