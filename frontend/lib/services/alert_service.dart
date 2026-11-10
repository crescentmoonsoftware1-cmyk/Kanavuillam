import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Direct Discord Crash & Error Reporter for Kanavu Illam.
/// Sends unhandled exceptions straight to the private Discord #errors channel.
class AlertService {
  static const String _webhookUrl =
      'https://discord.com/api/webhooks/1569606089861767272/LJcrIYQbbX_AOg1Sc2vXETtgF6ZSiz8dikY7yVCs8oLZWB-hvvGbgv0HfMOXfmdEv0L8';

  // De-duplication cache: avoids spamming Discord if an error fires repeatedly
  static final Set<String> _reportedErrors = <String>{};
  static DateTime _lastReportTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Report an unhandled Flutter error (e.g. FlutterError.onError)
  static void reportFlutterError(FlutterErrorDetails details) {
    reportCrash(
      details.exception,
      details.stack,
      context: details.context?.toDescription(),
      library: details.library,
    );
  }

  /// Report any Dart unhandled exception (e.g. PlatformDispatcher.onError)
  static void reportCrash(
    Object error,
    StackTrace? stack, {
    String? context,
    String? library,
  }) {
    final now = DateTime.now();
    final errorString = error.toString();
    final dedupKey = '${error.runtimeType}:$errorString';

    // Prevent duplicate error spam within 30 seconds
    if (_reportedErrors.contains(dedupKey) &&
        now.difference(_lastReportTime).inSeconds < 30) {
      return;
    }

    _reportedErrors.add(dedupKey);
    _lastReportTime = now;

    // Clean up cache periodically
    if (_reportedErrors.length > 50) {
      _reportedErrors.clear();
    }

    // Format stack trace to the top 8 most relevant lines
    String formattedStack = 'No stack trace available';
    if (stack != null) {
      final lines = stack.toString().split('\n').take(8).toList();
      formattedStack = lines.join('\n');
    }

    // Fire-and-forget async POST to Discord
    _dispatchToDiscord(
      title: '🚨 Flutter App Crash / Exception',
      description: errorString.length > 1000
          ? '${errorString.substring(0, 1000)}...'
          : errorString,
      fields: [
        if (context != null && context.isNotEmpty)
          {'name': 'Context', 'value': context, 'inline': true},
        if (library != null && library.isNotEmpty)
          {'name': 'Library', 'value': library, 'inline': true},
        {
          'name': 'Platform',
          'value': defaultTargetPlatform.name,
          'inline': true,
        },
        {
          'name': 'Build Mode',
          'value': kReleaseMode
              ? 'Release'
              : (kProfileMode ? 'Profile' : 'Debug'),
          'inline': true,
        },
        {
          'name': 'Stack Trace',
          'value': '```dart\n${formattedStack.length > 900 ? '${formattedStack.substring(0, 900)}...' : formattedStack}\n```',
          'inline': false,
        },
      ],
    );
  }

  static void _dispatchToDiscord({
    required String title,
    required String description,
    required List<Map<String, dynamic>> fields,
  }) {
    try {
      final uri = Uri.parse(_webhookUrl);
      final payload = jsonEncode({
        'username': 'Flutter Crash Bot',
        'embeds': [
          {
            'title': title,
            'description': description,
            'color': 15548997, // Discord Red #ED4245
            'fields': fields,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
            'footer': {'text': 'Kanavu Illam Mobile Telemetry'},
          }
        ],
      });

      http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .catchError((_) {
            // Silently ignore network failures to ensure app stability
            return http.Response('', 500);
          });
    } catch (_) {
      // Never let monitoring code crash the application
    }
  }
}
