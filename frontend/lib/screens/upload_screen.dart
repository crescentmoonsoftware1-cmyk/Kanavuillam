import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import 'secure_payment_screen.dart';

class UploadScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> project, Set<String> selectedIds)?
      onProjectLoaded;
  final Function(
    XFile ground,
    XFile? first,
    XFile? second,
    int floors,
    Set<String> selectedIds,
    String orientation,
  )? onStartGeneration;
  final bool isExternalLoading;

  const UploadScreen({
    super.key,
    this.onProjectLoaded,
    this.onStartGeneration,
    this.isExternalLoading = false,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _WorkflowStepItem {
  final String titleEn;
  final String titleTa;
  final String subtitleEn;
  final String subtitleTa;
  final IconData icon;
  final String image;
  final int step;

  const _WorkflowStepItem({
    required this.titleEn,
    required this.titleTa,
    required this.subtitleEn,
    required this.subtitleTa,
    required this.icon,
    required this.image,
    required this.step,
  });
}

class _UploadScreenState extends State<UploadScreen> {
  static const int _initialVirtualPage = 1000;
  int _virtualPage = _initialVirtualPage;
  late PageController _pageController;
  Timer? _autoPlayTimer;

  XFile? _groundFile;
  Uint8List? _groundFileBytes;
  int? _groundFileSizeBytes;
  XFile? _firstFloorFile;
  XFile? _secondFloorFile;
  final int _selectedFloors = 0;
  String _selectedOrientation = 'East'; // user-chosen plot facing direction

  static const List<_WorkflowStepItem> _workflowSteps = [
    _WorkflowStepItem(
      titleEn: 'Upload',
      titleTa: 'பதிவேற்றம்',
      subtitleEn: 'Add your 2D plan',
      subtitleTa: 'உங்கள் 2D வரைபடத்தைச் சேர்க்கவும்',
      icon: Icons.cloud_upload_outlined,
      image:
          'https://lh3.googleusercontent.com/aida/AEtjO1WYGjukOPEQxqtFhkC5Xfc-Eg30vHHUYMINIpN63AjZbfsXww0X4nASqL7eEc_UttXAr3LEIRTtWrqZBApLpmpY14pcjo4VLww5d1kjolUfXZZ1Ax2u75K28HB-aQMvS572UXM6L-6Etq-WG_N8yIaP4VItn-4cGr2CrZMQMa3vXZG3B6UzZ4FXbMh7S-yKW_ghohWFIemD9yWijKxmwVdKx-myJxZj_RAgwlJSpeNIw25e62WCTt08Oyi0',
      step: 1,
    ),
    _WorkflowStepItem(
      titleEn: 'Pay',
      titleTa: 'கட்டணம்',
      subtitleEn: 'Secure UPI or card',
      subtitleTa: 'பாதுகாப்பான UPI அல்லது அட்டை',
      icon: Icons.payments_outlined,
      image:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDfXeQxxzTIZ8DFO2EYUVVqVwVuTbPnEQ-DzDUJaLl4PgXIXLBveyUABMuoj3LXQTftZLdLuSxn6gkgo-lYhfXrWDUie62H0m1epsZXqUgAABQeieDZ3yCso9x11zInyv6yseg7NDr2e0hDvl6QXa2wnkfu3g7nHMx_xiUVcgWncO2jc_9Ikmi0Vkqy9XuyaE4GK8HauWsqBIhT45GRn9u3_Zsky53lO-fYg-aNS-UTLNxva_qs_JVHjA',
      step: 2,
    ),
    _WorkflowStepItem(
      titleEn: 'Reports',
      titleTa: 'அறிக்கைகள்',
      subtitleEn: '3D, Vastu, Cost',
      subtitleTa: '3D, வாஸ்து, மதிப்பீடு',
      icon: Icons.view_in_ar_outlined,
      image:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDLZOt4b6n3vSFu-cqlLntqLK8xMzSSMNhif3OdN5cjhMmHuBMmzbjZ6Gjk2F_Y0MbeDU4mL2wH8uehp4QZmNaL51l1dBFD-FDtHoEqPWH1MC6ai18SDw-5B_YG5BCPfn0x2IRDr96w_GiJ1VVQe4Z8rn_4quax_DSq01r9nuChe0U0MK3ir-ZDzvKt9SUrGnQHEEJYox_E9stG68cACMvErpg8E5iPKU-VaqyNAfYW6aHQcXci8gDhDA',
      step: 3,
    ),
    _WorkflowStepItem(
      titleEn: 'Download',
      titleTa: 'பதிவிறக்கு',
      subtitleEn: 'One PDF report',
      subtitleTa: 'முழு PDF அறிக்கை',
      icon: Icons.file_download_outlined,
      image:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuA0JpbkGD46RLWXoDmuaUXe91EE0-TXpT83W2ffvQhIZg-7FL7TGdfhS4bP0x_vLWPziR0nm7jDPdMzYoO_TlO3FgimeO9OJ0NI1HKFuRrmTngM2vxjHInQFACJpnajt-r-QfnJJjxDJtgis03eg6Qdm41CywLOtyWDt08w29mGw5fI56e1xq64LQsQTkDzJqGjABPJ64W11X4NAiHG7lLHa-BF8PxAByiweWfig65fhrgtvGmaMis6PA',
      step: 4,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.82,
      initialPage: _initialVirtualPage,
    );
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        final current = _pageController.page?.round() ?? _virtualPage;
        _pageController.animateToPage(
          current + 1,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickBlueprint(ImageSource source) async {
    try {
      final img = await ImagePicker().pickImage(
        source: source,
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 100,
      );
      if (img != null) {
        final bytes = await img.readAsBytes();
        if (!mounted) return;
        setState(() {
          _groundFile = img;
          _groundFileBytes = bytes;
          _groundFileSizeBytes = bytes.length;
        });
        // Show direction picker popup before going to Review & Pay
        await _showDirectionPopup();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  /// Popup - user chooses plot facing direction (East/North/South/West)
  Future<void> _showDirectionPopup() async {
    if (!mounted) return;
    final config = Provider.of<AppConfigProvider>(context, listen: false);
    final isDark = config.isDarkMode;

    // 4 Vastu Moolai directions
    final directions = [
      {
        'key': 'East',
        'emoji': '🌅',
        'en': 'East',
        'ta': 'கிழக்கு',
        'moolaiEn': 'Sunrise / Prosperity',
        'moolaiTa': 'சூரிய உதயம் / செழிப்பு',
        'color': const Color(0xFFF59E0B),
      },
      {
        'key': 'North',
        'emoji': '🧭',
        'en': 'North',
        'ta': 'வடக்கு',
        'moolaiEn': 'Kubera / Wealth Zone',
        'moolaiTa': 'குபேரன் / செல்வம்',
        'color': const Color(0xFF10B981),
      },
      {
        'key': 'West',
        'emoji': '🌇',
        'en': 'West',
        'ta': 'மேற்கு',
        'moolaiEn': 'Vayu Moolai / Wind',
        'moolaiTa': 'வாயு மூலை / காற்று',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'key': 'South',
        'emoji': '🔥',
        'en': 'South',
        'ta': 'தெற்கு',
        'moolaiEn': 'Yama / Strength',
        'moolaiTa': 'யமன் / வலிமை',
        'color': const Color(0xFFEF4444),
      },
    ];

    String tempSelected = _selectedOrientation;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setPopupState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2A) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A5F), Color(0xFF0F2744)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('🏠',
                                    style: TextStyle(fontSize: 20)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  config.tr(
                                    'Choose Plot Facing Direction',
                                    'மனை பார்த்த திசை தேர்வு',
                                  ),
                                  style: GoogleFonts.syne(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            config.tr(
                              'Which direction does your main entrance face?',
                              'உங்கள் வீட்டின் முன் வாசல் எத்திசை நோக்கி உள்ளது?',
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Direction Grid
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.55,
                        ),
                        itemCount: directions.length,
                        itemBuilder: (_, i) {
                          final d = directions[i];
                          final key = d['key'] as String;
                          final color = d['color'] as Color;
                          final isSelected = tempSelected == key;
                          return GestureDetector(
                            onTap: () =>
                                setPopupState(() => tempSelected = key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withValues(alpha: 0.15)
                                    : (isDark
                                        ? const Color(0xFF1C2840)
                                        : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : (isDark
                                          ? Colors.white12
                                          : Colors.grey.shade200),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.25),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        d['emoji'] as String,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        config.tr(
                                          d['en'] as String,
                                          d['ta'] as String,
                                        ),
                                        style: GoogleFonts.syne(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? color
                                              : (isDark
                                                  ? Colors.white
                                                  : Colors.black87),
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const Spacer(),
                                        Icon(Icons.check_circle,
                                            size: 16, color: color),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    config.tr(
                                      d['moolaiEn'] as String,
                                      d['moolaiTa'] as String,
                                    ),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: isSelected
                                          ? color.withValues(alpha: 0.85)
                                          : (isDark
                                              ? Colors.white38
                                              : Colors.grey.shade500),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Vastu info note
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E3A5F).withValues(alpha: 0.4)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                const Color(0xFF3B82F6).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('ℹ️', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                config.tr(
                                  'Vastu score is calculated based on your entrance direction. Correct selection = accurate report.',
                                  'வாஸ்து மதிப்பெண் உங்கள் முன்வாசல் திசையை வைத்து கணிக்கப்படும். சரியான தேர்வு = துல்லியமான அறிக்கை.',
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Confirm button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A5F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setState(() => _selectedOrientation = tempSelected);
                            Navigator.of(ctx).pop();
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                config.tr(
                                  'Confirm & Continue →',
                                  'உறுதிப்படுத்து & தொடர் →',
                                ),
                                style: GoogleFonts.syne(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
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
            );
          },
        );
      },
    );

    // After dialog closes, go to Review & Pay
    if (mounted) _navigateToReviewAndPay();
  }

  void _showPickSourceModal(AppConfigProvider config) {
    final cardColor = config.cardColor;
    final primaryTextColor = config.primaryTextColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: config.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  config.tr(
                      'Choose 2D Plan Source', 'வரைபடத்தைத் தேர்ந்தெடுக்கவும்'),
                  style: GoogleFonts.syne(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildSourceOption(
                        icon: Icons.photo_library_outlined,
                        title: config.tr('Gallery', 'கேலரி'),
                        subtitle: config.tr('Photos & Scans', 'புகைப்படங்கள்'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickBlueprint(ImageSource.gallery);
                        },
                        config: config,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildSourceOption(
                        icon: Icons.camera_alt_outlined,
                        title: config.tr('Camera', 'கேமரா'),
                        subtitle: config.tr('Take photo of plan', 'நேரடி படம்'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickBlueprint(ImageSource.camera);
                        },
                        config: config,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormatPill(String text, AppConfigProvider config,
      {bool isHighlight = false}) {
    final isDark = config.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlight
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
            : (isDark ? const Color(0xFF181F2A) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isHighlight
              ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary)
                  .withValues(alpha: 0.5)
              : config.borderColor,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
          color: isHighlight
              ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary)
              : config.secondaryTextColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required AppConfigProvider config,
  }) {
    final isDark = config.isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181F2A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: config.borderColor),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242E3E) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: config.borderColor),
              ),
              child: Icon(icon, size: 24, color: config.primaryTextColor),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: config.primaryTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: config.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToReviewAndPay() {
    if (_groundFile == null) return;

    const totalAmount = 500.0;
    const selectedItemsDisplay = [
      '3D VISUALIZATION',
      'VASTU ANALYSIS',
      'COST ESTIMATION',
      'STRUCTURAL DESIGN',
    ];
    final selectedIdsSet = {'3d', 'vastu', 'cost', 'structural'};

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SecurePaymentScreen(
          amount: totalAmount,
          selectedItems: selectedItemsDisplay,
          file: _groundFile,
          fileName: _groundFile?.name,
          onFinish: () {
            widget.onStartGeneration?.call(
              _groundFile!,
              _firstFloorFile,
              _secondFloorFile,
              _selectedFloors,
              selectedIdsSet,
              _selectedOrientation,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCarouselCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String image,
    required int step,
    required int pageIndex,
    required AppConfigProvider config,
  }) {
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: config.cardColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: config.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: config.isDarkMode ? 0.35 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Text Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.syne(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: config.primaryTextColor,
                        letterSpacing: -0.22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: config.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Image Content with Rich Graphic Fallback
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: config.surfacePillColor.withValues(alpha: 0.6),
                        child: Center(
                          child: Icon(
                            icon,
                            size: 44,
                            color: config.secondaryTextColor
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            config.cardColor,
                            config.cardColor.withValues(alpha: 0.85),
                            config.cardColor.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.25, 0.65],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: config.cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: config.borderColor),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$step',
                          style: GoogleFonts.syne(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: config.primaryTextColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background Compass Art Overlay
          Positioned(
            top: 28,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 300,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      isDark ? Colors.white10 : Colors.white,
                      isDark
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.08 : 0.05,
              child: CustomPaint(
                painter: _CompassPainter(color: primaryTextColor),
              ),
            ),
          ),

          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      top: 16.0,
                      bottom: 110.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // TOP BRAND EMBLEM HEADER
                        Column(
                          children: [
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: CustomPaint(
                                painter:
                                    _LargeLogoPainter(color: primaryTextColor),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Kanavu Illam',
                              style: GoogleFonts.syne(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // WORKFLOW STEP CAROUSEL
                        SizedBox(
                          height: 154,
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              dragDevices: {
                                PointerDeviceKind.touch,
                                PointerDeviceKind.mouse,
                                PointerDeviceKind.trackpad,
                              },
                            ),
                            child: PageView.builder(
                              controller: _pageController,
                              physics: const BouncingScrollPhysics(),
                              onPageChanged: (index) {
                                setState(() {
                                  _virtualPage = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                final stepIndex = index % _workflowSteps.length;
                                final item = _workflowSteps[stepIndex];
                                return _buildCarouselCard(
                                  title: config.tr(item.titleEn, item.titleTa),
                                  subtitle: config.tr(
                                    item.subtitleEn,
                                    item.subtitleTa,
                                  ),
                                  icon: item.icon,
                                  image: item.image,
                                  step: item.step,
                                  pageIndex: index,
                                  config: config,
                                );
                              },
                            ),
                          ),
                        ),

                        // CAROUSEL DOT INDICATORS
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 12.0, bottom: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final currentStep = _virtualPage % 4;
                              final bool isActive = currentStep == index;
                              return GestureDetector(
                                onTap: () {
                                  final current =
                                      _pageController.page?.round() ??
                                          _virtualPage;
                                  final activeStep = current % 4;
                                  int diff = index - activeStep;
                                  if (diff > 2) diff -= 4;
                                  if (diff < -2) diff += 4;
                                  _pageController.animateToPage(
                                    current + diff,
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6.0),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    height: 8.0,
                                    width: isActive ? 24.0 : 8.0,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? primaryTextColor
                                          : borderColor,
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                        // 2D PLAN BLUEPRINT DROPZONE & PREVIEW CARD
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 14.0,
                          ),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(28),
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
                          child: _groundFile == null
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Blueprint Dropzone with architectural border
                                    InkWell(
                                      onTap: () => _showPickSourceModal(config),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 18,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF141820)
                                              : const Color(0xFFFBFBFB),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isDark
                                                ? const Color(0xFF2E3846)
                                                : const Color(0xFFD4D4D8),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Hero Animated Upload Icon with pulse waves & floating upload motion
                                            _AnimatedUploadIcon(
                                              isDark: isDark,
                                              primaryColor: primaryTextColor,
                                              borderColor: borderColor,
                                            ),
                                            const SizedBox(height: 10),

                                            // Headline
                                            Text(
                                              config.tr(
                                                'Upload 2D Floor Plan',
                                                '2D வரைபடத்தைப் பதிவேற்றவும்',
                                              ),
                                              style: GoogleFonts.syne(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                                color: primaryTextColor,
                                                letterSpacing: -0.2,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 6),

                                            // Subtitle
                                            Text(
                                              config.tr(
                                                'Tap here to browse blueprint from Gallery or Camera',
                                                'கேலரி அல்லது கேமராவிலிருந்து வரைபடத்தைத் தேர்ந்தெடுக்கவும்',
                                              ),
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: secondaryTextColor,
                                                height: 1.35,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 16),

                                            // Format Badges
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              alignment: WrapAlignment.center,
                                              children: [
                                                _buildFormatPill('JPG', config),
                                                _buildFormatPill('PNG', config),
                                                _buildFormatPill('PDF', config),
                                                _buildFormatPill(
                                                  'MAX 25MB',
                                                  config,
                                                  isHighlight: true,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 20),

                                            // Select Plan Button
                                            Container(
                                              height: 44,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 22,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white
                                                    : AppColors.primary,
                                                borderRadius:
                                                    BorderRadius.circular(100),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color:
                                                        Colors.black.withValues(
                                                      alpha:
                                                          isDark ? 0.35 : 0.12,
                                                    ),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .add_photo_alternate_outlined,
                                                    size: 18,
                                                    color: isDark
                                                        ? Colors.black
                                                        : Colors.white,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    config.tr(
                                                      'Select Floor Plan',
                                                      'வரைபடம் தேர்வு செய்க',
                                                    ),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? Colors.black
                                                          : Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Blueprint Real Image Preview Canvas
                                    Container(
                                      width: double.infinity,
                                      height: 170,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF0F1218)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Stack(
                                          children: [
                                            // Blueprint Grid pattern
                                            Positioned.fill(
                                              child: Opacity(
                                                opacity: 0.18,
                                                child: CustomPaint(
                                                  painter:
                                                      _BlueprintCardGridPainter(
                                                    color: primaryTextColor,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // Actual Image Thumbnail
                                            if (_groundFileBytes != null)
                                              Positioned.fill(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14),
                                                    child: Image.memory(
                                                      _groundFileBytes!,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            else
                                              Center(
                                                child: Icon(
                                                  Icons
                                                      .insert_drive_file_outlined,
                                                  size: 56,
                                                  color: primaryTextColor,
                                                ),
                                              ),

                                            // Top-Left Status Badge
                                            Positioned(
                                              top: 12,
                                              left: 12,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: (isDark
                                                          ? Colors.black
                                                          : Colors.white)
                                                      .withValues(alpha: 0.88),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: borderColor
                                                        .withValues(alpha: 0.6),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration:
                                                          const BoxDecoration(
                                                        color:
                                                            Color(0xFF10B981),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'PLAN READY',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 0.5,
                                                        color: primaryTextColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // Top-Right Change & Remove Actions
                                            Positioned(
                                              top: 10,
                                              right: 10,
                                              child: Row(
                                                children: [
                                                  InkWell(
                                                    onTap: () =>
                                                        _showPickSourceModal(
                                                            config),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            100),
                                                    child: Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: (isDark
                                                                ? Colors.black
                                                                : Colors.white)
                                                            .withValues(
                                                                alpha: 0.88),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: borderColor,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        Icons.refresh_rounded,
                                                        size: 16,
                                                        color: primaryTextColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        _groundFile = null;
                                                        _groundFileBytes = null;
                                                        _groundFileSizeBytes =
                                                            null;
                                                      });
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            100),
                                                    child: Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: (isDark
                                                                ? Colors.black
                                                                : Colors.white)
                                                            .withValues(
                                                                alpha: 0.88),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: borderColor,
                                                        ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.close_rounded,
                                                        size: 16,
                                                        color:
                                                            Color(0xFFEF4444),
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

                                    const SizedBox(height: 14),

                                    // File Detail Strip
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1A202C)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: borderColor.withValues(
                                              alpha: 0.8),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.insert_drive_file_outlined,
                                            size: 20,
                                            color: secondaryTextColor,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _groundFile!.name,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: primaryTextColor,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (_groundFileSizeBytes !=
                                                    null)
                                                  Text(
                                                    '${(_groundFileSizeBytes! / 1024).toStringAsFixed(1)} KB • Ready for processing',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: secondaryTextColor,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981)
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'VALID',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF10B981),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    // Auto Vastu & Direction Analysis Notice
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 14,
                                          color: isDark
                                              ? const Color(0xFF38BDF8)
                                              : AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          config.tr(
                                            'Auto Vastu & Entrance Analysis Enabled',
                                            'தானியங்கி வாஸ்து & வாசல் திசை பகுப்பாய்வு இயக்கப்பட்டது',
                                          ),
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 14),

                                    // Proceed CTA Button
                                    InkWell(
                                      onTap: _navigateToReviewAndPay,
                                      borderRadius: BorderRadius.circular(100),
                                      child: Container(
                                        width: double.infinity,
                                        height: 52,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.primary,
                                          borderRadius:
                                              BorderRadius.circular(100),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: isDark ? 0.35 : 0.15,
                                              ),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const SizedBox(width: 28),
                                            Text(
                                              config.tr(
                                                'Proceed to Generate',
                                                'உருவாக்க தொடர்க',
                                              ),
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.black
                                                    : Colors.white,
                                              ),
                                            ),
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.black
                                                    : Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.arrow_forward,
                                                size: 18,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
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
          ),

          // External Processing / Loading Indicator Overlay
          if (widget.isExternalLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: config.borderColor),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          config.tr(
                            'Generating 3D Villa & Reports...',
                            '3D வில்லா & அறிக்கைகள் உருவாகிறது...',
                          ),
                          style: GoogleFonts.syne(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          config.tr(
                            'Analyzing Vastu, Structure & Estimates',
                            'வாஸ்து, கட்டமைப்பு மற்றும் செலவு கணக்கீடு',
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: secondaryTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 80x80 Logo Emblem CustomPainter
class _LargeLogoPainter extends CustomPainter {
  final Color color;
  _LargeLogoPainter({this.color = AppColors.primary});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path1 = Path()
      ..moveTo(16, 36)
      ..lineTo(40, 16)
      ..lineTo(64, 36)
      ..lineTo(64, 66)
      ..lineTo(16, 66)
      ..close();

    final path2 = Path()
      ..moveTo(29, 29)
      ..lineTo(29, 55);

    final path3 = Path()
      ..moveTo(43, 32)
      ..lineTo(32, 42.5)
      ..lineTo(43, 53);

    final path4 = Path()
      ..moveTo(51, 32)
      ..lineTo(51, 55);

    canvas.save();
    canvas.scale(size.width / 80, size.height / 80);
    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
    canvas.drawPath(path3, paint);
    canvas.drawPath(path4, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LargeLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}

// Compass Painter for Background Art
class _CompassPainter extends CustomPainter {
  final Color color;
  _CompassPainter({this.color = AppColors.primary});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    const cy = 124.0;

    canvas.drawCircle(Offset(cx, cy), 140, paint);

    final dashPaint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const double dashWidth = 3;
    const double dashSpace = 3;
    final Path rectPath = Path()
      ..addRect(Rect.fromLTWH(cx - 65, cy - 56, 130, 112));

    for (PathMetric measurePath in rectPath.computeMetrics()) {
      double distance = 0.0;
      while (distance < measurePath.length) {
        Path extractPath =
            measurePath.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extractPath, dashPaint);
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawLine(Offset(cx - 65, cy), Offset(cx + 65, cy), paint);
    canvas.drawLine(Offset(cx, cy - 56), Offset(cx, cy + 56), paint);
    canvas.drawRect(Rect.fromLTWH(cx - 49, cy - 42, 36, 30), paint);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      oldDelegate.color != color;
}

// Background Architectural CAD Grid for Hero Card
class _BlueprintCardGridPainter extends CustomPainter {
  final Color color;
  _BlueprintCardGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    const double step = 22.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintCardGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

// Animated Upload Action Icon with Pulsing Waves & Ascending Arrow
class _AnimatedUploadIcon extends StatefulWidget {
  final bool isDark;
  final Color primaryColor;
  final Color borderColor;

  const _AnimatedUploadIcon({
    required this.isDark,
    required this.primaryColor,
    required this.borderColor,
  });

  @override
  State<_AnimatedUploadIcon> createState() => _AnimatedUploadIconState();
}

class _AnimatedUploadIconState extends State<_AnimatedUploadIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor =
        widget.isDark ? const Color(0xFF38BDF8) : AppColors.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;

        // Wave ripple 1 (0.0 -> 1.0)
        final ripple1Scale = 1.0 + (t * 0.42);
        final ripple1Opacity = ((1.0 - t) * 0.45).clamp(0.0, 1.0);

        // Wave ripple 2 (offset by 0.5)
        final t2 = (t + 0.5) % 1.0;
        final ripple2Scale = 1.0 + (t2 * 0.42);
        final ripple2Opacity = ((1.0 - t2) * 0.35).clamp(0.0, 1.0);

        // Upload Arrow: continuous upward glide from bottom (+9) to top (-11)
        final arrowY = 9.0 - (20.0 * t);
        final double arrowOpacity;
        if (t < 0.2) {
          arrowOpacity = t / 0.2;
        } else if (t < 0.72) {
          arrowOpacity = 1.0;
        } else {
          arrowOpacity = (1.0 - t) / 0.28;
        }

        // Particle trail dot: follows behind
        final tDot = (t + 0.68) % 1.0;
        final dotY = 12.0 - (22.0 * tDot);
        final double dotOpacity;
        if (tDot < 0.2) {
          dotOpacity = tDot / 0.2;
        } else if (tDot < 0.72) {
          dotOpacity = 0.75;
        } else {
          dotOpacity = (1.0 - tDot) / 0.28;
        }

        return SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Outer Expanding Wave Ring 1
              Transform.scale(
                scale: ripple1Scale,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withValues(alpha: ripple1Opacity),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // Outer Expanding Wave Ring 2
              Transform.scale(
                scale: ripple2Scale,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withValues(alpha: ripple2Opacity),
                      width: 1.2,
                    ),
                  ),
                ),
              ),

              // Central Floating Glowing Orb
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isDark
                        ? [
                            const Color(0xFF1E2838),
                            const Color(0xFF131923),
                          ]
                        : [
                            const Color(0xFFFFFFFF),
                            const Color(0xFFF1F5F9),
                          ],
                  ),
                  border: Border.all(
                    color: widget.isDark
                        ? const Color(0xFF38BDF8).withValues(alpha: 0.4)
                        : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(
                        alpha: widget.isDark ? 0.25 : 0.12,
                      ),
                      blurRadius: 14,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(27),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Blueprint Grid Texture inside Orb
                      Opacity(
                        opacity: widget.isDark ? 0.18 : 0.08,
                        child: CustomPaint(
                          size: const Size(54, 54),
                          painter: _BlueprintCardGridPainter(
                            color: widget.primaryColor,
                          ),
                        ),
                      ),

                      // Cloud / Base Horizon Tray
                      Positioned(
                        bottom: 9,
                        child: Icon(
                          Icons.cloud_outlined,
                          size: 28,
                          color: (widget.isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8))
                              .withValues(alpha: 0.7),
                        ),
                      ),

                      // Trailing upload particle dot
                      Positioned(
                        child: Transform.translate(
                          offset: Offset(0, dotY),
                          child: Opacity(
                            opacity: dotOpacity.clamp(0.0, 1.0),
                            child: Container(
                              width: 3.5,
                              height: 3.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Rising Upload Arrow
                      Positioned(
                        child: Transform.translate(
                          offset: Offset(0, arrowY),
                          child: Opacity(
                            opacity: arrowOpacity.clamp(0.0, 1.0),
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              size: 20,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
