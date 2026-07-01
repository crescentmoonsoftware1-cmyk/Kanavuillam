import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'viewer_screen.dart';

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

    final pw = (project['width'] as num?)?.toDouble() ?? 38.0;
    final ph = (project['height'] as num?)?.toDouble() ?? 36.0;

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
              title: '3. 3D STRUCTURAL PILLAR & BEAM SKELETON',
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(6), bottomRight: Radius.circular(6)),
                child: SizedBox(
                  height: 350,
                  child: ViewerScreen(
                    projectData: widget.projectData,
                    isStructural: true,
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            _BeamScheduleCard(schedule: structural['beam_schedule'])
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: 24),
            _TypicalBeamDetails(details: structural['beam_details'])
                .animate()
                .fadeIn(delay: 300.ms),
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            const _FootingDetailsCard().animate().fadeIn(delay: 450.ms),
            const SizedBox(height: 24),
            _StructuralMaterialEstimationCard(
                    estimation: structural['material_estimation'])
                .animate()
                .fadeIn(delay: 460.ms),
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
      title: '2. BEAM LAYOUT PLAN',
      child: AspectRatio(
        aspectRatio: pw / (ph * 1.3),
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
      title: '4. BEAM SCHEDULE',
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
      title: '6. TYPICAL BEAM DETAILS',
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
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFF1F5F9),
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          child,
        ]),
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

class _StructuralMaterialEstimationCard extends StatelessWidget {
  final Map<String, dynamic>? estimation;
  const _StructuralMaterialEstimationCard({this.estimation});

  @override
  Widget build(BuildContext context) {
    final e = estimation ??
        {
          'cement_bags': 450,
          'steel_kg': 4200,
          'sand_cft': 1800,
          'aggregate_cft': 2200
        };

    return _BlueprintCard(
      title: '10. STRUCTURAL MATERIAL ESTIMATION',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _DetailRow('Cement', '${e['cement_bags']} Bags'),
            _DetailRow('Steel (Rebar)', '${e['steel_kg']} kg'),
            _DetailRow('Sand', '${e['sand_cft']} cft'),
            _DetailRow('Aggregate', '${e['aggregate_cft']} cft'),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: _textMid, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: _textDark, fontSize: 13)),
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
    _drawBase(canvas, size, pw, ph, (sX, sY) {
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
    _drawBase(canvas, size, pw, ph, (sX, sY) {
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
    _drawBase(canvas, size, pw, ph, (sX, sY) {
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
void _drawBase(Canvas canvas, Size size, double pw, double ph,
    void Function(double sX, double sY) drawInner) {
  const double padLeft = 60;
  const double padTop = 60;
  canvas.translate(padLeft, padTop);

  final drawW = size.width - padLeft - 20;
  final drawH = size.height - padTop - 20;
  final sX = drawW / pw;
  final sY = drawH / ph;

  drawInner(sX, sY);

  // Bubbles
  _drawBubble(canvas, Offset(0, 0), '1', true);
  _drawBubble(canvas, Offset(pw * sX, 0), '2', true);
  _drawBubble(canvas, Offset(0, 0), 'A', false);
  _drawBubble(canvas, Offset(0, ph * sY), 'B', false);
}

List<Offset> _getWallPts(dynamic w, double sX, double sY) {
  double x1, y1, x2, y2;
  if (w['start'] is List) {
    x1 = (w['start'][0] as num).toDouble();
    y1 = (w['start'][1] as num).toDouble();
    x2 = (w['end'][0] as num).toDouble();
    y2 = (w['end'][1] as num).toDouble();
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
