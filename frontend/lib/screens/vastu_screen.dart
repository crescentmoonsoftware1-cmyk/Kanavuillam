import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';

const _bg = Color(0xFFFAF9F6); // Premium Cream/Off-white
const _surface = Colors.white;
const _accent = Color(0xFFB8860B); // Classic Gold
const _textPri = Color(0xFF1E293B); // Deep Navy/Slate
const _textSec = Color(0xFF64748B);

class VastuScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  const VastuScreen({super.key, required this.projectData});

  @override
  State<VastuScreen> createState() => _VastuScreenState();
}

class _VastuScreenState extends State<VastuScreen> {
  late Future<Map<String, dynamic>> _vastuFuture;
  String _selectedLang = 'English';
  String _selectedFloor = 'ground';
  bool _isTranslating = false;
  final Map<String, Map<String, dynamic>> _resultsCache = {};

  @override
  void initState() {
    super.initState();
    final initialVastu =
        widget.projectData['vastu_data'] ?? widget.projectData['_vastu'];
    if (initialVastu != null && _selectedLang == 'English') {
      _resultsCache['English'] = initialVastu;
      _vastuFuture = Future.value(initialVastu);
    } else {
      _vastuFuture = ApiService()
          .analyzeVastu(
        widget.projectData['id'].toString(),
        lang: _selectedLang,
      )
          .then((val) {
        _resultsCache[_selectedLang] = val;
        return val;
      });
    }
  }

  void _fetchVastu() {
    if (_resultsCache.containsKey(_selectedLang)) {
      setState(() {
        _vastuFuture = Future.value(_resultsCache[_selectedLang]);
      });
      return;
    }

    setState(() {
      _isTranslating = true;
      _vastuFuture = ApiService()
          .analyzeVastu(
        widget.projectData['id'].toString(),
        lang: _selectedLang,
      )
          .then((val) {
        _resultsCache[_selectedLang] = val;
        setState(() => _isTranslating = false);
        return val;
      }).catchError((e) {
        setState(() => _isTranslating = false);
        throw e;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _vastuFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              _isTranslating) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: _accent),
                  const SizedBox(height: 16),
                  Text(
                    _isTranslating
                        ? (_selectedLang == 'Tamil'
                            ? 'மொழிபெயர்க்கிறது...'
                            : 'Translating...')
                        : (_selectedLang == 'Tamil'
                            ? 'ஆய்வு செய்கிறது...'
                            : 'Analyzing...'),
                    style: const TextStyle(color: _textSec, fontSize: 14),
                  ),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Color.fromARGB(255, 252, 35, 35)),
              ),
            );
          }
          final rootV = snapshot.data!;
          final bool isMultiFloor = rootV.containsKey('ground');
          final v = isMultiFloor
              ? (rootV[_selectedFloor] ?? rootV.values.first)
              : rootV;
          final score = v['score'] ?? 0;
          final grade = v['grade'] ?? '-';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _selectedLang == 'Tamil'
                                    ? 'வாஸ்து அறிக்கை'
                                    : 'Vastu Report',
                                style: const TextStyle(
                                  color: _textPri,
                                  fontSize: 24, // Slightly smaller
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    Color.fromARGB(255, 11, 31, 184),
                                    Color(0xFF00B4D8)
                                  ]),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'KI',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedLang == 'Tamil'
                                ? 'மிகவும் துல்லியமான வாஸ்து ஆய்வு'
                                : 'Highly accurate Vastu analysis',
                            style: const TextStyle(
                              color: _textSec,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Floor Switcher
                    if (isMultiFloor &&
                        rootV.keys.where((k) => k != 'total').length > 1)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _accent.withValues(alpha: 0.5),
                              width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children:
                              rootV.keys.where((k) => k != 'total').map((k) {
                            final floorName = k.toString();
                            return _LangChip(
                              label: floorName == 'ground'
                                  ? 'Ground'
                                  : (floorName == 'first'
                                      ? 'First'
                                      : floorName.toUpperCase()),
                              isSelected: _selectedFloor == floorName,
                              onTap: () {
                                if (_selectedFloor != floorName) {
                                  setState(() => _selectedFloor = floorName);
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    // Language Switcher
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _accent.withValues(alpha: 0.5), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          _LangChip(
                            label: 'EN',
                            isSelected: _selectedLang == 'English',
                            onTap: () {
                              if (_selectedLang != 'English') {
                                setState(() => _selectedLang = 'English');
                                _fetchVastu();
                              }
                            },
                          ),
                          _LangChip(
                            label: 'தமிழ்',
                            isSelected: _selectedLang == 'Tamil',
                            onTap: () {
                              if (_selectedLang != 'Tamil') {
                                setState(() => _selectedLang = 'Tamil');
                                _fetchVastu();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(),
                const SizedBox(height: 28),

                // ── House Orientation Banner ────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.explore_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedLang == 'Tamil'
                                  ? 'வீட்டின் திசை அமைப்பு (House Facing Direction)'
                                  : 'HOUSE FACING ORIENTATION',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '🏡 ${(v['orientation'] ?? 'EAST').toString().toUpperCase()} FACING HOUSE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedLang == 'Tamil'
                                  ? '2D வரைபடத்தில் காந்தப்புல மற்றும் சூரிய ஆற்றல் திசைக்கோடு'
                                  : 'Solar magnetic alignment derived dynamically from 2D floor plan',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.08, end: 0),

                const SizedBox(height: 16),
                // ── Score Card ───────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                        color: _accent.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      // Score circle
                      _VastuScoreCircle(score: score),
                      const SizedBox(width: 28),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedLang == 'Tamil'
                                  ? 'தரம் $grade'
                                  : 'Grade $grade',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _selectedLang == 'Tamil'
                                  ? 'வாஸ்து இணக்க மதிப்பீடு'
                                  : 'Vastu Compliance Score',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08, end: 0),

                const SizedBox(height: 24),
                // ── Placement Analysis ──────────────────────────────────────────
                _PlacementAnalysis(
                  lang: _selectedLang,
                  data: v,
                  delay: 140,
                ),

                const SizedBox(height: 24),
                _Section(
                  title: _selectedLang == 'Tamil'
                      ? 'முக்கிய பலங்கள்'
                      : 'Key Strengths',
                  items: List<String>.from(v['strengths'] ?? []),
                  color: _accent,
                  icon: Icons.check_circle_outline_rounded,
                  delay: 160,
                ),
                const SizedBox(height: 16),
                _Section(
                  title: _selectedLang == 'Tamil'
                      ? 'வாஸ்து குறைபாடுகள்'
                      : 'Violations',
                  items: List<String>.from(v['violations'] ?? []),
                  color: const Color.fromARGB(255, 249, 48, 48),
                  icon: Icons.warning_amber_rounded,
                  delay: 200,
                ),
                const SizedBox(height: 16),
                _Section(
                  title: _selectedLang == 'Tamil' ? 'ஆலோசனைகள்' : 'Suggestions',
                  items: List<String>.from(v['suggestions'] ?? []),
                  color: const Color.fromARGB(255, 248, 149, 28),
                  icon: Icons.lightbulb_outline_rounded,
                  delay: 240,
                ),

                if (score < 100) ...[
                  _WhyPointsReduced(
                    lang: _selectedLang,
                    score: score,
                    items: List<String>.from(v['whyPointsReduced'] ?? v['violations'] ?? []),
                    delay: 260,
                  ),
                ],

                const SizedBox(height: 24),
                _VastuScienceExplanation(
                  lang: _selectedLang,
                  delay: 280,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlacementAnalysis extends StatelessWidget {
  final String lang;
  final Map<String, dynamic> data;
  final int delay;

  const _PlacementAnalysis({
    required this.lang,
    required this.data,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final isTamil = lang == 'Tamil';
    IconData getRoomIcon(String name) {
      final n = name.toLowerCase();
      if (n.contains('kitchen') || n.contains('cook')) return Icons.soup_kitchen_outlined;
      if (n.contains('bed') || n.contains('master') || n.contains('guest')) return Icons.bed_outlined;
      if (n.contains('bath') || n.contains('toilet') || n.contains('wc') || n.contains('wash')) return Icons.bathroom_outlined;
      if (n.contains('stair') || n.contains('step')) return Icons.stairs_outlined;
      if (n.contains('pooja') || n.contains('puja') || n.contains('prayer')) return Icons.brightness_5_outlined;
      if (n.contains('living') || n.contains('hall') || n.contains('drawing')) return Icons.weekend_outlined;
      if (n.contains('dining')) return Icons.restaurant_outlined;
      if (n.contains('entrance') || n.contains('door') || n.contains('main')) return Icons.door_front_door_outlined;
      if (n.contains('store') || n.contains('utility')) return Icons.inventory_2_outlined;
      return Icons.meeting_room_outlined;
    }

    final List<Map<String, dynamic>> items = [];

    if (data['roomPlacements'] is List && (data['roomPlacements'] as List).isNotEmpty) {
      for (final r in (data['roomPlacements'] as List)) {
        if (r is Map && r['name'] != null && r['text'] != null) {
          items.add({
            'icon': getRoomIcon(r['name'].toString()),
            'label': r['name'].toString(),
            'zone': r['zone']?.toString() ?? '',
            'isIdeal': r['isIdeal'] == true,
            'val': r['text'].toString(),
          });
        }
      }
    } else {
      final fallbackItems = [
        {
          'icon': Icons.door_front_door_outlined,
          'label': isTamil ? 'தலைவாசல்' : 'Entrance',
          'zone': 'North-East',
          'isIdeal': true,
          'val': data['mainEntrance']
        },
        {
          'icon': Icons.soup_kitchen_outlined,
          'label': isTamil ? 'சமையலறை' : 'Kitchen',
          'zone': 'South-East',
          'isIdeal': true,
          'val': data['kitchen']
        },
        {
          'icon': Icons.bed_outlined,
          'label': isTamil ? 'படுக்கையறை' : 'Master Bed',
          'zone': 'South-West',
          'isIdeal': true,
          'val': data['masterBedroom']
        },
        {
          'icon': Icons.bathroom_outlined,
          'label': isTamil ? 'குளியலறை' : 'Bathroom',
          'zone': 'North-West',
          'isIdeal': true,
          'val': data['bathroom']
        },
        {
          'icon': Icons.stairs_outlined,
          'label': isTamil ? 'படிக்கட்டு' : 'Staircase',
          'zone': 'South-West',
          'isIdeal': true,
          'val': data['staircase']
        },
        {
          'icon': Icons.brightness_5_outlined,
          'label': isTamil ? 'பூஜை அறை' : 'Pooja Room',
          'zone': 'North-East',
          'isIdeal': true,
          'val': data['poojaRoom']
        },
        {
          'icon': Icons.weekend_outlined,
          'label': isTamil ? 'வரவேற்புறை' : 'Living Room',
          'zone': 'North-East',
          'isIdeal': true,
          'val': data['livingRoom']
        },
      ];
      for (final i in fallbackItems) {
        if (i['val'] != null && i['val'].toString().isNotEmpty) {
          items.add(i);
        }
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
        border: Border.all(color: _accent.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.explore_outlined,
                    color: _accent, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  isTamil ? 'அமைவிடம் மற்றும் திசை ஆய்வு' : 'ROOM PLACEMENT & DIRECTION AUDIT',
                  style: const TextStyle(
                    color: _textPri,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...items.map((item) {
            final isIdeal = item['isIdeal'] == true;
            final zoneText = item['zone'].toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFBF7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isIdeal
                      ? const Color(0xFF10B981).withValues(alpha: 0.35)
                      : const Color(0xFFEF4444).withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            Icon(item['icon'] as IconData, size: 22, color: _accent),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                item['label'].toString().toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: _textPri,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dynamic Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isIdeal
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isIdeal
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isIdeal
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              size: 14,
                              color: isIdeal
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF991B1B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isIdeal
                                  ? (isTamil ? 'சரியான வாஸ்து திசை' : 'Correct Direction')
                                  : (isTamil ? 'வாஸ்து குறைபாடு' : 'Wrong Placement'),
                              style: TextStyle(
                                color: isIdeal
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF991B1B),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (zoneText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '📍 Zone: $zoneText',
                        style: const TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    item['val'].toString(),
                    style: const TextStyle(
                      color: _textPri,
                      fontSize: 13.5,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideX(begin: 0.05, end: 0);
  }
}


class _Section extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;
  final IconData icon;
  final int delay;

  const _Section({
    required this.title,
    required this.items,
    required this.color,
    required this.icon,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> flatItems = [];
    for (final item in items) {
      if (item.contains('\n')) {
        final lines = item.split('\n');
        for (final l in lines) {
          final trimmed = l.trim();
          if (trimmed.isNotEmpty) {
            flatItems.add(trimmed);
          }
        }
      } else {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty) {
          flatItems.add(trimmed);
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...flatItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: _textPri,
                        fontSize: 14,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideY(begin: 0.06, end: 0);
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black87 : _textSec,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _VastuScoreCircle extends StatelessWidget {
  final int score;
  const _VastuScoreCircle({required this.score});

  Color _getScoreColor(int s) {
    if (s >= 80) return _accent;
    if (s >= 60) return const Color(0xFFF8951C);
    return const Color(0xFFF93030);
  }

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor(score);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score.toDouble()),
      duration: 1500.ms,
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer Glow
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            // Background track
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 4,
                color: color.withValues(alpha: 0.1),
              ),
            ),
            // Progress ring
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: value / 100,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                color: color,
              ),
            ),
            // Number
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                Text(
                  '%',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(
          begin: const Offset(1, 1),
          end: const Offset(1.03, 1.03),
          duration: 2.seconds,
          curve: Curves.easeInOut,
        );
  }
}

class _WhyPointsReduced extends StatelessWidget {
  final String lang;
  final int score;
  final List<String> items;
  final int delay;

  const _WhyPointsReduced({
    required this.lang,
    required this.score,
    required this.items,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final int pointsLost = 100 - score;
    final isTamil = lang == 'Tamil';

    final List<String> flatItems = [];
    for (final item in items) {
      if (item.contains('\n')) {
        final lines = item.split('\n');
        for (final l in lines) {
          final trimmed = l.trim();
          if (trimmed.isNotEmpty) {
            flatItems.add(trimmed);
          }
        }
      } else {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty) {
          flatItems.add(trimmed);
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFE53935).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_down_rounded,
                    color: Color(0xFFE53935), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  isTamil
                      ? 'மதிப்பெண் குறைய காரணங்கள் (-$pointsLost)'
                      : 'WHY SCORE REDUCED (-$pointsLost POINTS)',
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (flatItems.isEmpty)
            Text(
              isTamil
                  ? 'குறிப்பிட்ட காரணங்கள் இல்லை.'
                  : 'No specific reduction causes listed.',
              style: const TextStyle(color: _textSec, fontSize: 14),
            )
          else
            ...flatItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                              color: _textPri, fontSize: 14, height: 1.6, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.05, end: 0);
  }
}

class _VastuScienceExplanation extends StatelessWidget {
  final String lang;
  final int delay;

  const _VastuScienceExplanation({required this.lang, required this.delay});

  @override
  Widget build(BuildContext context) {
    final isTamil = lang == 'Tamil';
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF64748B).withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  isTamil
                      ? 'வாஸ்து சாஸ்திரம் எவ்வாறு செயல்படுகிறது? (பஞ்சபூத இயற்பியல்)'
                      : 'HOW VASTU SHASTRA WORKS (PANCHA BHOOTA SCIENCE)',
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isTamil
                ? 'வாஸ்து சாஸ்திரம் என்பது பூமியின் காந்தப்புலம் (Magnetic Field), சூரியனின் அகச்சிவப்பு கதிர்கள் (Solar Radiation) மற்றும் காற்று ஓட்டம் (Wind Energy) ஆகியவற்றை அடிப்படையாகக் கொண்ட கட்டிடக் கலை அறிவியலாகும். உங்கள் 2D வரைபடத்தில் 5 முக்கிய மண்டலங்கள் ஆய்வு செய்யப்பட்டுள்ளன:'
                : 'Vastu Shastra is an architectural science that optimizes Magnetic Fields, Solar Radiation, and Wind Velocity for physical & mental well-being. Five key elemental zones govern your 2D floor plan layout:',
            style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.6, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          _elementTile(
            title: isTamil ? '1. அக்னி மூலை (South-East Fire Zone)' : '1. South-East Zone (Agni - Fire Element)',
            desc: isTamil
                ? 'சமையலறைக்கு உகந்தது. சூரியனின் காலை வெப்பக் கதிர்கள் பாக்டீரியாக்களை அழித்து செரிமான ஆரோக்கியத்தை மேம்படுத்தும்.'
                : 'Ideal for Kitchen. Harnesses morning solar heat, sanitizes cooking space, and energizes digestion.',
            color: const Color(0xFFEF4444),
          ),
          _elementTile(
            title: isTamil ? '2. நிருதி மூலை (South-West Earth Zone)' : '2. South-West Zone (Niruthi - Earth Element)',
            desc: isTamil
                ? 'முதன்மை படுக்கையறைக்கு உகந்தது. பூமியின் அதிக கனமான புவிஈர்ப்பு மண்டலம் குடும்பத் தலைவருக்கு நிலைத்தன்மையையும் மன உறுதியையும் தரும்.'
                : 'Ideal for Master Bedroom. Highest gravitational mass stability that anchors financial security and authority.',
            color: const Color(0xFFD97706),
          ),
          _elementTile(
            title: isTamil ? '3. ஈசான்ய மூலை (North-East Water/Divine Zone)' : '3. North-East Zone (Eesanyam - Water Element)',
            desc: isTamil
                ? 'பூஜை அறை மற்றும் வரவேற்பறைக்கு உகந்தது. பூமியின் வடகிழக்கு காந்த அலைகள் ஊடுருவும் நுழைவாயிலாக இருப்பதால் லேசாகவும் தூய்மையாகவும் இருக்க வேண்டும்.'
                : 'Ideal for Pooja & Open Hall. Gateway for cosmic magnetic forces; must be light, clean, and uncluttered.',
            color: const Color(0xFF0284C7),
          ),
          _elementTile(
            title: isTamil ? '4. வாயு மூலை (North-West Air Zone)' : '4. North-West Zone (Vayu - Air Element)',
            desc: isTamil
                ? 'கழிவறை மற்றும் விருந்தினர் அறைக்கு உகந்தது. காற்று சுழற்சி மண்டலம் துர்நாற்றம் மற்றும் கழிவு ஆற்றலை உடனுக்குடன் வெளியேற்றும்.'
                : 'Ideal for Restrooms & Guest rooms. Air circulation sector that dispels toxins and movement energies efficiently.',
            color: const Color(0xFF059669),
          ),
          _elementTile(
            title: isTamil ? '5. பிரம்மஸ்தானம் (Center Space Element)' : '5. Center Core (Brahmasthan - Space Element)',
            desc: isTamil
                ? 'வீட்டின் மையப்பகுதி. இது கனமான சுவர்கள் இன்றி திறந்தவெளியாக இருப்பதால் ஆற்றல் சுழற்சி தடையின்றி நடக்கும்.'
                : 'Central courtyard core. Must remain free of heavy structural loads for unhindered cosmic energy flow.',
            color: const Color(0xFF7C3AED),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _elementTile({required String title, required String desc, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF1E293B)),
                children: [
                  TextSpan(text: '$title\n', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                  TextSpan(text: desc, style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

