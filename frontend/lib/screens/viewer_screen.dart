import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'js_stub.dart' if (dart.library.html) 'dart:js_interop';

// Conditional imports to prevent mobile build crashes
import 'web_stub.dart' if (dart.library.html) 'dart:ui_web' as ui_web;

import 'web_stub.dart' if (dart.library.html) 'package:web/web.dart' as web;

class ViewerScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  final bool isElevation;
  final VoidCallback? onNavigateToVastu;
  final void Function(Uint8List bytes)? onScreenshotReady;
  const ViewerScreen({
    super.key,
    required this.projectData,
    this.isElevation = false,
    this.onNavigateToVastu,
    this.onScreenshotReady,
  });

  @override
  State<ViewerScreen> createState() => ViewerScreenState();
}

class ViewerScreenState extends State<ViewerScreen> {
  // Mobile Controller
  late final WebViewController _mobileController;

  // Web State
  final String _viewId =
      'viewer-iframe-${DateTime.now().millisecondsSinceEpoch}';
  web.HTMLIFrameElement? _webIFrame;

  bool _isWebViewReady = false;

  // Completer to receive screenshot from web iframe
  Completer<String?>? _screenshotCompleter;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _setupWebView();
    } else {
      _setupMobileView();
    }
  }

  void _setupWebView() {
    final viewParam =
        widget.isElevation ? '?view=elevation&hideToolbar=true' : '';
    final url = 'assets/viewer/viewer.html$viewParam';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      _webIFrame = web.HTMLIFrameElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.display = 'block'
        ..src = url;

      // When the iframe is ready, it will ping us, and we'll send the data
      web.window.addEventListener(
        'message',
        (web.Event event) {
          final message = event as web.MessageEvent;
          final raw = message.data.toString();
          if (raw == 'viewer_ready') {
            _sendDataToWeb();
          } else if (raw.startsWith('{')) {
            try {
              final parsed = json.decode(raw) as Map<String, dynamic>;
              if (parsed['type'] == 'screenshot_result') {
                _screenshotCompleter?.complete(parsed['data'] as String?);
                _screenshotCompleter = null;
              }
            } catch (_) {}
          }
        }.toJS,
      );

      return _webIFrame!;
    });

    Future.microtask(() {
      if (mounted) setState(() => _isWebViewReady = true);
    });
  }

  void _sendDataToWeb() {
    if (_webIFrame == null || widget.projectData['model_data'] == null) return;
    final modelData = widget.projectData['model_data'];
    final data = json.encode({'type': 'render', 'data': modelData});
    _webIFrame!.contentWindow?.postMessage(data.toJS, '*'.toJS);

    // Auto-capture after Three.js has had time to render (3 seconds)
    if (widget.onScreenshotReady != null) {
      Future.delayed(const Duration(seconds: 3), _autoCapture);
    }
  }

  void _setupMobileView() {
    _mobileController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color.fromARGB(0, 157, 154, 154))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isWebViewReady = true);
            _injectData();
          },
        ),
      )
      ..loadFlutterAsset(
        'assets/viewer/viewer.html${widget.isElevation ? "?view=elevation&hideToolbar=true" : ""}',
      );
  }

  void _injectData() {
    // For mobile WebView only — web uses URL-encoded data
    if (kIsWeb) return;
    final modelData = widget.projectData['model_data'];
    final dynamic dataToSend =
        (modelData != null && modelData is Map && modelData.isNotEmpty)
            ? modelData
            : _getDemoModel();
    final jsonData = json.encode(dataToSend);
    _mobileController.runJavaScript('window.renderProject($jsonData);');
    if (widget.isElevation) {
      Future.delayed(const Duration(milliseconds: 400), () {
        _mobileController.runJavaScript(
          "if(window.setView) setView('elevation');",
        );
      });
    }

    // Auto-capture after Three.js has had time to render (3 seconds)
    if (widget.onScreenshotReady != null) {
      Future.delayed(const Duration(seconds: 3), _autoCapture);
    }
  }

  /// Called automatically after render to capture and store the 3D view
  Future<void> _autoCapture() async {
    if (!mounted) return;
    final bytes = await captureScreenshot();
    if (bytes != null && mounted) {
      debugPrint('[ViewerScreen] Auto-captured 3D screenshot: ${bytes.length} bytes');
      widget.onScreenshotReady?.call(bytes);
    }
  }

  /// Automatically switches to each floor view, waits, and captures the screenshot.
  Future<Map<String, Uint8List>> captureAllFloorScreenshots() async {
    if (!_isWebViewReady) return {};
    
    Map<String, Uint8List> result = {};
    final modelData = widget.projectData['model_data'];
    final floors = modelData?['floors'] as Map<String, dynamic>?;
    
    if (floors != null && floors.keys.length > 1) {
      for (var floor in floors.keys) {
        try {
          if (kIsWeb) {
            final msg = json.encode({'type': 'set_view', 'view': floor});
            _webIFrame?.contentWindow?.postMessage(msg.toJS, '*'.toJS);
          } else {
            await _mobileController.runJavaScript("if(window.setView) setView('$floor');");
          }
        } catch (_) {}
        
        await Future.delayed(const Duration(milliseconds: 1200));
        final bytes = await captureScreenshot();
        if (bytes != null) result[floor] = bytes;
      }
      
      // Reset view to stacked after capturing
      try {
        if (kIsWeb) {
          final msg = json.encode({'type': 'set_view', 'view': 'stacked'});
          _webIFrame?.contentWindow?.postMessage(msg.toJS, '*'.toJS);
        } else {
          await _mobileController.runJavaScript("if(window.setView) setView('stacked');");
        }
      } catch (_) {}
      
    } else {
      // Single floor
      final bytes = await captureScreenshot();
      if (bytes != null) result['default'] = bytes;
    }
    
    return result;
  }

  /// Captures the current 3D view as PNG bytes.
  /// Call this from shell_screen to get the 3D screenshot for PDF.
  Future<Uint8List?> captureScreenshot() async {
    if (!_isWebViewReady) return null;
    try {
      if (kIsWeb) {
        // Send capture request to iframe, await response via Completer
        _screenshotCompleter = Completer<String?>();
        final msg = json.encode({'type': 'capture_screenshot'});
        _webIFrame?.contentWindow?.postMessage(msg.toJS, '*'.toJS);
        final dataUrl = await _screenshotCompleter!.future
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        if (dataUrl == null || !dataUrl.startsWith('data:image')) return null;
        final base64Str = dataUrl.split(',').last;
        return base64Decode(base64Str);
      } else {
        // Mobile: call JS captureScreenshot() and decode result
        final result = await _mobileController.runJavaScriptReturningResult(
            'window.captureScreenshot()') as String?;
        if (result == null || result == 'null') return null;
        // result may be quoted JSON string like "data:image/png;base64,..."
        String dataUrl = result;
        if (dataUrl.startsWith('"')) dataUrl = json.decode(dataUrl) as String;
        if (!dataUrl.startsWith('data:image')) return null;
        final base64Str = dataUrl.split(',').last;
        return base64Decode(base64Str);
      }
    } catch (e) {
      debugPrint('[ViewerScreen] captureScreenshot error: $e');
      return null;
    }
  }

  /// Fallback demo model with 6 rooms so viewer is never empty
  Map<String, dynamic> _getDemoModel() {
    return {
      'project': {'name': 'Demo Home', 'width': 30, 'height': 40},
      'rooms': [
        {'name': 'Living Room', 'x': 0, 'y': 0, 'width': 15, 'height': 18},
        {'name': 'Master Bedroom', 'x': 15, 'y': 0, 'width': 15, 'height': 18},
        {'name': 'Kitchen', 'x': 0, 'y': 18, 'width': 10, 'height': 12},
        {'name': 'Dining', 'x': 10, 'y': 18, 'width': 10, 'height': 12},
        {'name': 'Bedroom 2', 'x': 20, 'y': 18, 'width': 10, 'height': 12},
        {'name': 'Bathroom', 'x': 0, 'y': 30, 'width': 10, 'height': 10},
        {'name': 'Toilet', 'x': 10, 'y': 30, 'width': 8, 'height': 10},
        {'name': 'Utility', 'x': 18, 'y': 30, 'width': 12, 'height': 10},
      ],
      'walls': [],
      'doors': [
        {'x': 7.5, 'y': 0, 'width': 3.5, 'angle': 0},
      ],
      'windows': [
        {'x': 3, 'y': 0, 'width': 3, 'dir': 'z'},
        {'x': 22, 'y': 0, 'width': 3, 'dir': 'z'},
      ],
      'furnitures': [
        {
          'type': 'sofa',
          'x': 7.5,
          'y': 9,
          'width': 8,
          'height': 3,
          'rotation': 0,
        },
        {
          'type': 'bed',
          'x': 22,
          'y': 9,
          'width': 6,
          'height': 7,
          'rotation': 0,
        },
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final modelData = widget.projectData['model_data'] as Map<String, dynamic>?;
    final floors = modelData?['floors'] as Map<String, dynamic>?;
    int roomCount = 0;

    if (floors != null) {
      floors.forEach((key, value) {
        if (value is Map && value['rooms'] is List) {
          roomCount += (value['rooms'] as List).length;
        }
      });
    } else {
      final rooms = (modelData?['rooms'] as List<dynamic>?) ?? [];
      roomCount = rooms.length;
    }

    return Container(
      color: const Color.fromARGB(255, 255, 255, 255),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.view_in_ar_rounded,
                      color: Color.fromARGB(255, 0, 200, 183),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '3D Visualization',
                      style: TextStyle(
                        color: Color.fromARGB(255, 0, 0, 0),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    const Text(
                      'Professional Isometric Rendering',
                      style: TextStyle(
                        color: Color.fromARGB(255, 0, 167, 125),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (roomCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(
                            255,
                            177,
                            177,
                            177,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color.fromARGB(
                              255,
                              0,
                              180,
                              135,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '— $roomCount room${roomCount == 1 ? '' : 's'} detected',
                          style: const TextStyle(
                            color: Color.fromARGB(255, 0, 0, 0),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── 3D WebView ──────────────────────────────────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  if (kIsWeb)
                    HtmlElementView(viewType: _viewId)
                  else
                    WebViewWidget(controller: _mobileController),
                  if (!_isWebViewReady)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00C896),
                      ),
                    ),

                  // ── Vastu Floating Button ──────────────────────────────────
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
