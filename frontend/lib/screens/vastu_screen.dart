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

  IconData _getRoomIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('bed') || lower.contains('master')) {
      return Icons.bed_rounded;
    } else if (lower.contains('kitchen') || lower.contains('cook')) {
      return Icons.soup_kitchen_rounded;
    } else if (lower.contains('bath') ||
        lower.contains('toilet') ||
        lower.contains('wc')) {
      return Icons.bathtub_rounded;
    } else if (lower.contains('living') ||
        lower.contains('hall') ||
        lower.contains('drawing')) {
      return Icons.weekend_rounded;
    } else if (lower.contains('pooja') ||
        lower.contains('puja') ||
        lower.contains('prayer') ||
        lower.contains('mandir')) {
      return Icons.self_improvement_rounded;
    } else if (lower.contains('stair') || lower.contains('step')) {
      return Icons.stairs_rounded;
    } else if (lower.contains('dining')) {
      return Icons.dining_rounded;
    } else if (lower.contains('portico') ||
        lower.contains('parking') ||
        lower.contains('car') ||
        lower.contains('porch')) {
      return Icons.directions_car_rounded;
    } else if (lower.contains('utility') ||
        lower.contains('store') ||
        lower.contains('wash')) {
      return Icons.local_laundry_service_rounded;
    } else if (lower.contains('balcony') || lower.contains('terrace')) {
      return Icons.deck_rounded;
    }
    return Icons.meeting_room_rounded;
  }

  Map<String, dynamic> _normalizeVastuResult(Map<String, dynamic> raw) {
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);

    // 1. DYNAMIC ROOM AUDIT MAPPING (from backend rooms, roomPlacements, or 2D plan rooms)
    List<dynamic> roomsList = [];
    if (map['rooms'] is List && (map['rooms'] as List).isNotEmpty) {
      roomsList = (map['rooms'] as List).map((r) {
        if (r is Map) {
          final title = (r['title'] ?? r['name'] ?? 'Room').toString();
          return {
            'title': title,
            'subtitle': (r['subtitle'] ?? r['zone'] ?? '').toString(),
            'isCorrect': r['isCorrect'] ?? r['isIdeal'] ?? true,
            'icon': (r['icon'] is IconData) ? r['icon'] : _getRoomIcon(title),
            'analysis': (r['analysis'] is List)
                ? r['analysis']
                : (r['text'] != null ? [r['text'].toString()] : []),
          };
        }
        return r;
      }).toList();
    } else if (map['roomPlacements'] is List &&
        (map['roomPlacements'] as List).isNotEmpty) {
      roomsList = (map['roomPlacements'] as List).map((rp) {
        if (rp is Map) {
          final title = (rp['name'] ?? 'Room').toString();
          final zone = (rp['zone'] ?? '').toString();
          final isCorrect = rp['isIdeal'] == true;
          final text = (rp['text'] ?? '').toString();
          return {
            'title': title,
            'subtitle': zone,
            'isCorrect': isCorrect,
            'icon': _getRoomIcon(title),
            'analysis': text.isNotEmpty ? [text] : [],
          };
        }
        return rp;
      }).toList();
    } else {
      // Fallback: Use rooms directly extracted from the uploaded 2D plan!
      final dynamic projRooms = widget.projectData['rooms'] ??
          widget.projectData['model_data']?['rooms'] ??
          widget.projectData['model_data']?['floors']?['ground']?['rooms'];
      if (projRooms is List && projRooms.isNotEmpty) {
        roomsList = projRooms.map((r) {
          if (r is Map) {
            final title = (r['name'] ?? r['label'] ?? 'Room').toString();
            return {
              'title': title,
              'subtitle': r['zone']?.toString() ?? '2D Plan Room',
              'isCorrect': true,
              'icon': _getRoomIcon(title),
              'analysis': [
                r['vastu']?.toString() ??
                    'Accurately detected from uploaded 2D plan.'
              ],
            };
          }
          return r;
        }).toList();
      }
    }
    map['rooms'] = roomsList;

    // 2. DYNAMIC FIXES & REMEDIES MAPPING (from fixes or suggestions)
    List<dynamic> fixesList = [];
    if (map['fixes'] is List && (map['fixes'] as List).isNotEmpty) {
      fixesList = (map['fixes'] as List).asMap().entries.map((entry) {
        final f = entry.value;
        if (f is Map) {
          return {
            'number': f['number']?.toString() ?? '${entry.key + 1}',
            'issue': f['issue']?.toString() ?? 'Vastu Defect',
            'fix': f['fix']?.toString() ?? '',
            'points': f['points']?.toString() ?? '+5 pts',
          };
        }
        return {
          'number': '${entry.key + 1}',
          'issue': 'Vastu Remedy ${entry.key + 1}',
          'fix': f.toString(),
          'points': '+5 pts',
        };
      }).toList();
    } else if (map['suggestions'] is List &&
        (map['suggestions'] as List).isNotEmpty) {
      final violList =
          (map['violations'] is List) ? (map['violations'] as List) : [];
      fixesList = (map['suggestions'] as List).asMap().entries.map((entry) {
        final idx = entry.key;
        final s = entry.value.toString();
        final issue = (idx < violList.length)
            ? violList[idx].toString()
            : 'Vastu Alignment ${idx + 1}';
        return {
          'number': '${idx + 1}',
          'issue': issue,
          'fix': s,
          'points': '+5 pts',
        };
      }).toList();
    }
    map['fixes'] = fixesList;

    return map;
  }

  /// Unwrap nested {ground: {...}} structure from backend response and normalize fields
  Map<String, dynamic> _unwrapVastuData(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map<String, dynamic>) {
      // If it has 'ground' key with score inside, unwrap it
      if (raw.containsKey('ground') && raw['ground'] is Map) {
        final g = raw['ground'] as Map<String, dynamic>;
        if (g.containsKey('score')) return _normalizeVastuResult(g);
      }
      // If already flat (has score directly), return normalized
      if (raw.containsKey('score')) return _normalizeVastuResult(raw);
    }
    return {};
  }

  @override
  void initState() {
    super.initState();
    final rawVastu =
        widget.projectData['vastu_data'] ?? widget.projectData['_vastu'];
    final initialVastu = _unwrapVastuData(rawVastu);
    if (initialVastu.isNotEmpty) {
      _resultsCache['EN'] = initialVastu;
      _vastuFuture = Future.value(_resultsCache['EN']!);
    } else {
      _vastuFuture = _fetchVastuData('EN');
    }
  }

  Future<Map<String, dynamic>> _fetchVastuData(String lang) async {
    try {
      final raw = await ApiService().analyzeVastu(
        widget.projectData['id']?.toString() ?? 'demo',
        lang: lang == 'TA' ? 'Tamil' : 'English',
      );
      final res = _unwrapVastuData(raw);
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
    // Return an empty error state - never show fake hardcoded room placements
    return {
      'score': 0,
      'grade': '--',
      'orientation': widget.projectData['orientation'] ?? 'East',
      'error': true,
      'strengths': <String>[],
      'violations': [
        isTamil
            ? 'இணைப்பில் சிக்கல் உள்ளது. மீண்டும் முயற்சி செய்யவும்.'
            : 'Connection error. Please try again.',
      ],
      'whyPointsReduced': <String>[],
      'rooms': <Map<String, dynamic>>[],
      'fixes': <Map<String, dynamic>>[],
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

            final int score =
                (data['score'] is num) ? (data['score'] as num).toInt() : 65;
            final String grade = data['grade']?.toString() ?? 'B';
            final String orientation =
                data['orientation']?.toString() ?? 'North';
            final int pointsLost = 100 - score;

            final List strengths = (data['strengths'] is List &&
                    (data['strengths'] as List).isNotEmpty)
                ? (data['strengths'] as List)
                : (_getFallbackData(langKey)['strengths'] as List);

            final List violations = (data['violations'] is List &&
                    (data['violations'] as List).isNotEmpty)
                ? (data['violations'] as List)
                : (_getFallbackData(langKey)['violations'] as List);

            final List whyPointsReduced = (data['whyPointsReduced'] is List &&
                    (data['whyPointsReduced'] as List).isNotEmpty)
                ? (data['whyPointsReduced'] as List)
                : (data['negativePoints'] is List &&
                        (data['negativePoints'] as List).isNotEmpty
                    ? (data['negativePoints'] as List)
                    : (_getFallbackData(langKey)['whyPointsReduced'] as List));

            final List rooms =
                (data['rooms'] is List && (data['rooms'] as List).isNotEmpty)
                    ? (data['rooms'] as List)
                    : (_getFallbackData(langKey)['rooms'] as List);

            final List fixes =
                (data['fixes'] is List && (data['fixes'] as List).isNotEmpty)
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
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF18191D),
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
                                      fontWeight: FontWeight.w400,
                                      color: const Color(0xFF8E94A0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Language Capsule (Matches Stitch image)
                            Container(
                              height: 34,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCFDFF),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: !isTamil
                                            ? const Color(0xFF1B212F)
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: Text(
                                        'EN',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: !isTamil
                                              ? Colors.white
                                              : const Color(0xFF364050),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isTamil
                                            ? const Color(0xFF1B212F)
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: Text(
                                        'தமிழ்',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: isTamil
                                              ? Colors.white
                                              : const Color(0xFF364050),
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
                              child:
                                  Container(height: 1, color: AppColors.border),
                            ),
                            Row(
                              children: [
                                _buildSubTab(
                                  title: isTamil ? 'மதிப்பெண்' : 'Score',
                                  icon: Icons.speed_rounded,
                                  isActive: _currentSubTab == 0,
                                  onTap: () =>
                                      setState(() => _currentSubTab = 0),
                                ),
                                _buildSubTab(
                                  title: isTamil ? 'அறைகள்' : 'Rooms',
                                  icon: Icons.table_chart_outlined,
                                  isActive: _currentSubTab == 1,
                                  onTap: () =>
                                      setState(() => _currentSubTab = 1),
                                ),
                                _buildSubTab(
                                  title: isTamil ? 'பரிகாரங்கள்' : 'Fixes',
                                  icon: Icons.build_rounded,
                                  isActive: _currentSubTab == 2,
                                  onTap: () =>
                                      setState(() => _currentSubTab = 2),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.06),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

          // Crystal Clear Score Hero Section with Grade on the Right Side
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'Grade $grade',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(100),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (score / 100.0).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBA73B), Color(0xFFE58A18)],
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
            ],
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF18191D),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEBCB),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '-$pointsLost points',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB46205),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (whyPointsReduced.isNotEmpty)
            ...whyPointsReduced.asMap().entries.map(
              (entry) => _buildNumberedReasonRow(
                entry.key + 1,
                entry.value.toString(),
              ),
            )
          else
            _buildNumberedReasonRow(
              1,
              isTamil
                  ? 'எந்த பெரிய குறைபாடும் இல்லை!'
                  : 'Pristine alignment! No major defects.',
            ),
          const SizedBox(height: 8),

          // View Fixes Button (matches Stitch image)
          GestureDetector(
            onTap: () => setState(() => _currentSubTab = 2),
            child: Container(
              height: 52,
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFBA73B), Color(0xFFE58A18)],
                ),
                borderRadius: BorderRadius.circular(100),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59E58A18),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isTamil ? 'பரிகாரங்களை காண்க' : 'View Fixes',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E252D),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Color(0xFF1E252D),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. ROOMS SUBTAB ────────────────────────────────────────────────────────
  Widget _buildRoomsView(List rooms, bool isTamil) {
    final int correctCount =
        rooms.where((r) => r is Map && r['isCorrect'] == true).length;

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
              final IconData icon = (r['icon'] is IconData)
                  ? r['icon'] as IconData
                  : _getRoomIcon(title);
              final List analysis =
                  (r['analysis'] is List) ? (r['analysis'] as List) : [];

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
                label: isTamil
                    ? 'பலங்கள் (${strengths.length})'
                    : 'Strengths (${strengths.length})',
                isSelected: _analysisFilter == 1,
                onTap: () => setState(() => _analysisFilter = 1),
                color: const Color(0xFF059669),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: isTamil
                    ? 'குறைபாடுகள் (${violations.length})'
                    : 'Violations (${violations.length})',
                isSelected: _analysisFilter == 2,
                onTap: () => setState(() => _analysisFilter = 2),
                color: const Color(0xFFDC2626),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: isTamil
                    ? 'பரிகாரங்கள் (${fixes.length})'
                    : 'Fixes (${fixes.length})',
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
                  title: isTamil
                      ? 'மதிப்பெண் குறைந்த காரணங்கள்'
                      : 'Why Points Reduced',
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
                      title: isTamil
                          ? 'பரிகாரங்கள் & தீர்வுகள்'
                          : 'Suggestions & Fixes',
                      badge: '${fixes.length}',
                      icon: Icons.lightbulb_outline_rounded,
                      color: AppColors.primary,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3.5),
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
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    const Color goldAmber = Color(0xFFE58A18);
    const Color goldAmberLight = Color(0xFFFBA73B);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: isActive ? goldAmber : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Positioned(
                bottom: 0,
                left: 14,
                right: 14,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [goldAmberLight, goldAmber],
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberedReasonRow(int number, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(12),
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
              color: Color(0xFFE9EEF4),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF364050),
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
                color: const Color(0xFF18191D),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check,
                                size: 12, color: Colors.black),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE58A18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE58A18), Color(0xFFFBA73B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
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
            ? [
                'சரியான வாஸ்து அமைவிடம்',
                'நேர்மறை ஆற்றலை ஈர்க்கிறது',
                'நல்வாழ்விற்கு உகந்தது'
              ]
            : [
                'Perfect Vastu placement',
                'Enhances positive energy',
                'Optimal for well-being'
              ])
        : (isTamil
            ? [
                'கடுமையான வாஸ்து குறைபாடு',
                'ஆற்றல் தடையை ஏற்படுத்துகிறது',
                'பரிகாரங்கள் தேவை'
              ]
            : [
                'Severe Vastu violation',
                'Causes restlessness',
                'Weakens decisions & finances'
              ]);

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
          padding:
              const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 28),
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
                                color: Color(0xFFE58A18),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '!',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
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
