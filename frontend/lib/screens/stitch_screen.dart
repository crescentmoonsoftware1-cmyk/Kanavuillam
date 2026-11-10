import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standalone Runner for testing the Stitch Prototype independently.
/// Run via terminal:
/// `cd frontend && flutter run -t ../stitch/stitch_screen.dart`
/// or
/// `cd stitch && flutter run -t stitch_screen.dart`
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StandaloneStitchApp());
}

class StandaloneStitchApp extends StatefulWidget {
  const StandaloneStitchApp({super.key});

  @override
  State<StandaloneStitchApp> createState() => _StandaloneStitchAppState();
}

class _StandaloneStitchAppState extends State<StandaloneStitchApp> {
  bool _isDarkMode = false;

  void _toggleTheme(bool isDark) {
    setState(() => _isDarkMode = isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kanavu Illam - Stitch Preview',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFE9EEF4),
        colorSchemeSeed: const Color(0xFFE58A18),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorSchemeSeed: const Color(0xFFE58A18),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
      ),
      home: StitchHomeScreen(
        isDarkMode: _isDarkMode,
        onThemeChanged: _toggleTheme,
      ),
    );
  }
}

/// Standalone Flutter implementation of `stitch/code.html`
/// Sized & optimized for standard mobile viewports with full responsiveness.
class StitchHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback? onUploadTap;
  final ValueChanged<int>? onNavTap;
  final int initialTabIndex;
  final bool isDarkMode;
  final ValueChanged<bool>? onThemeChanged;

  const StitchHomeScreen({
    super.key,
    this.userData,
    this.onUploadTap,
    this.onNavTap,
    this.initialTabIndex = 0,
    this.isDarkMode = false,
    this.onThemeChanged,
  });

  @override
  State<StitchHomeScreen> createState() => _StitchHomeScreenState();
}

class _StitchHomeScreenState extends State<StitchHomeScreen> {
  static const int _infiniteBase = 1000;
  late final PageController _pageController;
  int _currentPage = _infiniteBase;
  Timer? _autoPlayTimer;
  late int _selectedNavIndex;
  late bool _darkMode;

  // The 5 core workflow cards from stitch/code.html with production assets
  final List<_StitchWorkflowCardData> _cards = const [
    _StitchWorkflowCardData(
      stepTitle: 'Upload',
      stepSubtitle: 'Add your 2D plan',
      mainTitle: 'Blueprint Intake',
      description: 'Upload PDF, CAD or image file',
      icon: Icons.cloud_upload_outlined,
      tag1Label: 'Formats',
      tag1Value: 'PNG, JPG, PDF',
      tag2Label: 'Max size',
      tag2Value: '25 MB',
      tag3Label: 'Time',
      tag3Value: '1 min',
      imageAsset: 'assets/images/upload.png',
      networkUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBiFlmXVN_7HKt1PLo0rFB0ZrQQTm1E7qUsYTFnme3XVNs-CLMT-T4WUlTVW610uTWA-xukTu6D62MDq6Fck2cE2NDADmPPVNwe8EsbprIfUQqdyc4A17A7GIGFSwpX18fQ3r2HoH4b8EpKDIRGupSpEB7QCUjlSyZIb2fh3lPNkE0Z2Beo4AmR25s8HVIwJcHNhXpqlrLlY9vH6TuGa3iGiMCfs0S6l9G2ytHofraoAMrwkst-fTHh',
      imageGradientColors: [Color(0xFF364050), Color(0xFF1B212F)],
    ),
    _StitchWorkflowCardData(
      stepTitle: 'Payment',
      stepSubtitle: 'Pay securely',
      mainTitle: 'Secure Processing',
      description: 'Instant order confirmation',
      icon: Icons.account_balance_wallet_outlined,
      tag1Label: 'Methods',
      tag1Value: 'UPI, Card',
      tag2Label: 'From',
      tag2Value: '₹1',
      tag3Label: 'Unlock',
      tag3Value: 'Instant',
      imageAsset: 'assets/images/payment.png',
      networkUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDtpuO8qRX4wdUKWIV2C0QWw68LGDNX_b4dC46LfHnI0lsVOTIhLgw-O_cr51R1xHBzF7OwwV125wpk_GuPFim04sssWXfT3BOT9qEw9Ur1jScNtdgr9PgkGJCKBgePTIJgw0-VcxYxjuxoOFl7dEf5ew6hljD2YFfvipRa1vi9enbITX9TFxgMhhhAYwSXqeZwLl-6PRMcdzkVrv5p0rBbB74EqfDJt76sFjsnl9u7T3vh2EwIT4r4',
      imageGradientColors: [Color(0xFF283548), Color(0xFF1B212F)],
    ),
    _StitchWorkflowCardData(
      stepTitle: 'Analysis',
      stepSubtitle: 'Checks your plan',
      mainTitle: 'Plan Audit',
      description: 'Structural & Vastu compliance',
      icon: Icons.auto_awesome_outlined,
      tag1Label: 'Checks',
      tag1Value: 'Layout, Rooms',
      tag2Label: 'Includes',
      tag2Value: 'Vastu',
      tag3Label: 'Time',
      tag3Value: 'Minutes',
      imageAsset: 'assets/images/analysis.png',
      networkUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDbXTv1zMgyIyYuTgQUvexpNyg3_-3UEm97f2nocofgcafB1yvEzp75hzYC0LCvw9yBsEMxfCYxBI2IqMDbN-vZ-MgL8IGx-nvjNpb4Nxyz66PwDlBok_noXkufpyAJjDNAkiJxg6wkOnF7sW9AMI9UYJko93oqWOt6ET618JsnNN9ITdbgCpyacIp6XMKWO-DPx4n1O4vxZgH4u_cXzu786aakmeqmrERsJHMCYgpCdaNSILDs1T7c',
      imageGradientColors: [Color(0xFF242E3E), Color(0xFF161B26)],
    ),
    _StitchWorkflowCardData(
      stepTitle: 'Report',
      stepSubtitle: 'See 3D, Vastu and cost',
      mainTitle: 'Comprehensive Reports',
      description: 'Interactive 3D model & BOQ estimates',
      icon: Icons.bar_chart_rounded,
      tag1Label: '3D plan',
      tag1Value: 'Included',
      tag2Label: 'Vastu',
      tag2Value: 'Full audit',
      tag3Label: 'Cost',
      tag3Value: 'BOQ report',
      imageAsset: 'assets/images/report.png',
      networkUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuABEcGFG1B_wwsD94-Q4baFfq95XI5Ye65a7qbxFinNYRPdB1MOHvakoRZR9yhTptFIa_fXw6JNoWDcaPsFFPPch5eamIAOjlIFIQHNI2BFnBabccpP5ck8Z95hv3O0WimbLKeHQcO8X-KLKmLxLpDklDicdr-fsE4Exd5sEU9A6AuCTOE9N500o3Ml9V_yjTP5cmO9jmxRkxJQZA1kwAORzLIoX1BSGuZn_CysCuIOp_ZYBKXM_zR6',
      imageGradientColors: [Color(0xFF2E384D), Color(0xFF1B212F)],
    ),
    _StitchWorkflowCardData(
      stepTitle: 'Download',
      stepSubtitle: 'Save your reports',
      mainTitle: 'Export Deliverables',
      description: 'High-res PDFs and drawing sheets',
      icon: Icons.download_outlined,
      tag1Label: 'Format',
      tag1Value: 'PDF',
      tag2Label: 'Stored',
      tag2Value: 'In History',
      tag3Label: 'Access',
      tag3Value: 'Anytime',
      imageAsset: 'assets/images/download.png',
      networkUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCbhcsgdPEmLkv6yjbzCyKwWn8iEzlLpKVHrojVgdTQfIlaLgWa5L1eZtr70N63I2tD8Wa_peFuav0qUBxDshpyn0Rc8sroYuJcQ0FiclkJc47Idh8Huf3YOiR18mbkUDMBeS0lbc2vW9xVJt0cRWlvx7SgY9nAuObAxHi-lLZFeaw_aBLKi4JlNFIuOrEvlypE-hdP459occ7rqsLND1jx9RG2OMOKxmNfAgIbfmU-Yb_KQY-aOjfm',
      imageGradientColors: [Color(0xFF364050), Color(0xFF1B212F)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedNavIndex = widget.initialTabIndex;
    _darkMode = widget.isDarkMode;
    _currentPage = _infiniteBase;
    _pageController = PageController(
      initialPage: _infiniteBase,
      viewportFraction: 0.88,
    );
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant StitchHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      setState(() => _darkMode = widget.isDarkMode);
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (!mounted) return;
      if (_selectedNavIndex != 0) return; // Only autoplay when Home tab is active
      if (!_pageController.hasClients) return;
      final nextPage = _currentPage + 1;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: const Cubic(0.25, 1.0, 0.5, 1.0),
      );
    });
  }

  void _onUserInteraction() {
    _startAutoPlay();
  }

  void _onSwitchTab(int index) {
    setState(() => _selectedNavIndex = index);
    widget.onNavTap?.call(index);
    if (index == 0) {
      _startAutoPlay();
    } else {
      _autoPlayTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _darkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE9EEF4),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF1B212F), Color(0xFF0F172A)]
                : const [Color(0xFFE9EEF4), Color(0xFFD8DFE9)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // ─── TAB CONTENT (HOME, HISTORY, PROFILE) ─────────────────────
              IndexedStack(
                index: _selectedNavIndex,
                children: [
                  // Tab 0: Stitch Home Screen
                  _buildHomeView(isDark),

                  // Tab 1: Standalone Stitch History View
                  _buildHistoryView(isDark),

                  // Tab 2: Standalone Stitch Profile View
                  _buildProfileView(isDark),
                ],
              ),

              // ─── CORE FLOATING SCOOPED NAVIGATION BAR ──────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _CoreFloatingCapsuleNavBar(
                  selectedIndex: _selectedNavIndex,
                  onTap: _onSwitchTab,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 0. HOME VIEW ─────────────────────────────────────────────────────────
  Widget _buildHomeView(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // 1. HERO HEADER WITH ISOMETRIC HOUSE ILLUSTRATION
            _buildHeroHeader(isDark),

            const SizedBox(height: 16),

            // 2. PRIMARY QUICK CTA: UPLOAD FLOOR PLAN PILL
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildUploadPillButton(isDark),
            ),

            const SizedBox(height: 24),

            // 3. "HOW IT WORKS" TITLE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'How it works',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF18191D),
                  letterSpacing: -0.3,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 4. INFINITE / SWIPEABLE CARDS CAROUSEL
            _buildCardsCarousel(isDark),
          ],
        ),
      ),
    );
  }

  // ─── 1. HERO HEADER ────────────────────────────────────────────────────────
  Widget _buildHeroHeader(bool isDark) {
    return SizedBox(
      height: 250,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Isometric 3D House Cutaway Model on Top-Right
          Positioned(
            right: -25,
            top: 0,
            width: 250,
            height: 270,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/house_isometric.jpg',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'house_isometric.jpg',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.network(
                    'https://lh3.googleusercontent.com/aida/AEtjO1W2Cpuk3ws8Slhl2rVuVHXtIcAynJTxH1LBOu04YYlaZmMJ_4kvDdIheD9GTzUuyBtnICazEoQ9zW_yajvZqt78JID3lT8_1d0QDY8bNTMvUgvxIo_vgzqM4TvDXQTY0N0fj-xRA7JPfAIRZis2axhZFmhxWum0tKeU3IZBNbt023fgGu7WSBFQIDL_2KgnD9_imEwYJ_tA2Y1g3-5uyqPabiTdYd3drVQbhIRPb2J4',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _buildFallbackHouseGraphic(),
                  ),
                ),
              ),
            ),
          ),

          // Main Headline Typography
          Positioned(
            left: 20,
            top: 36,
            width: 235,
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 31,
                  height: 1.22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF18191D),
                  letterSpacing: -1.0,
                ),
                children: const [
                  TextSpan(text: 'Know \nyour home\nbefore you \n'),
                  TextSpan(
                    text: 'build it.',
                    style: TextStyle(color: Color(0xFFE58A18)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fallback isometric house vector in case network image is delayed
  Widget _buildFallbackHouseGraphic() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF364050).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Center(
        child: Icon(
          Icons.home_work_rounded,
          size: 96,
          color: Color(0xFFE58A18),
        ),
      ),
    );
  }

  // ─── 2. PRIMARY QUICK CTA: UPLOAD FLOOR PLAN PILL ───────────────────────────
  Widget _buildUploadPillButton(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onUploadTap ?? () => _showUploadOptionsModal(),
        borderRadius: BorderRadius.circular(100),
        child: Ink(
          height: 52,
          padding: const EdgeInsets.only(left: 20, right: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B212F) : const Color(0xFFFCFDFF),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F1B212F),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upload Floor Plan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF18191D),
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF242C3D) : const Color(0xFFE9EEF4),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Color(0xFFE58A18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUploadOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFFFCFDFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload Floor Plan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF18191D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your 2D sketch, CAD blueprint, or architectural layout to generate instant 3D models and Vastu compliance.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF8E94A0),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Blueprint intake ready! Max size: 25 MB (JPG, PNG, PDF)',
                        style: GoogleFonts.plusJakartaSans(),
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF1E252D),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE58A18),
                  foregroundColor: const Color(0xFF1E252D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                label: const Text('Select File'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 4. CAROUSEL OF WORKFLOW CARDS ─────────────────────────────────────────
  Widget _buildCardsCarousel(bool isDark) {
    return SizedBox(
      height: 330,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is UserScrollNotification) {
            _onUserInteraction();
          }
          return false;
        },
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentPage = index);
          },
          itemBuilder: (context, index) {
            final card = _cards[index % _cards.length];
            final isActive = (index % _cards.length) == (_currentPage % _cards.length);

            return AnimatedScale(
              scale: isActive ? 1.0 : 0.96,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: isActive ? 1.0 : 0.70,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: GestureDetector(
                    onTap: () {
                      if (card.stepTitle == 'Download') {
                        _onSwitchTab(1); // Jump to History
                      } else if (card.stepTitle == 'Upload') {
                        _showUploadOptionsModal();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B212F) : const Color(0xFFFCFDFF),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE9EAEC),
                          width: 1.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x141B212F),
                            blurRadius: 32,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Visual Header / Graphic Banner
                          Container(
                            width: double.infinity,
                            height: 180,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: card.imageGradientColors,
                              ),
                            ),
                            child: Stack(
                              children: [
                                // 1. Asset Graphic Image with network & blueprint fallbacks
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Image.asset(
                                      card.imageAsset,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => card.networkUrl != null
                                          ? Image.network(
                                              card.networkUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => CustomPaint(
                                                painter: _BlueprintPatternPainter(),
                                              ),
                                            )
                                          : CustomPaint(
                                              painter: _BlueprintPatternPainter(),
                                            ),
                                    ),
                                  ),
                                ),

                                // 2. High-contrast gradient vignette
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.12),
                                          Colors.black.withValues(alpha: 0.50),
                                          Colors.black.withValues(alpha: 0.92),
                                        ],
                                        stops: const [0.0, 0.55, 1.0],
                                      ),
                                    ),
                                  ),
                                ),

                                // 3. Text Badge Overlay at bottom-left
                                Positioned(
                                  left: 16,
                                  bottom: 14,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        card.stepTitle,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        card.stepSubtitle,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.75),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Card Body: Title + Icon Badge
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      card.mainTitle,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF18191D),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      card.description,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF8E94A0),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF242C3D) : const Color(0xFFE9EEF4),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      card.icon,
                                      size: 20,
                                      color: const Color(0xFFE58A18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),
                          Divider(
                            height: 1,
                            color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE9EAEC),
                          ),
                          const SizedBox(height: 8),

                          // Card Tags Row (Formats, Max Size, Time)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildCardStat(card.tag1Label, card.tag1Value, isDark),
                                _buildCardStat(card.tag2Label, card.tag2Value, isDark),
                                _buildCardStat(card.tag3Label, card.tag3Value, isDark),
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
          },
        ),
      ),
    );
  }

  Widget _buildCardStat(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF8E94A0),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF18191D),
          ),
        ),
      ],
    );
  }

  // ─── 1. STANDALONE STITCH HISTORY VIEW ──────────────────────────────────────
  Widget _buildHistoryView(bool isDark) {
    final sampleProjects = [
      {'title': '3D & Vastu Plan 01', 'date': 'Today', 'price': '₹1', 'tags': ['3D', 'Vastu', 'BOQ']},
      {'title': 'Modern Duplex Layout', 'date': 'Yesterday', 'price': '₹1', 'tags': ['3D', 'Structural']},
      {'title': 'Architectural Plan 03', 'date': '04 Nov 2026', 'price': '₹1', 'tags': ['Vastu', 'BOQ']},
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Plan History',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF18191D),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE58A18).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${sampleProjects.length} Plans',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE58A18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Folder Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF364050), Color(0xFF1B212F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x291B212F),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(Icons.folder_special_rounded, color: Color(0xFFE58A18), size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stored Deliverables',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '3D Models, CAD Sheets & Vastu Audits',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.70),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Project List Items
          ...sampleProjects.map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B212F) : const Color(0xFFFCFDFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE9EAEC),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F1B212F),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242C3D) : const Color(0xFFE9EEF4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.architecture_rounded, color: Color(0xFFE58A18), size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['title'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF18191D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              p['date'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF8E94A0),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              p['price'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE58A18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showProjectPreview(p),
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    color: const Color(0xFF8E94A0),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 2. STANDALONE STITCH PROFILE VIEW ──────────────────────────────────────
  Widget _buildProfileView(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile & Settings',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF18191D),
            ),
          ),
          const SizedBox(height: 16),

          // User Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B212F) : const Color(0xFFFCFDFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE9EAEC),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x141B212F),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE58A18).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_rounded,
                      color: Color(0xFFE58A18),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kanavu Illam User',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF18191D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stitch Standalone Preview',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF8E94A0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Settings Items
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B212F) : const Color(0xFFFCFDFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE9EAEC),
              ),
            ),
            child: Column(
              children: [
                // Theme Toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242C3D) : const Color(0xFFE9EEF4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: const Color(0xFFE58A18),
                      size: 18,
                    ),
                  ),
                  title: Text(
                    'Dark Mode',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF18191D),
                    ),
                  ),
                  value: _darkMode,
                  activeTrackColor: const Color(0xFFE58A18),
                  activeThumbColor: const Color(0xFFFCFDFF),
                  onChanged: (val) {
                    setState(() => _darkMode = val);
                    widget.onThemeChanged?.call(val);
                  },
                ),
                Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE9EAEC),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242C3D) : const Color(0xFFE9EEF4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.language_rounded, color: Color(0xFFE58A18), size: 18),
                  ),
                  title: Text(
                    'Language',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF18191D),
                    ),
                  ),
                  trailing: Text(
                    'English / தமிழ்',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE58A18),
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE9EAEC),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242C3D) : const Color(0xFFE9EEF4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user_outlined, color: Color(0xFFE58A18), size: 18),
                  ),
                  title: Text(
                    'Architecture Version',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF18191D),
                    ),
                  ),
                  trailing: Text(
                    'v2.0 (Stitch)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8E94A0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── PROJECT PREVIEW MODAL ─────────────────────────────────────────────────
  void _showProjectPreview(Map<String, dynamic> project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFFFCFDFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project['title'] ?? 'Project Details',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF18191D),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Date: ${project['date'] ?? ''} • Package: ${project['price'] ?? '₹1'}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF8E94A0),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE58A18),
                  foregroundColor: const Color(0xFF1B212F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// ─── CORE FLOATING CAPSULE NAVIGATION BAR (Scoop Cradle) ────────────────────
class _CoreFloatingCapsuleNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool isDark;

  const _CoreFloatingCapsuleNavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_CoreFloatingCapsuleNavBar> createState() =>
      _CoreFloatingCapsuleNavBarState();
}

class _CoreFloatingCapsuleNavBarState extends State<_CoreFloatingCapsuleNavBar>
    with TickerProviderStateMixin {
  late AnimationController _posController;
  late AnimationController _buttonController;
  late Animation<double> _posAnim;
  late Animation<double> _buttonScaleAnim;
  late int _activeTabIndex;
  bool _isAnimating = false;

  static int _getTabIndex(int screenIndex) {
    if (screenIndex == 1) return 0; // History (left)
    if (screenIndex == 2) return 2; // Profile (right)
    return 1; // Home (center default)
  }

  static int _getScreenIndex(int tabIndex) {
    if (tabIndex == 0) return 1; // History
    if (tabIndex == 2) return 2; // Profile
    return 0; // Home
  }

  @override
  void initState() {
    super.initState();
    _activeTabIndex = _getTabIndex(widget.selectedIndex);

    _posController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _posAnim = Tween<double>(
      begin: _activeTabIndex.toDouble(),
      end: _activeTabIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _posController,
      curve: Curves.easeInOutCubic,
    ));

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _buttonScaleAnim =
        Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOutBack,
    ));
    _buttonController.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _CoreFloatingCapsuleNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetTab = _getTabIndex(widget.selectedIndex);
    if (targetTab != _activeTabIndex && !_isAnimating) {
      _animateToTab(targetTab, notify: false);
    }
  }

  void _animateToTab(int targetTab, {bool notify = true}) async {
    if (targetTab == _activeTabIndex && !_isAnimating) return;
    _isAnimating = true;

    // Phase 1: Button dives down into the scoop
    await _buttonController.reverse(from: 1.0);

    // Phase 2: Empty scoop notch glides across to the target tab
    final startVal = _posAnim.value;
    _posAnim = Tween<double>(
      begin: startVal,
      end: targetTab.toDouble(),
    ).animate(CurvedAnimation(
      parent: _posController,
      curve: Curves.easeInOutCubic,
    ));
    setState(() {
      _activeTabIndex = targetTab;
    });
    await _posController.forward(from: 0.0);

    // Phase 3: Button pops up out of the scoop at destination
    await _buttonController.forward(from: 0.0);

    _isAnimating = false;
    if (notify) {
      widget.onTap(_getScreenIndex(targetTab));
    }
  }

  @override
  void dispose() {
    _posController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final barColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final shadowColor =
        isDark ? Colors.black.withValues(alpha: 0.55) : const Color(0x281B212F);

    final tabIcons = [
      Icons.history_rounded,
      Icons.home_rounded,
      Icons.person_outline_rounded,
    ];

    const tabCount = 3;
    const barHeight = 75.0;
    const buttonDiam = 54.0;
    const buttonTop = -17.0;

    return SizedBox(
      width: double.infinity,
      height: barHeight,
      child: AnimatedBuilder(
        animation: Listenable.merge([_posController, _buttonController]),
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final tabWidth = w / tabCount;
              final currentCx = (0.5 + _posAnim.value) * tabWidth;

              final buttonBgColor =
                  isDark ? const Color(0xFF283548) : Colors.white;
              final activeIconColor =
                  isDark ? const Color(0xFFE58A18) : const Color(0xFF1E293B);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Authentic Curved Scoop Painter (exact cubic bezier cradle)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CurvedScoopedNavBarPainter(
                        pos: _posAnim.value,
                        itemsLength: tabCount,
                        color: barColor,
                        shadowColor: shadowColor,
                      ),
                    ),
                  ),

                  // 2. Inactive icons centered inside the bar
                  ...List.generate(tabCount, (i) {
                    final dist = (_posAnim.value - i).abs().clamp(0.0, 1.0);
                    final buttonImpact =
                        i == _activeTabIndex ? _buttonScaleAnim.value : 0.0;
                    final iconOpacity =
                        ((1.0 - buttonImpact) * dist).clamp(0.0, 1.0);

                    return Positioned(
                      left: i * tabWidth,
                      width: tabWidth,
                      top: 15,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () => _animateToTab(i),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Opacity(
                            opacity: iconOpacity,
                            child: Icon(
                              tabIcons[i],
                              size: 25,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // 3. Floating Circular Button nestled snugly in the scoop
                  Positioned(
                    left: currentCx - (buttonDiam / 2),
                    top: buttonTop,
                    width: buttonDiam,
                    height: buttonDiam,
                    child: GestureDetector(
                      onTap: () => _animateToTab(_activeTabIndex),
                      behavior: HitTestBehavior.opaque,
                      child: ScaleTransition(
                        scale: _buttonScaleAnim,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: buttonBgColor,
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.50)
                                    : Colors.black.withValues(alpha: 0.16),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              tabIcons[_activeTabIndex],
                              key: ValueKey<int>(_activeTabIndex),
                              size: 26,
                              color: activeIconColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Custom Painter creating the authentic curved navigation bar scoop
/// with smooth cubic bezier shoulders and cradle matching the reference exactly
class _CurvedScoopedNavBarPainter extends CustomPainter {
  final double pos;
  final int itemsLength;
  final Color color;
  final Color shadowColor;

  _CurvedScoopedNavBarPainter({
    required this.pos,
    required this.itemsLength,
    required this.color,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final span = 1.0 / itemsLength;
    final s = 80.0 / w;
    final startingLoc = pos * span;
    final loc = startingLoc + (span - s) / 2;

    final p0x = (loc - 0.1) * w;
    final c1x = (loc + s * 0.20) * w;
    final c2x = loc * w;
    final midx = (loc + s * 0.50) * w;
    final c3x = (loc + s) * w;
    final c4x = (loc + s - s * 0.20) * w;
    final p1x = (loc + s * 1.10) * w;
    final dipY = h * 0.60;

    final path = Path();
    final p0xClamped = p0x.clamp(0.0, w);
    if (p0xClamped > 0) {
      path.lineTo(p0xClamped, 0);
    }
    path.cubicTo(c1x, 0, c2x, dipY, midx, dipY);
    path.cubicTo(c3x, dipY, c4x, 0, p1x, 0);
    final p1xClamped = p1x.clamp(0.0, w);
    if (p1xClamped < w) {
      path.lineTo(w, 0);
    }
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    // Ambient diffuse shadow along top contour
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path.shift(const Offset(0, -2)), shadowPaint);

    // Solid bar surface
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _CurvedScoopedNavBarPainter oldDelegate) =>
      oldDelegate.pos != pos ||
      oldDelegate.color != color ||
      oldDelegate.shadowColor != shadowColor;
}

// ─── DATA MODEL ──────────────────────────────────────────────────────────────
class _StitchWorkflowCardData {
  final String stepTitle;
  final String stepSubtitle;
  final String mainTitle;
  final String description;
  final IconData icon;
  final String tag1Label;
  final String tag1Value;
  final String tag2Label;
  final String tag2Value;
  final String tag3Label;
  final String tag3Value;
  final String imageAsset;
  final String? networkUrl;
  final List<Color> imageGradientColors;

  const _StitchWorkflowCardData({
    required this.stepTitle,
    required this.stepSubtitle,
    required this.mainTitle,
    required this.description,
    required this.icon,
    required this.tag1Label,
    required this.tag1Value,
    required this.tag2Label,
    required this.tag2Value,
    required this.tag3Label,
    required this.tag3Value,
    required this.imageAsset,
    this.networkUrl,
    required this.imageGradientColors,
  });
}

// ─── CUSTOM ARCHITECTURAL BLUEPRINT PAINTER ──────────────────────────────────
class _BlueprintPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    // Draw blueprint grid lines
    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Subtle architectural accent diagonal
    final accentPaint = Paint()
      ..color = const Color(0xFFE58A18).withValues(alpha: 0.15)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(size.width * 0.7, 0),
      Offset(size.width, size.height * 0.4),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
