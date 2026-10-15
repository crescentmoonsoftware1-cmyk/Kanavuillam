import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const HistoryScreen({
    super.key,
    this.userData,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadUserHistory();
  }

  static final List<Map<String, dynamic>> _sampleProjects = [
    {
      'name': 'KI_Project 01',
      'date': '12 Oct 2026',
      'features': ['3d', 'vastu', 'cost', 'structural'],
      'amount': '₹500',
      'image_url': null,
    },
    {
      'name': 'KI_Project 02',
      'date': '28 Sep 2026',
      'features': ['3d', 'vastu', 'cost', 'structural'],
      'amount': '₹500',
      'image_url': null,
    },
    {
      'name': 'KI_Project 03',
      'date': '15 Sep 2026',
      'features': ['3d', 'vastu', 'cost', 'structural'],
      'amount': '₹500',
      'image_url': null,
    },
    {
      'name': 'KI_Project 04',
      'date': '02 Aug 2026',
      'features': ['3d', 'vastu', 'cost', 'structural'],
      'amount': '₹500',
      'image_url': null,
    },
    {
      'name': 'KI_Project 05',
      'date': '19 Jul 2026',
      'features': ['3d', 'vastu', 'cost', 'structural'],
      'amount': '₹500',
      'image_url': null,
    },
    {
      'name': 'KI_Project 06',
      'date': '04 Jun 2026',
      'features': ['3d', 'vastu', 'cost', 'structural'],
      'amount': '₹500',
      'image_url': null,
    },
  ];

  Future<void> _loadUserHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = (widget.userData?['email'] as String?) ??
          prefs.getString('user_email');

      if (email == null || email.isEmpty || email == 'unknown') {
        if (mounted) {
          setState(() {
            _projects = _sampleProjects;
            _isLoading = false;
          });
        }
        return;
      }

      final fetched = await _apiService.getAllProjects(email);

      if (mounted) {
        if (fetched.isNotEmpty) {
          int index = 1;
          final mapped = fetched.map<Map<String, dynamic>>((p) {
            String rawName = p['name'] ?? 'KI_Project';
            String displayName = rawName;
            List<String> features = ['3d', 'vastu', 'cost', 'structural'];
            String amount = '₹500';

            if (rawName.contains('|')) {
              final parts = rawName.split('|');
              displayName = parts[0];
              if (parts.length > 1 && parts[1].isNotEmpty) {
                final reportKeys = parts[1]
                    .split(',')
                    .map((e) => e.trim().toLowerCase())
                    .toList();
                features = reportKeys;
              }
              if (parts.length > 2) {
                amount = '₹${(double.tryParse(parts[2]) ?? 500).toInt()}';
              }
            }

            final lowerName = displayName.toLowerCase().trim();
            if (lowerName == 'kanavuillam_report' ||
                lowerName == 'new project' ||
                lowerName == 'project' ||
                lowerName.startsWith('floor plan') ||
                lowerName.isEmpty) {
              displayName = 'KI_Project ${index.toString().padLeft(2, '0')}';
            } else {
              displayName = 'KI_Project ${index.toString().padLeft(2, '0')}';
            }
            index++;

            final createdAt = p['created_at'] != null
                ? p['created_at'].toString().split('T').first
                : 'Recent';

            final imageUrl = p['image_url']?.toString();

            return {
              'name': displayName,
              'date': createdAt,
              'features': features,
              'amount': amount,
              'image_url': imageUrl,
              'raw': p,
            };
          }).toList();

          setState(() {
            _projects = mapped;
            _isLoading = false;
          });
        } else {
          setState(() {
            _projects = _sampleProjects;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _projects = _sampleProjects;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppConfigProvider config;
    try {
      config = context.watch<AppConfigProvider>();
    } catch (_) {
      config = AppConfigProvider();
    }

    final primaryTextColor = config.primaryTextColor;
    final secondaryTextColor = config.secondaryTextColor;
    final isDark = config.isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF14171F) : AppColors.canvasGradientTop,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.canvasGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      // 1. TOP HEADER (Dark slate gradient card matching design system)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0),
                        height: 140,
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF364050), Color(0xFF1B212F)],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color:
                                const Color(0xFFFCFDFF).withValues(alpha: 0.12),
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x381B212F),
                              blurRadius: 40,
                              offset: Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  config.tr('History', 'வரலாறு'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFFCFDFF),
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  config.tr(
                                    '${_projects.length} Floor Plans',
                                    '${_projects.length} தள வரைபடங்கள்',
                                  ),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 24,
                                color: Color(0xFFFCFDFF),
                              ),
                              onPressed: () {
                                setState(() => _isLoading = true);
                                _loadUserHistory();
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 2. Project List
                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFFE58A18),
                                ),
                              )
                            : _projects.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32.0),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 68,
                                            height: 68,
                                            decoration: BoxDecoration(
                                              color: config.cardColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: config.borderColor),
                                            ),
                                            child: Icon(
                                              Icons.folder_open_rounded,
                                              size: 32,
                                              color: secondaryTextColor,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            config.tr('No Projects Yet',
                                                'திட்டங்கள் எதுவும் இல்லை'),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            config.tr(
                                              'Upload your 2D floor plan to see generated 3D models and reports here.',
                                              'உருவாக்கப்பட்ட 3D மாதிரி மற்றும் அறிக்கைகளைக் காண 2D வரைபடத்தைப் பதிவேற்றவும்.',
                                            ),
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12.5,
                                              color: secondaryTextColor,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.only(
                                      left: 16,
                                      right: 16,
                                      top: 4,
                                      bottom: 120, // Floating nav room
                                    ),
                                    itemCount: _projects.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      return _buildProjectCard(
                                        _projects[index],
                                        index,
                                        config: config,
                                        isDark: isDark,
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),

                  // Bottom Gradient Fade for smooth list ending
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 90,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              isDark
                                  ? const Color(0xFF14171F)
                                  : const Color(0xFFD8DFE9),
                              (isDark
                                      ? const Color(0xFF14171F)
                                      : const Color(0xFFD8DFE9))
                                  .withValues(alpha: 0.8),
                              (isDark
                                      ? const Color(0xFF14171F)
                                      : const Color(0xFFD8DFE9))
                                  .withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
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

  // ─── Individual Project Card (NO NAVIGATION ON CLICK) ────────────────────────
  Widget _buildProjectCard(
    Map<String, dynamic> project,
    int index, {
    required AppConfigProvider config,
    required bool isDark,
  }) {
    final String amount = project['amount'] ?? '₹500';
    String rawTitle = project['name']?.toString() ?? '';
    String displayTitle = 'KI_Project ${(index + 1).toString().padLeft(2, '0')}';
    if (rawTitle.isNotEmpty &&
        !rawTitle.toLowerCase().startsWith('floor plan') &&
        !rawTitle.toLowerCase().contains('kanavuillam_report') &&
        !rawTitle.toLowerCase().contains('new project') &&
        !rawTitle.toLowerCase().startsWith('ki_project')) {
      displayTitle = rawTitle;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B212F) : const Color(0xFFFCFDFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2C3545) : const Color(0xFFE8EDF3),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141B212F),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. User Uploaded 2D Floor Plan Image Preview Thumbnail
          _build2DPlanThumbnail(project['image_url']?.toString(), isDark: isDark),

          const SizedBox(width: 12),

          // 2. Project Details + 4 Deliverable Icons (Display only, no navigation)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Title and Amount Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        displayTitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFFCFDFF)
                              : const Color(0xFF1E252D),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE58A18)
                            .withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        amount,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE58A18),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 3),

                // Row 2: Date
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: isDark
                          ? const Color(0xFF8E99A8)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      project['date'] ?? '',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF8E99A8)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Row 3: 4 Deliverable Feature Icons: [3D], [Vastu], [Cost], [Structural]
                _buildFeatureIconsRow(
                  project['features'] as List<dynamic>? ??
                      ['3d', 'vastu', 'cost', 'structural'],
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2D Floor Plan Thumbnail with "2D" Badge & Fallback Painter ──────────────
  Widget _build2DPlanThumbnail(String? imageUrl, {required bool isDark}) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFF141923),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C3545) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _resolvePlanImageWidget(imageUrl, isDark: isDark),

            // Mini "2D" badge in top-left
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B212F).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0xFFE58A18).withValues(alpha: 0.7),
                    width: 0.7,
                  ),
                ),
                child: Text(
                  '2D',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE58A18),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resolvePlanImageWidget(String? imageUrl, {required bool isDark}) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      final cleanUrl = imageUrl.trim();

      // 1. Data URI (Base64 encoded floor plan image)
      if (cleanUrl.startsWith('data:image')) {
        try {
          final commaIndex = cleanUrl.indexOf(',');
          final base64Str =
              commaIndex != -1 ? cleanUrl.substring(commaIndex + 1) : cleanUrl;
          final bytes = base64Decode(base64Str);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _buildFallbackBlueprint(isDark: isDark),
          );
        } catch (_) {}
      }

      // 2. Network image URL (HTTP or HTTPS)
      if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
        return Image.network(
          cleanUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildFallbackBlueprint(isDark: isDark),
        );
      }
    }

    // 3. Fallback: Architectural 2D Blueprint Graphic Painter
    return _buildFallbackBlueprint(isDark: isDark);
  }

  Widget _buildFallbackBlueprint({required bool isDark}) {
    return CustomPaint(
      painter: _BlueprintThumbnailPainter(),
    );
  }

  // ─── 4 Deliverable Icons: [3D], [Vastu], [Cost], [Structural] (DISPLAY ONLY) ──
  Widget _buildFeatureIconsRow(
    List<dynamic> features, {
    required bool isDark,
  }) {
    final featList = features.map((e) => e.toString().toLowerCase()).toList();
    final has3D = featList.contains('3d') || featList.isEmpty;
    final hasVastu = featList.contains('va') || featList.contains('vastu');
    final hasCost = featList.contains('₹') ||
        featList.contains('cost') ||
        featList.contains('boq');
    final hasStruct =
        featList.contains('st') || featList.contains('structural');

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 3D Villa Icon
          _buildFeatureChip(
            icon: Icons.view_in_ar_rounded,
            label: '3D',
            accentColor: const Color(0xFFE58A18),
            isEnabled: has3D,
            isDark: isDark,
          ),
          const SizedBox(width: 5),

          // 2. Vastu Shastra Icon
          _buildFeatureChip(
            icon: Icons.explore_outlined,
            label: 'Vastu',
            accentColor: const Color(0xFF10B981),
            isEnabled: hasVastu,
            isDark: isDark,
          ),
          const SizedBox(width: 5),

          // 3. Cost Estimation Icon
          _buildFeatureChip(
            icon: Icons.currency_rupee_rounded,
            label: 'Cost',
            accentColor: const Color(0xFF3B82F6),
            isEnabled: hasCost,
            isDark: isDark,
          ),
          const SizedBox(width: 5),

          // 4. Structural Engineering Icon
          _buildFeatureChip(
            icon: Icons.architecture_rounded,
            label: 'Struct',
            accentColor: const Color(0xFF8B5CF6),
            isEnabled: hasStruct,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip({
    required IconData icon,
    required String label,
    required Color accentColor,
    required bool isEnabled,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: isEnabled
            ? accentColor.withValues(alpha: isDark ? 0.16 : 0.10)
            : (isDark ? const Color(0xFF232A38) : const Color(0xFFF1F4F8)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEnabled
              ? accentColor.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0)),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12.5,
            color: isEnabled
                ? accentColor
                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isEnabled
                  ? (isDark ? const Color(0xFFFCFDFF) : const Color(0xFF1E252D))
                  : (isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8)),
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Architectural 2D Blueprint Graphic Painter ─────────────────────────
class _BlueprintThumbnailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark blueprint background
    final bgPaint = Paint()..color = const Color(0xFF151B27);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Blueprint subtle grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF222C3D)
      ..strokeWidth = 0.6;
    for (double x = 8; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 8; y < size.height; y += 10) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 3. Exterior perimeter wall
    final wallPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square;

    final wallRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      const Radius.circular(3),
    );
    canvas.drawRRect(wallRect, wallPaint);

    // 4. Interior room partition walls
    final partitionPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Horizontal partition
    canvas.drawLine(
      Offset(8, size.height * 0.52),
      Offset(size.width * 0.65, size.height * 0.52),
      partitionPaint,
    );
    // Vertical partition
    canvas.drawLine(
      Offset(size.width * 0.65, 8),
      Offset(size.width * 0.65, size.height - 8),
      partitionPaint,
    );

    // 5. Amber door swing arc
    final doorPaint = Paint()
      ..color = const Color(0xFFE58A18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(size.width * 0.36, size.height * 0.52), radius: 6),
      0,
      1.57,
      false,
      doorPaint,
    );

    // Mini blueprint marker
    final dotPaint = Paint()..color = const Color(0xFFE58A18);
    canvas.drawCircle(
        Offset(size.width * 0.36, size.height * 0.52), 1.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
