import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';

class WebCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;
  final String orderId;

  const WebCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    required this.orderId,
  });

  @override
  State<WebCheckoutScreen> createState() => _WebCheckoutScreenState();
}

class _WebCheckoutScreenState extends State<WebCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0E14))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            _checkIfSuccessUrl(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.contains('payment-success') ||
                request.url.startsWith('kanavuillam://payment-success')) {
              _onPaymentSuccess();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[WebCheckout Error]: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));

    // Also poll backend status every 3 seconds as a safety fallback
    _startStatusPolling();
  }

  void _startStatusPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final res = await http.get(
          Uri.parse('${ApiService.baseUrl}/payment/status/${widget.orderId}'),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['status'] == 'paid') {
            timer.cancel();
            _onPaymentSuccess();
          }
        }
      } catch (_) {}
    });
  }

  void _checkIfSuccessUrl(String url) {
    if (url.contains('payment-success')) {
      _onPaymentSuccess();
    }
  }

  void _onPaymentSuccess() {
    _statusTimer?.cancel();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151A23),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Secure Web Checkout',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'UPI / Cards / NetBanking',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.amberDefault,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: const Color(0xFF0B0E14),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.amberDefault,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
