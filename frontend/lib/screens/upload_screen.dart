import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decor.dart';
import '../widgets/floor_plan_upload_illustration.dart';
import 'direction_screen.dart';

/// High-Fidelity Home Screen based on stitch_kanavu_illam_home_screeneditrd
/// Features:
/// 1. Deep Navy Header ("Plan Your Dream Home")
/// 2. Sheet Container with 36px top border radius
/// 3. Card 1: Deliverables Carousel Card (Modern Luxury Villa at Dusk, 4K & DWG Bundle)
/// 4. Card 2: Upload 2D Floor Plan Hero Card with 10s Isometric Vector House Pen-Draw animation
/// 5. Full bilingual (English / Tamil) support and responsive layout
class UploadScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> project, Set<String> selectedIds)?
      onProjectLoaded;
  final Function(XFile ground, XFile? first, XFile? second, int floors,
      Set<String> selectedIds, String orientation)? onStartGeneration;
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

class _UploadScreenState extends State<UploadScreen> {
  XFile? _groundFile;
  Uint8List? _groundFileBytes;
  XFile? _firstFloorFile;
  XFile? _secondFloorFile;
  final int _selectedFloors = 0;
  int _activeCarouselIndex = 0;
  int _currentVirtualPage = 1000;
  final PageController _carouselPageController =
      PageController(initialPage: 1000);
  Timer? _carouselTimer;

  // 5 Workflow Steps: Upload -> Payment -> Analysis -> Report -> Download
  static const List<Map<String, dynamic>> _workflowSteps = [
    {
      'step': 1,
      'stepTag': 'Step 01',
      'pillText': '2D Blueprint Input',
      'pillTextTa': 'வரைபடம் பதிவு',
      'title': 'Upload 2D Plan',
      'titleTa': '2D வரைபடம் பதிவேற்றம்',
      'subtitle': 'Add your 2D sketch, blueprint, or architectural layout',
      'subtitleTa': 'கேலரி அல்லது கேமரா வழியாக 2D வரைபடத்தை சேர்க்கவும்',
      'image': 'assets/images/upload.png',
      'badge1': 'JPG & PDF',
      'badge1Sub': 'FORMAT',
      'badge2': 'MAX 25MB',
      'badge2Sub': 'LIMIT',
      'footerLeft': 'Plan Submission',
      'footerRight': 'Step 1 of 5',
      'icon': Icons.cloud_upload_outlined,
    },
    {
      'step': 2,
      'stepTag': 'Step 02',
      'pillText': 'Instant Access',
      'pillTextTa': 'உடனடி அனுமதி',
      'title': 'Secure Payment',
      'titleTa': 'பாதுகாப்பான கட்டணம்',
      'subtitle': 'Transparent pricing with automated instant activation',
      'subtitleTa': 'வெளிப்படையான விலை மற்றும் உடனடி UPI கட்டணம்',
      'image': 'assets/images/payment.png',
      'badge1': 'UPI & Card',
      'badge1Sub': 'GATEWAY',
      'badge2': 'Instant',
      'badge2Sub': 'UNLOCK',
      'footerLeft': '100% Secure & Encrypted',
      'footerRight': 'Step 2 of 5',
      'icon': Icons.lock_outline_rounded,
    },
    {
      'step': 3,
      'stepTag': 'Step 03',
      'pillText': 'AI Vision Engine',
      'pillTextTa': 'AI பகுப்பாய்வு',
      'title': 'AI Plan Analysis',
      'titleTa': 'AI திட்ட ஆய்வு',
      'subtitle': 'Instant neural scan for rooms, walls & 16-zone Vastu',
      'subtitleTa': 'அறைகள், சுவர்கள் மற்றும் வாஸ்துவின் துல்லிய பகுப்பாய்வு',
      'image': 'assets/images/analysis.png',
      'badge1': '16-Zone',
      'badge1Sub': 'VASTU',
      'badge2': 'AI Engine',
      'badge2Sub': 'SCANNING',
      'footerLeft': 'Neural Spatial Extraction',
      'footerRight': 'Step 3 of 5',
      'icon': Icons.document_scanner_outlined,
    },
    {
      'step': 4,
      'stepTag': 'Step 04',
      'pillText': 'Full Audit Dossier',
      'pillTextTa': 'முழு அறிக்கைகள்',
      'title': 'Comprehensive Reports',
      'titleTa': 'விரிவான அறிக்கைகள்',
      'subtitle': 'Accurate Vastu score, complete BOQ & structural report',
      'subtitleTa': 'வாஸ்து மதிப்பெண், முழு BOQ செலவு மதிப்பீடு தயார்',
      'image': 'assets/images/report.png',
      'badge1': 'BOQ & Cost',
      'badge1Sub': 'ESTIMATE',
      'badge2': 'Structure',
      'badge2Sub': 'AUDIT',
      'footerLeft': 'Full Construction Audit',
      'footerRight': 'Step 4 of 5',
      'icon': Icons.analytics_outlined,
    },
    {
      'step': 5,
      'stepTag': 'Step 05',
      'pillText': 'Final Deliverables',
      'pillTextTa': 'இறுதி தயாரிப்புகள்',
      'title': 'Download Deliverables',
      'titleTa': 'பதிவிறக்கம்',
      'subtitle': 'Export high-resolution 3D elevations and CAD/DWG package',
      'subtitleTa': 'அச்சுக்குத் தயாரான 4K எலிவேஷன் மற்றும் CAD கோப்புகள்',
      'image': 'assets/images/download.png',
      'fallbackImage': 'assets/images/stitch_hero_villa.png',
      'badge1': '4K & DWG',
      'badge1Sub': 'DELIVERABLE',
      'badge2': 'Bundle',
      'badge2Sub': 'PACKAGE',
      'footerLeft': 'Ready for construction print',
      'footerRight': 'Step 5 of 5',
      'icon': Icons.file_download_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _startCarouselTimer();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer =
        Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted && _carouselPageController.hasClients) {
        _currentVirtualPage++;
        _carouselPageController.animateToPage(
          _currentVirtualPage,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselPageController.dispose();
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
        });
        _navigateToDirectionScreen();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showPickSourceModal(AppConfigProvider config) {
    showModalBottomSheet(
      context: context,
      backgroundColor: config.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: config.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                config.tr(
                    'Choose 2D Plan Source', 'வரைபடத்தைத் தேர்ந்தெடுக்கவும்'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: config.primaryTextColor,
                ),
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 12),
            ],
          ),
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
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222938) : AppColors.innerPanel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: config.borderColor),
        ),
        child: Column(
          children: [
            AppDecor.darkIconTile(icon: icon, size: 48, iconSize: 22),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: config.primaryTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
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

  void _navigateToDirectionScreen() {
    if (_groundFile == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DirectionScreen(
          groundFile: _groundFile!,
          groundFileBytes: _groundFileBytes,
          firstFloorFile: _firstFloorFile,
          secondFloorFile: _secondFloorFile,
          selectedFloors: _selectedFloors,
          onStartGeneration: widget.onStartGeneration,
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
    final isTamil = config.isTamil;

    // Navy header background colors matching stitch specification
    // Slate Grey gradient matching history_screen.dart top header card
    final headerGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF232B38), Color(0xFF14171F)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF364050), Color(0xFF1B212F)],
          );
    final sheetBg = isDark ? const Color(0xFF131826) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF14171F) : const Color(0xFF1B212F),
      body: Container(
        decoration: BoxDecoration(
          gradient: headerGradient,
        ),
        child: Stack(
          children: [
            // Upper Slate Header Area (Matching History page style)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 195,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top: Brand Name
                      Text(
                        'Kanavuillam',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFCFDFF),
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isTamil
                            ? 'உங்கள் 2D வரைபடத்தை துல்லியமான 3D திட்டமாக மாற்றுங்கள்.'
                            : 'Turn your 2D sketch or blueprint into an accurate 3D architectural plan.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFFCBD5E1),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Curved Off-White Sheet (Starts from 160px and extends down)
            Positioned.fill(
              top: 160,
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(36)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(36)),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 95),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ─── CARD 1: Deliverables Carousel Card ───────────────
                        _buildDeliverablesCard(config),

                        const SizedBox(height: 14),

                        // ─── CARD 2: Hero Upload Card with Isometric Animation ─
                        _buildUploadCard(config),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // External Loading Overlay
            if (widget.isExternalLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 32),
                      decoration: BoxDecoration(
                        color: config.cardColor,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 56,
                            height: 56,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFE58A18)),
                              backgroundColor: Color(0x33E58A18),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            config.tr(
                              'Generating 3D Villa & Reports...',
                              '3D வில்லா & அறிக்கைகள் உருவாகிறது...',
                            ),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: config.primaryTextColor,
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
      ),
    );
  }

  // ─── CARD 1: 5-Step Workflow Carousel Card (2.5s Auto-Sliding PageView) ────
  Widget _buildDeliverablesCard(AppConfigProvider config) {
    final isTamil = config.isTamil;

    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: config.isDarkMode
              ? const Color(0xFF2E384D)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F1E3D),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // True Horizontally Sliding Carousel
            Positioned.fill(
              child: PageView.builder(
                controller: _carouselPageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (idx) {
                  setState(() {
                    _currentVirtualPage = idx;
                    _activeCarouselIndex = idx % _workflowSteps.length;
                  });
                  _startCarouselTimer();
                },
                itemBuilder: (context, virtualIdx) {
                  final item =
                      _workflowSteps[virtualIdx % _workflowSteps.length];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background Image
                      Image.asset(
                        item['image'] as String,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            item['fallbackImage'] as String,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          );
                        },
                      ),

                      // Dusk Gradient Overlay for high readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xFF0B1322),
                              const Color(0xFF0B1322).withValues(alpha: 0.70),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.48, 1.0],
                          ),
                        ),
                      ),

                      // Bottom Content Section
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title + Subtitle + Right Badges
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isTamil
                                            ? item['titleTa'] as String
                                            : item['title'] as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isTamil
                                            ? item['subtitleTa'] as String
                                            : item['subtitle'] as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w400,
                                          color: const Color(0xFFCBD5E1),
                                          height: 1.25,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Stats badges
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          item['badge1'] as String,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFE8890C),
                                          ),
                                        ),
                                        Text(
                                          item['badge1Sub'] as String,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF94A3B8),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      width: 1,
                                      height: 20,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      color:
                                          Colors.white.withValues(alpha: 0.25),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          item['badge2'] as String,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          item['badge2Sub'] as String,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF94A3B8),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),
                            Container(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            const SizedBox(height: 6),

                            // Footer info line
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['footerLeft'] as String,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                Text(
                                  item['footerRight'] as String,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom Segment Progress Indicator (5 equal segments)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3.5,
              child: Row(
                children: List.generate(_workflowSteps.length, (index) {
                  final isActive =
                      index == (_activeCarouselIndex % _workflowSteps.length);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final diff = index -
                            (_activeCarouselIndex % _workflowSteps.length);
                        _currentVirtualPage += diff;
                        _carouselPageController.animateToPage(
                          _currentVirtualPage,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOutCubic,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFE8890C)
                              : Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CARD 2: Upload 2D Floor Plan Hero Card (Reference Design) ───────────
  Widget _buildUploadCard(AppConfigProvider config) {
    final isDark = config.isDarkMode;
    final cardBg = isDark ? const Color(0xFF131D31) : const Color(0xFFFFFFFF);
    final borderColor = isDark
        ? const Color(0xFFE58A18).withValues(alpha: 0.40)
        : const Color(0xFFF6C878).withValues(alpha: 0.90);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: isDark
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x0F0F1E3D),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: borderColor,
          strokeWidth: 1.6,
          radius: 28,
          dashLength: 7.0,
          gapLength: 5.0,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: _groundFile == null
              ? _buildEmptyUploadContent(config)
              : _buildPickedFilePreview(config),
        ),
      ),
    );
  }

  Widget _buildEmptyUploadContent(AppConfigProvider config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Header: "Upload your plan" & "PNG, JPG, JPEG • Max 5MB"
        Column(
          children: [
            Text(
              config.tr('Upload your plan', 'உங்கள் வரைபடத்தை பதிவேற்றவும்'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: config.primaryTextColor,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              'PNG, JPG, JPEG • Max 5MB',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: config.isDarkMode
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Compact Animated Illustration Stack (Blueprints + 3D Floating Cloud)
        GestureDetector(
          onTap: () => _showPickSourceModal(config),
          behavior: HitTestBehavior.opaque,
          child: FloorPlanUploadIllustration(
            height: 120,
            isDark: config.isDarkMode,
          ),
        ),

        const SizedBox(height: 12),

        // Primary "Choose Floor Plan" Action Button (Exact Reference Design)
        GestureDetector(
          onTap: () => _showPickSourceModal(config),
          child: Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE88D10), Color(0xFFD67300)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x38E58A18),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.file_upload_outlined,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  config.tr('Choose Floor Plan', 'வரைபடம் தேர்வு செய்க'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPickedFilePreview(AppConfigProvider config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              config.tr('Floor Plan Selected', 'வரைபடம் தேர்ந்தெடுக்கப்பட்டது'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: config.primaryTextColor,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _groundFile = null;
                  _groundFileBytes = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: Colors.red),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFF1B212F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _groundFileBytes != null
                ? Image.memory(_groundFileBytes!, fit: BoxFit.contain)
                : const Center(
                    child: Icon(Icons.insert_drive_file_outlined,
                        size: 48, color: Colors.white70),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _navigateToDirectionScreen,
          child: Container(
            height: 50,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFBA73B), Color(0xFFE58A18)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4DE58A18),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  config.tr('Proceed to Generate', 'உருவாக்க தொடர்க'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E252D),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    size: 16, color: Color(0xFF1E252D)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Dashed Rounded Rectangle Border Painter for Upload Card
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double gapLength;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.6,
    this.radius = 28.0,
    this.dashLength = 7.0,
    this.gapLength = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double length = math.min(dashLength, metric.length - distance);
        final segment = metric.extractPath(distance, distance + length);
        canvas.drawPath(segment, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius;
}
