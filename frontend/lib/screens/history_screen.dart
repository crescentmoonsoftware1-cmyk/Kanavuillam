import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers/app_config_provider.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const HistoryScreen({super.key, this.userData});

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

  Future<void> _loadUserHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = (widget.userData?['email'] as String?) ??
          prefs.getString('user_email');

      if (email == null || email.isEmpty || email == 'unknown') {
        if (mounted) {
          setState(() {
            _projects = [];
            _isLoading = false;
          });
        }
        return;
      }

      final fetched = await _apiService.getAllProjects(email);

      if (mounted) {
        if (fetched.isNotEmpty) {
          final mapped = fetched.map<Map<String, dynamic>>((p) {
            String rawName = p['name'] ?? 'Project';
            String displayName = rawName;
            List<String> features = ['3D', 'Va', '₹', 'St'];
            String amount = '₹500';

            if (rawName.contains('|')) {
              final parts = rawName.split('|');
              displayName = parts[0];
              if (parts.length > 1 && parts[1].isNotEmpty) {
                final reportKeys = parts[1].split(',');
                features = [];
                if (reportKeys.contains('3d')) features.add('3D');
                if (reportKeys.contains('vastu')) features.add('Va');
                if (reportKeys.contains('cost') || reportKeys.contains('boq')) {
                  features.add('₹');
                }
                if (reportKeys.contains('structural')) features.add('St');
                if (features.isEmpty) features = ['3D'];
              }
              if (parts.length > 2) {
                amount = '₹${(double.tryParse(parts[2]) ?? 500).toInt()}';
              }
            }

            final createdAt = p['created_at'] != null
                ? p['created_at'].toString().split('T').first
                : 'Recent';

            return {
              'name': displayName,
              'date': createdAt,
              'features': features,
              'amount': amount,
              'raw': p,
            };
          }).toList();

          setState(() {
            _projects = mapped;
            _isLoading = false;
          });
        } else {
          setState(() {
            _projects = [];
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _projects = [];
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

    final bgColor = config.bgColor;
    final primaryTextColor = config.primaryTextColor;
    final secondaryTextColor = config.secondaryTextColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 16.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                config.tr('History', 'வரலாறு'),
                                style: GoogleFonts.syne(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: primaryTextColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                config.tr(
                                  '${_projects.length} Downloads',
                                  '${_projects.length} பதிவிறக்கங்கள்',
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                          // Subtle Refresh / Sync icon
                          IconButton(
                            icon: Icon(
                              Icons.refresh_rounded,
                              size: 20,
                              color: secondaryTextColor,
                            ),
                            onPressed: () {
                              setState(() => _isLoading = true);
                              _loadUserHistory();
                            },
                          ),
                        ],
                      ),
                    ),

                    // Project List
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: primaryTextColor,
                              ),
                            )
                          : _projects.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32.0,
                                    ),
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
                                              color: config.borderColor,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.folder_open_rounded,
                                            size: 32,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          config.tr(
                                            'No Projects Yet',
                                            'திட்டங்கள் எதுவும் இல்லை',
                                          ),
                                          style: GoogleFonts.syne(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
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
                                          style: GoogleFonts.inter(
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
                                    left: 20,
                                    right: 20,
                                    top: 6,
                                    bottom: 120, // Breathing space for bottom nav
                                  ),
                                  itemCount: _projects.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    return _buildProjectCard(
                                      _projects[index],
                                      config: config,
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
                            bgColor,
                            bgColor.withValues(alpha: 0.8),
                            bgColor.withValues(alpha: 0.0),
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
    );
  }

  Widget _buildProjectCard(
    Map<String, dynamic> project, {
    required AppConfigProvider config,
  }) {
    final List<String> features =
        List<String>.from(project['features'] ?? ['3D']);
    final String amount = project['amount'] ?? '₹500';
    final isDark = config.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: config.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Blueprint Architectural Thumbnail
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: config.surfacePillColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: CustomPaint(
              painter: _BlueprintThumbPainter(
                color: config.primaryTextColor,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Project Title & Badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project['name'] ?? 'Floor Plan',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: config.primaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  project['date'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: config.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: features
                      .map((f) => _buildFeatureBadge(f, config: config))
                      .toList(),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Amount Spent Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                config.tr('Spent', 'செலவு'),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: config.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                amount,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: config.primaryTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(
    String label, {
    required AppConfigProvider config,
  }) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: config.surfacePillColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: config.primaryTextColor,
        ),
      ),
    );
  }
}

// Custom Painter for the architectural blueprint thumbnail icon
class _BlueprintThumbPainter extends CustomPainter {
  final Color color;
  const _BlueprintThumbPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);

    // Outer architectural boundary rect
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 3, 34, 34),
        const Radius.circular(3),
      ),
      paint..strokeWidth = 1.8,
    );

    // Floor plan inner grid lines
    canvas.drawLine(const Offset(3, 20), const Offset(37, 20), paint);
    canvas.drawLine(const Offset(18, 3), const Offset(18, 20), paint);
    canvas.drawLine(const Offset(28, 20), const Offset(28, 37), paint);
    canvas.drawCircle(const Offset(8, 28), 1.5, Paint()..color = color);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BlueprintThumbPainter oldDelegate) =>
      oldDelegate.color != color;
}
