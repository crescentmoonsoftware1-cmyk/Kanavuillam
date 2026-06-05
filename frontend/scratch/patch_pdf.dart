import 'dart:io';

void main() async {
  final file = File('lib/services/pdf_service.dart');
  var content = await file.readAsString();

  // 1. Move variables
  final varsToMove = """
      final modelData = data['model_data'] ?? {};
      final floorsData = modelData['floors'];
      final floorsMap = floorsData is Map ? floorsData : {};
      final ground = floorsMap['ground'] as Map<String, dynamic>? ?? {};
      final project = (ground['project'] as Map<String, dynamic>?) ?? (modelData['project'] as Map<String, dynamic>?) ?? {};
      final projWidth = (project['width'] as num?)?.toDouble() ?? 30.0;
      final projHeight = (project['height'] as num?)?.toDouble() ?? 40.0;
  """;
  
  // Remove them from elevation block
  content = content.replaceFirst(
      "final modelData = data['model_data'] ?? {};\n        final floorsData = modelData['floors'];\n        final floors = floorsData is Map ? floorsData : {};\n        final ground = floors['ground'] as Map<String, dynamic>? ?? {};\n        final project = (ground['project'] as Map<String, dynamic>?) ?? (modelData['project'] as Map<String, dynamic>?) ?? {};\n        \n        final projWidth = (project['width'] as num?)?.toDouble() ?? 30.0;\n        final projHeight = (project['height'] as num?)?.toDouble() ?? 40.0;",
      "// variables moved up");
      
  content = content.replaceFirst("final floors = floorsData is Map ? floorsData : {};", "final floors = floorsMap;");

  // Insert before structUrls
  content = content.replaceFirst(
    "final visualData = data['visual_data']",
    "$varsToMove\n      final visualData = data['visual_data']"
  );
  
  // Replace the floor count logic since it was separated
  content = content.replaceFirst(
    "int floorCount = floorsData is int ? floorsData : 1;\n        if (floors.containsKey('first')) floorCount = 2;\n        if (floors.containsKey('second')) floorCount = 3;",
    "int floorCount = floorsData is int ? floorsData : 1;\n        if (floorsMap.containsKey('first')) floorCount = 2;\n        if (floorsMap.containsKey('second')) floorCount = 3;"
  );

  // 2. Add _buildBeamLayout method
  final layoutMethod = """
  static pw.Widget _buildBeamLayout(Map ground, Map structData, double projW, double projH) {
    final walls = ground['walls'] as List? ?? [];
    final columns = structData['structural_layout']?['columns'] as List? ?? [];
    
    return pw.Container(
      height: 300,
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        color: PdfColors.white,
      ),
      child: pw.CustomPaint(
        size: const PdfPoint(400, 300),
        painter: (PdfGraphics canvas, PdfPoint size) {
          final drawW = size.x - 40;
          final drawH = size.y - 40;
          final sX = drawW / projW;
          final sY = drawH / projH;
          
          canvas.saveContext();
          canvas.setTransform(pw.Matrix4.translationValues(20, 20, 0));
          
          canvas.setStrokeColor(PdfColors.black);
          canvas.setLineWidth(1.5);
          for (var w in walls) {
            double x1 = 0, y1 = 0, x2 = 0, y2 = 0;
            if (w['start'] is List) {
              x1 = (w['start'][0] as num).toDouble();
              y1 = (w['start'][1] as num).toDouble();
              x2 = (w['end'][0] as num).toDouble();
              y2 = (w['end'][1] as num).toDouble();
            } else if (w['start_x'] != null) {
              x1 = (w['start_x'] as num).toDouble();
              y1 = (w['start_y'] as num).toDouble();
              x2 = (w['end_x'] as num).toDouble();
              y2 = (w['end_y'] as num).toDouble();
            }
            canvas.drawLine(x1 * sX, y1 * sY, x2 * sX, y2 * sY);
          }
          canvas.strokePath();
          
          canvas.setFillColor(PdfColors.red600);
          for (var c in columns) {
            final cx = (c['x'] as num).toDouble();
            final cy = (c['y'] as num).toDouble();
            final cw = 0.75 * sX;
            final ch = 0.75 * sY;
            canvas.drawRect(cx * sX - cw/2, cy * sY - ch/2, cw, ch);
          }
          canvas.fillPath();
          
          canvas.restoreContext();
        }
      )
    );
  }
}""";

  content = content.replaceFirst("}\n}", "}\n$layoutMethod");
  
  // 3. Insert call in structural page
  content = content.replaceFirst(
    "pw.SizedBox(height: 15),\n                      pw.Text('Beam Schedule',",
    "pw.SizedBox(height: 15),\n                      pw.Text('Beam Layout Plan', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textDark)),\n                      pw.SizedBox(height: 10),\n                      _buildBeamLayout(ground, struct, projWidth, projHeight),\n                      pw.SizedBox(height: 25),\n                      pw.Text('Beam Schedule',"
  );

  await file.writeAsString(content);
  print('Patched successfully');
}
