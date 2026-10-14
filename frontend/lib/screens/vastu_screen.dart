import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decor.dart';
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
  int _currentSubTab = 0; // 0: Score, 1: Rooms, 2: Fixes
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
      'orientation': widget.projectData['orientation'] ?? 'East',
      'strengths': isTamil
          ? [
              'முதன்மை வாயில் 3-வது பாதத்தில் (இந்திரன்) சாதகமாக அமைந்துள்ளது.',
              'பூஜை அறை வடகிழக்கு ஈசான்ய பகுதியில் நேர்த்தியாக அமைந்துள்ளது.',
              'அறைகளின் இட ஒதுக்கீடு முக்கிய வாஸ்து விகிதாச்சாரங்களுடன் பொருந்துகிறது.'
            ]
          : [
              'Main entrance located in favorable 3rd Pada (Indra)',
              'Puja room aligned to pristine North-East quadrant',
              'Spatial room allocation aligns with core Vastu proportions'
            ],
      'violations': isTamil
          ? [
              'கழிவுநீர்த் தொட்டி பிரம்மஸ்தான சுற்றளவோடு மோதுகிறது.',
              'முதன்மை படுக்கையறை வடகிழக்கில் உள்ளது (அக்னி/வருண முரண்பாடு).',
              'சமையலறை மூழ்கி மற்றும் சமையல் அடுப்பு அருகில் வைக்கப்பட்டுள்ளது.',
              'முக்கிய படிக்கட்டு நுழைவாயிலுக்கு அருகில் எதிர்-கடிகார திசையில் சுழல்கிறது.',
              'வடகிழக்கு மண்டலத்தில் கனரக மரச்சாமான்கள் வைக்கப்பட்டுள்ளன.'
            ]
          : [
              'Septic tank positioning clashes with Brahmasthan perimeter',
              'Master bedroom located in North-East (Agni/Varuna clash)',
              'Kitchen sink and cooking stove placed adjacent',
              'Main staircase rotating anti-clockwise near foyer',
              'Heavy furniture placed in the North-East zone'
            ],
      'whyPointsReduced': isTamil
          ? [
              'படுக்கையறை தவறான திசை: 15 புள்ளிகள் குறைப்பு (-15 pts)',
              'பூஜை அறை அக்னி மூலையில்: 10 புள்ளிகள் குறைப்பு (-10 pts)',
              'படிக்கட்டு சுழற்சி அமைப்பு: 10 புள்ளிகள் குறைப்பு (-10 pts)'
            ]
          : [
              'Master bedroom located in North-East (Agni/Varuna clash)',
              'Kitchen sink and cooking stove placed adjacent',
              'Main staircase rotating anti-clockwise near foyer'
            ],
      'rooms': [
        {
          'title': isTamil ? 'வரவேற்பறை' : 'Living Room',
          'subtitle': 'North-West',
          'isCorrect': true,
          'icon': Icons.chair_outlined,
          'analysis': isTamil
              ? ['சரியான வாஸ்து அமைவிடம்', 'நேர்மறை ஆற்றலை ஈர்க்கிறது', 'நல்வாழ்விற்கு உகந்தது']
              : ['Perfect Vastu placement', 'Enhances positive energy', 'Optimal for well-being']
        },
        {
          'title': isTamil ? 'சமையலறை' : 'Kitchen',
          'subtitle': 'South-East',
          'isCorrect': true,
          'icon': Icons.local_fire_department_outlined,
          'analysis': isTamil
              ? ['அக்னி மூலை - உகந்த அமைவிடம்', 'ஆரோக்கியத்தை மேம்படுத்துகிறது', 'காலை சூரிய ஒளி பயன்']
              : ['Ideal Agni fire corner', 'Improves digestion & health', 'Harnesses morning solar rays']
        },
        {
          'title': isTamil ? 'கழிவறை' : 'Bathroom',
          'subtitle': 'North-West',
          'isCorrect': true,
          'icon': Icons.bathtub_outlined,
          'analysis': isTamil
              ? ['வாயு மூலை சரியான இடம்', 'கழிவுகளை வெளியேற்ற உகந்தது', 'துர்நாற்றம் பரவாது']
              : ['Vayu wind zone alignment', 'Optimal waste elimination', 'No damp stagnation']
        },
        {
          'title': isTamil ? 'முதன்மை படுக்கையறை' : 'Master Bedroom',
          'subtitle': 'North-East',
          'isCorrect': false,
          'icon': Icons.bed_outlined,
          'analysis': isTamil
              ? ['கடுமையான வாஸ்து குறைபாடு', 'தென்மேற்கிற்கு மாற்ற வேண்டும்', 'மன அமைதியின்மை ஏற்படும்']
              : ['Severe Vastu violation', 'Heavy load in spiritual zone', 'Weakens decisions & finances']
        },
        {
          'title': isTamil ? 'பூஜை அறை' : 'Pooja Room',
          'subtitle': 'South-East',
          'isCorrect': false,
          'icon': Icons.wb_sunny_outlined,
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
        },
        {
          'number': '2',
          'issue': isTamil ? 'படுக்கை வடகிழக்கு நோக்கி உள்ளது' : 'Bed frame in North-East',
          'fix': isTamil ? 'படுக்கையை தென்மேற்கு நோக்கி நகர்த்தவும்' : 'Move bed to South-West quadrant',
          'points': '+8 pts',
        },
        {
          'number': '3',
          'issue': isTamil ? 'பூஜை அறை தென்கிழக்கில் உள்ளது' : 'Pooja room in South-East',
          'fix': isTamil ? 'பூஜை அறையை வடகிழக்கிற்கு மாற்றவும்' : 'Shift pooja altar to North-East',
          'points': '+10 pts',
        },
        {
          'number': '4',
          'issue': isTamil ? 'திசை ஆற்றல் முரண்பாடுகள்' : 'Quadrant energy conflicts',
          'fix': isTamil ? 'வாஸ்து பிரமிடு அல்லது படிகங்களை பொருத்தவும்' : 'Install Vastu brass pyramid energy studs',
          'points': '+2 pts',
        },
      ]
    };
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>();
    final isTamil = config.isTamil;
    final langKey = isTamil ? 'TA' : 'EN';
    final planName = widget.projectData['name']?.toString() ?? 'kanavuillam_report';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.canvasGradient,
        ),
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _vastuFuture,
            builder: (context, snapshot) {
              final data = snapshot.data ?? _getFallbackData(langKey);

              final int score = (data['score'] is num) ? (data['score'] as num).toInt() : 65;
              final String grade = data['grade']?.toString() ?? 'B';
              final String orientation = data['orientation']?.toString() ?? widget.projectData['orientation']?.toString() ?? 'East';
              final int pointsLost = 100 - score;

              final List strengths = (data['strengths'] is List && (data['strengths'] as List).isNotEmpty)
                  ? (data['strengths'] as List)
                  : (_getFallbackData(langKey)['strengths'] as List);

              final List violations = (data['violations'] is List && (data['violations'] as List).isNotEmpty)
                  ? (data['violations'] as List)
                  : (_getFallbackData(langKey)['violations'] as List);

              final List whyPointsReduced = (data['whyPointsReduced'] is List && (data['whyPointsReduced'] as List).isNotEmpty)
                  ? (data['whyPointsReduced'] as List)
                  : (_getFallbackData(langKey)['whyPointsReduced'] as List);

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
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── 1. HEADER ROW ─────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      planName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.inkPrimary,
                                        letterSpacing: -0.3,
                                        height: 1.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isTamil ? 'வாஸ்து அறிக்கை' : 'Vastu report',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.inkQuiet,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Language Toggle Capsule
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
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
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: !isTamil ? AppColors.inkDark : Colors.transparent,
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                        child: Text(
                                          'EN',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: !isTamil ? Colors.white : AppColors.inkMuted,
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
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isTamil ? AppColors.inkDark : Colors.transparent,
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                        child: Text(
                                          'தமிழ்',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isTamil ? Colors.white : AppColors.inkMuted,
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

                        // ── 2. MAIN TABS ROW (3D, Vastu, Cost, Structure, Download) ──
                        SizedBox(
                          height: 34,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              _buildMainTabChip(
                                title: '3D',
                                isActive: false,
                                onTap: () => widget.onNavigateToTab?.call(1),
                              ),
                              const SizedBox(width: 6),
                              _buildMainTabChip(
                                title: isTamil ? 'வாஸ்து' : 'Vastu',
                                isActive: true,
                                onTap: () {},
                              ),
                              const SizedBox(width: 6),
                              _buildMainTabChip(
                                title: isTamil ? 'செலவு' : 'Cost',
                                isActive: false,
                                onTap: () => widget.onNavigateToTab?.call(3),
                              ),
                              const SizedBox(width: 6),
                              _buildMainTabChip(
                                title: isTamil ? 'அமைப்பு' : 'Structure',
                                isActive: false,
                                onTap: () => widget.onNavigateToTab?.call(4),
                              ),
                              const SizedBox(width: 6),
                              _buildMainTabChip(
                                title: isTamil ? 'பதிவிறக்கம்' : 'Download',
                                isActive: false,
                                onTap: () => widget.onNavigateToTab?.call(5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ── 3. SUB TABS CAPSULE (Score, Rooms, Fixes) ─────────
                        Container(
                          height: 48,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              _buildSubTabItem(
                                index: 0,
                                title: isTamil ? 'மதிப்பெண்' : 'Score',
                                icon: Icons.explore_outlined,
                                isActive: _currentSubTab == 0,
                              ),
                              _buildSubTabItem(
                                index: 1,
                                title: isTamil ? 'அறைகள்' : 'Rooms',
                                icon: Icons.grid_view_outlined,
                                isActive: _currentSubTab == 1,
                              ),
                              _buildSubTabItem(
                                index: 2,
                                title: isTamil ? 'பரிகாரங்கள்' : 'Fixes',
                                icon: Icons.build_outlined,
                                isActive: _currentSubTab == 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── 4. CONTENT CARD (Radius 28, Elevated Card) ────────
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: AppColors.borderLight),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x141B212F),
                                  blurRadius: 32,
                                  offset: Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
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
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── SUBTAB CAPSULE BUTTON ──────────────────────────────────────────────────
  Widget _buildSubTabItem({
    required int index,
    required String title,
    required IconData icon,
    required bool isActive,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentSubTab = index),
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? AppColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x141B212F),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: isActive ? AppColors.inkPrimary : AppColors.inkMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      color: isActive ? AppColors.inkPrimary : AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
              if (isActive) ...[
                const SizedBox(height: 2),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.amberDefault,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── MAIN TAB CHIP ──────────────────────────────────────────────────────────
  Widget _buildMainTabChip({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.inkDark : AppColors.card,
          borderRadius: BorderRadius.circular(100),
          border: isActive ? null : Border.all(color: AppColors.borderLight),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x141B212F),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }

  // ── SUBTAB CONTENT SWITCHER ────────────────────────────────────────────────
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
        return _buildFixesView(
          strengths: strengths,
          violations: violations,
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

  // ── 1. SCORE SUBTAB (1:1 with Stitch Prototype) ───────────────────────────
  Widget _buildScoreView({
    required int score,
    required String grade,
    required String orientation,
    required int pointsLost,
    required List whyPointsReduced,
    required bool isTamil,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Orientation Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$orientation Facing',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isTamil ? 'வீட்டின் திசை அமைப்பு' : 'House orientation',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.inkQuiet,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.canvasGradientTop,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          orientation,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Big Score: 65 / 100 with Grade B
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            score.toString(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkPrimary,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/100',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkQuiet,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.inkDark,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'Grade $grade',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Amber Progress Bar
                  Container(
                    width: double.infinity,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (score / 100.0).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.amberGradient,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Score Reduced Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isTamil ? 'மதிப்பெண் குறைவு' : 'Score reduced',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.amberTint,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            '-$pointsLost points',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.amberDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Numbered Reason Rows
                  ...whyPointsReduced.asMap().entries.map((entry) {
                    final int idx = entry.key + 1;
                    final String text = entry.value.toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: AppColors.canvasGradientTop,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              idx.toString(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              text,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.inkPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Bottom Amber CTA Button
          AppDecor.primaryPillButton(
            text: isTamil ? 'பரிகாரங்களை காண்க' : 'View Fixes',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => setState(() => _currentSubTab = 2),
          ),
        ],
      ),
    );
  }

  // ── 2. ROOMS SUBTAB (1:1 with Stitch Prototype) ───────────────────────────
  Widget _buildRoomsView(List rooms, bool isTamil) {
    final int correctCount = rooms.where((r) => r is Map && r['isCorrect'] == true).length;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isTamil ? 'அறைகள் ஆய்வு' : 'Room audit',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkPrimary,
                ),
              ),
              Text(
                isTamil
                    ? '$correctCount / ${rooms.length} சரியானது'
                    : '$correctCount of ${rooms.length} correct',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkReading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, i) {
                final r = rooms[i] as Map;
                final String title = r['title']?.toString() ?? 'Room';
                final String subtitle = r['subtitle']?.toString() ?? '';
                final bool isCorrect = r['isCorrect'] == true;
                final IconData icon = (r['icon'] is IconData) ? r['icon'] as IconData : Icons.meeting_room_outlined;
                final List analysis = (r['analysis'] is List) ? (r['analysis'] as List) : [];

                return InkWell(
                  onTap: () {
                    _showRoomDetailBottomSheet(
                      context: context,
                      title: title,
                      subtitle: subtitle,
                      isCorrect: isCorrect,
                      analysisList: analysis,
                      isTamil: isTamil,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      children: [
                        // Icon circle
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: AppColors.canvasGradientTop,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 22, color: AppColors.inkMuted),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppColors.inkQuiet,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Status Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCorrect ? AppColors.canvasGradientTop : AppColors.amberTint,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCorrect ? Icons.check_rounded : Icons.warning_amber_rounded,
                                size: 13,
                                color: isCorrect ? AppColors.inkMuted : AppColors.amberDark,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isCorrect
                                    ? (isTamil ? 'சரியானது' : 'Correct')
                                    : (isTamil ? 'தவறானது' : 'Wrong'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isCorrect ? AppColors.inkMuted : AppColors.amberDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.inkQuiet,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. FIXES & ANALYSIS SUBTAB (1:1 with Stitch Prototype) ─────────────────
  Widget _buildFixesView({
    required List strengths,
    required List violations,
    required List fixes,
    required int score,
    required bool isTamil,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildAnalysisFilterChip(
                  label: isTamil ? 'அனைத்தும்' : 'All',
                  isSelected: _analysisFilter == 0,
                  onTap: () => setState(() => _analysisFilter = 0),
                ),
                const SizedBox(width: 6),
                _buildAnalysisFilterChip(
                  label: isTamil ? 'பலங்கள் (${strengths.length})' : 'Strengths (${strengths.length})',
                  isSelected: _analysisFilter == 1,
                  onTap: () => setState(() => _analysisFilter = 1),
                ),
                const SizedBox(width: 6),
                _buildAnalysisFilterChip(
                  label: isTamil ? 'குறைபாடுகள் (${violations.length})' : 'Violations (${violations.length})',
                  isSelected: _analysisFilter == 2,
                  onTap: () => setState(() => _analysisFilter = 2),
                ),
                const SizedBox(width: 6),
                _buildAnalysisFilterChip(
                  label: isTamil ? 'பரிகாரங்கள் (${fixes.length})' : 'Fixes (${fixes.length})',
                  isSelected: _analysisFilter == 3,
                  onTap: () => setState(() => _analysisFilter = 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                // 1. KEY STRENGTHS
                if (_analysisFilter == 0 || _analysisFilter == 1) ...[
                  Text(
                    isTamil ? 'முக்கிய பலங்கள்' : 'KEY STRENGTHS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.inkReading,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...strengths.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: AppColors.canvasGradientTop,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: AppColors.inkMuted,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                s.toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.inkPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),
                ],

                // 2. VIOLATIONS
                if (_analysisFilter == 0 || _analysisFilter == 2) ...[
                  Text(
                    isTamil ? 'வாஸ்து குறைபாடுகள்' : 'VIOLATIONS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.inkReading,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...violations.map((v) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: AppColors.amberTint,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: AppColors.amberDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                v.toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.inkPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),
                ],

                // 3. FIXES / REMEDIES
                if (_analysisFilter == 0 || _analysisFilter == 3) ...[
                  Text(
                    isTamil ? 'பரிகாரங்கள் & தீர்வுகள்' : 'REMEDIES & FIXES',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.inkReading,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...fixes.asMap().entries.map((entry) {
                    final int idx = entry.key + 1;
                    final Map f = entry.value as Map;
                    final String issue = f['issue']?.toString() ?? '';
                    final String fix = f['fix']?.toString() ?? '';
                    final String points = f['points']?.toString() ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: AppColors.inkDark,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              idx.toString(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
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
                                    Expanded(
                                      child: Text(
                                        issue,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.inkPrimary,
                                        ),
                                      ),
                                    ),
                                    if (points.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.amberTint,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          points,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.amberDark,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fix,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    color: AppColors.inkReading,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Bottom Amber CTA Button
          AppDecor.primaryPillButton(
            text: isTamil ? 'செலவு மதிப்பீட்டை காண்க' : 'Proceed to Cost',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {
              if (widget.onNavigateToTab != null) {
                widget.onNavigateToTab!(3); // Tab 3 is Cost
              } else if (widget.onNavigateToNext != null) {
                widget.onNavigateToNext!();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.inkDark : AppColors.card,
          borderRadius: BorderRadius.circular(100),
          border: isSelected ? null : Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }

  // ── ROOM DETAILS BOTTOM SHEET ──────────────────────────────────────────────
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
                  color: AppColors.borderLight,
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
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isCorrect ? AppColors.canvasGradientTop : AppColors.amberTint,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              isCorrect
                                  ? (isTamil ? 'சரியானது' : 'Correct')
                                  : (isTamil ? 'தவறானது' : 'Wrong'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isCorrect ? AppColors.inkMuted : AppColors.amberDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.inkQuiet,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Analysis List
              Column(
                children: items.map<Widget>((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.amberDefault,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.toString(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: AppColors.inkPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Action Button
              AppDecor.primaryPillButton(
                text: isTamil ? 'புரிந்தது' : 'Got it',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}
