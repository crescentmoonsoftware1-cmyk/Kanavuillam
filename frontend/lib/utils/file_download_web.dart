import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../core/theme/app_colors.dart';

Future<bool> savePdfFile(
    BuildContext context, String filename, Uint8List bytes) async {
  try {
    await Printing.sharePdf(bytes: bytes, filename: filename);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Download initiated: $filename'),
          backgroundColor: AppColors.snackbarSuccess,
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
          backgroundColor: AppColors.snackbarError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
}
