import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';

Future<bool> savePdfFile(
    BuildContext context, String filename, Uint8List bytes) async {
  try {
    String? savedFilePath;

    if (Platform.isAndroid) {
      // 1. Try public Download directory on Android (/storage/emulated/0/Download)
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final target = File('${downloadDir.path}/$filename');
          await target.writeAsBytes(bytes, flush: true);
          savedFilePath = target.path;
        }
      } catch (e) {
        debugPrint('[Download] Public download folder error: $e');
      }

      // 2. Try external storage directory
      if (savedFilePath == null) {
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            final target = File('${extDir.path}/$filename');
            await target.writeAsBytes(bytes, flush: true);
            savedFilePath = target.path;
          }
        } catch (e) {
          debugPrint('[Download] External storage error: $e');
        }
      }
    }

    // 3. Fallback for iOS or if previous attempts failed
    if (savedFilePath == null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final target = File('${appDir.path}/$filename');
        await target.writeAsBytes(bytes, flush: true);
        savedFilePath = target.path;
      } catch (e) {
        debugPrint('[Download] App docs error: $e');
      }
    }

    // 4. Native share/save sheet so user also has native choices (WhatsApp, Drive, etc.)
    try {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (_) {}

    // 5. Show user confirmation with OPEN button
    if (context.mounted && savedFilePath != null) {
      final finalPath = savedFilePath;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Saved to Downloads: $filename'),
          backgroundColor: const Color(0xFF00C896),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'OPEN',
            textColor: Colors.white,
            onPressed: () {
              OpenFilex.open(finalPath);
            },
          ),
        ),
      );
    }
    return true;
  } catch (e) {
    debugPrint('[Download] Mobile save error: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
}
