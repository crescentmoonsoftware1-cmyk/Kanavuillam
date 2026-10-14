import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ignore: unused_import
import 'js_stub.dart' if (dart.library.html) 'dart:js_interop';

// Conditional imports to prevent mobile build crashes
import 'web_stub.dart' if (dart.library.html) 'dart:ui_web' as ui_web;
import 'web_stub.dart' if (dart.library.html) 'package:web/web.dart' as web;

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';

class ViewerScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  final bool isElevation;
  final bool isStructural;
  final VoidCallback? onNavigateToVastu;
  final void Function(int tabIndex)? onNavigateToTab;
  final VoidCallback? onBack;
  final void Function(Uint8List bytes)? onScreenshotReady;
  const ViewerScreen({
    super.key,
    required this.projectData,
    this.isElevation = false,
    this.isStructural = false,
    this.onNavigateToVastu,
    this.onNavigateToTab,
    this.onBack,
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

  @override
  void didUpdateWidget(ViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectData != widget.projectData) {
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
    Map<String, dynamic>? modelData =
        widget.projectData['model_data'] as Map<String, dynamic>?;

    if (!_isValidV4Data(modelData)) {
      modelData = _getDemoModel();
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

  void _injectData() {
    if (kIsWeb) return;
    Map<String, dynamic>? modelData =
        widget.projectData['model_data'] as Map<String, dynamic>?;

    if (!_isValidV4Data(modelData)) {
      modelData = _getDemoModel();
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
    AppConfigProvider config;
    try {
      config = context.watch<AppConfigProvider>();
    } catch (_) {
      config = AppConfigProvider();
    }

    final isDark = config.isDarkMode;
    final bgColor = config.bgColor;
    final cardColor = config.cardColor;
    final primaryTextColor = config.primaryTextColor;
    final secondaryTextColor = config.secondaryTextColor;
    final borderColor = config.borderColor;
    final surfacePillColor = config.surfacePillColor;

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
    if (roomCount == 0) roomCount = 4;

    return Container(
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. HEADER (Only if not embedded in structural screen) ─────────
          if (!widget.isStructural) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.tr(
                            '3D Villa Model',
                            '3D வில்லா மாதிரி',
                          ),
                          style: GoogleFonts.syne(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          config.tr(
                            'Interactive 3D Architecture',
                            'முழுமையான 3D கட்டிட வடிவமைப்பு',
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: surfacePillColor,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$roomCount ${config.tr('Rooms', 'அறைகள்')}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── 2. 3D WEBVIEW VIEWPORT (Clean canvas without overlays) ────────
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: widget.isStructural ? 0 : 16,
              ),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
                borderRadius:
                    BorderRadius.circular(widget.isStructural ? 0 : 24),
                border:
                    widget.isStructural ? null : Border.all(color: borderColor),
                boxShadow: widget.isStructural
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.05,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(widget.isStructural ? 0 : 24),
                child: Stack(
                  children: [
                    // Canvas / Webview
                    Positioned.fill(
                      child: kIsWeb
                          ? HtmlElementView(viewType: _viewId)
                          : WebViewWidget(controller: _mobileController),
                    ),

                    if (!_isWebViewReady)
                      Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: isDark ? Colors.white : AppColors.primary,
                        ),
                      ),

                    // Bottom Floating Gesture Hint
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.touch_app_outlined,
                                size: 12,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                config.tr(
                                  'Drag to rotate • Pinch to zoom',
                                  'சுழற்ற இழுக்கவும் • பெரிதாக்கவும்',
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 3. BOTTOM NEXT REPORT BAR (Seamless flow into Vastu) ──────────
          if (!widget.isStructural) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.05,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: surfacePillColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.explore_rounded,
                        size: 19,
                        color: isDark ? Colors.white : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            config.tr(
                              'Next: Vastu Analysis',
                              'அடுத்தது: வாஸ்து பகுப்பாய்வு',
                            ),
                            style: GoogleFonts.syne(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            config.tr(
                              'Room-by-room compliance score',
                              'திசைகள் & வாஸ்து சரிபார்ப்பு',
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: secondaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: widget.onNavigateToVastu,
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE58A18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE58A18), Color(0xFFFBA73B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE58A18).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          config.tr('VASTU', 'வாஸ்து'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
