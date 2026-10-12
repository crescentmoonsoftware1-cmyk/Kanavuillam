import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';

class VastuScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  final void Function(int tabIndex)? onNavigateToTab;
  final VoidCallback? onNavigateToNext;
  final VoidCallback? onBack;

  const VastuScreen({
    super.key,
    required this.projectData,
    this.onNavigateToTab,
    this.onNavigateToNext,
    this.onBack,
  });

  @override
  State<VastuScreen> createState() => _VastuScreenState();
}

class _VastuScreenState extends State<VastuScreen> {
  int _currentSubTab = 0; // 0: Score, 1: Rooms, 2: Fixes & Analysis
  int _analysisFilter = 0; // 0: All, 1: Strengths, 2: Violations, 3: Fixes

  late Future<Map<String, dynamic>> _vastuFuture;
  final Map<String, Map<String, dynamic>> _resultsCache = {};

  @override
  void initState() {
    super.initState();
    final initialVastu =
        widget.projectData['vastu_data'] ?? widget.projectData['_vastu'];
    if (initialVastu != null) {
      _resultsCache['EN'] = Map<String, dynamic>.from(initialVastu);
      _vastuFuture = Future.value(_resultsCache['EN']);
    } else {
      _vastuFuture = _fetchVastuData('EN');
    }
  }

  Future<Map<String, dynamic>> _fetchVastuData(String lang) async {
    try {
      final res = await ApiService().analyzeVastu(
        widget.projectData['id']?.toString() ?? 'demo',
        lang: lang == 'TA' ? 'Tamil' : 'English',
      );
      _resultsCache[lang] = res;
      return res;
    } catch (_) {
      final fallback = _getFallbackData(lang);
      _resultsCache[lang] = fallback;
      return fallback;
    }
  }

  Map<String, dynamic> _getFallbackData(String lang) {
    final isTamil = lang == 'TA';
    return {
      'score': 65,
      'grade': 'B',
      'orientation': 'North',
      'strengths': isTamil
          ? [
              'முதன்மை வாயில் ஈசான்யத்தில் (வடகிழக்கு) நேர்மறை ஆற்றலை ஈர்க்கிறது.',
              'சமையலறை ஆக்னேயத்தில் (தென்கிழக்கு) அக்னி மூலையில் சரியான அமைப்பில் உள்ளது.',
              'வரவேற்பறை மற்றும் காற்று சுழற்சி பிரம்மஸ்தானத்தை ஒட்டி திறந்துள்ளது.'
            ]
          : [
              'Main entrance in North-East (Ishanya) harnesses positive solar magnetic prana.',
              'Kitchen positioned in South-East (Agni) fire corner for digestive vitality.',
              'Living area open layout promotes unhindered air circulation and natural lighting.'
            ],
      'violations': isTamil
          ? [
              'முதன்மை படுக்கையறை வடகிழக்கில் உள்ளது (தென்மேற்கிற்கு உகந்தது).',
              'பூஜை அறை தென்கிழக்கு அக்னி மூலையில் உள்ளது (ஈசான்யத்திற்கு உகந்தது).',
              'படிக்கட்டு சுழற்சி எதிர்-கடிகார திசையில் அமைந்துள்ளது.'
            ]
          : [
              'Master bedroom in North-East (violates South-West gravitational earth anchor).',
              'Pooja room placed in South-East fire zone (should be in North-East Ishanya).',
              'Staircase risers follow anti-clockwise flow creating energy resistance.'
            ],
      'whyPointsReduced': isTamil
          ? [
              'படுக்கையறை தவறான திசை: 15 புள்ளிகள் குறைப்பு (-15 pts)',
              'பூஜை அறை அக்னி மூலையில்: 10 புள்ளிகள் குறைப்பு (-10 pts)',
              'படிக்கட்டு சுழற்சி அமைப்பு: 10 புள்ளிகள் குறைப்பு (-10 pts)'
            ]
          : [
              'Master bedroom incorrect zone: -15 points deduction',
              'Pooja room in fire quadrant: -10 points deduction',
              'Staircase anti-clockwise flow: -10 points deduction'
            ],
      'rooms': [
        {
          'title': isTamil ? 'வரவேற்பறை' : 'Living Room',
          'subtitle': 'North-West',
          'isCorrect': true,
          'icon': Icons.chair,
          'analysis': isTamil
              ? ['சரியான வாஸ்து அமைவிடம்', 'நேர்மறை ஆற்றலை ஈர்க்கிறது', 'நல்வாழ்விற்கு உகந்தது']
              : ['Perfect Vastu placement', 'Enhances positive energy', 'Optimal for well-being']
        },
        {
          'title': isTamil ? 'சமையலறை' : 'Kitchen',
          'subtitle': 'South-East',
          'isCorrect': true,
          'icon': Icons.local_fire_department,
          'analysis': isTamil
              ? ['அக்னி மூலை - உகந்த அமைவிடம்', 'ஆரோக்கியத்தை மேம்படுத்துகிறது', 'காலை சூரிய ஒளி பயன்']
              : ['Ideal Agni fire corner', 'Improves digestion & health', 'Harnesses morning solar rays']
        },
        {
          'title': isTamil ? 'கழிவறை' : 'Bathroom',
          'subtitle': 'North-West',
          'isCorrect': true,
          'icon': Icons.bathtub,
          'analysis': isTamil
              ? ['வாயு மூலை சரியான இடம்', 'கழிவுகளை வெளியேற்ற உகந்தது', 'துர்நாற்றம் பரவாது']
              : ['Vayu wind zone alignment', 'Optimal waste elimination', 'No damp stagnation']
        },
        {
          'title': isTamil ? 'முதன்மை படுக்கையறை' : 'Master Bedroom',
          'subtitle': 'North-East',
          'isCorrect': false,
          'icon': Icons.bed,
          'analysis': isTamil
              ? ['கடுமையான வாஸ்து குறைபாடு', 'தென்மேற்கிற்கு மாற்ற வேண்டும்', 'மன அமைதியின்மை ஏற்படும்']
              : ['Severe Vastu violation', 'Heavy load in spiritual zone', 'Weakens decisions & finances']
        },
        {
          'title': isTamil ? 'பூஜை அறை' : 'Pooja Room',
          'subtitle': 'South-East',
          'isCorrect': false,
          'icon': Icons.wb_sunny,
          'analysis': isTamil
              ? ['அக்னி மூலையில் அமைத்தல் கூடாது', 'வடகிழக்கு ஈசான்யத்திற்கு மாற்றவும்', 'மனஅமைதி பாதிக்கும்']
              : ['Wrong fire placement for worship', 'Shift to North-East Ishanya', 'Spiritual disturbance']
        },
      ],
      'fixes': [
        {
          'number': '1',
          'issue': isTamil ? 'முதன்மை படுக்கையறை வடகிழக்கில் உள்ளது' : 'Master bedroom in North-East',
          'fix': isTamil ? 'பூஜை அல்லது படிப்பு அறையாக மாற்றவும்' : 'Convert to prayer or study space',
          'points': '+15 pts',
          'border': true,
        },
        {
          'number': '2',
          'issue': isTamil ? 'படுக்கை வடகிழக்கு நோக்கி உள்ளது' : 'Bed frame in North-East',
          'fix': isTamil ? 'படுக்கையை தென்மேற்கு நோக்கி நகர்த்தவும்' : 'Move bed to South-West',
          'points': '+8 pts',
          'border': true,
        },
        {
          'number': '3',
          'issue': isTamil ? 'பூஜை அறை தென்கிழக்கில் உள்ளது' : 'Pooja room in South-East',
          'fix': isTamil ? 'பூஜை அறையை வடகிழக்கிற்கு மாற்றவும்' : 'Shift pooja to North-East',
          'points': '+10 pts',
          'border': true,
        },
        {
          'number': '4',
          'issue': isTamil ? 'திசை ஆற்றல் முரண்பாடுகள்' : 'Quadrant energy conflicts',
          'fix': isTamil ? 'வாஸ்து பிரமிடு அல்லது படிகங்களை பொருத்தவும்' : 'Install Vastu pyramids on site',
          'points': '+2 pts',
          'border': false,
        },
      ]
    };
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>();
    final isTamil = config.isTamil;
    final langKey = isTamil ? 'TA' : 'EN';

    const String planName = 'kanavuillam_report';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _vastuFuture,
          builder: (context, snapshot) {
            final data = snapshot.data ?? _getFallbackData(langKey);

            final int score = (data['score'] is num) ? (data['score'] as num).toInt() : 65;
            final String grade = data['grade']?.toString() ?? 'B';
            final String orientation = data['orientation']?.toString() ?? 'North';
            final int pointsLost = 100 - score;

            final List strengths = (data['strengths'] is List && (data['strengths'] as List).isNotEmpty)
                ? (data['strengths'] as List)
                : (_getFallbackData(langKey)['strengths'] as List);

            final List violations = (data['violations'] is List && (data['violations'] as List).isNotEmpty)
                ? (data['violations'] as List)
                : (_getFallbackData(langKey)['violations'] as List);

            final List whyPointsReduced = (data['whyPointsReduced'] is List && (data['whyPointsReduced'] as List).isNotEmpty)
                ? (data['whyPointsReduced'] as List)
                : (data['negativePoints'] is List && (data['negativePoints'] as List).isNotEmpty
                    ? (data['negativePoints'] as List)
                    : (_getFallbackData(langKey)['whyPointsReduced'] as List));

            final List rooms = (data['rooms'] is List && (data['rooms'] as List).isNotEmpty)
                ? (data['rooms'] as List)
                : (_getFallbackData(langKey)['rooms'] as List);

            final List fixes = (data['fixes'] is List && (data['fixes'] as List).isNotEmpty)
                ? (data['fixes'] as List)
                : (_getFallbackData(langKey)['fixes'] as List);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 14.0,
                    bottom: 14.0,
                  ),
                  child: Column(
                    children: [
                      // ── 1. HEADER ─────────────────────────────────────────
                      SizedBox(
                        height: 52,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    planName,
                                    style: GoogleFonts.syne(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                      letterSpacing: -0.2,
                                      height: 1.0,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isTamil ? 'வாஸ்து அறிக்கை' : 'Vastu report',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Language Capsule
                            Container(
                              height: 34,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (isTamil) {
                                        config.setTamil(false);
                                        setState(() {
                                          _vastuFuture = _fetchVastuData('EN');
                                        });
                                      }
                                    },
                                    child: Container(
                                      height: 30,
                                      padding: const EdgeInsets.symmetric(horizontal: 11),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: !isTamil ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(100),
                                        boxShadow: !isTamil
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.primary.withValues(alpha: 0.05),
                                                  blurRadius: 2,
                                                  offset: const Offset(0, 1),
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        'EN',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: !isTamil ? FontWeight.w600 : FontWeight.w400,
                                          color: !isTamil ? AppColors.textDark : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      if (!isTamil) {
                                        config.setTamil(true);
                                        setState(() {
                                          _vastuFuture = _fetchVastuData('TA');
                                        });
                                      }
                                    },
                                    child: Container(
                                      height: 30,
                                      padding: const EdgeInsets.symmetric(horizontal: 11),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isTamil ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(100),
                                        boxShadow: isTamil
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.primary.withValues(alpha: 0.05),
                                                  blurRadius: 2,
                                                  offset: const Offset(0, 1),
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        'தமிழ்',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: isTamil ? FontWeight.w600 : FontWeight.w400,
                                          color: isTamil ? AppColors.textDark : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── 2. MAIN TABS (3D, Vastu, Cost, Structure, Download) ─────────
                      SizedBox(
                        height: 36,
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildMainTab(
                                title: '3D',
                                isActive: false,
                                onTap: () => widget.onNavigateToTab?.call(1),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildMainTab(
                                title: isTamil ? 'வாஸ்து' : 'Vastu',
                                isActive: true,
                                onTap: () {},
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildMainTab(
                                title: isTamil ? 'செலவு' : 'Cost',
                                isActive: false,
                                onTap: () => widget.onNavigateToTab?.call(3),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildMainTab(
                                title: isTamil ? 'அமைப்பு' : 'Structure',
                                isActive: false,
                                onTap: () => widget.onNavigateToTab?.call(4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildMainTab(
                                title: isTamil ? 'பதிவிறக்கம்' : 'Download',
                                isActive: false,
                                onTap: () => widget.onNavigateToTab?.call(5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── 3. SUB TABS (Score, Rooms, Fixes & Analysis) ──────
                      SizedBox(
                        height: 42,
                        child: Stack(
                          children: [
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(height: 1, color: AppColors.border),
                            ),
                            Row(
                              children: [
                                _buildSubTab(
                                  title: isTamil ? 'மதிப்பெண்' : 'Score',
                                  isActive: _currentSubTab == 0,
                                  onTap: () => setState(() => _currentSubTab = 0),
                                ),
                                _buildSubTab(
                                  title: isTamil ? 'அறைகள்' : 'Rooms',
                                  isActive: _currentSubTab == 1,
                                  onTap: () => setState(() => _currentSubTab = 1),
                                ),
                                _buildSubTab(
                                  title: isTamil ? 'பரிகாரங்கள்' : 'Fixes',
                                  isActive: _currentSubTab == 2,
                                  onTap: () => setState(() => _currentSubTab = 2),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── 4. CONTENT AREA (White Rounded Card with Full Height) ──
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.06),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _buildSubTabContent(
                            subTab: _currentSubTab,
                            score: score,
                            grade: grade,
                            orientation: orientation,
                            pointsLost: pointsLost,
                            strengths: strengths,
                            violations: violations,
                            whyPointsReduced: whyPointsReduced,
                            rooms: rooms,
                            fixes: fixes,
                            isTamil: isTamil,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── SUBTAB BUILDERS ────────────────────────────────────────────────────────

  Widget _buildSubTabContent({
    required int subTab,
    required int score,
    required String grade,
    required String orientation,
    required int pointsLost,
    required List strengths,
    required List violations,
    required List whyPointsReduced,
    required List rooms,
    required List fixes,
    required bool isTamil,
  }) {
    switch (subTab) {
      case 1:
        return _buildRoomsView(rooms, isTamil);
      case 2:
        return _buildFixesAndAnalysisView(
          strengths: strengths,
          violations: violations,
          whyPointsReduced: whyPointsReduced,
          fixes: fixes,
          score: score,
          isTamil: isTamil,
        );
      case 0:
      default:
        return _buildScoreView(
          score: score,
          grade: grade,
          orientation: orientation,
          pointsLost: pointsLost,
          whyPointsReduced: whyPointsReduced,
          isTamil: isTamil,
        );
    }
  }

  // ── 1. SCORE SUBTAB (Crystal Clear Display, NO Overflow, NO Cutoff) ────────
  Widget _buildScoreView({
    required int score,
    required String grade,
    required String orientation,
    required int pointsLost,
    required List whyPointsReduced,
    required bool isTamil,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Orientation Row with Expanded (Fixed 22px Overflow!)
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.explore, size: 20, color: Colors.black),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$orientation Facing',
                      style: GoogleFonts.syne(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTamil ? 'வீட்டின் திசை அமைப்பு' : 'House orientation',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  orientation,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 16),

          // Crystal Clear Score Hero Section (NO Clipping!)
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      score.toString(),
                      style: GoogleFonts.syne(
                        fontSize: 54,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        height: 1.0,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/100',
                      style: GoogleFonts.syne(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Grade $grade',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (score / 100.0).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Container(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 16),

          // Points Reduced Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isTamil ? 'மதிப்பெண் குறைவு' : 'Score reduced',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '-$pointsLost points',
                  style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (whyPointsReduced.isNotEmpty)
            ...whyPointsReduced.map(
              (pt) => Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: _buildReasonRow(Icons.remove_circle_outline, pt.toString()),
              ),
            )
          else
            _buildReasonRow(
              Icons.check_circle,
              isTamil ? 'எந்த பெரிய குறைபாடும் இல்லை!' : 'No severe issues found!',
            ),
        ],
      ),
    );
  }

  // ── 2. ROOMS SUBTAB ────────────────────────────────────────────────────────
  Widget _buildRoomsView(List rooms, bool isTamil) {
    final int correctCount = rooms.where((r) => r is Map && r['isCorrect'] == true).length;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isTamil ? 'அறைகள் ஆய்வு' : 'Room audit',
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            Text(
              isTamil
                  ? '$correctCount / ${rooms.length} சரியானது'
                  : '$correctCount of ${rooms.length} correct',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              final r = rooms[i] as Map;
              final String title = r['title']?.toString() ?? 'Room';
              final String subtitle = r['subtitle']?.toString() ?? '';
              final bool isCorrect = r['isCorrect'] == true;
              final IconData icon = (r['icon'] is IconData) ? r['icon'] as IconData : Icons.meeting_room;
              final List analysis = (r['analysis'] is List) ? (r['analysis'] as List) : [];

              return _buildRoomRow(
                context: context,
                icon: icon,
                title: title,
                subtitle: subtitle,
                isCorrect: isCorrect,
                border: i < rooms.length - 1,
                analysisList: analysis,
                isTamil: isTamil,
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 3. FIXES & COMPREHENSIVE ANALYSIS (Strengths, Violations, Points, Fixes) ──
  Widget _buildFixesAndAnalysisView({
    required List strengths,
    required List violations,
    required List whyPointsReduced,
    required List fixes,
    required int score,
    required bool isTamil,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Pills: All | Strengths | Violations | Fixes
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip(
                label: isTamil ? 'அனைத்தும்' : 'All',
                isSelected: _analysisFilter == 0,
                onTap: () => setState(() => _analysisFilter = 0),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: isTamil ? 'பலங்கள் (${strengths.length})' : 'Strengths (${strengths.length})',
                isSelected: _analysisFilter == 1,
                onTap: () => setState(() => _analysisFilter = 1),
                color: const Color(0xFF059669),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: isTamil ? 'குறைபாடுகள் (${violations.length})' : 'Violations (${violations.length})',
                isSelected: _analysisFilter == 2,
                onTap: () => setState(() => _analysisFilter = 2),
                color: const Color(0xFFDC2626),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: isTamil ? 'பரிகாரங்கள் (${fixes.length})' : 'Fixes (${fixes.length})',
                isSelected: _analysisFilter == 3,
                onTap: () => setState(() => _analysisFilter = 3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Content Area based on Filter
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              // 1. STRENGTHS SECTION
              if (_analysisFilter == 0 || _analysisFilter == 1) ...[
                _buildSectionHeader(
                  title: isTamil ? 'முக்கிய பலங்கள்' : 'Key Strengths',
                  badge: '${strengths.length}',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF059669),
                ),
                const SizedBox(height: 8),
                ...strengths.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF059669),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.primary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 14),
              ],

              // 2. VIOLATIONS SECTION
              if (_analysisFilter == 0 || _analysisFilter == 2) ...[
                _buildSectionHeader(
                  title: isTamil ? 'வாஸ்து குறைபாடுகள்' : 'Violations',
                  badge: '${violations.length}',
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFDC2626),
                ),
                const SizedBox(height: 8),
                ...violations.map(
                  (v) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            v.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.primary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 14),
              ],

              // 3. POINTS REDUCTION BREAKDOWN
              if (_analysisFilter == 0 || _analysisFilter == 2) ...[
                _buildSectionHeader(
                  title: isTamil ? 'மதிப்பெண் குறைந்த காரணங்கள்' : 'Why Points Reduced',
                  badge: '-${100 - score} pts',
                  icon: Icons.trending_down_rounded,
                  color: const Color(0xFFB45309),
                ),
                const SizedBox(height: 8),
                ...whyPointsReduced.map(
                  (pt) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFB45309),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pt.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.primary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 14),
              ],

              // 4. FIXES & SUGGESTIONS SECTION
              if (_analysisFilter == 0 || _analysisFilter == 3) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader(
                      title: isTamil ? 'பரிகாரங்கள் & தீர்வுகள்' : 'Suggestions & Fixes',
                      badge: '${fixes.length}',
                      icon: Icons.lightbulb_outline_rounded,
                      color: AppColors.primary,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '$score → 100',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...fixes.asMap().entries.map((entry) {
                  final i = entry.key;
                  final f = entry.value as Map;
                  final String number = f['number']?.toString() ?? '${i + 1}';
                  final String issue = f['issue']?.toString() ?? '';
                  final String fix = f['fix']?.toString() ?? '';
                  final String points = f['points']?.toString() ?? '';

                  return _buildFixRow(
                    number: number,
                    issue: issue,
                    fix: fix,
                    points: points,
                    border: i < fixes.length - 1,
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── HELPER WIDGETS ─────────────────────────────────────────────────────────

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? AppColors.primary)
              : AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String badge,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 7),
        Text(
          title,
          style: GoogleFonts.syne(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            badge,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainTab({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isActive ? null : onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(100),
          boxShadow: isActive
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            maxLines: 1,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubTab({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
            if (isActive)
              Positioned(
                bottom: 0,
                left: 16,
                right: 16,
                child: Container(height: 2, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.surfaceSecondary,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: Colors.black),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isCorrect,
    required bool border,
    required List analysisList,
    required bool isTamil,
  }) {
    return InkWell(
      onTap: () {
        _showRoomDetailBottomSheet(
          context: context,
          title: title,
          subtitle: subtitle,
          isCorrect: isCorrect,
          analysisList: analysisList,
          isTamil: isTamil,
        );
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: Colors.black),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCorrect)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check, size: 12, color: Colors.black),
                            const SizedBox(width: 3),
                            Text(
                              isTamil ? 'சரியானது' : 'Correct',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          isTamil ? 'தவறானது' : 'Wrong',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (border) Container(height: 1, color: AppColors.borderLight),
        ],
      ),
    );
  }

  void _showRoomDetailBottomSheet({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isCorrect,
    required List analysisList,
    required bool isTamil,
  }) {
    final List defaultAnalysis = isCorrect
        ? (isTamil
            ? ['சரியான வாஸ்து அமைவிடம்', 'நேர்மறை ஆற்றலை ஈர்க்கிறது', 'நல்வாழ்விற்கு உகந்தது']
            : ['Perfect Vastu placement', 'Enhances positive energy', 'Optimal for well-being'])
        : (isTamil
            ? ['கடுமையான வாஸ்து குறைபாடு', 'ஆற்றல் தடையை ஏற்படுத்துகிறது', 'பரிகாரங்கள் தேவை']
            : ['Severe Vastu violation', 'Causes restlessness', 'Weakens decisions & finances']);

    final items = analysisList.isNotEmpty ? analysisList : defaultAnalysis;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          padding: const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.syne(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!isCorrect)
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEEEEEE),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '!',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                  height: 1.0,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceSecondary,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.black,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$subtitle · ${isCorrect ? (isTamil ? 'சரியானது' : 'Correct') : (isTamil ? 'தவறானது' : 'Wrong')}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Analysis List
              Column(
                children: items.map<Widget>((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Action Button
              InkWell(
                onTap: () => Navigator.pop(ctx),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isTamil ? 'புரிந்தது' : 'Got it',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFixRow({
    required String number,
    required String issue,
    required String fix,
    required String points,
    required bool border,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            issue,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (points.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              points,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF065F46),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      fix,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (border) Container(height: 1, color: AppColors.borderLight),
      ],
    );
  }
}
