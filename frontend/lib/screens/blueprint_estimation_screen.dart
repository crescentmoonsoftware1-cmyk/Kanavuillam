import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─── Premium Light Palette ──────────────────────────────────────────────────
const _bg = Color(0xFFF1F5FB);
const _textPri = Color.fromARGB(255, 241, 242, 245);
const _textSec = Color.fromARGB(255, 7, 7, 7);
const _accent = Color.fromARGB(255, 1, 136, 163);
const _tealEnd = Color.fromARGB(255, 1, 167, 153);
const _purple = Color(0xFF818CF8);
const _pink = Color(0xFFC084FC);

class BlueprintEstimationScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  const BlueprintEstimationScreen({super.key, required this.projectData});

  @override
  State<BlueprintEstimationScreen> createState() =>
      _BlueprintEstimationScreenState();
}

class _BlueprintEstimationScreenState extends State<BlueprintEstimationScreen> {
  // ─── State for Manual Material Selection ────────────────────────────────────
  final Map<String, Map<String, dynamic>> _materials = {
    'Cement': {
      'options': [
        'UltraTech (Premium)',
        'ACC Concrete+',
        'Birla Gold',
        'Priya',
        'Ramco'
      ],
      'selected': 'UltraTech (Premium)',
      'price_per_unit': 450.0,
      'base_price': 450.0,
      'unit': 'bag',
      'qty_multiplier': 0.45,
    },
    'Steel': {
      'options': [
        'TATA Tiscon SD',
        'JSW Neosteel 550D',
        'Vizag Steel',
        'Prime Gold',
        'vela'
      ],
      'selected': 'TATA Tiscon SD',
      'price_per_unit': 88.0,
      'base_price': 88.0,
      'unit': 'kg',
      'qty_multiplier': 4.8,
    },
    'Sand & Aggregate': {
      'options': [
        'M-Sand (Double Washed)',
        'P-Sand (Plastering)',
        'River Sand',
      ],
      'selected': 'M-Sand (Double Washed)',
      'price_per_unit': 75.0,
      'base_price': 75.0,
      'unit': 'cft',
      'qty_multiplier': 1.8,
    },
    'Aggregates': {
      'options': ['20mm Blue Metal', '40mm Blue Metal', 'Granite Chips'],
      'selected': '20mm Blue Metal',
      'price_per_unit': 64.0,
      'base_price': 64.0,
      'unit': 'cft',
      'qty_multiplier': 1.4,
    },
    'Bricks / Blocks': {
      'options': [
        'First Class Red Bricks',
        'AAC Blocks (Lightweight)',
        'Solid Concrete Blocks',
      ],
      'selected': 'First Class Red Bricks',
      'price_per_unit': 13.0,
      'base_price': 13.0,
      'unit': 'pcs',
      'qty_multiplier': 24.0,
    },
    'Flooring': {
      'options': [
        'Vitrified Tiles (Kajaria)',
        'Indian Marble',
        'Italian Granite',
      ],
      'selected': 'Vitrified Tiles (Kajaria)',
      'price_per_unit': 160.0,
      'base_price': 160.0,
      'unit': 'sqft',
      'qty_multiplier': 1.15,
    },
    'Electrical': {
      'options': [
        'Havells / Finolex (Std)',
        'L&T / Legrand (Prem)',
        'Anchor (Economy)',
      ],
      'selected': 'Havells / Finolex (Std)',
      'price_per_unit': 1350.0,
      'base_price': 1350.0,
      'unit': 'point',
      'qty_multiplier': 0.08,
    },
    'Plumbing': {
      'options': ['Ashirvad CPVC', 'Astral FlowGuard', 'Supreme Pipes'],
      'selected': 'Ashirvad CPVC',
      'price_per_unit': 3600.0,
      'base_price': 3600.0,
      'unit': 'point',
      'qty_multiplier': 0.03,
    },
    'Woodwork': {
      'options': ['Burma Teak Wood', 'Honné Wood', 'Flush Doors (Std)'],
      'selected': 'Burma Teak Wood',
      'price_per_unit': 5400.0,
      'base_price': 5400.0,
      'unit': 'cft',
      'qty_multiplier': 0.02,
    },
    'Painting': {
      'options': ['Asian Royale (Luxury)', 'Berger Silk', 'Nippon (Std)'],
      'selected': 'Asian Royale (Luxury)',
      'price_per_unit': 40.0,
      'base_price': 40.0,
      'unit': 'sqft',
      'qty_multiplier': 3.2,
    },
  };

  double _totalArea = 0;

  @override
  void initState() {
    super.initState();
    _totalArea = (widget.projectData['cost_data']?['total_area_sqft'] ?? 1200.0)
        .toDouble();
  }

  double _calculateTotal() {
    double total = 0;
    _materials.forEach((key, data) {
      double qty = _totalArea * data['qty_multiplier'];
      total += qty * data['price_per_unit'];
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final liveTotal = _calculateTotal();

    return Container(
      color: const Color.fromARGB(255, 230, 238, 238),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildTotalCard(liveTotal),
            const SizedBox(height: 40),
            _sectionLabel('I. MATERIAL SELECTION (MANUAL)'),
            const SizedBox(height: 20),
            ..._materials.entries.map(
              (entry) => _buildMaterialEditor(entry.key, entry.value),
            ),
            const SizedBox(height: 32),
            _buildRealtimeBanner(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estimation / Real-time Config',
          style: TextStyle(
            color: Color.fromARGB(255, 0, 0, 0),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 6),
        Row(
          children: [
            const Text(
              'Accurate',
              style: TextStyle(color: _textSec, fontSize: 14),
            ),
            _dot(),
            const Text(
              'Transparent',
              style: TextStyle(color: _textSec, fontSize: 14),
            ),
            _dot(),
            const Text(
              'Real-time',
              style: TextStyle(color: _textSec, fontSize: 14),
            ),
          ],
        ).animate().fadeIn(delay: 100.ms),
      ],
    );
  }

  Widget _dot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.circle, size: 4, color: _textSec.withValues(alpha: 0.4)),
      );

  Widget _buildTotalCard(double total) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 121, 133, 241),
            Color.fromARGB(255, 219, 197, 219),
            Color.fromARGB(255, 220, 159, 214),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 20,
            bottom: 20,
            child: Opacity(
              opacity: 0.9,
              child: Image.asset(
                'assets/viewer/Screenshot_2026-05-07_114145-removebg-preview.png',
                width: 140,
                fit: BoxFit.contain,
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -10, duration: 2.seconds),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESTIMATED PROJECT TOTAL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '₹${(total / 100000).toStringAsFixed(2)} Lakhs',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'for $_totalArea Sq.Ft.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildMaterialEditor(String name, Map<String, dynamic> data) {
    IconData icon = Icons.inventory_2_outlined;
    Color iconColor = Colors.green;
    if (name == 'Steel') {
      icon = Icons.reorder_rounded;
      iconColor = Colors.blue;
    } else if (name.contains('Sand')) {
      icon = Icons.grain;
      iconColor = Colors.orange;
    } else if (name.contains('Brick')) {
      icon = Icons.grid_view_rounded;
      iconColor = Colors.red;
    } else if (name == 'Flooring') {
      icon = Icons.layers_outlined;
      iconColor = Colors.purple;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${data['price_per_unit'].toInt()} / ${data['unit']}',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _customDropdown(data),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _customDropdown(Map<String, dynamic> data) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 0.1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: data['selected'],
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textSec),
          style: const TextStyle(
            color: Color.fromARGB(255, 65, 159, 164),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          items: (data['options'] as List<String>)
              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
              .toList(),
          onChanged: (val) {
            setState(() {
              data['selected'] = val;
              double bp = data['base_price'];
              if (val!.contains('Premium') ||
                  val.contains('TATA') ||
                  val.contains('UltraTech')) {
                data['price_per_unit'] = bp * 1.2;
              } else if (val.contains('Concrete+') || val.contains('JSW')) {
                data['price_per_unit'] = bp * 1.1;
              } else {
                data['price_per_unit'] = bp;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildRealtimeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Prices are updated in real-time',
                  style: TextStyle(
                    color: _textPri,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Market rates may vary based on location',
                  style: TextStyle(
                    color: _textSec,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.circle, color: Color(0xFF22C55E), size: 5),
                SizedBox(width: 4),
                Text(
                  'Live',
                  style: TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: Color.fromARGB(255, 0, 0, 0),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: _purple,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
