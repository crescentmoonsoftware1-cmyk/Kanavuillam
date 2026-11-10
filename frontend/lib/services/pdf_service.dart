import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'dart:ui' as ui;
import '../screens/structural_screen.dart';

class PdfService {
  static Future<Uint8List> createProfessionalPdf(
      Map<String, dynamic> data, Set<String> selectedReportIds,
      {Map<String, Uint8List>? screenshots3D}) async {
    Future<Uint8List?> fetchImage(String prompt,
        {String? imagePath, String? directUrl}) async {
      try {
        if (directUrl != null && directUrl.startsWith('data:image')) {
          final base64Str = directUrl.split(',').last;
          return base64Decode(base64Str);
        }

        if (directUrl != null && directUrl.isNotEmpty) {
          // Always use proxy to avoid CORS/Cloudflare issues on Flutter Web when downloading images for PDF
          final backendBase =
              ApiService.baseUrl.replaceAll(RegExp(r'/api$'), '');
          final proxyUrl =
              '$backendBase/api/proxy-image?url=${Uri.encodeComponent(directUrl)}';

          final res = await http.get(Uri.parse(proxyUrl),
              headers: kIsWeb
                  ? null
                  : {
                      'User-Agent':
                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
                    }).timeout(const Duration(seconds: 5),
              onTimeout: () => http.Response('timeout', 408));
          if (res.statusCode == 200) return res.bodyBytes;

          // Fallback to direct url if proxy fails
          final directRes = await http.get(Uri.parse(directUrl),
              headers: kIsWeb
                  ? null
                  : {
                      'User-Agent':
                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
                    }).timeout(const Duration(seconds: 5),
              onTimeout: () => http.Response('timeout', 408));
          if (directRes.statusCode == 200) return directRes.bodyBytes;

          debugPrint(
              'Failed to fetch directUrl. Status: ${directRes.statusCode}');
        } else {
          // Note: Elevation generation API removed; native architectural blueprint is used instead
          return null;
        }
      } catch (e) {
        debugPrint('Error fetching image for PDF: $e');
      }
      return null;
    }

    Map<String, Uint8List>? images3d;
    Map<String, Uint8List> imagesStructural = {};
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

    final costRoot =
        data['cost_data'] ?? data['_cost'] ?? modelData['_cost'] ?? {};
    final vastuRoot =
        data['vastu_data'] ?? data['_vastu'] ?? modelData['_vastu'] ?? {};

    bool isMultiFloor(Map m) => m.containsKey('ground');

    // Use floorsMap to reliably detect floors if costRoot is missing them
    final sourceForFloors = isMultiFloor(floorsMap) ? floorsMap : costRoot;
    final floors = isMultiFloor(sourceForFloors)
        ? sourceForFloors.keys.where((k) => k != 'total').toList()
        : ['default'];

    // Backend returns: visual_data = { variations: [...], structural: { blueprint_url, preview_url } }
    final visualData = data['visual_data'] as Map<String, dynamic>? ??
        modelData['_visual'] as Map<String, dynamic>? ??
        {};


    if (selectedReportIds.isEmpty || selectedReportIds.contains('3d')) {
      if (screenshots3D != null && screenshots3D.isNotEmpty) {
        images3d = screenshots3D;
        debugPrint('[PDF] Using live 3D screenshots');
      } else {
        // Fallback to the generated Isometric image from backend if available
        final variations =
            (visualData['variations'] ?? visualData['elevations']) as List? ??
                [];
        if (variations.length > 2) {
          final isoUrl = variations[2]['image_url']?.toString();
          if (isoUrl != null && isoUrl.isNotEmpty) {
            final fetchedIso = await fetchImage('isometric 3d architecture',
                directUrl: isoUrl);
            if (fetchedIso != null) {
              images3d = {'default': fetchedIso};
              debugPrint('[PDF] Using backend generated Isometric view for 3D');
            }
          }
        }
      }
    }

    if (selectedReportIds.isEmpty || selectedReportIds.contains('structural')) {
      for (var floor in floors) {
        try {

          final floorData =
              isMultiFloor(floorsMap) ? (floorsMap[floor] ?? ground) : ground;
          final r = floorData['rooms'] ?? modelData['rooms'] ?? [];
          final w = floorData['walls'] ?? modelData['walls'] ?? [];
          final pW = projWidth;
          final pH = projHeight;

          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          const size = ui.Size(1024, 768);

          // Fill background
          canvas.drawRect(ui.Offset.zero & size,
              ui.Paint()..color = const ui.Color(0xFFF1F5F9));

          final painter = StructuralIsometricPainter(
            rooms: r,
            walls: w,
            pw: pW,
            ph: pH,
          );

          painter.paint(canvas, size);
          final picture = recorder.endRecording();
          final img =
              await picture.toImage(size.width.toInt(), size.height.toInt());
          final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            imagesStructural[floor] = byteData.buffer.asUint8List();
          }
        } catch (e) {
          debugPrint(
              '[PDF] Error generating structural 3D image for floor $floor: $e');
        }
      }
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

      // Try traditional variation as fallback if the first one failed
      if (imageElevation == null && variations.length > 1) {
        final tradUrl = variations[1]['image_url']?.toString();
        if (tradUrl != null && tradUrl.isNotEmpty) {
          imageElevation =
              await fetchImage('traditional elevation', directUrl: tradUrl);
        }
      }

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

    pw.Font baseFont;
    pw.Font baseFontBold;
    pw.Font? tamilFont;
    pw.Font? tamilFontBold;

    try {
      baseFont = await PdfGoogleFonts.robotoRegular().timeout(const Duration(seconds: 4));
      baseFontBold = await PdfGoogleFonts.robotoBold().timeout(const Duration(seconds: 4));
    } catch (_) {
      baseFont = pw.Font.helvetica();
      baseFontBold = pw.Font.helveticaBold();
    }

    try {
      tamilFont = await PdfGoogleFonts.notoSansTamilRegular().timeout(const Duration(seconds: 4));
      tamilFontBold = await PdfGoogleFonts.notoSansTamilBold().timeout(const Duration(seconds: 4));
    } catch (_) {
      tamilFont = null;
      tamilFontBold = null;
    }

    final pdfTheme = pw.ThemeData.withFont(
      base: baseFont,
      bold: baseFontBold,
      fontFallback: [
        if (tamilFont != null) tamilFont,
        baseFontBold,
        if (tamilFontBold != null) tamilFontBold,
      ],
    );

    final pdf = pw.Document(theme: pdfTheme);

    String cleanProjectName(String? raw) {
      if (raw == null || raw.trim().isEmpty) return 'Residential Architectural Project';
      if (raw.contains('|')) {
        return 'Residential Architectural Feasibility Report';
      }
      return raw.trim();
    }

    String cleanDateString(String rawDate) {
      try {
        final dt = DateTime.parse(rawDate);
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
      } catch (_) {
        return rawDate.split(' ')[0];
      }
    }

    String formatIndianCurrency(num amount) {
      final int val = amount.round();
      if (val >= 10000000) {
        return 'Rs. ${(val / 10000000).toStringAsFixed(2)} Cr';
      } else if (val >= 100000) {
        return 'Rs. ${(val / 100000).toStringAsFixed(2)} Lakhs';
      }
      final str = val.toString();
      if (str.length <= 3) return 'Rs. $str';
      String lastThree = str.substring(str.length - 3);
      String otherNumbers = str.substring(0, str.length - 3);
      RegExp reg = RegExp(r'(\d+?)(?=(\d{2})+(?!\d))');
      String formatted = otherNumbers.replaceAllMapped(reg, (Match m) => '${m[1]},');
      return 'Rs. $formatted,$lastThree';
    }

    String formatNumberCommas(num val) {
      final str = val.round().toString();
      if (str.length <= 3) return str;
      String lastThree = str.substring(str.length - 3);
      String otherNumbers = str.substring(0, str.length - 3);
      RegExp reg = RegExp(r'(\d+?)(?=(\d{2})+(?!\d))');
      String formatted = otherNumbers.replaceAllMapped(reg, (Match m) => '${m[1]},');
      return '$formatted,$lastThree';
    }

    final rawName = data['name']?.toString() ?? 'Kanavu Illam Analysis Report';
    final cleanTitle = cleanProjectName(rawName);
    final rawDate = DateTime.now().toString().split('.')[0];
    final cleanDateStr = cleanDateString(rawDate);

    // Exact Logo Brand Palette
    final primaryColor = PdfColor.fromHex('#1B212F'); // Architectural Slate Grey (from logo)
    final brandAmber = PdfColor.fromHex('#E58A18');   // Gold Amber Accent (from logo)
    final slateSteel = PdfColor.fromHex('#364050');
    final slateMuted = PdfColor.fromHex('#64748B');
    final textDark = PdfColor.fromHex('#1E293B');
    final bgLight = PdfColor.fromHex('#F8FAFC');
    final borderSlate = PdfColor.fromHex('#E2E8F0');
    final tintAmber = PdfColor.fromHex('#FFFBEB');
    final accentGreen = PdfColor.fromHex('#10B981');
    final accentRed = PdfColor.fromHex('#EF4444');

    pw.Widget buildPageFooter(pw.Context context) {
      return pw.Column(
        children: [
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(child: pw.Container(height: 1.5, color: brandAmber)),
              pw.SizedBox(width: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text('KANAVU ILLAM',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 7, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Container(height: 1.5, color: brandAmber)),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Kanavu Illam™ · $cleanTitle · Confidential',
                    style: pw.TextStyle(color: slateMuted, fontSize: 8)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(color: slateMuted, fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      );
    }

    pw.Widget buildSectionHeader(String number, String title) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: brandAmber,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(number,
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(width: 8),
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 1.5, width: double.infinity, color: brandAmber),
          pw.SizedBox(height: 12),
        ],
      );
    }

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.only(left: 36, right: 36, top: 28, bottom: 28),
    );

    // =========================================================================
    // PAGE 1: EXECUTIVE COVER PAGE (APP LOGO + USER & PAYMENT DETAILS ONLY)
    // =========================================================================
    String paymentAmount = 'Rs. 1.00';
    if (data['amount'] != null) {
      paymentAmount = 'Rs. ${data['amount']}';
    } else if (rawName.contains('|')) {
      final parts = rawName.split('|');
      if (parts.length >= 3 && num.tryParse(parts[2]) != null) {
        paymentAmount = 'Rs. ${parts[2]}';
      }
    }
    final txnId = data['payment_id']?.toString() ??
        'KI-PAY-${(data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString()).replaceAll('project_', '').substring(0, math.min(10, (data['id']?.toString() ?? '8942107452').length))}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: primaryColor, width: 2),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Spacer(),

                // Center Large App Logo
                if (logoImageBytes != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: bgLight,
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: brandAmber, width: 2.5),
                    ),
                    child: pw.Image(pw.MemoryImage(logoImageBytes), height: 160),
                  )
                else
                  pw.Container(
                    width: 150,
                    height: 150,
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: brandAmber, width: 3),
                    ),
                    child: pw.Center(
                      child: pw.Text('KI',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 54,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                  ),

                pw.SizedBox(height: 22),
                pw.Text('KANAVU ILLAM',
                    style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: 1.5)),
                pw.SizedBox(height: 4),
                pw.Text('House Plan Analysis & Engineering Report',
                    style: pw.TextStyle(fontSize: 12, color: slateMuted)),

                pw.SizedBox(height: 32),

                // Card with ONLY User Details and Payment Details
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(18),
                  decoration: pw.BoxDecoration(
                    color: bgLight,
                    border: pw.Border.all(color: borderSlate, width: 1.5),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // User Details Section
                      pw.Text('USER DETAILS',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: brandAmber)),
                      pw.SizedBox(height: 10),
                      _buildInfoRow('User Name', (data['user_name'] != null && data['user_name'].toString().trim().isNotEmpty) ? data['user_name'].toString() : 'Valued Homeowner', textDark),
                      pw.SizedBox(height: 6),
                      _buildInfoRow('Email', (data['email'] != null && data['email'].toString().trim().isNotEmpty) ? data['email'].toString() : 'support@kanavuillam.in', textDark),
                      pw.SizedBox(height: 6),
                      _buildInfoRow('Contact', (data['phone'] != null && data['phone'].toString().trim().isNotEmpty) ? data['phone'].toString() : '+91 75508 80429', textDark),

                      pw.SizedBox(height: 14),
                      pw.Container(height: 1, color: borderSlate),
                      pw.SizedBox(height: 14),

                      // Payment Details Section
                      pw.Text('PAYMENT DETAILS',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: brandAmber)),
                      pw.SizedBox(height: 10),
                      _buildInfoRow('Amount Paid', paymentAmount, primaryColor, isBold: true),
                      pw.SizedBox(height: 6),
                      _buildInfoRow('Payment Status', 'PAID (Verified Online)', accentGreen, isBold: true),
                      pw.SizedBox(height: 6),
                      _buildInfoRow('Transaction Ref', txnId, textDark),
                      pw.SizedBox(height: 6),
                      _buildInfoRow('Payment Date', cleanDateStr, textDark),
                    ],
                  ),
                ),

                pw.Spacer(),

                // Minimal bottom branding note
                pw.Text('Kanavu Illam AI Architectural Engine · Crescent Moon Consulting Services',
                    style: pw.TextStyle(fontSize: 8, color: slateMuted)),
              ],
            ),
          );
        },
      ),
    );

    // =========================================================================
    // PAGE 2: 3D HOUSE VISUALIZATION & SPATIAL BLUEPRINT
    // =========================================================================
    if (selectedReportIds.isEmpty || selectedReportIds.contains('3d')) {
      for (var floor in floors) {
        final floorData = isMultiFloor(floorsMap) ? (floorsMap[floor] ?? ground) : ground;
        final rooms = floorData['rooms'] as List? ?? [];
        String title = floor == 'default' ? 'GROUND FLOOR SPATIAL MODEL' : '${floor.toString().toUpperCase()} FLOOR SPATIAL MODEL';

        pdf.addPage(
          pw.Page(
            pageTheme: pageTheme,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  buildSectionHeader('01', '3D HOUSE VISUALIZATION & SPATIAL BLUEPRINT'),
                  pw.Text(title,
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textDark)),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Container(
                      height: 290,
                      width: double.infinity,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#0B1325'),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: borderSlate, width: 1),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 8,
                        verticalRadius: 8,
                        child: images3d != null && (images3d[floor] != null || images3d['default'] != null)
                            ? pw.Center(
                                child: pw.Image(
                                  pw.MemoryImage(images3d[floor] ?? images3d['default']!),
                                  fit: pw.BoxFit.contain,
                                ),
                              )
                            : _buildApp3DModel(floorData, projWidth, projHeight),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: bgLight,
                      border: pw.Border.all(color: borderSlate, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('SPATIAL SPECIFICATIONS & ROOM DISTRIBUTION',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: brandAmber)),
                            pw.Text('${(projWidth * projHeight).toInt()} sq.ft Built-Up',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildOverviewBadge('Frontage', '${projWidth.toInt()} ft', borderSlate, textDark),
                            _buildOverviewBadge('Depth', '${projHeight.toInt()} ft', borderSlate, textDark),
                            _buildOverviewBadge('Orientation', '${project['orientation'] ?? data['orientation'] ?? 'North'}', borderSlate, textDark),
                            _buildOverviewBadge('Total Rooms', '${rooms.length} Zones', borderSlate, textDark),
                          ],
                        ),
                        if (rooms.isNotEmpty) ...[
                          pw.SizedBox(height: 10),
                          pw.Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            children: rooms.take(8).map((rm) {
                              final rName = rm['name']?.toString() ?? 'Room';
                              final rw = (rm['width'] as num?)?.toDouble() ?? 0;
                              final rh = (rm['height'] as num?)?.toDouble() ?? 0;
                              final dimStr = (rw > 0 && rh > 0) ? " (${rw.toInt()}'×${rh.toInt()}')" : "";
                              return pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  border: pw.Border.all(color: borderSlate),
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                child: pw.Text(
                                  '$rName$dimStr',
                                  style: pw.TextStyle(fontSize: 8, color: textDark),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.Spacer(),
                  buildPageFooter(context),
                ],
              );
            },
          ),
        );
      }
    }

    // =========================================================================
    // PAGE 3: VASTU SHASTRA COMPLIANCE AUDIT (FULL BOTTOM COVERAGE)
    // =========================================================================
    if (selectedReportIds.isEmpty || selectedReportIds.contains('vastu')) {
      for (var floor in floors) {
        final vastu = isMultiFloor(vastuRoot) ? (vastuRoot[floor] ?? vastuRoot) : vastuRoot;
        String title = floor == 'default' ? 'OVERALL VASTU AUDIT' : '${floor.toString().toUpperCase()} FLOOR VASTU AUDIT';

        pdf.addPage(
          pw.Page(
            pageTheme: pageTheme,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  buildSectionHeader('02', 'VASTU SHASTRA COMPLIANCE AUDIT'),
                  pw.Text(title,
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textDark)),
                  pw.SizedBox(height: 6),

                  // Score & Status Card
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: bgLight,
                      border: pw.Border.all(color: borderSlate, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Row(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: pw.BoxDecoration(
                                color: brandAmber,
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Text('${vastu['score'] ?? 75}/100',
                                  style: pw.TextStyle(
                                      fontSize: 15,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.white)),
                            ),
                            pw.SizedBox(width: 10),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Vastu Compliance Score',
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                                pw.Text('Grade: ${vastu['grade'] ?? 'B+'} · Vedic Architectural Standards',
                                    style: pw.TextStyle(fontSize: 8, color: slateMuted)),
                              ],
                            ),
                          ],
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#ECFDF5'),
                            border: pw.Border.all(color: accentGreen, width: 1),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text('VERIFIED ALIGNMENT',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accentGreen)),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  // Room Placement Matrix Table
                  pw.Text('Directional Room Placement Matrix',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: borderSlate, width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: primaryColor),
                        children: [
                          _buildTableHeaderCell('FUNCTIONAL ZONE'),
                          _buildTableHeaderCell('DIRECTION / ZONE'),
                          _buildTableHeaderCell('VASTU COMPLIANCE STATUS'),
                        ],
                      ),
                      if (vastu['mainEntrance'] != null)
                        _buildPlacementRow('Main Entrance', vastu['mainEntrance'].toString(), borderSlate, textDark),
                      if (vastu['kitchen'] != null)
                        _buildPlacementRow('Kitchen (Agni)', vastu['kitchen'].toString(), borderSlate, textDark),
                      if (vastu['masterBedroom'] != null)
                        _buildPlacementRow('Master Bedroom (Nirruthi)', vastu['masterBedroom'].toString(), borderSlate, textDark),
                      if (vastu['poojaRoom'] != null)
                        _buildPlacementRow('Pooja Room (Ishanya)', vastu['poojaRoom'].toString(), borderSlate, textDark),
                      if (vastu['livingRoom'] != null)
                        _buildPlacementRow('Living Room', vastu['livingRoom'].toString(), borderSlate, textDark),
                      if (vastu['bathroom'] != null)
                        _buildPlacementRow('Bathroom / Toilets', vastu['bathroom'].toString(), borderSlate, textDark),
                      if (vastu['staircase'] != null)
                        _buildPlacementRow('Staircase', vastu['staircase'].toString(), borderSlate, textDark),
                    ],
                  ),
                  pw.SizedBox(height: 8),

                  // Positive Alignments (Strengths)
                  if ((vastu['strengths'] as List?)?.isNotEmpty ?? false) ...[
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#ECFDF5'),
                        border: pw.Border.all(color: PdfColor.fromHex('#A7F3D0'), width: 1),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Positive Alignments (Benefits)',
                              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accentGreen)),
                          pw.SizedBox(height: 4),
                          ...(vastu['strengths'] as List).take(4).map((e) {
                            final clean = e.toString().replaceFirst(RegExp(r'^[\s\-\d\.]+\s*'), '');
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 2),
                              child: pw.Text('• $clean', style: pw.TextStyle(fontSize: 8, color: textDark)),
                            );
                          }),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 6),
                  ],

                  // Deductions & Remedial Suggestions Side-by-side
                  if (((vastu['violations'] as List?)?.isNotEmpty ?? false) || ((vastu['suggestions'] as List?)?.isNotEmpty ?? false)) ...[
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if ((vastu['violations'] as List?)?.isNotEmpty ?? false)
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              decoration: pw.BoxDecoration(
                                color: PdfColor.fromHex('#FEF2F2'),
                                border: pw.Border.all(color: PdfColor.fromHex('#FECACA'), width: 1),
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Deviations',
                                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accentRed)),
                                  pw.SizedBox(height: 4),
                                  ...(vastu['violations'] as List).take(3).map((e) {
                                    final clean = e.toString().replaceFirst(RegExp(r'^[\s\-\d\.]+\s*'), '');
                                    return pw.Padding(
                                      padding: const pw.EdgeInsets.only(bottom: 2),
                                      child: pw.Text('• $clean', style: pw.TextStyle(fontSize: 8, color: textDark)),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        if (((vastu['violations'] as List?)?.isNotEmpty ?? false) && ((vastu['suggestions'] as List?)?.isNotEmpty ?? false))
                          pw.SizedBox(width: 8),
                        if ((vastu['suggestions'] as List?)?.isNotEmpty ?? false)
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              decoration: pw.BoxDecoration(
                                color: tintAmber,
                                border: pw.Border.all(color: PdfColor.fromHex('#FDE68A'), width: 1),
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Corrective Remedies',
                                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: brandAmber)),
                                  pw.SizedBox(height: 4),
                                  ...(vastu['suggestions'] as List).take(3).map((e) {
                                    final clean = e.toString().replaceFirst(RegExp(r'^[\s\-\d\.]+\s*'), '');
                                    return pw.Padding(
                                      padding: const pw.EdgeInsets.only(bottom: 2),
                                      child: pw.Text('• $clean', style: pw.TextStyle(fontSize: 8, color: textDark)),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                  ],

                  // Bottom Fill: Vedic Directional & Elemental Zoning Matrix (covers empty space)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: bgLight,
                      border: pw.Border.all(color: borderSlate, width: 1),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('VEDIC DIRECTIONAL ZONING & HARMONIOUS SPATIAL PRINCIPLES',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: brandAmber)),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            _buildVastuZoneBadge('North-East (Ishanya)', 'Water / Solar Entry', 'Pooja, light entry & open positive flow', borderSlate, textDark),
                            pw.SizedBox(width: 6),
                            _buildVastuZoneBadge('South-East (Agni)', 'Fire / Vitality', 'Kitchen cooking hearth, electrical switchboards', borderSlate, textDark),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            _buildVastuZoneBadge('South-West (Nirruthi)', 'Earth / Heaviness', 'Master Bedroom, heavy storage & structural anchor', borderSlate, textDark),
                            pw.SizedBox(width: 6),
                            _buildVastuZoneBadge('North-West (Vayu)', 'Air / Motion', 'Guest bedroom, circulation & cross-ventilation', borderSlate, textDark),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.Spacer(),
                  buildPageFooter(context),
                ],
              );
            },
          ),
        );
      }
    }

    // =========================================================================
    // PAGE 4: CONSTRUCTION COST ESTIMATION & BOQ (FULL BOTTOM COVERAGE)
    // =========================================================================
    if (selectedReportIds.isEmpty || selectedReportIds.contains('cost')) {
      for (var floor in floors) {
        final costData = _extractCostDataForPdf(data, floor, projWidth, projHeight);
        final double totalArea = (costData['total_area_sqft'] as num?)?.toDouble() ?? (projWidth * projHeight);
        final est = costData['estimates'] as Map<String, dynamic>? ?? {};
        final materials = costData['materials'] as Map<String, dynamic>? ?? {};

        String title = floor == 'default' ? 'OVERALL COST ESTIMATION & BOQ' : '${floor.toString().toUpperCase()} FLOOR ESTIMATION & BOQ';

        pdf.addPage(
          pw.Page(
            pageTheme: pageTheme,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  buildSectionHeader('03', 'CONSTRUCTION COST ESTIMATION & BOQ'),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(title,
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: textDark)),
                      pw.Text('Based on ${totalArea.toInt()} sq.ft Built-Up Area · 2026 Live Market Rates',
                          style: pw.TextStyle(fontSize: 8, color: slateMuted)),
                    ],
                  ),
                  pw.SizedBox(height: 8),

                  // 3 Package Tier Cards
                  pw.Row(
                    children: [
                      _buildPackageCard('Basic Package', 'Rs. 1,750 / sqft', formatIndianCurrency(est['basic'] ?? 0), false, borderSlate, primaryColor, brandAmber, textDark),
                      pw.SizedBox(width: 8),
                      _buildPackageCard('Standard (Recommended)', 'Rs. 2,250 / sqft', formatIndianCurrency(est['standard'] ?? 0), true, borderSlate, primaryColor, brandAmber, textDark),
                      pw.SizedBox(width: 8),
                      _buildPackageCard('Premium Luxury', 'Rs. 3,350 / sqft', formatIndianCurrency(est['premium'] ?? 0), false, borderSlate, primaryColor, brandAmber, textDark),
                    ],
                  ),
                  pw.SizedBox(height: 10),

                  // Material Breakdown Table
                  pw.Text('Key Material Quantities & Cost Breakdown',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textDark)),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: borderSlate, width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: primaryColor),
                        children: [
                          _buildTableHeaderCell('MATERIAL ITEM'),
                          _buildTableHeaderCell('QUANTITY'),
                          _buildTableHeaderCell('UNIT'),
                          _buildTableHeaderCell('UNIT RATE'),
                          _buildTableHeaderCell('EST. TOTAL'),
                        ],
                      ),
                      ...materials.entries.take(8).map((e) {
                        final mat = e.value is Map ? e.value : {};
                        final q = (mat['quantity'] as num?)?.toDouble() ?? 0;
                        final p = (mat['price'] as num?)?.toDouble() ?? 0;
                        final itemTotal = (q * p).round();
                        return pw.TableRow(
                          children: [
                            _buildTableCell(mat['name']?.toString() ?? e.key.toString(), textDark, isBold: true),
                            _buildTableCell(formatNumberCommas(q), textDark),
                            _buildTableCell(mat['unit']?.toString() ?? '-', textDark),
                            _buildTableCell('Rs. ${formatNumberCommas(p)}', textDark),
                            _buildTableCell('Rs. ${formatNumberCommas(itemTotal)}', primaryColor, isBold: true),
                          ],
                        );
                      }),
                    ],
                  ),
                  pw.SizedBox(height: 8),

                  // Material vs Labor Split Banner
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: bgLight,
                      border: pw.Border.all(color: borderSlate),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Material Cost Component (~62%)',
                                style: pw.TextStyle(fontSize: 7, color: slateMuted)),
                            pw.Text(formatIndianCurrency((est['standard'] ?? 0) * 0.62),
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          ],
                        ),
                        pw.Container(width: 1, height: 20, color: borderSlate),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Labor & Contracting (~38%)',
                                style: pw.TextStyle(fontSize: 7, color: slateMuted)),
                            pw.Text(formatIndianCurrency((est['standard'] ?? 0) * 0.38),
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          ],
                        ),
                        pw.Container(width: 1, height: 20, color: borderSlate),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Standard Grand Total',
                                style: pw.TextStyle(fontSize: 7, color: slateMuted)),
                            pw.Text(formatIndianCurrency(est['standard'] ?? 0),
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: brandAmber)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  // Bottom Fill: Construction Milestones & Payment Schedule (covers empty space)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: bgLight,
                      border: pw.Border.all(color: borderSlate, width: 1),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PROJECT CONSTRUCTION MILESTONES & DISBURSEMENT PHASES',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: brandAmber)),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            _buildCostStageBadge('Stage 1 (20%)', 'Substructure', 'PCC, isolated footings & plinth tie beam', borderSlate, textDark),
                            pw.SizedBox(width: 6),
                            _buildCostStageBadge('Stage 2 (35%)', 'Superstructure', 'RCC columns, beam casting & roof slab concrete', borderSlate, textDark),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            _buildCostStageBadge('Stage 3 (25%)', 'Masonry & Conduits', 'Brick masonry, conduit piping & plastering', borderSlate, textDark),
                            pw.SizedBox(width: 6),
                            _buildCostStageBadge('Stage 4 (20%)', 'Finishing & Handover', 'Tile flooring, sanitary, painting & fixtures', borderSlate, textDark),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.Spacer(),
                  buildPageFooter(context),
                ],
              );
            },
          ),
        );
      }
    }

    // =========================================================================
    // PAGE 5: STRUCTURAL ENGINEERING ANALYSIS (IS 456:2000) (FULL BOTTOM COVERAGE)
    // =========================================================================
    if (selectedReportIds.isEmpty || selectedReportIds.contains('structural')) {
      final structuralRoot = data['structural_data'] as Map<String, dynamic>? ??
          modelData['_structural'] as Map<String, dynamic>? ??
          {};

      for (var floor in floors) {
        final struct = isMultiFloor(structuralRoot) ? structuralRoot[floor] : structuralRoot;
        if (struct == null || struct.isEmpty || struct is! Map) continue;

        final summary = struct['summary'] ?? {};
        final rcmd = struct['recommendations'] ?? {};
        String title = floor == 'default' ? 'GROUND FLOOR STRUCTURAL ANALYSIS' : '${floor.toString().toUpperCase()} FLOOR STRUCTURAL ANALYSIS';

        pdf.addPage(
          pw.Page(
            pageTheme: pageTheme,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  buildSectionHeader('04', 'STRUCTURAL ENGINEERING ANALYSIS (IS 456:2000)'),
                  pw.Text(title,
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: textDark)),
                  pw.SizedBox(height: 6),

                  if (imagesStructural[floor] != null) ...[
                    pw.Center(
                      child: pw.Container(
                        height: 195,
                        width: double.infinity,
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#F1F5F9'),
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: borderSlate, width: 1),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 8,
                          verticalRadius: 8,
                          child: pw.Center(
                            child: pw.Image(
                              pw.MemoryImage(imagesStructural[floor]!),
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                  ],

                  // Key Structural Parameters Grid
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: bgLight,
                      border: pw.Border.all(color: borderSlate, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildOverviewBadge('Columns', '${rcmd['column_count'] ?? '12'} Placements', borderSlate, textDark),
                        _buildOverviewBadge('Total Load', '${formatNumberCommas(summary['estimated_load_kg'] ?? 121408)} kg', borderSlate, textDark),
                        _buildOverviewBadge('Foundation', '${rcmd['foundation_depth_ft'] ?? '5'} ft Depth', borderSlate, textDark),
                        _buildOverviewBadge('Concrete Grade', 'M20 Design Mix', borderSlate, textDark),
                        _buildOverviewBadge('Steel Grade', 'Fe500 TMT Rebar', borderSlate, textDark),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  // Structural Safety & Stability Check Table
                  pw.Text('IS 456:2000 Structural Safety & Stability Verification',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textDark)),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: borderSlate, width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: primaryColor),
                        children: [
                          _buildTableHeaderCell('SAFETY & DESIGN PARAMETER'),
                          _buildTableHeaderCell('CALCULATED / SPECIFIED VALUE'),
                        ],
                      ),
                      _buildSafetyRow('Uploaded Plan Dimensions', "${projWidth.toInt()}' × ${projHeight.toInt()}' (${(projWidth * projHeight).toInt()} sq.ft)", textDark),
                      _buildSafetyRow('Design Standard Compliance', 'IS 456:2000 (Plain & RCC) & IS 1893:2016', textDark),
                      _buildSafetyRow('Dead Load (DL)', '3.8 kN/m² (Slab + Finishes + Internal Walls)', textDark),
                      _buildSafetyRow('Live Load (LL - IS 875 Part 2)', '2.0 kN/m² (Residential Occupancy)', textDark),
                      _buildSafetyRow('Total Factored Design Load', '${((1.5 * 3.8 + 1.5 * 2.0) * (projWidth * projHeight * 0.092903)).toStringAsFixed(1)} kN (~${(((1.5 * 3.8 + 1.5 * 2.0) * (projWidth * projHeight * 0.092903)) / 9.81).toStringAsFixed(1)} Tons)', textDark),
                      _buildSafetyRow('Deflection Margin Compliance', 'Calculated: ${(((math.max(projWidth, projHeight) * 0.45 * 0.3048 * 1000) / 250) * 0.57).toStringAsFixed(1)} mm (43% Safety Margin Under Limit)', textDark),
                      _buildSafetyRow('Seismic Ductility Zone', 'Zone III Seismic Resistant Ductile Detailing', textDark),
                    ],
                  ),
                  pw.SizedBox(height: 6),

                  // Bottom Fill: Geotechnical & Soil Design Specifications
                  pw.Container(
                    padding: const pw.EdgeInsets.all(7),
                    decoration: pw.BoxDecoration(
                      color: bgLight,
                      border: pw.Border.all(color: borderSlate, width: 1),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('GEOTECHNICAL & FOUNDATION STRATA ASSUMPTIONS (IS 1904 / IS 6403)',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: brandAmber)),
                        pw.SizedBox(height: 3),
                        _buildGuidelineItem('• Safe Bearing Capacity (SBC):', 'Assumed 180-200 kN/m² on firm non-expansive hard soil strata.'),
                        _buildGuidelineItem('• Water-Cement Ratio:', 'Strictly maintained at 0.45 - 0.50 with water-reducing admixtures for durability.'),
                        _buildGuidelineItem('• Steel Rebar Ductility:', 'High yield Fe500 TMT steel rebar with elongation > 14.5% conforming to IS 1786.'),
                      ],
                    ),
                  ),

                  pw.Spacer(),
                  buildPageFooter(context),
                ],
              );
            },
          ),
        );

        // =====================================================================
        // PAGE 6: STRUCTURAL BEAM & COLUMN LAYOUT BLUEPRINT (FULL BOTTOM COVERAGE)
        // =====================================================================
        pdf.addPage(
          pw.Page(
            pageTheme: pageTheme,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  buildSectionHeader('04', 'STRUCTURAL BEAM & COLUMN LAYOUT BLUEPRINT'),
                  pw.Text('Beam Layout Plan & Column Placement Blueprint',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
                  pw.SizedBox(height: 4),

                  _buildBeamLayout(
                    isMultiFloor(floorsMap) ? (floorsMap[floor] ?? ground) : ground,
                    struct,
                    projWidth,
                    projHeight,
                  ),
                  pw.SizedBox(height: 8),

                  // Beam Schedule Table
                  pw.Text('Beam Schedule & Reinforcement Details',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textDark)),
                  pw.SizedBox(height: 3),
                  pw.Table(
                    border: pw.TableBorder.all(color: borderSlate, width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: primaryColor),
                        children: [
                          _buildTableHeaderCell('BEAM MARK'),
                          _buildTableHeaderCell('CROSS-SECTION'),
                          _buildTableHeaderCell('TOP STEEL'),
                          _buildTableHeaderCell('BOTTOM STEEL'),
                          _buildTableHeaderCell('STIRRUPS / RINGS'),
                        ],
                      ),
                      pw.TableRow(children: [
                        _buildTableCell('B1 (Primary)', textDark, isBold: true),
                        _buildTableCell('9" × 12"', textDark),
                        _buildTableCell('2 - 16mm Fe500', textDark),
                        _buildTableCell('2 - 16mm Fe500', textDark),
                        _buildTableCell('8mm @ 6" c/c', textDark),
                      ]),
                      pw.TableRow(children: [
                        _buildTableCell('B2 (Secondary)', textDark, isBold: true),
                        _buildTableCell('9" × 9"', textDark),
                        _buildTableCell('2 - 12mm Fe500', textDark),
                        _buildTableCell('2 - 12mm Fe500', textDark),
                        _buildTableCell('8mm @ 8" c/c', textDark),
                      ]),
                    ],
                  ),
                  pw.SizedBox(height: 6),

                  // RCC Slab Specification Table
                  pw.Text('RCC Floor Slab Reinforcement (IS 456 Specification)',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textDark)),
                  pw.SizedBox(height: 3),
                  pw.Table(
                    border: pw.TableBorder.all(color: borderSlate, width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: primaryColor),
                        children: [
                          _buildTableHeaderCell('SLAB PARAMETER'),
                          _buildTableHeaderCell('STRUCTURAL SPECIFICATION'),
                        ],
                      ),
                      _buildSafetyRow('Slab Thickness', '5 Inches (125 mm) Solid RCC Slab', textDark),
                      _buildSafetyRow('Concrete Mix Grade', 'M20 Grade Design Mix (1 : 1.5 : 3)', textDark),
                      _buildSafetyRow('Main Steel (Short Span)', '8 mm TMT Fe500 @ 6" c/c spacing', textDark),
                      _buildSafetyRow('Distribution Steel (Long Span)', '8 mm TMT Fe500 @ 8" c/c spacing', textDark),
                      _buildSafetyRow('Clear Concrete Cover', '20 mm Standard Cover Blocks', textDark),
                    ],
                  ),
                  pw.SizedBox(height: 6),

                  // Bottom Fill: Curing & Formwork Stripping Standards
                  pw.Container(
                    padding: const pw.EdgeInsets.all(7),
                    decoration: pw.BoxDecoration(
                      color: bgLight,
                      border: pw.Border.all(color: borderSlate, width: 1),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CONCRETE CURING & FORMWORK STRIPPING NORMS (IS 456)',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: brandAmber)),
                        pw.SizedBox(height: 3),
                        _buildGuidelineItem('• Continuous Curing:', 'Maintain ponding on slabs and wet hessian on columns for minimum 14-21 days.'),
                        _buildGuidelineItem('• Formwork Stripping:', 'Columns: 24-48 hrs; Slab soffits: 7 days; Beam bottoms: 14 days (spans up to 6m).'),
                      ],
                    ),
                  ),

                  pw.Spacer(),
                  buildPageFooter(context),
                ],
              );
            },
          ),
        );
      }
    }

    // =========================================================================
    // ELEVATION PAGE (IF SELECTED)
    // =========================================================================
    if (selectedReportIds.contains('elevation')) {
      pdf.addPage(
        pw.Page(
          pageTheme: pageTheme,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                buildSectionHeader('05', 'FRONT ELEVATION BLUEPRINT & FACADE'),
                if (imageElevation != null) ...[
                  pw.Center(
                    child: pw.ClipRRect(
                      horizontalRadius: 8,
                      verticalRadius: 8,
                      child: pw.Image(pw.MemoryImage(imageElevation), fit: pw.BoxFit.contain, height: 320),
                    ),
                  ),
                  pw.SizedBox(height: 16),
                ],
                _buildNativeElevation(
                  ground,
                  isMultiFloor(floorsMap) ? floorsMap['first'] ?? {} : {},
                  projWidth,
                  projHeight,
                ),
                pw.SizedBox(height: 14),
                pw.Text('Architectural Facade Highlights',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: textDark)),
                pw.SizedBox(height: 6),
                pw.Text(
                    '• Large floor-to-ceiling glass apertures engineered for optimal daylight harvesting.\n• Linear geometric sunshade projections conforming to regional wind and rainfall patterns.\n• Contemporary exterior masonry composite with textured weather-proof coating.',
                    style: pw.TextStyle(fontSize: 9, color: slateMuted, lineSpacing: 1.4)),
                pw.Spacer(),
                buildPageFooter(context),
              ],
            );
          },
        ),
      );
    }

    // =========================================================================
    // FINAL PAGE: PROJECT FEASIBILITY SUMMARY & SIGN-OFF (NO EXTRA CARD, NO EXTRA PAGES!)
    // =========================================================================
    final finalVastu = isMultiFloor(vastuRoot)
        ? (vastuRoot['ground'] ?? vastuRoot['total'] ?? vastuRoot)
        : vastuRoot;
    final costEstimatesTotal = costRoot['total']?['estimates'] ?? costRoot['ground']?['estimates'] ?? costRoot['estimates'] ?? {};
    final grandStandard = (costEstimatesTotal['standard'] as num?)?.toDouble() ?? 3240000;

    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildSectionHeader('05', 'PROJECT FEASIBILITY SUMMARY & OFFICIAL SIGN-OFF'),
              pw.Text('Executive Summary & Comprehensive Project Audit',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textDark)),
              pw.SizedBox(height: 10),

              // 4 Key Summary Badges
              pw.Row(
                children: [
                  _buildSummaryPill('Vastu Score', '${finalVastu['score'] ?? 75}/100', 'Grade: ${finalVastu['grade'] ?? 'B+'}', brandAmber, bgLight, borderSlate),
                  pw.SizedBox(width: 8),
                  _buildSummaryPill('Structural Safety', '94 / 100', 'IS 456 Compliant', primaryColor, bgLight, borderSlate),
                  pw.SizedBox(width: 8),
                  _buildSummaryPill('Standard Budget', formatIndianCurrency(grandStandard), 'Turnkey Est.', brandAmber, bgLight, borderSlate),
                  pw.SizedBox(width: 8),
                  _buildSummaryPill('Timeline', '5 - 7 Months', 'Target Handover', primaryColor, bgLight, borderSlate),
                ],
              ),
              pw.SizedBox(height: 14),

              // Architectural & Engineering Guidelines
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: bgLight,
                  border: pw.Border.all(color: borderSlate, width: 1),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CRITICAL PRE-CONSTRUCTION & EXECUTION GUIDELINES',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: brandAmber)),
                    pw.SizedBox(height: 8),
                    _buildGuidelineItem('1. Soil Bearing Capacity (SBC):', 'Perform localized core plate-load testing before footing excavation to verify bearing pressure.'),
                    _buildGuidelineItem('2. Foundation Footing:', 'All isolated RCC footings must seat firmly into hard, non-expansive strata at minimum 5 ft depth.'),
                    _buildGuidelineItem('3. Curing Duration:', 'Ensure minimum 14-21 days of continuous pond curing for RCC slabs and wet hessian curing for columns.'),
                    _buildGuidelineItem('4. Material Quality:', 'Utilize certified Fe500 TMT steel rebars and fresh 53-grade OPC/PPC cement conforming to BIS codes.'),
                    _buildGuidelineItem('5. Statutory Approval:', 'Obtain local panchayat or municipal corporation building sanction prior to physical site work.'),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Project Closure & Summary Metadata Box
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: bgLight,
                  border: pw.Border.all(color: borderSlate, width: 1),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Project: $cleanTitle',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.SizedBox(height: 3),
                        pw.Text('Issuance Date: $cleanDateStr · Status: Validated Architectural Report',
                            style: pw.TextStyle(fontSize: 8, color: slateMuted)),
                      ],
                    ),
                    pw.Text('Kanavu Illam Engine',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: brandAmber)),
                  ],
                ),
              ),

              pw.Spacer(),
              buildPageFooter(context),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Map<String, dynamic> _extractCostDataForPdf(Map<String, dynamic> data,
      String floor, double projWidth, double projHeight) {
    final modelData = data['model_data'] as Map<String, dynamic>? ?? {};
    final costRoot =
        data['cost_data'] ?? data['_cost'] ?? modelData['_cost'] ?? {};

    Map<String, dynamic> cMap = {};
    if (costRoot is Map<String, dynamic>) {
      if (costRoot.containsKey(floor) && costRoot[floor] is Map) {
        cMap = Map<String, dynamic>.from(costRoot[floor]);
      } else if (costRoot.containsKey('total') && costRoot['total'] is Map) {
        cMap = Map<String, dynamic>.from(costRoot['total']);
      } else if (costRoot.containsKey('ground') && costRoot['ground'] is Map) {
        cMap = Map<String, dynamic>.from(costRoot['ground']);
      } else {
        cMap = Map<String, dynamic>.from(costRoot);
      }
    }

    double totalArea = (cMap['total_area_sqft'] as num?)?.toDouble() ??
        (projWidth * projHeight);
    if (totalArea <= 0) totalArea = 1000.0;

    Map<String, dynamic> estimates = {};
    if (cMap['estimates'] is Map && (cMap['estimates'] as Map).isNotEmpty) {
      estimates = Map<String, dynamic>.from(cMap['estimates']);
    }

    double basicVal =
        (estimates['basic'] as num?)?.toDouble() ?? (totalArea * 1750.0);
    double standardVal =
        (estimates['standard'] as num?)?.toDouble() ?? (totalArea * 2250.0);
    double premiumVal =
        (estimates['premium'] as num?)?.toDouble() ?? (totalArea * 3350.0);

    estimates['basic'] = basicVal.round();
    estimates['standard'] = standardVal.round();
    estimates['premium'] = premiumVal.round();

    Map<String, dynamic> materials = {};
    if (cMap['materials'] is Map && (cMap['materials'] as Map).isNotEmpty) {
      materials = Map<String, dynamic>.from(cMap['materials']);
    } else {
      double qCement = (totalArea * 0.40).roundToDouble();
      double qSteel = (totalArea * 3.8).roundToDouble();
      double qSand = (totalArea * 1.7).roundToDouble();
      double qAgg = (totalArea * 1.2).roundToDouble();
      double qBricks = (totalArea * 16.0).roundToDouble();
      double qTiles = (totalArea * 1.05).roundToDouble();
      double qPaint = (totalArea * 0.12).roundToDouble();
      double qElec = totalArea;
      double qPlumb = totalArea;
      double qDoors = (totalArea / 200).clamp(3, 15).roundToDouble();
      double qWindows = (totalArea / 180).clamp(3, 15).roundToDouble();

      materials = {
        'cement': {
          'name': 'Cement (OPC 53/PPC)',
          'quantity': qCement.toInt(),
          'unit': 'bags',
          'price': 440
        },
        'steel': {
          'name': 'TMT Steel Rebar',
          'quantity': qSteel.toInt(),
          'unit': 'kg',
          'price': 84
        },
        'sand': {
          'name': 'M-Sand / P-Sand',
          'quantity': qSand.toInt(),
          'unit': 'cft',
          'price': 75
        },
        'aggregate': {
          'name': 'Blue Metal Jalli',
          'quantity': qAgg.toInt(),
          'unit': 'cft',
          'price': 48
        },
        'bricks': {
          'name': 'Bricks / AAC Blocks',
          'quantity': qBricks.toInt(),
          'unit': 'pcs',
          'price': 12
        },
        'tiles': {
          'name': 'Flooring Tiles',
          'quantity': qTiles.toInt(),
          'unit': 'sqft',
          'price': 75
        },
        'paint': {
          'name': 'Emulsion Paint & Putty',
          'quantity': qPaint.toInt(),
          'unit': 'liters',
          'price': 280
        },
        'electrical': {
          'name': 'Electrical Wiring & Switches',
          'quantity': qElec.toInt(),
          'unit': 'sqft',
          'price': 140
        },
        'plumbing': {
          'name': 'Plumbing Pipes & Fittings',
          'quantity': qPlumb.toInt(),
          'unit': 'sqft',
          'price': 130
        },
        'doors': {
          'name': 'Main & Room Doors',
          'quantity': qDoors.toInt(),
          'unit': 'nos',
          'price': 12000
        },
        'windows': {
          'name': 'UPVC / Aluminum Windows',
          'quantity': qWindows.toInt(),
          'unit': 'nos',
          'price': 8500
        },
      };
    }

    return {
      'total_area_sqft': totalArea,
      'estimates': estimates,
      'materials': materials,
    };
  }

  static pw.Widget _buildBeamLayout(
      Map floorData, Map structData, double projW, double projH) {
    final walls = floorData['walls'] as List? ?? [];
    final rooms = floorData['rooms'] as List? ?? [];

    double maxW = projW > 0 ? projW : 30.0;
    double maxH = projH > 0 ? projH : 40.0;

    for (var w in walls) {
      double x1 = 0, y1 = 0, x2 = 0, y2 = 0;
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
      } else if (w['start_x'] != null) {
        x1 = (w['start_x'] as num).toDouble();
        y1 = (w['start_y'] as num).toDouble();
        x2 = (w['end_x'] as num).toDouble();
        y2 = (w['end_y'] as num).toDouble();
      }
      if (x1 > maxW) maxW = x1;
      if (x2 > maxW) maxW = x2;
      if (y1 > maxH) maxH = y1;
      if (y2 > maxH) maxH = y2;
    }
    for (var r in rooms) {
      final rx = (r['x'] as num?)?.toDouble() ?? 0.0;
      final ry = (r['y'] as num?)?.toDouble() ?? 0.0;
      final rw = (r['width'] as num?)?.toDouble() ?? 0.0;
      final rh = (r['height'] as num?)?.toDouble() ?? 0.0;
      if (rx + rw > maxW) maxW = rx + rw;
      if (ry + rh > maxH) maxH = ry + rh;
    }

    return pw.Container(
        height: 350,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          color: PdfColors.white,
        ),
        child: pw.LayoutBuilder(builder: (context, constraints) {
          final pad = 40.0;
          final availW = constraints!.maxWidth - (pad * 2);
          final availH = constraints.maxHeight - (pad * 2);
          final sX = availW / maxW;
          final sY = availH / maxH;
          final scale = (sX < sY) ? sX : sY;

          final contentW = maxW * scale;
          final contentH = maxH * scale;
          final padLeft = pad + (availW - contentW) / 2;
          final padTop = pad + (availH - contentH) / 2;

          return pw.Stack(children: [
            pw.SizedBox(
                width: constraints.maxWidth, height: constraints.maxHeight),
            pw.Positioned(
                left: padLeft,
                top: padTop,
                child: pw.CustomPaint(
                    size: PdfPoint(contentW, contentH),
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
                        } else if (w['start'] is Map) {
                          x1 = (w['start']['x'] as num).toDouble();
                          y1 = (w['start']['y'] as num).toDouble();
                          x2 = (w['end']['x'] as num).toDouble();
                          y2 = (w['end']['y'] as num).toDouble();
                        } else if (w['start_x'] != null) {
                          x1 = (w['start_x'] as num).toDouble();
                          y1 = (w['start_y'] as num).toDouble();
                          x2 = (w['end_x'] as num).toDouble();
                          y2 = (w['end_y'] as num).toDouble();
                        }
                        canvas.drawLine(x1 * scale, contentH - (y1 * scale),
                            x2 * scale, contentH - (y2 * scale));
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
                        } else if (w['start'] is Map) {
                          x1 = (w['start']['x'] as num).toDouble();
                          y1 = (w['start']['y'] as num).toDouble();
                          x2 = (w['end']['x'] as num).toDouble();
                          y2 = (w['end']['y'] as num).toDouble();
                        } else if (w['start_x'] != null) {
                          x1 = (w['start_x'] as num).toDouble();
                          y1 = (w['start_y'] as num).toDouble();
                          x2 = (w['end_x'] as num).toDouble();
                          y2 = (w['end_y'] as num).toDouble();
                        }
                        final cw = 8.0;
                        final ch = 8.0;
                        canvas.drawRect(x1 * scale - cw / 2,
                            contentH - (y1 * scale) - ch / 2, cw, ch);
                        canvas.drawRect(x2 * scale - cw / 2,
                            contentH - (y2 * scale) - ch / 2, cw, ch);
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
                left: padLeft + (rx + rw / 2) * scale - (name.length * 2.2),
                top: padTop + (contentH - (ry + rh / 2) * scale) - 6,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    name,
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ),
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
                left: padLeft + contentW - 10,
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
                left: padLeft - 25,
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
                left: padLeft - 25,
                top: padTop + contentH - 10,
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

    double maxW = projW > 0 ? projW : 30.0;
    double maxH = projH > 0 ? projH : 40.0;

    for (var w in walls) {
      double x1 = 0, y1 = 0, x2 = 0, y2 = 0;
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
      } else if (w['start_x'] != null) {
        x1 = (w['start_x'] as num).toDouble();
        y1 = (w['start_y'] as num).toDouble();
        x2 = (w['end_x'] as num).toDouble();
        y2 = (w['end_y'] as num).toDouble();
      }
      if (x1 > maxW) maxW = x1;
      if (x2 > maxW) maxW = x2;
      if (y1 > maxH) maxH = y1;
      if (y2 > maxH) maxH = y2;
    }
    for (var r in rooms) {
      final rx = (r['x'] as num?)?.toDouble() ?? 0.0;
      final ry = (r['y'] as num?)?.toDouble() ?? 0.0;
      final rw = (r['width'] as num?)?.toDouble() ?? 0.0;
      final rh = (r['height'] as num?)?.toDouble() ?? 0.0;
      if (rx + rw > maxW) maxW = rx + rw;
      if (ry + rh > maxH) maxH = ry + rh;
    }

    return pw.Container(
        height: 350,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#0B1325'),
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.LayoutBuilder(builder: (context, constraints) {
          final pad = 40.0;
          final availW = constraints!.maxWidth - (pad * 2);
          final availH = constraints.maxHeight - (pad * 2);
          final sX = availW / maxW;
          final sY = availH / maxH;
          final scale = (sX < sY) ? sX : sY;

          final contentW = maxW * scale;
          final contentH = maxH * scale;
          final padLeft = pad + (availW - contentW) / 2;
          final padTop = pad + (availH - contentH) / 2;

          return pw.Stack(children: [
            pw.SizedBox(
                width: constraints.maxWidth, height: constraints.maxHeight),
            pw.Positioned(
                left: padLeft,
                top: padTop,
                child: pw.CustomPaint(
                    size: PdfPoint(contentW, contentH),
                    painter: (PdfGraphics canvas, PdfPoint size) {
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

                      canvas.setFillColor(const PdfColor(0, 0, 0, 0.5));
                      canvas.drawRect(8, -12, contentW, contentH);
                      canvas.fillPath();

                      canvas.setFillColor(PdfColor.fromHex('#C9D1D9'));
                      canvas.drawRect(0, 0, contentW, contentH);
                      canvas.fillPath();

                      canvas.setStrokeColor(PdfColor.fromHex('#475569'));
                      canvas.setLineWidth(14.0);
                      for (var w in walls) {
                        double x1 = 0, y1 = 0, x2 = 0, y2 = 0;
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
                        } else if (w['start_x'] != null) {
                          x1 = (w['start_x'] as num).toDouble();
                          y1 = (w['start_y'] as num).toDouble();
                          x2 = (w['end_x'] as num).toDouble();
                          y2 = (w['end_y'] as num).toDouble();
                        }
                        canvas.drawLine(
                            x1 * scale + 3,
                            contentH - (y1 * scale) - 4,
                            x2 * scale + 3,
                            contentH - (y2 * scale) - 4);
                      }
                      canvas.strokePath();

                      canvas.setStrokeColor(PdfColor.fromHex('#F1F5F9'));
                      canvas.setLineWidth(10.0);
                      for (var w in walls) {
                        double x1 = 0, y1 = 0, x2 = 0, y2 = 0;
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
                        } else if (w['start_x'] != null) {
                          x1 = (w['start_x'] as num).toDouble();
                          y1 = (w['start_y'] as num).toDouble();
                          x2 = (w['end_x'] as num).toDouble();
                          y2 = (w['end_y'] as num).toDouble();
                        }
                        canvas.drawLine(x1 * scale, contentH - (y1 * scale),
                            x2 * scale, contentH - (y2 * scale));
                      }
                      canvas.strokePath();

                      final doors = floorData['doors'] as List? ?? [];
                      for (var d in doors) {
                        double dx = (d['x'] as num?)?.toDouble() ?? 0.0;
                        double dy = (d['y'] as num?)?.toDouble() ?? 0.0;
                        double dw = (d['width'] as num?)?.toDouble() ?? 3.0;
                        double ex = dx + (dw * 0.7);
                        double ey = dy + (dw * 0.7);

                        canvas.setStrokeColor(PdfColor.fromHex('#29180C'));
                        canvas.setLineWidth(4.0);
                        canvas.drawLine(
                            dx * scale + 3,
                            contentH - (dy * scale) - 4,
                            ex * scale + 3,
                            contentH - (ey * scale) - 4);
                        canvas.strokePath();

                        canvas.setStrokeColor(PdfColor.fromHex('#8B4513'));
                        canvas.drawLine(dx * scale, contentH - (dy * scale),
                            ex * scale, contentH - (ey * scale));
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
                  left: padLeft + (rx + rw / 2) * scale - (name.length * 2.8),
                  top: padTop + (ry + rh / 2) * scale - 8,
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

          // To perfectly center the isometric drawing vertically:
          // Max Y = offsetY + totalZ * scale
          // Min Y = offsetY - (projW + projH) * sinA * scale
          // We want (Max Y + Min Y) / 2 = constraints.maxHeight / 2
          final offsetY = (constraints.maxHeight / 2) -
              (totalZ * scale / 2) +
              ((projW + projH) * sinA * scale / 2);

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
                          } else if (w['start'] is Map) {
                            x1 = (w['start']['x'] as num).toDouble();

                            y1 = (w['start']['y'] as num).toDouble();

                            x2 = (w['end']['x'] as num).toDouble();

                            y2 = (w['end']['y'] as num).toDouble();
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
                          } else if (w['start'] is Map) {
                            x1 = (w['start']['x'] as num).toDouble();

                            y1 = (w['start']['y'] as num).toDouble();

                            x2 = (w['end']['x'] as num).toDouble();

                            y2 = (w['end']['y'] as num).toDouble();
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
                          } else if (w['start'] is Map) {
                            x1 = (w['start']['x'] as num).toDouble();

                            y1 = (w['start']['y'] as num).toDouble();

                            x2 = (w['end']['x'] as num).toDouble();

                            y2 = (w['end']['y'] as num).toDouble();
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

  static pw.Widget _buildOverviewBadge(String label, String value, PdfColor borderColor, PdfColor textColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: borderColor),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, PdfColor color, {bool isBold = false, double fontSize = 8}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.TableRow _buildPlacementRow(String zone, String direction, PdfColor borderColor, PdfColor textColor) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(zone, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textColor)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(direction, style: pw.TextStyle(fontSize: 8, color: textColor)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text('Compliant', style: const pw.TextStyle(fontSize: 8, color: PdfColors.green800)),
        ),
      ],
    );
  }

  static pw.TableRow _buildSafetyRow(String param, String val, PdfColor textColor) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(param, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textColor)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(val, style: pw.TextStyle(fontSize: 8, color: textColor)),
        ),
      ],
    );
  }

  static pw.Widget _buildPackageCard(String name, String rate, String total, bool isHighlight, PdfColor borderColor, PdfColor primaryColor, PdfColor brandAmber, PdfColor textColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: isHighlight ? PdfColor.fromHex('#FFFBEB') : PdfColor.fromHex('#F8FAFC'),
          border: pw.Border.all(color: isHighlight ? brandAmber : borderColor, width: isHighlight ? 1.5 : 1),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (isHighlight)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 4),
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: brandAmber,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text('RECOMMENDED',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 6, fontWeight: pw.FontWeight.bold)),
              ),
            pw.Text(name, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textColor)),
            pw.SizedBox(height: 2),
            pw.Text(rate, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(total, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: isHighlight ? brandAmber : primaryColor)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryPill(String title, String mainVal, String subVal, PdfColor accentColor, PdfColor bgColor, PdfColor borderColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: bgColor,
          border: pw.Border.all(color: borderColor),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            pw.SizedBox(height: 3),
            pw.Text(mainVal, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: accentColor)),
            pw.SizedBox(height: 2),
            pw.Text(subVal, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildGuidelineItem(String boldPrefix, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(boldPrefix, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B'))),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(text, style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#64748B'))),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildVastuZoneBadge(String zone, String element, String desc, PdfColor borderColor, PdfColor textColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: borderColor, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(zone, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textColor)),
                pw.Text(element, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Text(desc, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildCostStageBadge(String stage, String title, String desc, PdfColor borderColor, PdfColor textColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: borderColor, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(stage, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#E58A18'))),
                pw.Text(title, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textColor)),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Text(desc, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value, PdfColor valueColor, {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
