import 'dart:io';

void main() async {
  final file = File('lib/screens/download_screen.dart');
  final lines = await file.readAsLines();

  int startIndex = -1;
  int endIndex = -1;

  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('Future<Uint8List> _createProfessionalPdf(Map<String, dynamic> data) async {')) {
      startIndex = i;
    }
    // We know it ends before _downloadAll
    if (lines[i].contains('Future<void> _downloadAll(')) {
      // Find the end of the previous method. 
      for (int j = i - 1; j >= 0; j--) {
        if (lines[j].trim() == '}') {
          endIndex = j;
          break;
        }
      }
      break;
    }
  }

  if (startIndex != -1 && endIndex != -1) {
    print('Found from ${startIndex + 1} to ${endIndex + 1}');
    
    // Build pdf_service.dart
    final pdfServiceLines = [
      "import 'dart:convert';",
      "import 'package:flutter/foundation.dart';",
      "import 'package:flutter/material.dart';",
      "import 'package:pdf/pdf.dart';",
      "import 'package:pdf/widgets.dart' as pw;",
      "import 'package:http/http.dart' as http;",
      "import '../services/api_service.dart';",
      "",
      "class PdfService {",
    ];

    for (int i = startIndex; i <= endIndex; i++) {
      String line = lines[i];
      if (i == startIndex) {
        line = line.replaceFirst('Future<Uint8List> _createProfessionalPdf(Map<String, dynamic> data) async {', 
                                 'static Future<Uint8List> createProfessionalPdf(Map<String, dynamic> data, Set<String> selectedReportIds) async {');
      }
      pdfServiceLines.add('  $line'); // Indent inside class
    }
    
    pdfServiceLines.add("}");
    
    final newFile = File('lib/services/pdf_service.dart');
    await newFile.writeAsString(pdfServiceLines.join('\n'));
    print('Created pdf_service.dart');
    
    // Now remove those lines from download_screen.dart
    final newLines = List<String>.from(lines);
    newLines.removeRange(startIndex, endIndex + 1);
    
    // Add import to download_screen.dart
    newLines.insert(4, "import '../services/pdf_service.dart';");
    
    // Update calls in download_screen.dart
    for (int i = 0; i < newLines.length; i++) {
      if (newLines[i].contains('_createProfessionalPdf(data)')) {
        newLines[i] = newLines[i].replaceAll('_createProfessionalPdf(data)', 'PdfService.createProfessionalPdf(data, selectedReportIds)');
      }
    }
    
    await file.writeAsString(newLines.join('\n'));
    print('Updated download_screen.dart');
  } else {
    print('Could not find start or end index. Start: $startIndex, End: $endIndex');
  }
}
