import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
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

  static final List<Map<String, dynamic>> _sampleProjects = [
    {
      'name': 'Floor Plan 01',
      'date': '12 Oct 2026',
      'features': ['3D', 'Va', '₹', 'St'],
      'amount': '₹499',
    },
    {
      'name': 'Floor Plan 02',
      'date': '28 Sep 2026',
      'features': ['3D', 'Va', '₹', 'St'],
      'amount': '₹799',
    },
    {
      'name': 'Floor Plan 03',
      'date': '15 Sep 2026',
      'features': ['3D', 'Va', '₹', 'St'],
      'amount': '₹499',
    },
    {
      'name': 'Floor Plan 04',
      'date': '02 Aug 2026',
      'features': ['3D', 'Va', '₹', 'St'],
      'amount': '₹1,299',
    },
    {
      'name': 'Floor Plan 05',
      'date': '19 Jul 2026',
      'features': ['3D', 'Va', '₹', 'St'],
      'amount': '₹499',
    },
    {
      'name': 'Floor Plan 06',
      'date': '04 Jun 2026',
      'features': ['3D', 'Va', '₹', 'St'],
      'amount': '₹899',
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
      backgroundColor: isDark ? const Color(0xFF14171F) : AppColors.canvasGradientTop,
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
                      // 1. TOP DARK HEADER (16px side margin, ~140px tall, 32px radius)
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
                                    color: Colors.white,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  config.tr(
                                    '${_projects.length} Floor Plans',
                                    '${_projects.length} தள வரைபடங்கள்',
                                  ),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                            // Subtle Refresh / Sync icon
                            IconButton(
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 22,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                setState(() => _isLoading = true);
                                _loadUserHistory();
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

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
                                      left: 16,
                                      right: 16,
                                      top: 4,
                                      bottom: 110, // Space for bottom nav
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
                            isDark ? const Color(0xFF14171F) : const Color(0xFFD8DFE9),
                            (isDark ? const Color(0xFF14171F) : const Color(0xFFD8DFE9)).withValues(alpha: 0.8),
                            (isDark ? const Color(0xFF14171F) : const Color(0xFFD8DFE9)).withValues(alpha: 0.0),
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

  Widget _buildProjectCard(
    Map<String, dynamic> project, {
    required AppConfigProvider config,
  }) {
    final String amount = project['amount'] ?? '₹499';
    final isDark = config.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2230) : const Color(0xFFFCFDFF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE9EAEC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A1B212F),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 48x48 circle #2E3744 with white icon
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF2E3744),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.grid_view_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Project Title & Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project['name'] ?? 'Floor Plan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF18191D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  project['date'] ?? '',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF8E94A0),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Amount
          Text(
            amount,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF18191D),
            ),
          ),
        ],
      ),
    );
  }
}

