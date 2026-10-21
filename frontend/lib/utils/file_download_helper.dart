import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart'
    if (dart.library.io) 'file_download_mobile.dart';

class FileDownloadHelper {
  static Future<bool> downloadAndSavePdf(
      BuildContext context, String filename, Uint8List bytes) async {
    return savePdfFile(context, filename, bytes);
  }
}
