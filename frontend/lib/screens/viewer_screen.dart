import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'js_stub.dart' if (dart.library.html) 'dart:js_interop';

// Conditional imports to prevent mobile build crashes
import 'web_stub.dart' if (dart.library.html) 'dart:ui_web' as ui_web;

import 'web_stub.dart' if (dart.library.html) 'package:web/web.dart' as web;
import '../widgets/door_window_selector_widget.dart';

class ViewerScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  final bool isElevation;
  final bool isStructural;
  final VoidCallback? onNavigateToVastu;
  final void Function(Uint8List bytes)? onScreenshotReady;
  const ViewerScreen({
    super.key,
    required this.projectData,
    this.isElevation = false,
    this.isStructural = false,
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
  String _doorStyle = 'glass';
  String _windowStyle = 'wood';

  // Completer to receive screenshot from web iframe
  Completer<String?>? _screenshotCompleter;

  void _updateDoorStyle(String style) {
    setState(() => _doorStyle = style);
    if (kIsWeb) {
      final msg = json.encode({'type': 'set_door_style', 'style': style});
      _webIFrame?.contentWindow?.postMessage(msg.toJS, '*'.toJS);
    } else {
      _mobileController
          .runJavaScript("if(window.setDoorStyle) setDoorStyle('$style');");
    }
  }

  void _updateWindowStyle(String style) {
    setState(() => _windowStyle = style);
    if (kIsWeb) {
      final msg = json.encode({'type': 'set_window_style', 'style': style});
      _webIFrame?.contentWindow?.postMessage(msg.toJS, '*'.toJS);
    } else {
      _mobileController.runJavaScript(
          "if(window.setWindowStyle) setWindowStyle('$style');");
    }
  }

  void _showDoorWindowSelector() {
    showDialog(
      context: context,
      builder: (ctx) => DoorWindowSelectorWidget(
        currentDoorStyle: _doorStyle,
        currentWindowStyle: _windowStyle,
        onDoorStyleChanged: _updateDoorStyle,
        onWindowStyleChanged: _updateWindowStyle,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _setupWebView();
    } else {
      _setupMobileView();
    }
  }

  @override
  void didUpdateWidget(ViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectData != widget.projectData) {
      _validationFailed = false;
      if (kIsWeb) {
        _sendDataToWeb();
      } else {
        _injectData();
      }
    }
  }

  bool _isValidV4Data(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return false;
    // Accept either the new nested 'floors' structure or the flat structure
    if (data.containsKey('floors') ||
        data.containsKey('rooms') ||
        data.containsKey('walls')) {
      return true;
    }
    return false;
  }

  void _setupWebView() {
    String viewParam = '';
    if (widget.isElevation) viewParam = '?view=elevation&hideToolbar=true';
    if (widget.isStructural) viewParam = '?view=structural&hideToolbar=true';
    final url = 'assets/viewer/viewer.html$viewParam';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      _webIFrame = web.HTMLIFrameElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.display = 'block'
        ..src = url;

      web.window.addEventListener(
        'message',
        (web.Event event) {
          final message = event as web.MessageEvent;

          String raw = '';
          try {
            final dartData = message.data?.dartify();
            raw = dartData?.toString() ?? '';
          } catch (e) {
            // Ignore messages that cannot be dartified (e.g. from extensions)
          }

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

      // Fallback: forcefully send data just in case the message event was missed or blocked
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) _sendDataToWeb();
      });
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) _sendDataToWeb();
      });
    });
  }

  void _sendDataToWeb() {
    if (_webIFrame == null) return;
    final modelData = widget.projectData['model_data'] as Map<String, dynamic>?;

    if (!_isValidV4Data(modelData)) {
      setState(() {
        _validationFailed = true;
      });
      return;
    }

    final data = json.encode({'type': 'render', 'data': modelData});
    _webIFrame!.contentWindow?.postMessage(data.toJS, '*'.toJS);

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
        'assets/viewer/viewer.html${widget.isElevation ? "?view=elevation&hideToolbar=true" : (widget.isStructural ? "?view=structural&hideToolbar=true" : "")}',
      );
  }

  bool _validationFailed = false;

  void _injectData() {
    if (kIsWeb) return;
    final modelData = widget.projectData['model_data'] as Map<String, dynamic>?;

    if (!_isValidV4Data(modelData)) {
      setState(() {
        _validationFailed = true;
      });
      return;
    }

    final jsonData = json.encode(modelData);
    _mobileController.runJavaScript('window.renderProject($jsonData);');

    if (widget.isElevation) {
      Future.delayed(const Duration(milliseconds: 400), () {
        _mobileController
            .runJavaScript("if(window.setView) setView('elevation');");
      });
    } else if (widget.isStructural) {
      Future.delayed(const Duration(milliseconds: 400), () {
        _mobileController
            .runJavaScript("if(window.setView) setView('structural');");
      });
    }

    if (widget.onScreenshotReady != null) {
      Future.delayed(const Duration(seconds: 3), _autoCapture);
    }
  }

  Future<void> _autoCapture() async {
    if (!mounted) return;
    final bytes = await captureScreenshot();
    if (bytes != null && mounted) {
      debugPrint(
          '[ViewerScreen] Auto-captured 3D screenshot: ${bytes.length} bytes');
      widget.onScreenshotReady?.call(bytes);
    }
  }

  Future<void> setCameraMode(String mode) async {
    if (!_isWebViewReady) return;
    try {
      if (kIsWeb) {
        final msg = json.encode({'type': 'set_cam_mode', 'mode': mode});
        _webIFrame?.contentWindow?.postMessage(msg.toJS, '*'.toJS);
      } else {
        await _mobileController
            .runJavaScript("if(window.setCamMode) setCamMode('$mode');");
      }
    } catch (e) {
      debugPrint('[ViewerScreen] setCameraMode error: $e');
    }
  }

  /// Automatically switches to 3D Top View for PDF, captures screenshots, and restores view.
  Future<Map<String, Uint8List>> captureAllFloorScreenshots() async {
    if (!_isWebViewReady) return {};

    Map<String, Uint8List> result = {};
    final modelData = widget.projectData['model_data'];
    final floors = modelData?['floors'] as Map<String, dynamic>?;

    // Force 3D Top View camera mode for clean PDF export
    await setCameraMode('top');
    await Future.delayed(const Duration(milliseconds: 500));

    if (floors != null && floors.keys.length > 1) {
      for (var floor in floors.keys) {
        try {
          if (kIsWeb) {
            final msg = json.encode({'type': 'set_view', 'view': floor});
            _webIFrame?.contentWindow?.postMessage(msg.toJS, '*'.toJS);
          } else {
            await _mobileController
                .runJavaScript("if(window.setView) setView('$floor');");
          }
        } catch (_) {}

        await Future.delayed(const Duration(milliseconds: 800));
        await setCameraMode('top');
        await Future.delayed(const Duration(milliseconds: 400));

        final bytes = await captureScreenshot();
        if (bytes != null) result[floor] = bytes;
      }

      // Reset view to stacked after capturing
      try {
        if (kIsWeb) {
          final msg = json.encode({'type': 'set_view', 'view': 'stacked'});
          _webIFrame?.contentWindow?.postMessage(msg.toJS, '*'.toJS);
        } else {
          await _mobileController
              .runJavaScript("if(window.setView) setView('stacked');");
        }
      } catch (_) {}
    } else {
      // Single floor: capture clean top view
      final bytes = await captureScreenshot();
      if (bytes != null) result['default'] = bytes;
    }

    // Restore interactive camera view (isometric) for user
    await setCameraMode('iso');

    return result;
  }

  /// Captures the 3D view as PNG bytes (defaulting to Top View for PDF).
  Future<Uint8List?> captureScreenshot({String mode = 'top'}) async {
    if (!_isWebViewReady) return null;
    try {
      if (kIsWeb) {
        // Send capture request to iframe, await response via Completer
        _screenshotCompleter = Completer<String?>();
        final msg = json.encode({'type': 'capture_screenshot', 'mode': mode});
        _webIFrame?.contentWindow?.postMessage(msg.toJS, '*'.toJS);
        final dataUrl = await _screenshotCompleter!.future
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        if (dataUrl == null || !dataUrl.startsWith('data:image')) return null;
        final base64Str = dataUrl.split(',').last;
        return base64Decode(base64Str);
      } else {
        // Mobile: call JS captureScreenshot('top') and decode result
        final result = await _mobileController.runJavaScriptReturningResult(
            "window.captureScreenshot('$mode')") as String?;
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
    if (_validationFailed) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(
                'Invalid Architectural Model Data',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'The geometry layout could not be verified. Please re-run the layout processor.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

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
          if (!widget.isStructural)
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


                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
