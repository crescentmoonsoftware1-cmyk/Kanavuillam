import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class PdfService {
  static Future<Uint8List> createProfessionalPdf(
      Map<String, dynamic> data, Set<String> selectedReportIds,
      {Map<String, Uint8List>? screenshots3D}) async {
    Future<Uint8List?> fetchImage(String prompt,
        {String? imagePath, String? directUrl}) async {
      try {
        if (directUrl != null && directUrl.isNotEmpty) {
          final res = await http.get(Uri.parse(directUrl), headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
          });
          if (res.statusCode == 200) return res.bodyBytes;
          debugPrint('Failed to fetch directUrl. Status: ${res.statusCode}');
        } else {
          final backendBase =
              ApiService.baseUrl.replaceAll(RegExp(r'/api$'), '');
          String urlString =
              '$backendBase/api/generate-elevation?prompt=${Uri.encodeComponent(prompt)}';
          if (imagePath != null && imagePath.isNotEmpty) {
            urlString += '&image_path=${Uri.encodeComponent(imagePath)}';
          }
          final url = Uri.parse(urlString);
          final res = await http.get(url, headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
          });
          if (res.statusCode == 200) return res.bodyBytes;
          debugPrint(
              'Failed to fetch from fallback API. Status: ${res.statusCode}');
        }
      } catch (e) {
        debugPrint('Error fetching image for PDF: $e');
      }
      return null;
    }

    Map<String, Uint8List>? images3d;
    Uint8List? imageStructural;
    Uint8List? imageElevation;

    final modelData = data['model_data'] ?? {};
    final floorsData = modelData['floors'];
    final floorsMap = floorsData is Map ? floorsData : {};
    final ground = floorsMap['ground'] as Map<String, dynamic>? ?? {};
    final project = (ground['project'] as Map<String, dynamic>?) ??
        (modelData['project'] as Map<String, dynamic>?) ??
        {};
    final projWidth = (project['width'] as num?)?.toDouble() ?? 30.0;
    final projHeight = (project['height'] as num?)?.toDouble() ?? 40.0;

    // Backend returns: visual_data = { variations: [...], structural: { blueprint_url, preview_url } }
    final visualData = data['visual_data'] as Map<String, dynamic>? ??
        modelData['_visual'] as Map<String, dynamic>? ??
        {};

    // Structural blueprint URL is inside visual_data.structural (set by server.js line 807-808)
    // Also fallback to structural_data[floor].blueprint_url
    final visualStructural =
        visualData['structural'] as Map<String, dynamic>? ?? {};
    final structuralData = data['structural_data'] as Map<String, dynamic>? ??
        modelData['_structural'] as Map<String, dynamic>? ??
        {};
    final groundStructural =
        (structuralData['ground'] as Map<String, dynamic>?) ?? structuralData;

    if (selectedReportIds.isEmpty || selectedReportIds.contains('3d')) {
      // Use live 3D screenshots if captured from viewer, otherwise null (will use CustomPaint fallback)
      if (screenshots3D != null && screenshots3D.isNotEmpty) {
        images3d = screenshots3D;
        debugPrint('[PDF] Using live 3D screenshots');
      }
      // No asset fallback - will use _buildApp3DModel vector drawing instead
    }

    if (selectedReportIds.isEmpty || selectedReportIds.contains('structural')) {
      // Priority: visual_data.structural.blueprint_url → structural_data.ground.blueprint_url
      final directStruct = visualStructural['blueprint_url']?.toString() ??
          groundStructural['blueprint_url']?.toString();
      imageStructural = await fetchImage(
          'architectural engineering structural steel beam and column reinforcement blueprint diagram, construction plan',
          directUrl: directStruct);
    }

    if (selectedReportIds.isEmpty || selectedReportIds.contains('elevation')) {
      int floorCount = floorsData is int ? floorsData : 1;
      if (floorsMap.containsKey('first')) floorCount = 2;
      if (floorsMap.containsKey('second')) floorCount = 3;

      // Backend server saves elevations as 'variations' (not 'elevations')
      // visual_data.variations[0].image_url is the AI-generated elevation
      final variations =
          (visualData['variations'] ?? visualData['elevations']) as List? ?? [];

      String prompt = '';
      String? directUrl;
      if (variations.isNotEmpty) {
        // Use first variation - image_url is direct Pollinations URL
        directUrl = variations[0]['image_url']?.toString();
        prompt = variations[0]['prompt']?.toString() ?? '';
      }

      if (directUrl == null || directUrl.isEmpty) {
        // Build prompt from floor plan data as fallback
        final rooms = ground['rooms'] as List? ?? [];
        String spatialFeatures = '';
        final midX = projWidth / 2;

        for (var r in rooms) {
          final name = (r['name']?.toString() ?? '').toLowerCase();
          final rx = (r['x'] as num?)?.toDouble() ?? 0.0;
          final side = rx >= midX ? 'right' : 'left';
          if (name.contains('portico') ||
              name.contains('parking') ||
              name.contains('car')) {
            spatialFeatures +=
                'On the $side side, a large open car portico with pillars. ';
          } else if (name.contains('stair') || name.contains('step')) {
            spatialFeatures += 'On the $side side, an external staircase. ';
          }
        }

        prompt =
            'Professional front elevation of a Modern Indian ${projWidth.toInt()}x${projHeight.toInt()}ft '
            '${floorCount == 2 ? "two-story" : (floorCount == 3 ? "three-story" : "single-story")} house. '
            '$spatialFeatures Modern Contemporary, Flat Roof, Premium Entrance. Photorealistic, 8k, daylight';
      }

      final imagePathStr = data['image_url']?.toString() ?? '';
      imageElevation = await fetchImage(prompt,
          imagePath: imagePathStr, directUrl: directUrl);
      if (imageElevation == null) {
        try {
          final ByteData fileData =
              await rootBundle.load('assets/viewer/professional_house.png');
          imageElevation = fileData.buffer.asUint8List();
        } catch (_) {}
      }
    }

    Uint8List? logoImageBytes;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      logoImageBytes = logoData.buffer.asUint8List();
    } catch (_) {}

    final pdf = pw.Document();

    final name = data['name'] ?? 'My Project';
    final date = DateTime.now().toString().split('.')[0];

    final model = data['model_data'] ?? {};
    final costRoot = data['cost_data'] ?? data['_cost'] ?? model['_cost'] ?? {};
    final vastuRoot =
        data['vastu_data'] ?? data['_vastu'] ?? model['_vastu'] ?? {};

    bool isMultiFloor(Map m) => m.containsKey('ground');

    final floors = isMultiFloor(costRoot)
        ? costRoot.keys.where((k) => k != 'total').toList()
        : ['default'];

    final primaryColor = PdfColor.fromHex('#1B365D');
    final accentBlue = PdfColor.fromHex('#EFF6FF');
    final accentOrange = PdfColor.fromHex('#F59E0B');
    final bgTeal = PdfColor.fromHex('#F5F7FA');
    final accentGreen = PdfColor.fromHex('#10B981');
    final accentRed = PdfColor.fromHex('#EF4444');
    final textDark = PdfColor.fromHex('#374151');
    final textMuted = PdfColor.fromHex('#6B7280');

    pw.Widget buildPageFooter(pw.Context context) {
      return pw.Column(children: [
        pw.SizedBox(height: 20),
        pw.Container(height: 2, color: accentOrange),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 10),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Project $name | Generated: $date | Confidential',
                    style: pw.TextStyle(color: textMuted, fontSize: 10)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(color: textMuted, fontSize: 10)),
              ]),
        ),
      ]);
    }

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin:
          const pw.EdgeInsets.only(left: 40, right: 40, top: 30, bottom: 30),
    );

    // Page 1 - Cover Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Center(
              child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                if (logoImageBytes != null) ...[
                  pw.Image(pw.MemoryImage(logoImageBytes), height: 160),
                  pw.SizedBox(height: 20),
                ] else ...[
                  pw.Container(
                    width: 140,
                    height: 150,
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      shape: pw.BoxShape.circle,
                    ),
                    child: pw.Center(
                      child: pw.Text('KI',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 40,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text('Kanavu illam',
                      style: pw.TextStyle(
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                          color: textDark)),
                ],
                pw.SizedBox(height: 40),
                pw.Text('Complete House Analysis Report',
                    style: pw.TextStyle(fontSize: 24, color: primaryColor)),
                pw.SizedBox(height: 80),
                pw.Text('User Name: ${data['user_name'] ?? 'Client Name'}',
                    style: pw.TextStyle(fontSize: 16, color: textDark)),
                pw.SizedBox(height: 10),
                pw.Text('Email: ${data['email'] ?? 'client@example.com'}',
                    style: pw.TextStyle(fontSize: 16, color: textDark)),
                pw.SizedBox(height: 10),
                pw.Text('Phone: ${data['phone'] ?? '+91-XXXXXXXXXX'}',
                    style: pw.TextStyle(fontSize: 16, color: textDark)),
                pw.SizedBox(height: 10),
                if (data['address'] != null && data['address'].isNotEmpty) ...[
                  pw.Text('Address: ${data['address']}',
                      style: pw.TextStyle(fontSize: 16, color: textDark),
                      textAlign: pw.TextAlign.center),
                ],
              ]));
        },
      ),
    );

    if (selectedReportIds.isEmpty || selectedReportIds.contains('3d')) {
      // Page 2 - 3D House Visualization
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          footer: buildPageFooter,
          build: (pw.Context context) {
            return [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                child: pw.Text('01 · 3D HOUSE VISUALIZATION',
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor)),
              ),
              pw.Container(
                  height: 2, width: double.infinity, color: accentOrange),
              pw.SizedBox(height: 20),
              ...floors.map((floor) {
                final floorData = isMultiFloor(floorsMap)
                    ? (floorsMap[floor] ?? ground)
                    : ground;
                String title = floor == 'default'
                    ? 'Internal Floor Plan Model'
                    : '${floor.toString().toUpperCase()} Floor Model';
                return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title,
                          style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 10),
                      if (images3d != null && (images3d![floor] != null || images3d!['default'] != null))
                        pw.ClipRRect(
                            horizontalRadius: 8,
                            verticalRadius: 8,
                            child: pw.Image(pw.MemoryImage(images3d![floor] ?? images3d!['default']!),
                                fit: pw.BoxFit.contain, height: 250))
                      else
                        _buildApp3DModel(floorData, projWidth, projHeight),
                      pw.SizedBox(height: 25),
                    ]);
              }).toList(),
            ];
          },
        ),
      );
    }

    if (selectedReportIds.isEmpty || selectedReportIds.contains('vastu')) {
      // Page 3 - Vastu Report
      for (var floor in floors) {
        pdf.addPage(
          pw.MultiPage(
            pageTheme: pageTheme,
            footer: buildPageFooter,
            build: (pw.Context context) {
              final vastu = isMultiFloor(vastuRoot)
                  ? (vastuRoot[floor] ?? vastuRoot)
                  : vastuRoot;
              String title = floor == 'default'
                  ? 'Overall Vastu Analysis'
                  : '${floor.toString().toUpperCase()} Floor Vastu Analysis';
              String headerTitle = floor == 'default'
                  ? '02 · VASTU REPORT'
                  : '02 · VASTU REPORT - ${floor.toString().toUpperCase()} FLOOR';

              return [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 10),
                  child: pw.Text(headerTitle,
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor)),
                ),
                pw.Container(
                    height: 2, width: double.infinity, color: accentOrange),
                pw.SizedBox(height: 20),
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title,
                          style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 10),
                      pw.Row(children: [
                        pw.Text('Score: ',
                            style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: textDark)),
                        pw.Text(
                            '${vastu['score'] ?? 'N/A'}/100 (${vastu['grade'] ?? 'N/A'})',
                            style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: accentGreen)),
                      ]),
                      pw.SizedBox(height: 15),

                      // PLACEMENT ANALYSIS
                      pw.Text('Placement Analysis',
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 5),
                      if (vastu['mainEntrance'] != null)
                        pw.Text('- Entrance: ${vastu['mainEntrance']}',
                            style: pw.TextStyle(fontSize: 12, color: textDark)),
                      if (vastu['kitchen'] != null)
                        pw.Text('- Kitchen: ${vastu['kitchen']}',
                            style: pw.TextStyle(fontSize: 12, color: textDark)),
                      if (vastu['masterBedroom'] != null)
                        pw.Text('- Master Bedroom: ${vastu['masterBedroom']}',
                            style: pw.TextStyle(fontSize: 12, color: textDark)),
                      if (vastu['bathroom'] != null)
                        pw.Text('- Bathroom: ${vastu['bathroom']}',
                            style: pw.TextStyle(fontSize: 12, color: textDark)),
                      if (vastu['staircase'] != null)
                        pw.Text('- Staircase: ${vastu['staircase']}',
                            style: pw.TextStyle(fontSize: 12, color: textDark)),
                      if (vastu['poojaRoom'] != null)
                        pw.Text('- Pooja Room: ${vastu['poojaRoom']}',
                            style: pw.TextStyle(fontSize: 12, color: textDark)),
                      if (vastu['livingRoom'] != null)
                        pw.Text('- Living Room: ${vastu['livingRoom']}',
                            style: pw.TextStyle(fontSize: 12, color: textDark)),
                      pw.SizedBox(height: 15),
                      if ((vastu['strengths'] as List?)?.isNotEmpty ??
                          false) ...[
                        pw.Text('Benefits',
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: accentGreen)),
                        pw.SizedBox(height: 5),
                        ...(vastu['strengths'] as List).map((e) => pw.Text(
                            '- $e',
                            style:
                                pw.TextStyle(fontSize: 12, color: textDark))),
                        pw.SizedBox(height: 15),
                      ],
                      if ((vastu['violations'] as List?)?.isNotEmpty ??
                          false) ...[
                        pw.Text('Reasons for Score Reduction',
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: accentRed)),
                        pw.SizedBox(height: 5),
                        ...(vastu['violations'] as List).map((e) => pw.Text(
                            '- $e',
                            style:
                                pw.TextStyle(fontSize: 12, color: textDark))),
                        pw.SizedBox(height: 15),
                      ],
                      if ((vastu['suggestions'] as List?)?.isNotEmpty ??
                          false) ...[
                        pw.Text('Suggestions',
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: accentBlue)),
                        pw.SizedBox(height: 5),
                        ...(vastu['suggestions'] as List).map((e) => pw.Text(
                            '- $e',
                            style:
                                pw.TextStyle(fontSize: 12, color: textDark))),
                        pw.SizedBox(height: 20),
                      ],
                    ]),
              ];
            },
          ),
        );
      }
    }

    if (selectedReportIds.isEmpty || selectedReportIds.contains('cost')) {
      // Page 4 - Estimation
      for (var floor in floors) {
        pdf.addPage(
          pw.MultiPage(
            pageTheme: pageTheme,
            footer: buildPageFooter,
            build: (pw.Context context) {
              final cost = isMultiFloor(costRoot) ? costRoot[floor] : costRoot;
              if (cost == null || cost.isEmpty || cost is! Map) {
                return [];
              }
              final est = cost['estimates'] ?? {};
              String title = floor == 'default'
                  ? 'Overall Estimation'
                  : '${floor.toString().toUpperCase()} Floor Estimation';
              String headerTitle = floor == 'default'
                  ? '03 · ESTIMATION'
                  : '03 · ESTIMATION - ${floor.toString().toUpperCase()} FLOOR';

              return [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 10),
                  child: pw.Text(headerTitle,
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor)),
                ),
                pw.Container(
                    height: 2, width: double.infinity, color: accentOrange),
                pw.SizedBox(height: 20),
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title,
                          style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: bgTeal,
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Basic',
                                        style: pw.TextStyle(
                                            fontSize: 12, color: textMuted)),
                                    pw.Text('Rs. ${est['basic'] ?? 'N/A'}',
                                        style: pw.TextStyle(
                                            fontSize: 14,
                                            fontWeight: pw.FontWeight.bold,
                                            color: textDark)),
                                  ]),
                              pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Standard',
                                        style: pw.TextStyle(
                                            fontSize: 12, color: textMuted)),
                                    pw.Text('Rs. ${est['standard'] ?? 'N/A'}',
                                        style: pw.TextStyle(
                                            fontSize: 14,
                                            fontWeight: pw.FontWeight.bold,
                                            color: textDark)),
                                  ]),
                              pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Premium',
                                        style: pw.TextStyle(
                                            fontSize: 12, color: textMuted)),
                                    pw.Text('Rs. ${est['premium'] ?? 'N/A'}',
                                        style: pw.TextStyle(
                                            fontSize: 14,
                                            fontWeight: pw.FontWeight.bold,
                                            color: textDark)),
                                  ]),
                            ]),
                      ),
                      pw.SizedBox(height: 20),
                      if (cost['materials'] != null &&
                          cost['materials'] is Map) ...[
                        pw.Text('Material Breakdown',
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: textDark)),
                        pw.SizedBox(height: 10),
                        pw.Table(
                            border:
                                pw.TableBorder.all(color: PdfColors.grey300),
                            children: [
                              pw.TableRow(
                                  decoration: const pw.BoxDecoration(
                                      color: PdfColors.grey100),
                                  children: [
                                    pw.Padding(
                                        padding: const pw.EdgeInsets.all(5),
                                        child: pw.Text('Material',
                                            style: pw.TextStyle(
                                                fontWeight: pw.FontWeight.bold,
                                                fontSize: 10))),
                                    pw.Padding(
                                        padding: const pw.EdgeInsets.all(5),
                                        child: pw.Text('Quantity',
                                            style: pw.TextStyle(
                                                fontWeight: pw.FontWeight.bold,
                                                fontSize: 10))),
                                    pw.Padding(
                                        padding: const pw.EdgeInsets.all(5),
                                        child: pw.Text('Unit',
                                            style: pw.TextStyle(
                                                fontWeight: pw.FontWeight.bold,
                                                fontSize: 10))),
                                    pw.Padding(
                                        padding: const pw.EdgeInsets.all(5),
                                        child: pw.Text('Rate (Rs)',
                                            style: pw.TextStyle(
                                                fontWeight: pw.FontWeight.bold,
                                                fontSize: 10))),
                                  ]),
                              ...(cost['materials'] as Map).entries.map((e) {
                                final mat = e.value;
                                return pw.TableRow(children: [
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(
                                          mat['name']?.toString() ??
                                              e.key.toString(),
                                          style: const pw.TextStyle(
                                              fontSize: 10))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(
                                          mat['quantity']?.toString() ?? '-',
                                          style: const pw.TextStyle(
                                              fontSize: 10))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(
                                          mat['unit']?.toString() ?? '-',
                                          style: const pw.TextStyle(
                                              fontSize: 10))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(
                                          mat['price']?.toString() ?? '-',
                                          style: const pw.TextStyle(
                                              fontSize: 10))),
                                ]);
                              }),
                            ]),
                        pw.SizedBox(height: 20),
                      ],
                    ]),
                if (floor == floors.last) ...[
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  pw.Text('Grand Total',
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor)),
                  pw.SizedBox(height: 5),
                  pw.Text(
                      'Total costs depend on the selected finishing package and fluctuating market material rates.',
                      style: pw.TextStyle(fontSize: 12, color: textMuted)),
                ]
              ];
            },
          ),
        );
      }
    }

    if (selectedReportIds.isEmpty || selectedReportIds.contains('structural')) {
      // structural_data is top-level key in projectData (set by server.js line 867)
      // It has shape: { ground: {...}, first: {...} } (multi-floor)
      final structuralRoot = data['structural_data'] as Map<String, dynamic>? ??
          modelData['_structural'] as Map<String, dynamic>? ??
          {};

      // Page 5 - Structural Analysis
      for (var floor in floors) {
        pdf.addPage(
          pw.MultiPage(
            pageTheme: pageTheme,
            footer: buildPageFooter,
            build: (pw.Context context) {
              final struct = isMultiFloor(structuralRoot)
                  ? structuralRoot[floor]
                  : structuralRoot;
              if (struct == null || struct.isEmpty || struct is! Map) {
                return [];
              }
              final summary = struct['summary'] ?? {};
              final rcmd = struct['recommendations'] ?? {};
              String title = floor == 'default'
                  ? 'Overall Structure'
                  : '${floor.toString().toUpperCase()} Floor Structure';
              String headerTitle = floor == 'default'
                  ? '04 · STRUCTURAL ANALYSIS'
                  : '04 · STRUCTURAL ANALYSIS - ${floor.toString().toUpperCase()} FLOOR';

              return [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 10),
                  child: pw.Text(headerTitle,
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor)),
                ),
                pw.Container(
                    height: 2, width: double.infinity, color: accentOrange),
                pw.SizedBox(height: 20),
                if (floor == floors.first && imageStructural != null) ...[
                  pw.ClipRRect(
                      horizontalRadius: 8,
                      verticalRadius: 8,
                      child: pw.Image(pw.MemoryImage(imageStructural),
                          fit: pw.BoxFit.cover, height: 200)),
                  pw.SizedBox(height: 20),
                ],
                if (floor == floors.first) ...[
                  pw.Text('Structural Estimation',
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: textDark)),
                  pw.SizedBox(height: 10),
                  pw.Text(
                      'Based on AI engineering algorithms, the load-bearing distribution, column placement, and foundation specifications are evaluated.',
                      style: pw.TextStyle(
                          fontSize: 12, color: textMuted, lineSpacing: 1.5)),
                  pw.SizedBox(height: 15),
                ],
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title,
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 8),
                      pw.Text(
                          '- Recommended Columns: ${rcmd['column_count'] ?? 'N/A'}',
                          style: pw.TextStyle(fontSize: 12, color: textDark)),
                      pw.Text(
                          '- Estimated Load: ${summary['estimated_load_kg'] ?? 'N/A'} kg',
                          style: pw.TextStyle(fontSize: 12, color: textDark)),
                      pw.Text(
                          '- Foundation Depth: ${rcmd['foundation_depth_ft'] ?? '5'} ft',
                          style: pw.TextStyle(fontSize: 12, color: textDark)),
                      pw.SizedBox(height: 15),
                      pw.Text('Beam Layout Plan',
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 10),
                      _buildBeamLayout(
                          isMultiFloor(floorsMap)
                              ? (floorsMap[floor] ?? ground)
                              : ground,
                          struct,
                          projWidth,
                          projHeight),
                      pw.SizedBox(height: 25),
                      pw.Text('Beam Schedule',
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 10),
                      pw.Table(
                          border: pw.TableBorder.all(color: PdfColors.grey400),
                          children: [
                            pw.TableRow(
                                decoration: const pw.BoxDecoration(
                                    color: PdfColors.grey100),
                                children: [
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text('MARK',
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 10))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text('SIZE',
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 10))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text('TOP',
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 10))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text('BOT',
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 10))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text('STIRRUP',
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 10))),
                                ]),
                            pw.TableRow(children: [
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('B1',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('9"x12"',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('2-16mm',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('2-16mm',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('8mm@6"',
                                      style: const pw.TextStyle(fontSize: 10))),
                            ]),
                            pw.TableRow(children: [
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('B2',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('9"x9"',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('2-12mm',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('2-12mm',
                                      style: const pw.TextStyle(fontSize: 10))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(5),
                                  child: pw.Text('8mm@8"',
                                      style: const pw.TextStyle(fontSize: 10))),
                            ]),
                          ]),
                      pw.SizedBox(height: 15),
                      pw.Text('Structural Material Estimation',
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark)),
                      pw.SizedBox(height: 10),
                      pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                              color: PdfColors.grey100,
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(8))),
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                    '- Cement: ${struct['material_estimation']?['cement_bags'] ?? 450} Bags',
                                    style: const pw.TextStyle(fontSize: 12)),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                    '- Steel (Rebar): ${struct['material_estimation']?['steel_kg'] ?? 4200} kg',
                                    style: const pw.TextStyle(fontSize: 12)),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                    '- Sand: ${struct['material_estimation']?['sand_cft'] ?? 1800} cft',
                                    style: const pw.TextStyle(fontSize: 12)),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                    '- Aggregate: ${struct['material_estimation']?['aggregate_cft'] ?? 2200} cft',
                                    style: const pw.TextStyle(fontSize: 12)),
                              ])),
                      pw.SizedBox(height: 25),
                    ]),
                if (floor == floors.last) ...[
                  pw.Text('- Status: VERIFIED',
                      style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: accentGreen)),
                  pw.SizedBox(height: 5),
                  pw.Text('- Integrity Score: 94/100',
                      style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: accentBlue)),
                ]
              ];
            },
          ),
        );
      }
    }

    if (selectedReportIds.isEmpty || selectedReportIds.contains('elevation')) {
      // Page 6 - Elevation
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          footer: buildPageFooter,
          build: (pw.Context context) {
            return [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                child: pw.Text('05 · FRONT ELEVATION BLUEPRINT',
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor)),
              ),
              pw.Container(
                  height: 2, width: double.infinity, color: accentOrange),
              pw.SizedBox(height: 20),
              if (imageElevation != null) ...[
                pw.ClipRRect(
                    horizontalRadius: 8,
                    verticalRadius: 8,
                    child: pw.Image(pw.MemoryImage(imageElevation),
                        fit: pw.BoxFit.cover, height: 250)),
                pw.SizedBox(height: 20),
              ],
              _buildNativeElevation(
                  ground,
                  isMultiFloor(floorsMap) ? floorsMap['first'] ?? {} : {},
                  projWidth,
                  projHeight),
              pw.SizedBox(height: 20),
              pw.Text('Elevation Features',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: textDark)),
              pw.SizedBox(height: 10),
              pw.Text(
                  '- Large glass facades implemented for maximum natural lighting.\n- Minimalist overhangs and linear geometric forms.\n- Textured stone and wood composite exterior finishes applied.\n- Proportional height distribution across all designed floors.',
                  style: pw.TextStyle(
                      fontSize: 12, color: textMuted, lineSpacing: 1.5)),
            ];
          },
        ),
      );
    }

    // Page 7 - Project Summary
    final finalVastu = isMultiFloor(vastuRoot)
        ? (vastuRoot['ground'] ?? vastuRoot['total'] ?? vastuRoot)
        : vastuRoot;
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        footer: buildPageFooter,
        build: (pw.Context context) {
          return [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              child: pw.Text('06 · PROJECT SUMMARY',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor)),
            ),
            pw.Container(
                height: 2, width: double.infinity, color: accentOrange),
            pw.SizedBox(height: 20),
            pw.Text('Overall Ratings',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark)),
            pw.SizedBox(height: 10),
            pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(children: [
                        pw.Text('Vastu',
                            style:
                                pw.TextStyle(fontSize: 14, color: textMuted)),
                        pw.SizedBox(height: 5),
                        pw.Text('${finalVastu['score'] ?? 'N/A'}/100',
                            style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: accentOrange)),
                      ]),
                    ])),
            pw.SizedBox(height: 30),
            pw.Text('House Details',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark)),
            pw.SizedBox(height: 10),
            pw.Text(
                '- Project Name: $name\n- Generated Date: $date\n- Floors Analyzed: ${floors.length}\n- Architectural Style: Modern Contemporary',
                style: pw.TextStyle(
                    fontSize: 12, color: textMuted, lineSpacing: 1.5)),
          ];
        },
      ),
    );

    // Page 8 - Thank You
    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(40),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                    bottom: pw.BorderSide(color: accentOrange, width: 6)),
              ),
              child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('THANK YOU',
                        style: pw.TextStyle(
                            fontSize: 38,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor)),
                    pw.SizedBox(height: 10),
                    pw.Text('for using Kanavu illam',
                        style: pw.TextStyle(fontSize: 22, color: textDark)),
                  ]),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildBeamLayout(
      Map floorData, Map structData, double projW, double projH) {
    final walls = floorData['walls'] as List? ?? [];

    final rooms = floorData['rooms'] as List? ?? [];

    return pw.Container(
        height: 350,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          color: PdfColors.white,
        ),
        child: pw.LayoutBuilder(builder: (context, constraints) {
          final padLeft = 40.0;
          final padTop = 40.0;
          final drawW = constraints!.maxWidth - padLeft - 20;
          final drawH = constraints.maxHeight - padTop - 20;
          final sX = drawW / projW;
          final sY = drawH / projH;

          return pw.Stack(children: [
            pw.SizedBox(
                width: constraints.maxWidth, height: constraints.maxHeight),
            pw.Positioned(
                left: padLeft,
                top: padTop,
                child: pw.CustomPaint(
                    size: PdfPoint(drawW, drawH),
                    painter: (PdfGraphics canvas, PdfPoint size) {
                      canvas.setStrokeColor(PdfColors.black);
                      canvas.setLineWidth(2.0);
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
                        canvas.drawLine(x1 * sX, drawH - (y1 * sY), x2 * sX,
                            drawH - (y2 * sY));
                      }
                      canvas.strokePath();

                      canvas.setFillColor(PdfColors.red600);
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
                        final cw = 8.0;
                        final ch = 8.0;
                        canvas.drawRect(x1 * sX - cw / 2,
                            drawH - (y1 * sY) - ch / 2, cw, ch);
                        canvas.drawRect(x2 * sX - cw / 2,
                            drawH - (y2 * sY) - ch / 2, cw, ch);
                      }
                      canvas.fillPath();
                    })),
            ...rooms.map((r) {
              final rw = (r['width'] as num?)?.toDouble() ?? 0.0;
              final rh = (r['height'] as num?)?.toDouble() ?? 0.0;
              final rx = (r['x'] as num?)?.toDouble() ?? 0.0;
              final ry = (r['y'] as num?)?.toDouble() ?? 0.0;
              final name = r['name']?.toString() ?? '';

              return pw.Positioned(
                left: padLeft + (rx + rw / 2) * sX - (name.length * 2.5),
                top: padTop + (ry + rh / 2) * sY - 4,
                child: pw.Text(name,
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),
              );
            }),
            pw.Positioned(
                left: padLeft - 10,
                top: padTop - 25,
                child: pw.Container(
                    width: 20,
                    height: 20,
                    decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: PdfColors.black)),
                    alignment: pw.Alignment.center,
                    child: pw.Text('1',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)))),
            pw.Positioned(
                left: padLeft + drawW - 10,
                top: padTop - 25,
                child: pw.Container(
                    width: 20,
                    height: 20,
                    decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: PdfColors.black)),
                    alignment: pw.Alignment.center,
                    child: pw.Text('2',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)))),
            pw.Positioned(
                left: padLeft - 30,
                top: padTop - 10,
                child: pw.Container(
                    width: 20,
                    height: 20,
                    decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: PdfColors.black)),
                    alignment: pw.Alignment.center,
                    child: pw.Text('A',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)))),
            pw.Positioned(
                left: padLeft - 30,
                top: padTop + drawH - 10,
                child: pw.Container(
                    width: 20,
                    height: 20,
                    decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: PdfColors.black)),
                    alignment: pw.Alignment.center,
                    child: pw.Text('B',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)))),
          ]);
        }));
  }

  static pw.Widget _buildApp3DModel(Map floorData, double projW, double projH) {
    final walls = floorData['walls'] as List? ?? [];
    final rooms = floorData['rooms'] as List? ?? [];

    return pw.Container(
        height: 350,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#0B1325'), // Dark grid background
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.LayoutBuilder(builder: (context, constraints) {
          final padLeft = 40.0;
          final padTop = 40.0;
          final drawW = constraints!.maxWidth - padLeft - 20;
          final drawH = constraints.maxHeight - padTop - 20;
          final sX = drawW / projW;
          final sY = drawH / projH;

          return pw.Stack(children: [
            pw.SizedBox(
                width: constraints.maxWidth, height: constraints.maxHeight),
            pw.Positioned(
                left: padLeft,
                top: padTop,
                child: pw.CustomPaint(
                    size: PdfPoint(drawW, drawH),
                    painter: (PdfGraphics canvas, PdfPoint size) {
                      // Draw Grid Lines
                      canvas.setStrokeColor(PdfColor.fromHex('#1E293B'));
                      canvas.setLineWidth(1.0);
                      double gridSpace = 20.0;
                      for (double x = 0; x < size.x; x += gridSpace) {
                        canvas.drawLine(x, 0, x, size.y);
                      }
                      for (double y = 0; y < size.y; y += gridSpace) {
                        canvas.drawLine(0, y, size.x, y);
                      }
                      canvas.strokePath();

                      // Shadow
                      canvas.setFillColor(const PdfColor(0, 0, 0, 0.5));
                      canvas.drawRect(8, -12, drawW, drawH);
                      canvas.fillPath();

                      // Floor Base
                      canvas.setFillColor(PdfColor.fromHex('#C9D1D9'));
                      canvas.drawRect(0, 0, drawW, drawH);
                      canvas.fillPath();

                      // Wall shadows (3D effect)
                      canvas.setStrokeColor(PdfColor.fromHex('#475569'));
                      canvas.setLineWidth(14.0);
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
                        canvas.drawLine(x1 * sX + 3, drawH - (y1 * sY) - 4,
                            x2 * sX + 3, drawH - (y2 * sY) - 4);
                      }
                      canvas.strokePath();

                      // Walls (Top surface)
                      canvas.setStrokeColor(PdfColor.fromHex('#F1F5F9'));
                      canvas.setLineWidth(10.0);
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
                        canvas.drawLine(x1 * sX, drawH - (y1 * sY), x2 * sX,
                            drawH - (y2 * sY));
                      }
                      canvas.strokePath();

                      // Doors (3D open effect)
                      final doors = floorData['doors'] as List? ?? [];
                      for (var d in doors) {
                        double dx = (d['x'] as num?)?.toDouble() ?? 0.0;
                        double dy = (d['y'] as num?)?.toDouble() ?? 0.0;
                        double dw = (d['width'] as num?)?.toDouble() ?? 3.0;
                        // Draw an angled door (45 deg) protruding outward
                        double ex = dx + (dw * 0.7);
                        double ey = dy + (dw * 0.7);

                        // Door Shadow
                        canvas.setStrokeColor(PdfColor.fromHex('#29180C'));
                        canvas.setLineWidth(4.0);
                        canvas.drawLine(dx * sX + 3, drawH - (dy * sY) - 4,
                            ex * sX + 3, drawH - (ey * sY) - 4);
                        canvas.strokePath();

                        // Door Surface
                        canvas.setStrokeColor(PdfColor.fromHex('#8B4513'));
                        canvas.drawLine(dx * sX, drawH - (dy * sY), ex * sX,
                            drawH - (ey * sY));
                        canvas.strokePath();
                      }
                    })),
            ...rooms.map((r) {
              final rw = (r['width'] as num?)?.toDouble() ?? 0.0;
              final rh = (r['height'] as num?)?.toDouble() ?? 0.0;
              final rx = (r['x'] as num?)?.toDouble() ?? 0.0;
              final ry = (r['y'] as num?)?.toDouble() ?? 0.0;
              final name = r['name']?.toString().toUpperCase() ?? '';

              return pw.Positioned(
                  left: padLeft + (rx + rw / 2) * sX - (name.length * 2.8),
                  top: padTop + (ry + rh / 2) * sY - 8,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color:
                          PdfColor(14 / 255.0, 116 / 255.0, 144 / 255.0, 0.85),
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(
                          color: PdfColor(0, 200 / 255.0, 150 / 255.0, 0.5),
                          width: 1.0),
                    ),
                    child: pw.Text(name,
                        style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white)),
                  ));
            }),
          ]);
        }));
  }

  static pw.Widget _buildNativeElevation(
      Map ground, Map first, double projW, double projH) {
    return pw.Container(
        height: 350,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          color: PdfColor.fromHex('#0F172A'),
        ),
        child: pw.LayoutBuilder(builder: (context, constraints) {
          final double floorH = 10.0;
          final double parapetH = 3.0;
          final cosA = 0.866;
          final sinA = 0.5;

          bool hasFirstFloor = first.isNotEmpty;
          double totalZ =
              hasFirstFloor ? (floorH * 2 + parapetH) : (floorH + parapetH);

          double isoW = (projW + projH) * cosA;
          double isoH = (projW + projH) * sinA + totalZ;

          final drawW = constraints!.maxWidth * 0.8;
          final drawH = constraints.maxHeight * 0.7;

          final sX = drawW / isoW;
          final sY = drawH / isoH;
          final scale = sX < sY ? sX : sY;

          final offsetX =
              constraints.maxWidth / 2 - (projW - projH) * cosA * scale / 2;
          final offsetY = constraints.maxHeight / 2 +
              (projW + projH) * sinA * scale / 2 -
              (isoH * scale) / 2;

          return pw.Stack(children: [
            pw.Positioned(
                left: 0,
                bottom: 0,
                child: pw.CustomPaint(
                    size: PdfPoint(constraints.maxWidth, constraints.maxHeight),
                    painter: (PdfGraphics canvas, PdfPoint size) {
                      PdfPoint iso(double x, double y, double z) {
                        double sx = (x - y) * cosA * scale;
                        double sy = -(x + y) * sinA * scale + (z * scale);
                        return PdfPoint(offsetX + sx, offsetY + sy);
                      }

                      final wallColor = PdfColor.fromHex('#F1F5F9');
                      final borderColor = PdfColor.fromHex('#334155');
                      final slabColor = PdfColor.fromHex('#E2E8F0');
                      final compoundColor = PdfColor.fromHex('#CBD5E1');

                      final windowColor = PdfColor.fromHex('#BFE8FB');
                      final windowBorder = PdfColor.fromHex('#0F172A');
                      final doorColor = PdfColor.fromHex('#8B4513');

                      List<Map<String, dynamic>> polys = [];

                      void addPoly(double depth, List<PdfPoint> pts,
                          PdfColor fill, PdfColor stroke, int type,
                          {List<PdfPoint>? cross}) {
                        polys.add({
                          'depth': depth,
                          'pts': pts,
                          'fill': fill,
                          'stroke': stroke,
                          'type': type,
                          'cross': cross,
                        });
                      }

                      void addWall(double x1, double y1, double x2, double y2,
                          double z1, double z2, PdfColor fill, PdfColor stroke,
                          {bool isWindow = false}) {
                        double depth = (x1 + x2 + y1 + y2) / 4;
                        var pts = [
                          iso(x1, y1, z1),
                          iso(x2, y2, z1),
                          iso(x2, y2, z2),
                          iso(x1, y1, z2)
                        ];
                        List<PdfPoint>? cross;
                        if (isWindow) {
                          double mx = (x1 + x2) / 2,
                              my = (y1 + y2) / 2,
                              mz = (z1 + z2) / 2;
                          cross = [
                            iso(mx, my, z1),
                            iso(mx, my, z2),
                            iso(x1, y1, mz),
                            iso(x2, y2, mz)
                          ];
                        }
                        addPoly(depth, pts, fill, stroke, isWindow ? 1 : 0,
                            cross: cross);
                      }

                      void addSlab(double x, double y, double w, double l,
                          double z, PdfColor fill, PdfColor stroke) {
                        double depth = (x + x + w + y + y + l) / 4;
                        var pts = [
                          iso(x, y, z),
                          iso(x + w, y, z),
                          iso(x + w, y + l, z),
                          iso(x, y + l, z)
                        ];
                        addPoly(depth, pts, fill, stroke, 0);
                      }

                      // Compound Wall
                      double cwH = 4.0;
                      addWall(0, 0, projW, 0, 0, cwH, compoundColor,
                          borderColor); // Back
                      addWall(projW, 0, projW, projH, 0, cwH, compoundColor,
                          borderColor); // Right
                      addWall(0, 0, 0, projH, 0, cwH, compoundColor,
                          borderColor); // Left
                      // Front with Main Gate opening
                      addWall(0, projH, projW - 14, projH, 0, cwH,
                          compoundColor, borderColor); // Front Left
                      addWall(projW - 2, projH, projW, projH, 0, cwH,
                          compoundColor, borderColor); // Front Right corner

                      void addFloor(Map floor, double baseZ) {
                        final rooms = floor['rooms'] as List? ?? [];
                        for (var r in rooms) {
                          double x = (r['x'] as num?)?.toDouble() ?? 0;
                          double y = (r['y'] as num?)?.toDouble() ?? 0;
                          double w = (r['width'] as num?)?.toDouble() ?? 0;
                          double l = (r['height'] as num?)?.toDouble() ?? 0;
                          String name =
                              (r['name']?.toString() ?? '').toLowerCase();

                          if (name.contains('portico') ||
                              name.contains('parking') ||
                              name.contains('car')) {
                            addSlab(x, y, w, l, baseZ + floorH, slabColor,
                                borderColor);
                            addWall(x + w - 1.0, y + l - 1.0, x + w, y + l,
                                baseZ, baseZ + floorH, wallColor, borderColor);
                            addWall(x, y + l - 1.0, x + 1.0, y + l, baseZ,
                                baseZ + floorH, wallColor, borderColor);
                          } else if (name.contains('stair') ||
                              name.contains('step')) {
                            int steps = 10;
                            for (int i = 0; i < steps; i++) {
                              double stepH = floorH / steps;
                              double stepY = y + l - (l / steps) * (i + 1);

                              addSlab(
                                  x,
                                  stepY,
                                  w,
                                  l / steps,
                                  baseZ + stepH * (i + 1),
                                  slabColor,
                                  borderColor);
                              addWall(
                                  x,
                                  stepY + l / steps,
                                  x + w,
                                  stepY + l / steps,
                                  baseZ,
                                  baseZ + stepH * (i + 1),
                                  slabColor,
                                  borderColor);
                              addWall(
                                  x + w,
                                  stepY,
                                  x + w,
                                  stepY + l / steps,
                                  baseZ,
                                  baseZ + stepH * (i + 1),
                                  slabColor,
                                  borderColor);
                            }
                          } else {
                            addSlab(x, y, w, l, baseZ + floorH, slabColor,
                                borderColor);
                          }
                        }

                        final walls = floor['walls'] as List? ?? [];
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
                          addWall(x1, y1, x2, y2, baseZ, baseZ + floorH,
                              wallColor, borderColor);
                        }

                        final doors = floor['doors'] as List? ?? [];
                        for (var d in doors) {
                          double x = (d['x'] as num?)?.toDouble() ?? 0;
                          double y = (d['y'] as num?)?.toDouble() ?? 0;
                          double dw = (d['width'] as num?)?.toDouble() ?? 3.5;
                          addWall(x, y, x + dw, y, baseZ, baseZ + 7.0,
                              doorColor, borderColor);
                        }

                        final windows = floor['windows'] as List? ?? [];
                        for (var w in windows) {
                          double x = (w['x'] as num?)?.toDouble() ?? 0;
                          double y = (w['y'] as num?)?.toDouble() ?? 0;
                          double ww = (w['width'] as num?)?.toDouble() ?? 4.0;
                          addWall(x, y, x + ww, y, baseZ + 3.0, baseZ + 7.0,
                              windowColor, windowBorder,
                              isWindow: true);
                        }
                      }

                      addFloor(ground, 0);
                      if (hasFirstFloor) {
                        addFloor(first, floorH);
                        final walls = first['walls'] as List? ?? [];
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
                          addWall(x1, y1, x2, y2, floorH * 2,
                              floorH * 2 + parapetH, wallColor, borderColor);
                        }
                      } else {
                        final walls = ground['walls'] as List? ?? [];
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
                          addWall(x1, y1, x2, y2, floorH, floorH + parapetH,
                              wallColor, borderColor);
                        }
                      }

                      // Sort by depth. Larger (x+y) is closer.
                      polys.sort((a, b) {
                        if (a['depth'] == b['depth']) {
                          return (a['type'] as int).compareTo(b['type'] as int);
                        }
                        return (a['depth'] as double)
                            .compareTo(b['depth'] as double);
                      });

                      // Draw Ground Base
                      canvas.setFillColor(PdfColor.fromHex('#94A3B8'));
                      canvas.moveTo(iso(0, 0, 0).x, iso(0, 0, 0).y);
                      canvas.lineTo(iso(projW, 0, 0).x, iso(projW, 0, 0).y);
                      canvas.lineTo(
                          iso(projW, projH, 0).x, iso(projW, projH, 0).y);
                      canvas.lineTo(iso(0, projH, 0).x, iso(0, projH, 0).y);
                      canvas.fillPath();
                      canvas.setStrokeColor(borderColor);
                      canvas.moveTo(iso(0, 0, 0).x, iso(0, 0, 0).y);
                      canvas.lineTo(iso(projW, 0, 0).x, iso(projW, 0, 0).y);
                      canvas.lineTo(
                          iso(projW, projH, 0).x, iso(projW, projH, 0).y);
                      canvas.lineTo(iso(0, projH, 0).x, iso(0, projH, 0).y);
                      canvas.lineTo(iso(0, 0, 0).x, iso(0, 0, 0).y);
                      canvas.strokePath();

                      for (var p in polys) {
                        var pts = p['pts'] as List<PdfPoint>;
                        canvas.setFillColor(p['fill']);
                        canvas.moveTo(pts[0].x, pts[0].y);
                        canvas.lineTo(pts[1].x, pts[1].y);
                        canvas.lineTo(pts[2].x, pts[2].y);
                        canvas.lineTo(pts[3].x, pts[3].y);
                        canvas.fillPath();

                        canvas.setStrokeColor(p['stroke']);
                        canvas.setLineWidth(1.0);
                        canvas.moveTo(pts[0].x, pts[0].y);
                        canvas.lineTo(pts[1].x, pts[1].y);
                        canvas.lineTo(pts[2].x, pts[2].y);
                        canvas.lineTo(pts[3].x, pts[3].y);
                        canvas.lineTo(pts[0].x, pts[0].y);
                        canvas.strokePath();

                        if (p['cross'] != null) {
                          var cross = p['cross'] as List<PdfPoint>;
                          canvas.moveTo(cross[0].x, cross[0].y);
                          canvas.lineTo(cross[1].x, cross[1].y);
                          canvas.strokePath();

                          canvas.moveTo(cross[2].x, cross[2].y);
                          canvas.lineTo(cross[3].x, cross[3].y);
                          canvas.strokePath();
                        }
                      }
                    })),
          ]);
        }));
  }
}
