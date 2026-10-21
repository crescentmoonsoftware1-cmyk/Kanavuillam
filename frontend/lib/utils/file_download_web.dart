import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

Future<bool> savePdfFile(
    BuildContext context, String filename, Uint8List bytes) async {
  try {
    await Printing.sharePdf(bytes: bytes, filename: filename);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Download initiated: $filename'),
          backgroundColor: const Color(0xFF00C896),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
}
