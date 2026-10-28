import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';
import 'payment_success_screen.dart';

class SecurePaymentScreen extends StatefulWidget {
  final double amount;
  final List<String>? selectedItems;
  final String? fileName;
  final XFile? file;
  final VoidCallback? onFinish;

  const SecurePaymentScreen({
    super.key,
    required this.amount,
    this.selectedItems,
    this.fileName,
    this.file,
    this.onFinish,
  });

  @override
  State<SecurePaymentScreen> createState() => _SecurePaymentScreenState();
}

class _SecurePaymentScreenState extends State<SecurePaymentScreen> {
  bool _isProcessing = false;
  bool _promoApplied = false;
  bool _isReviewerAccount = false;
  final TextEditingController _promoController = TextEditingController();
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _checkReviewer();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _checkReviewer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = (prefs.getString('user_email') ?? '').trim().toLowerCase();
      if (mounted) {
        setState(() {
          if (email == 'playstore@kanavuillam.com' ||
              email == 'reviewer@kanavuillam.com' ||
              email.contains('playstore') ||
              email.contains('reviewer')) {
            _isReviewerAccount = true;
            _promoApplied = true;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _razorpay.clear();
    _promoController.dispose();
    super.dispose();
  }

  void _showPromoDialog(BuildContext context, AppConfigProvider config) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: config.isDarkMode ? const Color(0xFF1E2430) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          config.tr('Enter Promo / Reviewer Code', 'கூப்பன் குறியீட்டை உள்ளிடவும்'),
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: _promoController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'e.g. REVIEW100 or FREE100',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(config.tr('Cancel', 'ரத்துசெய்')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.amberDefault),
            onPressed: () {
              final code = _promoController.text.trim().toUpperCase();
              if (code == 'REVIEW100' || code == 'FREE100' || code == 'GOOGLE' || code == 'TEST') {
                setState(() => _promoApplied = true);
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Promo Code Applied! 100% OFF for Reviewer Access.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid Promo Code'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              config.tr('Apply', 'பயன்படுத்து'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _handlePayment() async {
    final effectiveAmount = _promoApplied ? 0.0 : widget.amount;

    // Reviewer promo or 100% off applied -> Directly proceed
    if (effectiveAmount <= 0) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              amount: 0,
              onFinish: widget.onFinish,
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email') ?? '';
      final userPhone = prefs.getString('user_phone') ?? '';

      final api = ApiService();
      final orderData = await api.createRazorpayOrder(effectiveAmount);

      final keyId = orderData['key_id'] as String?;
      final orderId = orderData['id'] as String?;

      if (orderData['is_mock'] == true) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentSuccessScreen(
                amount: effectiveAmount,
                onFinish: widget.onFinish,
              ),
            ),
          );
        }
        return;
      }

      if (keyId == null || keyId.isEmpty || keyId.contains('placeholder')) {
        throw Exception(
          'Razorpay Key ID is not configured on the server yet. Please add your Razorpay keys.',
        );
      }

      final options = {
        'key': keyId,
        'amount': orderData['amount'],
        'name': 'Kanavu Illam',
        'order_id': orderId,
        'description': 'AI Architectural Plan & 3D Deliverables',
        'timeout': 300,
        'prefill': {
          'contact': userPhone.isNotEmpty ? userPhone : '9876543210',
          'email': userEmail.isNotEmpty ? userEmail : 'user@kanavuillam.com',
        },
        'theme': {
          'color': '#F59E0B',
        },
      };

      _razorpay.open(options);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        final cleanMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cleanMsg),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      setState(() => _isProcessing = true);
      final api = ApiService();
      await api.verifyRazorpayPayment({
        'razorpay_order_id': response.orderId ?? '',
        'razorpay_payment_id': response.paymentId ?? '',
        'razorpay_signature': response.signature ?? '',
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              amount: widget.amount,
              onFinish: widget.onFinish,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Payment Error] Verification failed: $e');
      if (mounted) {
        final cleanMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification Notice: $cleanMsg'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    final errorMsg = response.message ?? 'Payment cancelled or failed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment: $errorMsg'),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External Wallet Selected: ${response.walletName}');
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
    final cardColor = config.cardColor;
    final primaryTextColor = config.primaryTextColor;
    final secondaryTextColor = config.secondaryTextColor;
    final borderColor = config.borderColor;
    final surfacePillColor = config.surfacePillColor;

    final displayName = widget.fileName ??
        (widget.file?.name) ??
        'house_plan.pdf';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF14171F) : AppColors.canvasGradientTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: primaryTextColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          config.tr('Review & Pay', 'சரிபார்த்து பணம் செலுத்தவும்'),
          style: GoogleFonts.syne(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.canvasGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 12.0,
                      ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. BLUEPRINT PREVIEW CARD
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.35 : 0.06,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Blueprint Icon Thumbnail
                              Container(
                                width: 56,
                                height: 56,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: surfacePillColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: CustomPaint(
                                  painter: _BlueprintThumbPainter(
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // File Info & Quality Check Passed Pill
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayName,
                                            style: GoogleFonts.inter(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w600,
                                              color: primaryTextColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => Navigator.pop(context),
                                          child: Text(
                                            config.tr('Change', 'மாற்று'),
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: primaryTextColor,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      config.tr(
                                        'Ground Floor • 1,600 sq ft',
                                        'தரைத்தளம் • 1,600 சதுர அடி',
                                      ),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.check,
                                            size: 11,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            config.tr(
                                              'Quality check passed',
                                              'வரைபடம் சரிபார்க்கப்பட்டது',
                                            ),
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: primaryTextColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 2. SECTION HEADING
                        Text(
                          config.tr(
                            'What you will get',
                            'நீங்கள் பெறும் அறிக்கைகள்',
                          ),
                          style: GoogleFonts.syne(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                            letterSpacing: -0.15,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 3. REPORT DELIVERABLES LIST
                        _buildReportDeliverable(
                          icon: Icons.view_in_ar_rounded,
                          title: config.tr(
                            '3D Model Visualization',
                            '3D கட்டிட மாதிரி',
                          ),
                          subtitle: config.tr(
                            'Photorealistic exterior & floor view',
                            'முழுமையான 3D தோற்றம்',
                          ),
                          config: config,
                        ),
                        const SizedBox(height: 10),
                        _buildReportDeliverable(
                          icon: Icons.explore_rounded,
                          title: config.tr(
                            'Vastu Analysis & Score',
                            'வாஸ்து பகுப்பாய்வு & மதிப்பெண்',
                          ),
                          subtitle: config.tr(
                            'Room-by-room directional compliance',
                            'திசைகள் மற்றும் வாஸ்து திருத்தங்கள்',
                          ),
                          config: config,
                        ),
                        const SizedBox(height: 10),
                        _buildReportDeliverable(
                          icon: Icons.calculate_rounded,
                          title: config.tr(
                            'Cost Breakdown / BOQ',
                            'மதிப்பீட்டு செலவு அறிக்கை',
                          ),
                          subtitle: config.tr(
                            'Live material rates & stage estimates',
                            'பொருள் மற்றும் கட்டமைப்பு செலவுகள்',
                          ),
                          config: config,
                        ),
                        const SizedBox(height: 10),
                        _buildReportDeliverable(
                          icon: Icons.foundation_rounded,
                          title: config.tr(
                            'Structural Safety Check',
                            'கட்டமைப்பு பாதுகாப்பு அறிக்கை',
                          ),
                          subtitle: config.tr(
                            'Footing, beam, column & rebar specs',
                            'தூண்கள், அடித்தளம் விவரங்கள்',
                          ),
                          config: config,
                        ),
                        const SizedBox(height: 14),

                        // Promo / Voucher Row for Google Play Reviewer or coupons
                        InkWell(
                          onTap: () => _showPromoDialog(context, config),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _promoApplied
                                  ? const Color(0xFFF0FDF4)
                                  : (isDark ? const Color(0xFF1E2430) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _promoApplied
                                    ? const Color(0xFF86EFAC)
                                    : (isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _promoApplied ? Icons.check_circle_rounded : Icons.local_offer_outlined,
                                  size: 18,
                                  color: _promoApplied ? const Color(0xFF16A34A) : AppColors.amberDefault,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _promoApplied
                                        ? 'Reviewer Promo Applied (100% Free Access)'
                                        : config.tr('Have a promo / reviewer code?', 'கூப்பன் குறியீடு உள்ளதா?'),
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _promoApplied
                                          ? const Color(0xFF16A34A)
                                          : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                    ),
                                  ),
                                ),
                                Text(
                                  _promoApplied
                                      ? config.tr('Applied', 'பயன்படுத்தப்பட்டது')
                                      : config.tr('Apply', 'பயன்படுத்து'),
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _promoApplied ? const Color(0xFF16A34A) : AppColors.amberDefault,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // 5. BOTTOM DOCKED PAYMENT PANEL
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    border: Border(
                      top: BorderSide(color: borderColor),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.35 : 0.08,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              config.tr('All 4 reports', '4 அறிக்கைகளும்'),
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: secondaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _promoApplied ? '₹0' : '₹${widget.amount.toInt()}',
                              style: GoogleFonts.syne(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: _promoApplied ? const Color(0xFF16A34A) : primaryTextColor,
                                letterSpacing: -0.24,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: _isProcessing ? null : _handlePayment,
                        borderRadius: BorderRadius.circular(100),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: AppColors.amberDefault,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33E58A18),
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isProcessing) ...[
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onAmberInk,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Text(
                                _isProcessing
                                    ? config.tr('Processing...', 'செயலாக்குகிறது...')
                                    : (_promoApplied || _isReviewerAccount)
                                        ? config.tr('Unlock All Reports (Free)', 'அறிக்கைகளை திறக்க (இலவசம்)')
                                        : config.tr(
                                            'Proceed to Pay',
                                            'செலுத்துங்கள்',
                                          ),
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onAmberInk,
                                ),
                              ),
                              if (!_isProcessing) ...[
                                const SizedBox(width: 10),
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: const BoxDecoration(
                                    color: Color(0x241E252D),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 15,
                                    color: AppColors.onAmberInk,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildReportDeliverable({
    required IconData icon,
    required String title,
    required String subtitle,
    required AppConfigProvider config,
  }) {
    final isDark = config.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: config.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: config.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: config.surfacePillColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: config.primaryTextColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.syne(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: config.primaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: config.secondaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.amberDefault,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 13,
              color: AppColors.onAmberInk,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Blueprint vector thumbnail
class _BlueprintThumbPainter extends CustomPainter {
  final Color color;
  const _BlueprintThumbPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 3, 34, 34),
        const Radius.circular(3),
      ),
      paint..strokeWidth = 1.8,
    );

    canvas.drawLine(const Offset(3, 20), const Offset(37, 20), paint);
    canvas.drawLine(const Offset(18, 3), const Offset(18, 20), paint);
    canvas.drawLine(const Offset(28, 20), const Offset(28, 37), paint);
    canvas.drawCircle(const Offset(8, 28), 1.5, Paint()..color = color);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BlueprintThumbPainter oldDelegate) =>
      oldDelegate.color != color;
}
