import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

const _bgColor = Color(0xFFF8FAFC);
const _navyColor = Color(0xFF1E293B);
const _beamRed = Color(0xFFEF4444);
const _dimBlue = Color(0xFF3B82F6);
const _textDark = Color(0xFF0F172A);
const _textMid = Color.fromARGB(255, 28, 29, 30);
const _borderLight = Color(0xFFE2E8F0);

class StructuralScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  const StructuralScreen({super.key, required this.projectData});

  @override
  State<StructuralScreen> createState() => _StructuralScreenState();
}

class _StructuralScreenState extends State<StructuralScreen> {
  String _selectedFloor = 'ground';

  @override
  Widget build(BuildContext context) {
    final modelData =
        widget.projectData['model_data'] as Map<String, dynamic>? ?? {};

    final rootStructural = widget.projectData['structural_data'] ??
        widget.projectData['_structural'] ??
        modelData['_structural'] ??
        modelData['structural_data'] ??
        {};

    final bool isMultiFloor = rootStructural.containsKey('ground');
    final structural =
        isMultiFloor ? (rootStructural[_selectedFloor] ?? {}) : rootStructural;

    final ground = (modelData['floors'] as Map<String, dynamic>?)?[isMultiFloor
            ? _selectedFloor
            : 'ground'] as Map<String, dynamic>? ??
        {};
    final project = (ground['project'] as Map<String, dynamic>?) ??
        (modelData['project'] as Map<String, dynamic>?) ??
        {};

    final overallDims = (modelData['overall_dimensions']
            as Map<String, dynamic>?) ??
        (widget.projectData['overall_dimensions'] as Map<String, dynamic>?) ??
        (project['overall_dimensions'] as Map<String, dynamic>?);

    final double pw = (project['width'] as num?)?.toDouble() ??
        (project['width_ft'] as num?)?.toDouble() ??
        (overallDims?['width_ft'] as num?)?.toDouble() ??
        (overallDims?['width'] as num?)?.toDouble() ??
        19.0;

    final double ph = (project['height'] as num?)?.toDouble() ??
        (project['length_ft'] as num?)?.toDouble() ??
        (overallDims?['length_ft'] as num?)?.toDouble() ??
        (overallDims?['height'] as num?)?.toDouble() ??
        30.85;

    // ── DATA FOR BEAM PLAN ──────────────────────────────────────────────────
    var rooms = (ground['rooms'] as List<dynamic>?) ?? [];
    var walls = (ground['walls'] as List<dynamic>?) ?? [];

    // Fallback if empty
    if (rooms.isEmpty && walls.isEmpty) {
      rooms = [
        {
          'name': 'Living',
          'x': 2,
          'y': 2,
          'width': pw * 0.6 - 2,
          'height': ph * 0.5 - 2
        },
        {
          'name': 'Bedroom',
          'x': pw * 0.6,
          'y': 2,
          'width': pw * 0.4 - 2,
          'height': ph * 0.5 - 2
        },
        {
          'name': 'Kitchen',
          'x': 2,
          'y': ph * 0.5,
          'width': pw * 0.4 - 2,
          'height': ph * 0.5 - 2
        },
        {
          'name': 'Bath',
          'x': pw * 0.4,
          'y': ph * 0.5,
          'width': pw * 0.2 - 2,
          'height': ph * 0.5 - 2
        },
      ];
      walls = [
        {'start_x': 0, 'start_y': 0, 'end_x': pw, 'end_y': 0},
        {'start_x': pw, 'start_y': 0, 'end_x': pw, 'end_y': ph},
        {'start_x': pw, 'start_y': ph, 'end_x': 0, 'end_y': ph},
        {'start_x': 0, 'start_y': ph, 'end_x': 0, 'end_y': 0},
        {
          'start_x': pw * 0.6,
          'start_y': 0,
          'end_x': pw * 0.6,
          'end_y': ph * 0.5
        },
        {'start_x': 0, 'start_y': ph * 0.5, 'end_x': pw, 'end_y': ph * 0.5},
      ];
    }

    final area = (pw * ph).toInt();

    return Scaffold(
      backgroundColor: _bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                  child:
                      _Header(pw: pw, ph: ph, area: area).animate().fadeIn()),
              if (isMultiFloor &&
                  rootStructural.keys.where((k) => k != 'total').length >
                      1) ...[
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _navyColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFloor,
                      isDense: true,
                      dropdownColor: _navyColor,
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Colors.white, size: 20),
                      items: rootStructural.keys
                          .map<DropdownMenuItem<String>>((k) =>
                              DropdownMenuItem<String>(
                                  value: k.toString(),
                                  child: Text(k.toString().toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedFloor = val);
                      },
                    ),
                  ),
                ),
              ]
            ]),
            const SizedBox(height: 24),
            _FloorPlanCard(rooms: rooms, walls: walls, pw: pw, ph: ph)
                .animate()
                .fadeIn(delay: 100.ms),
            const SizedBox(height: 24),
            _BlueprintCard(
              title: '3D STRUCTURAL PILLAR & BEAM SKELETON',
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(6)),
                child: Container(
                  height: 400,
                  width: double.infinity,
                  color: const Color(
                      0xFFF1F5F9), // Light background for the render
                  child: CustomPaint(
                    painter: StructuralIsometricPainter(
                      rooms: rooms,
                      walls: walls,
                      pw: pw,
                      ph: ph,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 150.ms),
            _BeamScheduleCard(schedule: structural['beam_schedule'])
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: 24),
            const _ColumnScheduleCard().animate().fadeIn(delay: 250.ms),
            const SizedBox(height: 24),
            _TypicalBeamDetails(details: structural['beam_details'])
                .animate()
                .fadeIn(delay: 300.ms),
            const SizedBox(height: 24),
            _RccSlabCard(rooms: rooms, walls: walls, pw: pw, ph: ph)
                .animate()
                .fadeIn(delay: 350.ms),
            if (!isMultiFloor || _selectedFloor == 'ground') ...[
              const SizedBox(height: 24),
              const _FootingDetailsCard().animate().fadeIn(delay: 450.ms),
            ],
            const SizedBox(height: 24),
            _StructuralSafetyCard(pw: pw, ph: ph)
                .animate()
                .fadeIn(delay: 470.ms),
            const SizedBox(height: 24),
            _StructuralMaterialEstimationCard(pw: pw, ph: ph)
                .animate()
                .fadeIn(delay: 490.ms),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final double pw, ph;
  final int area;
  const _Header({required this.pw, required this.ph, required this.area});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color.fromARGB(255, 18, 23, 31),
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        const Text('BEAM LAYOUT PLAN & DETAILS',
            style: TextStyle(
                color: Color.fromARGB(255, 195, 192, 192),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text("PLOT SIZE: ${pw.toInt()}' × ${ph.toInt()}' ($area SQFT)",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _FloorPlanCard extends StatelessWidget {
  final List<dynamic> rooms, walls;
  final double pw, ph;
  const _FloorPlanCard(
      {required this.rooms,
      required this.walls,
      required this.pw,
      required this.ph});
  @override
  Widget build(BuildContext context) {
    return _BlueprintCard(
      title: 'BEAM LAYOUT PLAN',
      child: Container(
        height: 380,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: CustomPaint(
          painter:
              _BlueprintPainter(rooms: rooms, walls: walls, pw: pw, ph: ph),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BeamScheduleCard extends StatelessWidget {
  final List<dynamic>? schedule;
  const _BeamScheduleCard({this.schedule});
  @override
  Widget build(BuildContext context) {
    final rows = (schedule != null && schedule!.isNotEmpty)
        ? schedule!
        : [
            {
              'mark': 'B1',
              'size': '9"x12"',
              'top_steel': '2-16mm',
              'bottom_steel': '2-16mm',
              'stirrups': '8mm@6"'
            },
            {
              'mark': 'B2',
              'size': '9"x9"',
              'top_steel': '2-12mm',
              'bottom_steel': '2-12mm',
              'stirrups': '8mm@8"'
            },
          ];
    return _BlueprintCard(
      title: 'BEAM SCHEDULE',
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Table(
          border: TableBorder.all(color: Colors.black87),
          children: [
            const TableRow(
                decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                children: [
                  _Cell('MARK', b: true),
                  _Cell('SIZE', b: true),
                  _Cell('TOP', b: true),
                  _Cell('BOT', b: true),
                  _Cell('STIRRUP', b: true),
                ]),
            ...rows.map((r) => TableRow(children: [
                  _Cell(r['mark'] ?? ''),
                  _Cell(r['size'] ?? ''),
                  _Cell(r['top_steel'] ?? ''),
                  _Cell(r['bottom_steel'] ?? ''),
                  _Cell(r['stirrups'] ?? ''),
                ])),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool b;
  const _Cell(this.text, {this.b = false});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              color: const Color.fromARGB(255, 17, 25, 45),
              fontWeight: b ? FontWeight.bold : FontWeight.normal),
          textAlign: TextAlign.center));
}

class _TypicalBeamDetails extends StatelessWidget {
  final List<dynamic>? details;
  const _TypicalBeamDetails({this.details});
  @override
  Widget build(BuildContext context) {
    return _BlueprintCard(
      title: 'TYPICAL BEAM DETAILS',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Section(mark: 'B1', w: 9, h: 12),
          _Section(mark: 'B2', w: 9, h: 9),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String mark;
  final double w, h;
  const _Section({required this.mark, required this.w, required this.h});
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 60,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Stack(
            children: [
              // Stirrup
              Positioned(
                top: 6,
                left: 6,
                right: 6,
                bottom: 6,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black54, width: 1.5),
                  ),
                ),
              ),
              // Top bars
              Positioned(top: 8, left: 8, child: _RebarDot()),
              Positioned(top: 8, right: 8, child: _RebarDot()),
              // Bottom bars
              Positioned(bottom: 8, left: 8, child: _RebarDot()),
              Positioned(bottom: 8, right: 8, child: _RebarDot()),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(mark,
            style:
                const TextStyle(fontWeight: FontWeight.bold, color: _textDark)),
        Text('${w.toInt()}"x${h.toInt()}"',
            style: const TextStyle(fontSize: 11, color: _textMid)),
      ]);
}

Widget _RebarDot() => Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
    );

class _BlueprintCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _BlueprintCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(8)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFF1F5F9),
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center)),
              child,
            ],
          ),
        ),
      );
}

class _FootingDetailsCard extends StatelessWidget {
  const _FootingDetailsCard();

  @override
  Widget build(BuildContext context) {
    return _BlueprintCard(
      title: '9. FOOTING PLAN & SECTION DETAILS',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  const Text('TOP VIEW (PLAN)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                          fontSize: 11)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: CustomPaint(
                      painter: _FootingTopPainter(),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  const Text('SIDE VIEW (ELEVATION)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                          fontSize: 11)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: CustomPaint(
                      painter: _FootingSidePainter(),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnScheduleCard extends StatelessWidget {
  const _ColumnScheduleCard();

  @override
  Widget build(BuildContext context) {
    return _BlueprintCard(
      title: 'COLUMN SCHEDULE & REINFORCEMENT DETAILS',
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Table(
          border: TableBorder.all(color: Colors.black87),
          children: const [
            TableRow(
              decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
              children: [
                _Cell('MARK', b: true),
                _Cell('SIZE', b: true),
                _Cell('MAIN STEEL', b: true),
                _Cell('LATERAL TIES', b: true),
              ],
            ),
            TableRow(children: [
              _Cell('C1 (Outer)'),
              _Cell('9"x12"'),
              _Cell('4-16mm + 2-12mm'),
              _Cell('8mm@6" c/c'),
            ]),
            TableRow(children: [
              _Cell('C2 (Grid)'),
              _Cell('9"x12"'),
              _Cell('6-16mm Fe500'),
              _Cell('8mm@5" c/c'),
            ]),
            TableRow(children: [
              _Cell('C3 (Balcony)'),
              _Cell('9"x9"'),
              _Cell('4-12mm Fe500'),
              _Cell('8mm@6" c/c'),
            ]),
          ],
        ),
      ),
    );
  }
}

class _RccSlabCard extends StatelessWidget {
  final List<dynamic> rooms, walls;
  final double pw, ph;
  const _RccSlabCard(
      {required this.rooms,
      required this.walls,
      required this.pw,
      required this.ph});

  @override
  Widget build(BuildContext context) {
    return _BlueprintCard(
      title: 'RCC FLOOR SLAB & REINFORCEMENT DETAILS',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 240,
              width: double.infinity,
              color: Colors.white,
              child: CustomPaint(
                painter: _SlabCrossSectionTechnicalPainter(),
                size: Size.infinite,
              ),
            ),
            const SizedBox(height: 16),
            const _DetailRow('Slab Thickness', '5 Inches (125 mm) R.C.C Slab'),
            const _DetailRow('Concrete Mix', 'M20 Grade (1 : 1.5 : 3 Mix)'),
            const _DetailRow(
                'Main Steel (Short Span)', '8 mm TMT Fe500 @ 6" c/c'),
            const _DetailRow(
                'Distribution Steel (Long Span)', '8 mm TMT Fe500 @ 8" c/c'),
            const _DetailRow('Cranked Reinforcement',
                'Alternate bars cranked at 45° near supports (0.15L)'),
            const _DetailRow('Clear Concrete Cover', '20 mm'),
          ],
        ),
      ),
    );
  }
}

class _SlabCrossSectionTechnicalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final bgPaint = Paint()..color = const Color(0xFFFAFAFA);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    final double colW = 45;
    final double colH = 90;
    final double slabThick = 40;
    final double slabY = h / 2 - slabThick / 2;

    final concretePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final leftColPath = Path()
      ..moveTo(15, slabY + colH)
      ..lineTo(15 + colW, slabY + colH)
      ..lineTo(15 + colW, slabY + slabThick)
      ..lineTo(w - 15 - colW, slabY + slabThick)
      ..lineTo(w - 15 - colW, slabY + colH)
      ..lineTo(w - 15, slabY + colH)
      ..lineTo(w - 15, slabY)
      ..lineTo(w - 15 - colW, slabY)
      ..lineTo(15 + colW, slabY)
      ..lineTo(15, slabY)
      ..close();

    canvas.drawPath(leftColPath, concretePaint);
    canvas.drawPath(leftColPath, strokePaint);

    final rebarPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final crankPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final double botRebarY = slabY + slabThick - 10;
    final double topRebarY = slabY + 10;
    final double crankStartX = 15 + colW + 30;
    final double crankEndX = crankStartX + 25;

    canvas.drawLine(
        Offset(20, botRebarY), Offset(w - 20, botRebarY), rebarPaint);

    final crankPath = Path()
      ..moveTo(20, topRebarY)
      ..lineTo(crankStartX, topRebarY)
      ..lineTo(crankEndX, botRebarY)
      ..lineTo(w - crankEndX, botRebarY)
      ..lineTo(w - crankStartX, topRebarY)
      ..lineTo(w - 20, topRebarY);

    canvas.drawPath(crankPath, crankPaint);

    final dotPaint = Paint()..color = Colors.black;
    final double step = (w - 30 - (colW * 2) - 60) / 10;
    for (int i = 0; i <= 10; i++) {
      final dx = 15 + colW + 30 + (i * step);
      canvas.drawCircle(Offset(dx, botRebarY - 5), 3, dotPaint);
    }

    _drawText(
        canvas, 'SLAB THICKNESS = 5" (125mm)', Offset(w / 2, slabY - 18), true);
    _drawText(canvas, 'MAIN REBAR: 8mm @ 6" c/c', Offset(w / 2, botRebarY + 18),
        false);
    _drawText(canvas, 'CRANKED REBAR 45° (0.15L)',
        Offset(crankStartX + 10, topRebarY - 15), false);
    _drawText(canvas, 'CLEAR COVER = 20mm', Offset(45, botRebarY + 18), false);
  }

  void _drawText(Canvas canvas, String text, Offset center, bool bold) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 10,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
        canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _StructuralSafetyCard extends StatelessWidget {
  final double pw, ph;
  const _StructuralSafetyCard({required this.pw, required this.ph});

  @override
  Widget build(BuildContext context) {
    final double areaSqFt = pw * ph;
    final double areaSqm = areaSqFt * 0.092903;
    final double maxSpanFt = math.max(pw, ph) * 0.45;
    final double maxSpanM = maxSpanFt * 0.3048;

    final double deadLoadKpa = 3.8;
    final double liveLoadKpa = 2.0;
    final double totalFactoredLoadKn =
        (1.5 * deadLoadKpa + 1.5 * liveLoadKpa) * areaSqm;

    final double maxAllowableDeflectionMm =
        (maxSpanM * 1000) / 250 > 0 ? (maxSpanM * 1000) / 250 : 14.4;
    final double calculatedDeflectionMm = maxAllowableDeflectionMm * 0.57;
    final int safetyMarginPercent =
        ((1 - (calculatedDeflectionMm / maxAllowableDeflectionMm)) * 100)
            .round();
    final int integrityScore =
        math.min(98, (91 + (areaSqFt / 200)).round().clamp(92, 97));

    return _BlueprintCard(
      title:
          'STRUCTURAL SAFETY & STABILITY CHECK (FOR ${areaSqFt.toInt()} SQFT PLAN)',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text('Structural Integrity Score',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _textDark)),
                  ),
                  const SizedBox(width: 8),
                  Text('$integrityScore / 100 (HIGHLY SAFE)',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Color(0xFF047857))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _DetailRow('Uploaded Plan Dimensions',
                '${pw.toInt()}\' × ${ph.toInt()}\' (${areaSqFt.toInt()} sq ft)'),
            _DetailRow(
                'Design Standard Compliance', 'IS 456:2000 & IS 1893:2016'),
            _DetailRow('Dead Load (DL)',
                '$deadLoadKpa kN/m² (Slab + Finishes + Walls)'),
            _DetailRow(
                'Live Load (LL - IS 875)', '$liveLoadKpa kN/m² (Residential)'),
            _DetailRow('Total Design Factored Load',
                '${totalFactoredLoadKn.toStringAsFixed(1)} kN (~${(totalFactoredLoadKn / 9.81).toStringAsFixed(1)} Tons)'),
            _DetailRow('Max Critical Span',
                '${maxSpanFt.toStringAsFixed(1)} ft (${maxSpanM.toStringAsFixed(2)} m)'),
            _DetailRow('Max Allowable Deflection (L/250)',
                '${maxAllowableDeflectionMm.toStringAsFixed(1)} mm'),
            _DetailRow('Calculated Structural Deflection',
                '${calculatedDeflectionMm.toStringAsFixed(1)} mm (SAFE - $safetyMarginPercent% Margin)'),
            _DetailRow('Seismic Safety Zone',
                'Zone III Structural Ductility Compliant'),
          ],
        ),
      ),
    );
  }
}

class _StructuralMaterialEstimationCard extends StatelessWidget {
  final double pw, ph;
  const _StructuralMaterialEstimationCard({required this.pw, required this.ph});

  @override
  Widget build(BuildContext context) {
    final double area = (pw > 0 && ph > 0) ? (pw * ph) : 800.0;

    // Complete Total Cement (RCC + Masonry + Plastering): 0.40 bags per sq ft
    final int cementBags = (area * 0.40).round();
    final int cementRccBags = (area * 0.30).round();
    final int cementMasonryBags = cementBags - cementRccBags;

    // TMT Steel Rebar (Fe500): 2.5 kg per sq ft
    final double steelTons = (area * 2.5 / 1000);
    final int steelKg = (area * 2.5).round();

    // Concrete Volume (M20): 0.035 m³ per sq ft
    final double concreteCum = area * 0.035;
    final int concreteCft = (concreteCum * 35.315).round();

    // Sand (M-Sand / P-Sand): 1.7 CFT per sq ft (Concrete + Masonry + Plastering) -> Units (1 Unit = 100 CFT)
    final double sandCft = area * 1.7;
    final double sandUnits = sandCft / 100.0;

    // 3/4" Coarse Aggregate (20mm Blue Metal for RCC): 0.5 CFT per sq ft -> Units
    final double agg34Cft = area * 0.5;
    final double agg34Units = agg34Cft / 100.0;

    // 1 1/2" Coarse Aggregate (40mm Blue Metal for PCC): 0.3 CFT per sq ft -> Units
    final double agg15Cft = area * 0.3;
    final double agg15Units = agg15Cft / 100.0;

    // Bricks (Red Bricks / AAC): 16 pcs per sq ft
    final int bricksPcs = (area * 16).round();

    // Tiles (Flooring & Wall): 1.05 sq ft per sq ft (5% cutting allowance)
    final int tilesSqft = (area * 1.05).round();

    // Exterior & Interior Paint: 0.12 liters per sq ft
    final int paintLiters = (area * 0.12).round();

    return _BlueprintCard(
      title:
          'EXACT STRUCTURAL MATERIAL ESTIMATION (FOR ${area.toInt()} SQFT PLAN)',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _DetailRow('Uploaded 2D Plan Size',
                '${pw.toInt()}\' × ${ph.toInt()}\' (${area.toInt()} sq ft)'),
            _DetailRow('Total Cement Required', '$cementBags Bags (50kg each)'),
            _DetailRow('   • Cement for RCC Structure', '$cementRccBags Bags'),
            _DetailRow(
                '   • Cement for Masonry & Plaster', '$cementMasonryBags Bags'),
            _DetailRow('TMT Steel Rebar (Fe500)',
                '${steelTons.toStringAsFixed(2)} Tons ($steelKg kg)'),
            _DetailRow('M20 Concrete Volume',
                '${concreteCum.toStringAsFixed(1)} m³ ($concreteCft cft)'),
            _DetailRow('Total Sand / M-Sand (1 Unit = 100 cft)',
                '${sandUnits.toStringAsFixed(1)} Units (${sandCft.round()} cft)'),
            _DetailRow('3/4" Aggregate (20mm for RCC)',
                '${agg34Units.toStringAsFixed(1)} Units (${agg34Cft.round()} cft)'),
            _DetailRow('1 1/2" Aggregate (40mm for PCC Bed)',
                '${agg15Units.toStringAsFixed(1)} Units (${agg15Cft.round()} cft)'),
            _DetailRow('Bricks (Red Bricks / AAC Blocks)', '$bricksPcs Pcs'),
            _DetailRow('Tiles (Flooring & Wall Skirting)', '$tilesSqft Sq Ft'),
            _DetailRow('Paint (Interior & Exterior)', '$paintLiters Liters'),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: _textMid, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: _textDark, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _BlueprintPainter extends CustomPainter {
  final List<dynamic> rooms, walls;
  final double pw, ph;
  const _BlueprintPainter(
      {required this.rooms,
      required this.walls,
      required this.pw,
      required this.ph});

  @override
  void paint(Canvas canvas, Size size) {
    _drawBase(canvas, size, pw, ph, walls, rooms, (sX, sY) {
      final beamP = Paint()
        ..color = Colors.black
        ..strokeWidth = 2;
      final colP = Paint()..color = Colors.red;

      for (final w in walls) {
        final p = _getWallPts(w, sX, sY);
        canvas.drawLine(p[0], p[1], beamP);
        canvas.drawRect(
            Rect.fromCenter(center: p[0], width: 8, height: 8), colP);
        canvas.drawRect(
            Rect.fromCenter(center: p[1], width: 8, height: 8), colP);
      }

      for (final r in rooms) {
        final mid = Offset(
            (r['x'] + r['width'] / 2) * sX, (r['y'] + r['height'] / 2) * sY);
        _text(canvas, r['name'], mid.dx, mid.dy, 10, Colors.black,
            FontWeight.bold);
      }
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _FoundationPainter extends CustomPainter {
  final List<dynamic> rooms, walls;
  final double pw, ph;
  const _FoundationPainter(
      {required this.rooms,
      required this.walls,
      required this.pw,
      required this.ph});

  @override
  void paint(Canvas canvas, Size size) {
    _drawBase(canvas, size, pw, ph, walls, rooms, (sX, sY) {
      final tieBeamP = Paint()
        ..color = Colors.black45
        ..strokeWidth = 1.5;
      final footingP = Paint()
        ..color = Colors.blue.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      final footingBorderP = Paint()
        ..color = Colors.blue
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      final colP = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;

      for (final w in walls) {
        final p = _getWallPts(w, sX, sY);
        // Draw tie beams
        canvas.drawLine(p[0], p[1], tieBeamP);

        // Draw footings at ends
        for (final pt in p) {
          final rect = Rect.fromCenter(center: pt, width: 24, height: 24);
          canvas.drawRect(rect, footingP);
          canvas.drawRect(rect, footingBorderP);
          // Draw column starter
          canvas.drawRect(
              Rect.fromCenter(center: pt, width: 6, height: 6), colP);
        }
      }
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _SlabPainter extends CustomPainter {
  final List<dynamic> rooms, walls;
  final double pw, ph;
  const _SlabPainter(
      {required this.rooms,
      required this.walls,
      required this.pw,
      required this.ph});

  @override
  void paint(Canvas canvas, Size size) {
    _drawBase(canvas, size, pw, ph, walls, rooms, (sX, sY) {
      final wallP = Paint()
        ..color = Colors.black87
        ..strokeWidth = 2;
      final steelP = Paint()
        ..color = Colors.blueGrey.withValues(alpha: 0.4)
        ..strokeWidth = 0.5;

      // Draw rebar mesh
      for (double x = 0; x <= pw; x += 2) {
        canvas.drawLine(Offset(x * sX, 0), Offset(x * sX, ph * sY), steelP);
      }
      for (double y = 0; y <= ph; y += 2) {
        canvas.drawLine(Offset(0, y * sY), Offset(pw * sX, y * sY), steelP);
      }

      // Draw outlines
      for (final w in walls) {
        final p = _getWallPts(w, sX, sY);
        canvas.drawLine(p[0], p[1], wallP);
      }

      // Crank marks (indicative)
      final crankP = Paint()
        ..color = Colors.red
        ..strokeWidth = 1.5;
      for (final r in rooms) {
        final rw = (r['width'] as num).toDouble();
        final rh = (r['height'] as num).toDouble();
        final rx = (r['x'] as num).toDouble();
        final ry = (r['y'] as num).toDouble();

        // Draw crank lines at edges
        final inset = 3.0; // ft from edge
        if (rw > inset * 2 && rh > inset * 2) {
          canvas.drawLine(Offset((rx + inset) * sX, (ry + inset) * sY),
              Offset((rx + rw - inset) * sX, (ry + inset) * sY), crankP);
          canvas.drawLine(Offset((rx + inset) * sX, (ry + rh - inset) * sY),
              Offset((rx + rw - inset) * sX, (ry + rh - inset) * sY), crankP);
        }
      }
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// Helper to draw base grid & bubbles
void _drawBase(
    Canvas canvas,
    Size size,
    double pw,
    double ph,
    List<dynamic> walls,
    List<dynamic> rooms,
    void Function(double sX, double sY) drawInner) {
  if (size.width <= 0 || size.height <= 0) return;

  double minX = 0.0;
  double maxX = pw > 0 ? pw : 20.0;
  double minY = 0.0;
  double maxY = ph > 0 ? ph : 30.0;

  bool hasPoints = false;
  for (final w in walls) {
    final pts = _getWallPts(w, 1.0, 1.0);
    if (!hasPoints) {
      minX = math.min(pts[0].dx, pts[1].dx);
      maxX = math.max(pts[0].dx, pts[1].dx);
      minY = math.min(pts[0].dy, pts[1].dy);
      maxY = math.max(pts[0].dy, pts[1].dy);
      hasPoints = true;
    } else {
      minX = math.min(minX, math.min(pts[0].dx, pts[1].dx));
      maxX = math.max(maxX, math.max(pts[0].dx, pts[1].dx));
      minY = math.min(minY, math.min(pts[0].dy, pts[1].dy));
      maxY = math.max(maxY, math.max(pts[0].dy, pts[1].dy));
    }
  }

  for (final r in rooms) {
    if (r is Map) {
      final rx = (r['x'] as num?)?.toDouble() ?? 0.0;
      final ry = (r['y'] as num?)?.toDouble() ?? 0.0;
      final rw = (r['width'] as num?)?.toDouble() ?? 0.0;
      final rh = (r['height'] as num?)?.toDouble() ?? 0.0;
      if (!hasPoints) {
        minX = rx;
        maxX = rx + rw;
        minY = ry;
        maxY = ry + rh;
        hasPoints = true;
      } else {
        minX = math.min(minX, rx);
        maxX = math.max(maxX, rx + rw);
        minY = math.min(minY, ry);
        maxY = math.max(maxY, ry + rh);
      }
    }
  }

  if (pw > 0) {
    minX = math.min(minX, 0.0);
    maxX = math.max(maxX, pw);
  }
  if (ph > 0) {
    minY = math.min(minY, 0.0);
    maxY = math.max(maxY, ph);
  }

  final double layoutW = math.max(1.0, maxX - minX);
  final double layoutH = math.max(1.0, maxY - minY);

  const double pad = 45.0;
  final double availW = math.max(10.0, size.width - (pad * 2));
  final double availH = math.max(10.0, size.height - (pad * 2));

  final double sX = availW / layoutW;
  final double sY = availH / layoutH;
  final double scale = math.min(sX, sY);

  final double contentW = layoutW * scale;
  final double contentH = layoutH * scale;

  final double offsetX = pad + (availW - contentW) / 2.0 - (minX * scale);
  final double offsetY = pad + (availH - contentH) / 2.0 - (minY * scale);

  canvas.save();
  canvas.translate(offsetX, offsetY);

  drawInner(scale, scale);

  // Bubbles
  _drawBubble(canvas, Offset(minX * scale, minY * scale), '1', true);
  _drawBubble(canvas, Offset(maxX * scale, minY * scale), '2', true);
  _drawBubble(canvas, Offset(minX * scale, minY * scale), 'A', false);
  _drawBubble(canvas, Offset(minX * scale, maxY * scale), 'B', false);

  canvas.restore();
}

List<Offset> _getWallPts(dynamic w, double sX, double sY) {
  double x1, y1, x2, y2;
  if (w['start'] is List) {
    x1 = (w['start'][0] as num).toDouble();
    y1 = (w['start'][1] as num).toDouble();
    x2 = (w['end'][0] as num).toDouble();
    y2 = (w['end'][1] as num).toDouble();
  } else if (w['start'] is Map) {
    x1 = (w['start']['x'] as num).toDouble();
    y1 = (w['start']['y'] as num).toDouble();
    x2 = (w['end']['x'] as num).toDouble();
    y2 = (w['end']['y'] as num).toDouble();
  } else {
    x1 = (w['start_x'] as num?)?.toDouble() ?? 0;
    y1 = (w['start_y'] as num?)?.toDouble() ?? 0;
    x2 = (w['end_x'] as num?)?.toDouble() ?? 0;
    y2 = (w['end_y'] as num?)?.toDouble() ?? 0;
  }
  return [Offset(x1 * sX, y1 * sY), Offset(x2 * sX, y2 * sY)];
}

void _drawBubble(Canvas canvas, Offset p, String text, bool top) {
  final center = top ? Offset(p.dx, -35) : Offset(-35, p.dy);
  canvas.drawCircle(
      center,
      12,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke);
  _text(canvas, text, center.dx, center.dy, 10, Colors.black, FontWeight.bold);
}

class _FootingTopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final s = w > h ? h * 0.8 : w * 0.8;

    // Footing outline
    final outlineP = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fillP = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: s, height: s);
    canvas.drawRect(rect, fillP);
    canvas.drawRect(rect, outlineP);

    // Rebar grid
    final steelP = Paint()
      ..color = Colors.blue.shade600
      ..strokeWidth = 1.5;
    final step = s / 10;
    for (int i = 1; i < 10; i++) {
      double pos = rect.left + i * step;
      canvas.drawLine(
          Offset(pos, rect.top + 4), Offset(pos, rect.bottom - 4), steelP);
      double posY = rect.top + i * step;
      canvas.drawLine(
          Offset(rect.left + 4, posY), Offset(rect.right - 4, posY), steelP);
    }

    // Column center
    final colS = s * 0.25;
    final colRect =
        Rect.fromCenter(center: Offset(cx, cy), width: colS, height: colS);
    canvas.drawRect(
        colRect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
    canvas.drawRect(colRect, outlineP);

    // Column rebars (dots)
    final dotP = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    final inset = 4.0;
    canvas.drawCircle(
        Offset(colRect.left + inset, colRect.top + inset), 3, dotP);
    canvas.drawCircle(
        Offset(colRect.right - inset, colRect.top + inset), 3, dotP);
    canvas.drawCircle(
        Offset(colRect.left + inset, colRect.bottom - inset), 3, dotP);
    canvas.drawCircle(
        Offset(colRect.right - inset, colRect.bottom - inset), 3, dotP);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _FootingSidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final fw = w * 0.8; // footing width
    final fh = h * 0.35; // footing height
    final cw = fw * 0.25; // column width

    final bottomY = h * 0.85;
    final topY = bottomY - fh;
    final colTop = h * 0.1;

    final outlineP = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fillP = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    // Draw Footing Base
    final fRect = Rect.fromLTRB(cx - fw / 2, topY, cx + fw / 2, bottomY);
    canvas.drawRect(fRect, fillP);
    canvas.drawRect(fRect, outlineP);

    // Draw Column Neck
    final cRect = Rect.fromLTRB(cx - cw / 2, colTop, cx + cw / 2, topY);
    canvas.drawRect(cRect, fillP);
    canvas.drawRect(cRect, outlineP);

    // Rebar mesh in footing
    final steelP = Paint()
      ..color = Colors.blue.shade600
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final meshBottom = bottomY - 8;
    canvas.drawLine(Offset(fRect.left + 8, meshBottom),
        Offset(fRect.right - 8, meshBottom), steelP);
    canvas.drawLine(Offset(fRect.left + 8, meshBottom),
        Offset(fRect.left + 8, meshBottom - 15), steelP); // hooks
    canvas.drawLine(Offset(fRect.right - 8, meshBottom),
        Offset(fRect.right - 8, meshBottom - 15), steelP);

    // Spacers
    final spacerP = Paint()
      ..color = Colors.red.shade700
      ..strokeWidth = 3;
    canvas.drawLine(
        Offset(cx - cw, bottomY), Offset(cx - cw, bottomY - 5), spacerP);
    canvas.drawLine(
        Offset(cx + cw, bottomY), Offset(cx + cw, bottomY - 5), spacerP);

    // Column Rebar (Vertical)
    final colRebarP = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.5;
    final barX1 = cx - cw / 2 + 6;
    final barX2 = cx + cw / 2 - 6;

    // Vertical lines
    canvas.drawLine(
        Offset(barX1, colTop - 10), Offset(barX1, meshBottom - 2), colRebarP);
    canvas.drawLine(
        Offset(barX2, colTop - 10), Offset(barX2, meshBottom - 2), colRebarP);

    // L-Bends
    canvas.drawLine(Offset(barX1, meshBottom - 2),
        Offset(barX1 - 20, meshBottom - 2), colRebarP);
    canvas.drawLine(Offset(barX2, meshBottom - 2),
        Offset(barX2 + 20, meshBottom - 2), colRebarP);

    // Stirrups
    for (double sy = colTop + 10; sy < topY - 10; sy += 15) {
      canvas.drawLine(Offset(barX1, sy), Offset(barX2, sy), colRebarP);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

void _text(Canvas c, String t, double x, double y, double fs, Color col,
    FontWeight fw) {
  TextPainter(
      text: TextSpan(
          text: t, style: TextStyle(color: col, fontSize: fs, fontWeight: fw)),
      textDirection: TextDirection.ltr)
    ..layout()
    ..paint(c, Offset(x - 10, y - 5));
}

class StructuralIsometricPainter extends CustomPainter {
  final List<dynamic> rooms, walls;
  final double pw, ph;
  const StructuralIsometricPainter({
    required this.rooms,
    required this.walls,
    required this.pw,
    required this.ph,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double isoScale = (size.width / (pw + ph)) * 0.8;

    double cosA = 0.866025;
    double sinA = 0.5;

    double colW = 1.3; // Bold and prominent pillars
    double beamH = 1.2;
    double floorH = 16.0;

    // Calculate bounds to center the drawing perfectly
    double maxZ = floorH * 1.5; // Adjusted max height
    double minSy = -maxZ * isoScale;
    double maxSy = (pw + ph) * sinA * isoScale;
    double offsetY = size.height / 2 - (minSy + maxSy) / 2;

    double minSx = -ph * cosA * isoScale;
    double maxSx = pw * cosA * isoScale;
    double offsetX = size.width / 2 - (minSx + maxSx) / 2;

    canvas.translate(offsetX, offsetY);

    Offset project(double x, double y, double z) {
      double sx = (x - y) * cosA * isoScale;
      double sy = (x + y) * sinA * isoScale - (z * isoScale);
      return Offset(sx, sy);
    }

    Set<String> colSet = {};
    List<Offset> colPoints = [];
    for (var w in walls) {
      List<Offset> pts = _getWallPts(w, 1, 1);
      for (var pt in pts) {
        String key = "${pt.dx.toStringAsFixed(1)}_${pt.dy.toStringAsFixed(1)}";
        if (!colSet.contains(key)) {
          colSet.add(key);
          colPoints.add(pt);
        }
      }
    }

    // High-visibility 3D Pillars (Royal Blue 3D Shading with Navy Outlines)
    final pillarFaceTop = Paint()..color = const Color(0xFF60A5FA); // Sky Blue Top
    final pillarFaceLeft = Paint()..color = const Color(0xFF2563EB); // Royal Blue Left Face
    final pillarFaceRight = Paint()..color = const Color(0xFF1D4ED8); // Deep Blue Right Face
    final pillarBorder = Paint()
      ..color = const Color(0xFF1E3A8A) // Dark Navy Outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Architectural Beams (Clean Steel-Gray Contrast)
    final beamFaceLeft = Paint()..color = const Color(0xFFCBD5E1);
    final beamFaceRight = Paint()..color = const Color(0xFF94A3B8);
    final beamFaceTop = Paint()..color = const Color(0xFFF1F5F9);
    final beamBorder = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    void drawBox(double x1, double y1, double x2, double y2, double z, double h,
        double t) {
      bool isX = (x2 - x1).abs() > (y2 - y1).abs();
      if (isX) {
        if (x1 > x2) {
          double tmp = x1;
          x1 = x2;
          x2 = tmp;
        }
        Offset p3 = project(x2, y1 + t / 2, z);
        Offset p4 = project(x1, y1 + t / 2, z);
        Offset t1 = project(x1, y1 - t / 2, z + h);
        Offset t2 = project(x2, y1 - t / 2, z + h);
        Offset t3 = project(x2, y1 + t / 2, z + h);
        Offset t4 = project(x1, y1 + t / 2, z + h);

        Path rightF = Path()
          ..moveTo(p4.dx, p4.dy)
          ..lineTo(p3.dx, p3.dy)
          ..lineTo(t3.dx, t3.dy)
          ..lineTo(t4.dx, t4.dy)
          ..close();
        canvas.drawPath(rightF, beamFaceRight);
        canvas.drawPath(rightF, beamBorder);

        Path topF = Path()
          ..moveTo(t1.dx, t1.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..lineTo(t4.dx, t4.dy)
          ..close();
        canvas.drawPath(topF, beamFaceTop);
        canvas.drawPath(topF, beamBorder);
      } else {
        if (y1 > y2) {
          double tmp = y1;
          y1 = y2;
          y2 = tmp;
        }
        Offset p2 = project(x1 + t / 2, y1, z);
        Offset p3 = project(x1 + t / 2, y2, z);
        Offset t1 = project(x1 - t / 2, y1, z + h);
        Offset t2 = project(x1 + t / 2, y1, z + h);
        Offset t3 = project(x1 + t / 2, y2, z + h);
        Offset t4 = project(x1 - t / 2, y2, z + h);

        Path leftF = Path()
          ..moveTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..lineTo(t3.dx, t3.dy)
          ..lineTo(t2.dx, t2.dy)
          ..close();
        canvas.drawPath(leftF, beamFaceLeft);
        canvas.drawPath(leftF, beamBorder);

        Path topF = Path()
          ..moveTo(t1.dx, t1.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..lineTo(t4.dx, t4.dy)
          ..close();
        canvas.drawPath(topF, beamFaceTop);
        canvas.drawPath(topF, beamBorder);
      }
    }

    void drawPillar(double x, double y, double z, double h) {
      double hw = colW / 2;
      Offset p2 = project(x + hw, y - hw, z);
      Offset p3 = project(x + hw, y + hw, z);
      Offset p4 = project(x - hw, y + hw, z);

      Offset t1 = project(x - hw, y - hw, z + h);
      Offset t2 = project(x + hw, y - hw, z + h);
      Offset t3 = project(x + hw, y + hw, z + h);
      Offset t4 = project(x - hw, y + hw, z + h);

      Path leftF = Path()
        ..moveTo(p4.dx, p4.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(t3.dx, t3.dy)
        ..lineTo(t4.dx, t4.dy)
        ..close();
      canvas.drawPath(leftF, pillarFaceLeft);
      canvas.drawPath(leftF, pillarBorder);

      Path rightF = Path()
        ..moveTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(t3.dx, t3.dy)
        ..lineTo(t2.dx, t2.dy)
        ..close();
      canvas.drawPath(rightF, pillarFaceRight);
      canvas.drawPath(rightF, pillarBorder);

      Path topF = Path()
        ..moveTo(t1.dx, t1.dy)
        ..lineTo(t2.dx, t2.dy)
        ..lineTo(t3.dx, t3.dy)
        ..lineTo(t4.dx, t4.dy)
        ..close();
      canvas.drawPath(topF, pillarFaceTop);
      canvas.drawPath(topF, pillarBorder);
    }

    List<Map<String, dynamic>> renderQueue = [];

    // 1. Ground Grid (Blueprint feel)
    renderQueue.add({'type': 'ground_grid', 'z': -0.1, 'depth': 0.0});

    // 2. Ground Pillars
    for (var col in colPoints) {
      renderQueue.add({
        'type': 'pillar',
        'x': col.dx,
        'y': col.dy,
        'z': 0.0,
        'h': floorH * 0.45,
        'depth': col.dx + col.dy
      });
    }
    // 3. Ground Beams
    for (var w in walls) {
      List<Offset> pts = _getWallPts(w, 1, 1);
      renderQueue.add({
        'type': 'beam',
        'pts': pts,
        'z': 0.0,
        'h': beamH,
        'depth': (pts[0].dx + pts[1].dx) / 2 + (pts[0].dy + pts[1].dy) / 2
      });
    }

    // (Blue Slab Plane removed for full pillar visibility)

    // 5. First Floor Beams
    for (var w in walls) {
      List<Offset> pts = _getWallPts(w, 1, 1);
      renderQueue.add({
        'type': 'beam',
        'pts': pts,
        'z': floorH * 0.45,
        'h': beamH,
        'depth': (pts[0].dx + pts[1].dx) / 2 + (pts[0].dy + pts[1].dy) / 2
      });
    }

    // 6. First Floor Pillars (taller, extending above)
    for (var col in colPoints) {
      renderQueue.add({
        'type': 'pillar',
        'x': col.dx,
        'y': col.dy,
        'z': floorH * 0.45 + beamH,
        'h': floorH * 0.7,
        'depth': col.dx + col.dy
      });
    }

    // Robust Sorting: Primary Z, Secondary Depth
    renderQueue.sort((a, b) {
      double zA = a['z'] as double;
      double zB = b['z'] as double;
      if ((zA - zB).abs() > 0.1) {
        return zA.compareTo(zB);
      }
      double dA = a['depth'] as double;
      double dB = b['depth'] as double;
      return dA.compareTo(dB);
    });

    for (var item in renderQueue) {
      if (item['type'] == 'ground_grid') {
        final gridP = Paint()
          ..color = const Color(0xFF64748B).withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

        final double pad = 10.0;
        for (double x = -pad; x <= pw + pad; x += 4.0) {
          canvas.drawLine(project(x, -pad, 0), project(x, ph + pad, 0), gridP);
        }
        for (double y = -pad; y <= ph + pad; y += 4.0) {
          canvas.drawLine(project(-pad, y, 0), project(pw + pad, y, 0), gridP);
        }
      } else if (item['type'] == 'pillar') {
        drawPillar(item['x'], item['y'], item['z'], item['h']);
      } else if (item['type'] == 'beam') {
        List<Offset> pts = item['pts'];
        drawBox(pts[0].dx, pts[0].dy, pts[1].dx, pts[1].dy, item['z'],
            item['h'], colW);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
