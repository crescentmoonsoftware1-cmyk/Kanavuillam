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
                                  gradient: const LinearGradient(
                                      colors: [_accent, Color(0xFF00B4D8)]),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'AI',
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
                                ? 'AI-மூலம் வாஸ்து சாஸ்திர ஆய்வு'
                                : 'Highly accurate AI-generated Vastu analysis',
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
                              color: _accent.withValues(alpha: 0.5), width: 1.5),
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
                    border:
                        Border.all(color: _accent.withValues(alpha: 0.3), width: 1.5),
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

                if (score < 100)
                  _WhyPointsReduced(
                    lang: _selectedLang,
                    score: score,
                    violations: List<String>.from(v['violations'] ?? []),
                    delay: 130,
                  ),

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
    final items = [
      {
        'icon': Icons.door_front_door_outlined,
        'label': isTamil ? 'தலைவாசல்' : 'Entrance',
        'val': data['mainEntrance']
      },
      {
        'icon': Icons.soup_kitchen_outlined,
        'label': isTamil ? 'சமையலறை' : 'Kitchen',
        'val': data['kitchen']
      },
      {
        'icon': Icons.bed_outlined,
        'label': isTamil ? 'படுக்கையறை' : 'Master Bed',
        'val': data['masterBedroom']
      },
      {
        'icon': Icons.bathroom_outlined,
        'label': isTamil ? 'குளியலறை' : 'Bathroom',
        'val': data['bathroom']
      },
      {
        'icon': Icons.stairs_outlined,
        'label': isTamil ? 'படிக்கட்டு' : 'Staircase',
        'val': data['staircase']
      },
      {
        'icon': Icons.brightness_5_outlined,
        'label': isTamil ? 'பூஜை அறை' : 'Pooja Room',
        'val': data['poojaRoom']
      },
      {
        'icon': Icons.weekend_outlined,
        'label': isTamil ? 'வரவேற்புறை' : 'Living Room',
        'val': data['livingRoom']
      },
    ].where((i) => i['val'] != null && i['val'].toString().isNotEmpty).toList();

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
              Text(
                isTamil ? 'அமைவிடம் ஆய்வு' : 'PLACEMENT ANALYSIS',
                style: const TextStyle(
                  color: _textPri,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...items.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7), // Match premium cream
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item['icon'] as IconData, size: 24, color: _accent),
                    const SizedBox(width: 16),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: _textPri, fontSize: 14, height: 1.5),
                          children: [
                            TextSpan(
                              text: '${item['label']}\n',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: _textSec,
                                  letterSpacing: 0.8),
                            ),
                            TextSpan(
                              text: item['val'].toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, color: _textPri),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
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
          ...items.map(
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
  final List<String> violations;
  final int delay;

  const _WhyPointsReduced({
    required this.lang,
    required this.score,
    required this.violations,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final int pointsLost = 100 - score;
    final isTamil = lang == 'Tamil';

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
          if (violations.isEmpty)
            Text(
              isTamil
                  ? 'குறிப்பிட்ட காரணங்கள் இல்லை.'
                  : 'No specific violations listed.',
              style: const TextStyle(color: _textSec, fontSize: 14),
            )
          else
            ...violations.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(
                              color: Color(0xFFE53935),
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          v,
                          style: const TextStyle(
                              color: _textPri, fontSize: 14, height: 1.5),
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
