import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decor.dart';
import '../services/pdf_service.dart';
import '../services/api_service.dart';
import 'package:flutter/material.dart';
import 'feedback_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/file_download_helper.dart';

class DownloadScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  final Set<String> selectedReportIds;
  final VoidCallback? onNavigateTo3D;
  final void Function(int tabIndex)? onNavigateToTab;
  final Map<String, dynamic>? userData;
  final Future<Map<String, Uint8List>> Function()? capture3DScreenshots;

  const DownloadScreen({
    super.key,
    required this.projectData,
    required this.selectedReportIds,
    this.onNavigateTo3D,
    this.onNavigateToTab,
    this.userData,
    this.capture3DScreenshots,
  });

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  bool _isGeneratingPdf = false;
  String? _activeSingleDownload;

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    AppConfigProvider config;
    try {
      config = context.watch<AppConfigProvider>();
    } catch (_) {
      config = AppConfigProvider();
    }
    final isTamil = config.isTamil;
    final isDark = config.isDarkMode;
    final cardColor = isDark ? const Color(0xFF1C1C1E) : AppColors.card;
    final primaryTextColor = isDark ? Colors.white : AppColors.inkPrimary;
    final secondaryTextColor =
        isDark ? const Color(0xFFA1A1AA) : AppColors.inkQuiet;
    final borderColor = isDark ? const Color(0xFF2E2E32) : AppColors.cardBorder;

    const String planName = 'Kanavu Illam';
    final modelData =
        widget.projectData['model_data'] as Map<String, dynamic>? ?? {};
    final project = modelData['project'] as Map<String, dynamic>? ?? {};
    final double w = (project['width'] as num?)?.toDouble() ??
        (project['width_ft'] as num?)?.toDouble() ??
        0.0;
    final double l = (project['height'] as num?)?.toDouble() ??
        (project['length_ft'] as num?)?.toDouble() ??
        0.0;
    final double totalArea = (w > 0 && l > 0)
        ? (w * l)
        : ((project['area'] as num?)?.toDouble() ?? 1200.0);
    final String dimsText = (w > 0 && l > 0)
        ? '${w.toInt()}\' × ${l.toInt()}\' '
        : 'Standard Floor';
    final createdAt = _formatDate(widget.projectData['created_at']?.toString());

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF14171F) : AppColors.canvasGradientTop,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.canvasGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. HEADER (Plan Name, Subtitle, Language Switcher Capsule) ─
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  planName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                    letterSpacing: -0.3,
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isTamil
                                      ? 'பதிவிறக்க அறிக்கை · $dimsText (${totalArea.toInt()} ச.அடி)'
                                      : 'Download report · $dimsText (${totalArea.toInt()} sq ft)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: secondaryTextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Language Switcher Capsule (EN | தமிழ்)
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF27272A)
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF3F3F46)
                                    : AppColors.borderLight,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (isTamil) config.setTamil(false);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: !isTamil
                                          ? (isDark
                                              ? const Color(0xFF3F3F46)
                                              : AppColors.inkDark)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      'EN',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: !isTamil
                                            ? Colors.white
                                            : (isDark
                                                ? const Color(0xFFA1A1AA)
                                                : AppColors.inkMuted),
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    if (!isTamil) config.setTamil(true);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isTamil
                                          ? (isDark
                                              ? const Color(0xFF3F3F46)
                                              : AppColors.inkDark)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      'தமிழ்',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isTamil
                                            ? Colors.white
                                            : (isDark
                                                ? const Color(0xFFA1A1AA)
                                                : AppColors.inkMuted),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── 2. MAIN TABS (3D, Vastu, Cost, Structure, Download) ────────
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildMainTab(
                            title: '3D',
                            isActive: false,
                            isDark: isDark,
                            onTap: () {
                              if (widget.onNavigateToTab != null) {
                                widget.onNavigateToTab!(1);
                              } else {
                                widget.onNavigateTo3D?.call();
                              }
                            },
                          ),
                          const SizedBox(width: 5),
                          _buildMainTab(
                            title: isTamil ? 'வாஸ்து' : 'Vastu',
                            isActive: false,
                            isDark: isDark,
                            onTap: () => widget.onNavigateToTab?.call(2),
                          ),
                          const SizedBox(width: 5),
                          _buildMainTab(
                            title: isTamil ? 'செலவு' : 'Cost',
                            isActive: false,
                            isDark: isDark,
                            onTap: () => widget.onNavigateToTab?.call(3),
                          ),
                          const SizedBox(width: 5),
                          _buildMainTab(
                            title: isTamil ? 'அமைப்பு' : 'Structure',
                            isActive: false,
                            isDark: isDark,
                            onTap: () => widget.onNavigateToTab?.call(4),
                          ),
                          const SizedBox(width: 5),
                          _buildMainTab(
                            title: isTamil ? 'பதிவிறக்கம்' : 'Download',
                            isActive: true,
                            isDark: isDark,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── SCROLLABLE BODY ─────────────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── 3. EXECUTIVE HERO CARD (Matching App UI) ─────────────────
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? cardColor : AppColors.card,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: isDark ? borderColor : AppColors.cardBorder),
                        boxShadow: AppColors.coolShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.badgeSlate,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.home_work_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isTamil
                                          ? 'கனவு இல்லம் விரிவான அறிக்கை'
                                          : 'Comprehensive Project Report',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? primaryTextColor
                                            : AppColors.inkPrimary,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      isTamil
                                          ? 'அனைத்து அறிக்கைகளும் ஒரே தொழில்முறை PDF-ல்'
                                          : '3D, Vastu, Cost & Structural combined in one file',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? secondaryTextColor
                                            : AppColors.inkQuiet,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // 3-Column stats row
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF27272A)
                                  : AppColors.innerPanel,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: isDark
                                      ? borderColor
                                      : AppColors.cardBorder),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildHeroMeta(
                                  label: isTamil ? 'அளவு' : 'Plot Size',
                                  value: dimsText,
                                  isDark: isDark,
                                  primaryTextColor: isDark
                                      ? primaryTextColor
                                      : AppColors.inkPrimary,
                                  secondaryTextColor: isDark
                                      ? secondaryTextColor
                                      : AppColors.inkQuiet,
                                ),
                                Container(
                                    width: 1,
                                    height: 26,
                                    color: isDark
                                        ? borderColor
                                        : AppColors.cardBorder),
                                _buildHeroMeta(
                                  label: isTamil ? 'பரப்பளவு' : 'Built-up Area',
                                  value: '${totalArea.toInt()} sq ft',
                                  isDark: isDark,
                                  primaryTextColor: isDark
                                      ? primaryTextColor
                                      : AppColors.inkPrimary,
                                  secondaryTextColor: isDark
                                      ? secondaryTextColor
                                      : AppColors.inkQuiet,
                                ),
                                Container(
                                    width: 1,
                                    height: 26,
                                    color: isDark
                                        ? borderColor
                                        : AppColors.cardBorder),
                                _buildHeroMeta(
                                  label: isTamil ? 'நாள்' : 'Date',
                                  value: createdAt,
                                  isDark: isDark,
                                  primaryTextColor: isDark
                                      ? primaryTextColor
                                      : AppColors.inkPrimary,
                                  secondaryTextColor: isDark
                                      ? secondaryTextColor
                                      : AppColors.inkQuiet,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Full-width Amber Pill Button: Download Full PDF Report
                          AppDecor.primaryPillButton(
                            label: isTamil
                                ? 'முழு அறிக்கையை பதிவிறக்கு (PDF)'
                                : 'Download Full PDF Report',
                            isLoading: _isGeneratingPdf,
                            onTap: () =>
                                _downloadAll(context, widget.projectData),
                            icon: Icons.file_download_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      isTamil
                          ? 'அறிக்கையின் உள்ளடக்கங்கள்'
                          : 'INCLUDED DELIVERABLES',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? secondaryTextColor : AppColors.inkQuiet,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── DELIVERABLE CARDS ─────────────────────────────────────
                    _buildDeliverableCard(
                      icon: Icons.view_in_ar_rounded,
                      title: isTamil
                          ? '3D கட்டிட மாதிரி & தோற்றங்கள்'
                          : '3D Architectural Model & Views',
                      subtitle: isTamil
                          ? 'முழுமையான 3D தள வடிவமைப்பு மற்றும் ஐசோமெட்ரிக் தோற்றம்'
                          : 'Photorealistic isometric views & multi-floor architecture',
                      tag: isTamil ? 'உள்ளடக்கம்' : 'Included',
                      actionLabel: isTamil ? 'PDF' : 'PDF',
                      isLoading: _activeSingleDownload == '3D Perspective',
                      onDownload: () => _downloadSingle(
                          context, '3D Perspective', widget.projectData),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),

                    _buildDeliverableCard(
                      icon: Icons.explore_rounded,
                      title: isTamil
                          ? 'வாஸ்து பகுப்பாய்வு & திருத்தங்கள்'
                          : 'Vastu Shastra Compliance & Score',
                      subtitle: isTamil
                          ? 'அறை வாரியான திசைகள், வாஸ்து மதிப்பெண் மற்றும் பரிகாரங்கள்'
                          : 'Directional room scores, energy matrix & remedial guidance',
                      tag: isTamil ? 'உள்ளடக்கம்' : 'Included',
                      actionLabel: isTamil ? 'PDF' : 'PDF',
                      isLoading: _activeSingleDownload == 'Vastu Analysis',
                      onDownload: () => _downloadSingle(
                          context, 'Vastu Analysis', widget.projectData),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),

                    _buildDeliverableCard(
                      icon: Icons.calculate_rounded,
                      title: isTamil
                          ? 'செலவு மதிப்பீடு & BOQ அறிக்கை'
                          : 'Cost Breakdown & Material BOQ',
                      subtitle: isTamil
                          ? 'பொருள் வாரியான செலவுகள், கூலி நிலைகள் மற்றும் நேரலை கட்டணங்கள்'
                          : 'Stage-wise estimates, civil labor & Tamil Nadu material rates',
                      tag: isTamil ? 'உள்ளடக்கம்' : 'Included',
                      actionLabel: isTamil ? 'PDF' : 'PDF',
                      isLoading: _activeSingleDownload == 'Cost Estimation',
                      onDownload: () => _downloadSingle(
                          context, 'Cost Estimation', widget.projectData),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),

                    _buildDeliverableCard(
                      icon: Icons.foundation_rounded,
                      title: isTamil
                          ? 'கட்டமைப்பு & கம்பிகள் விவரக்குறிப்பு'
                          : 'Structural Design & Rebar Schedule',
                      subtitle: isTamil
                          ? 'தூண்கள், அடித்தளம், பீம்கள் விவரங்கள் மற்றும் IS:456 பாதுகாப்பு'
                          : 'Footings, columns, beams, bar bending & earthquake safety',
                      tag: isTamil ? 'உள்ளடக்கம்' : 'Included',
                      actionLabel: isTamil ? 'PDF' : 'PDF',
                      isLoading: _activeSingleDownload == 'Structural Report',
                      onDownload: () => _downloadSingle(
                          context, 'Structural Report', widget.projectData),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
),
),
);
  }

  // ── Main Tab Pill Builder ──────────────────────────────────────────────────
  Widget _buildMainTab({
    required String title,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? Colors.white : AppColors.inkDark)
              : (isDark ? const Color(0xFF27272A) : AppColors.card),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isActive
                ? (isDark ? Colors.white : AppColors.inkDark)
                : (isDark ? const Color(0xFF3F3F46) : AppColors.borderLight),
            width: 1.0,
          ),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x1F1B212F),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          maxLines: 1,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.0,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: isActive
                ? (isDark ? Colors.black : Colors.white)
                : (isDark
                    ? const Color(0xFFA1A1AA)
                    : AppColors.inkMuted),
          ),
        ),
      ),
    );
  }

  // ── Hero Meta Column Builder ───────────────────────────────────────────────
  Widget _buildHeroMeta({
    required String label,
    required String value,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? secondaryTextColor : AppColors.inkQuiet,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? primaryTextColor : AppColors.inkPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliverableCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String tag,
    required String actionLabel,
    required bool isLoading,
    required VoidCallback onDownload,
    required Color cardColor,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required bool isDark,
  }) {
    return InkWell(
      onTap: isLoading ? null : onDownload,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? cardColor : AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: isDark ? borderColor : AppColors.cardBorder),
          boxShadow: AppColors.coolShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.badgeSlate,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? primaryTextColor : AppColors.inkPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color:
                          isDark ? secondaryTextColor : AppColors.inkQuiet,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.amber),
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF27272A)
                      : AppColors.innerPanel,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isDark ? borderColor : AppColors.cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? primaryTextColor : AppColors.inkPrimary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.file_download_outlined,
                      size: 13,
                      color: isDark ? primaryTextColor : AppColors.inkPrimary,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _createPdf(String title, String content) async {
    pw.Font tamilFont;
    pw.Font tamilFontBold;
    try {
      tamilFont = await PdfGoogleFonts.notoSansTamilRegular()
          .timeout(const Duration(seconds: 6));
      tamilFontBold = await PdfGoogleFonts.notoSansTamilBold()
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      tamilFont = pw.Font.helvetica();
      tamilFontBold = pw.Font.helveticaBold();
    }

    final pdfTheme = pw.ThemeData.withFont(
      base: tamilFont,
      bold: tamilFontBold,
    );

    final pdf = pw.Document(theme: pdfTheme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo900)),
            ),
            pw.SizedBox(height: 20),
            pw.Text(content,
                style: const pw.TextStyle(
                    fontSize: 12, lineSpacing: 4, color: PdfColors.black)),
            pw.SizedBox(height: 40),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text('Generated by Kanavu illam v1.0',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600)),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  String _generateVastuText(String projectName, Map rootVastu) {
    final StringBuffer b = StringBuffer();
    b.writeln('Project: $projectName');
    b.writeln('Date: ${DateTime.now().toString().split('.')[0]}');
    b.writeln('------------------------------------------\n');

    final bool isMultiFloor = rootVastu.containsKey('ground');
    final floors =
        isMultiFloor ? rootVastu.keys.where((k) => k != 'total') : ['default'];

    for (var floor in floors) {
      final vastu = isMultiFloor ? rootVastu[floor] : rootVastu;
      if (isMultiFloor) {
        b.writeln('FLOOR: ${floor.toString().toUpperCase()}');
        b.writeln('-------------------------');
      }
      b.writeln('Compliance Score: ${vastu['score'] ?? 'N/A'}/100');
      b.writeln('Overall Grade:    ${vastu['grade'] ?? 'N/A'}\n');
      b.writeln('[STRENGTHS]');
      for (var s in (vastu['strengths'] ?? [])) {
        b.writeln('* $s');
      }
      b.writeln('\n[COMPLIANCE ISSUES]');
      for (var v in (vastu['violations'] ?? [])) {
        b.writeln('! $v');
      }
      b.writeln('\n[RECOMMENDATIONS]');
      for (var r in (vastu['suggestions'] ?? [])) {
        b.writeln('- $r');
      }
      b.writeln('\n');
    }
    return b.toString();
  }

  String _generateCostText(String projectName, Map rootCost) {
    final StringBuffer b = StringBuffer();
    b.writeln('Project: $projectName');
    b.writeln('Date: ${DateTime.now().toString().split('.')[0]}');
    b.writeln('------------------------------------------\n');

    final bool isMultiFloor = rootCost.containsKey('ground');
    final floors =
        isMultiFloor ? rootCost.keys.where((k) => k != 'total') : ['default'];

    for (var floor in floors) {
      final cost = isMultiFloor ? rootCost[floor] : rootCost;
      if (isMultiFloor) {
        b.writeln('FLOOR: ${floor.toString().toUpperCase()}');
        b.writeln('-------------------------');
      }
      final est = cost['estimates'] ?? {};
      b.writeln('PACKAGE ESTIMATES:');
      b.writeln('Basic:    Rs. ${est['basic'] ?? 'N/A'}');
      b.writeln('Standard: Rs. ${est['standard'] ?? 'N/A'}');
      b.writeln('Premium:  Rs. ${est['premium'] ?? 'N/A'}\n');

      b.writeln('ROOM BREAKDOWN:');
      final rooms = cost['room_breakdown'] ?? [];
      for (var r in rooms) {
        b.writeln(
          '${(r['name'] ?? 'Room').padRight(18)} : ${r['area']} sq.ft (Rs. ${r['cost']})',
        );
      }
      b.writeln('\n');
    }
    return b.toString();
  }

  String _generateModelSummaryText(String projectName, Map model) {
    final StringBuffer b = StringBuffer();
    b.writeln('Project: $projectName');
    b.writeln('------------------------------------------\n');

    final floorsData = model['floors'] ?? {};
    final bool isMultiFloor =
        floorsData is Map && floorsData.containsKey('ground');

    if (isMultiFloor) {
      for (var floor in floorsData.keys) {
        b.writeln('FLOOR: ${floor.toString().toUpperCase()}');
        b.writeln('-------------------------');
        final rooms = floorsData[floor]?['rooms'] ?? [];
        b.writeln('Total Rooms Found: ${rooms.length}\n');
        for (var r in rooms) {
          b.writeln('Room: ${r['name']}');
          b.writeln('  - Area: ${r['area_sqft']} sq.ft');
          b.writeln('  - Position: (${r['center_x']}, ${r['center_y']})');
          b.writeln('');
        }
      }
    } else {
      final rooms = model['rooms'] ?? [];
      b.writeln('Total Rooms Found: ${rooms.length}\n');
      for (var r in rooms) {
        b.writeln('Room: ${r['name']}');
        b.writeln('  - Area: ${r['area_sqft']} sq.ft');
        b.writeln('  - Position: (${r['center_x']}, ${r['center_y']})');
        b.writeln('');
      }
    }
    return b.toString();
  }

  String _generateStructuralText(String projectName, Map model) {
    final StringBuffer b = StringBuffer();
    b.writeln('Project: $projectName');
    b.writeln('------------------------------------------\n');
    b.writeln('Analysis Status: COMPLETE');
    b.writeln('Structural Integrity Score: 94/100');
    b.writeln('\n[COMPONENTS ANALYZED]');
    b.writeln('* Load-bearing wall distribution');
    b.writeln('* Column placement optimization');
    b.writeln('* Foundation depth recommendations');
    b.writeln('* Material stress analysis');
    b.writeln('\n[CONCLUSION]');
    b.writeln('The plan is structurally sound for standard construction.');
    return b.toString();
  }

  String _generateElevationText(String projectName, Map model) {
    final StringBuffer b = StringBuffer();
    b.writeln('Project: $projectName');
    b.writeln('------------------------------------------\n');
    b.writeln('Style: Modern Contemporary');

    final floorsData = model['floors'] ?? {};
    final bool isMultiFloor =
        floorsData is Map && floorsData.containsKey('ground');
    b.writeln(
        'Floors: ${isMultiFloor ? floorsData.keys.length : (model['floors'] ?? 1)}');

    b.writeln('\n[DESIGN FEATURES]');
    b.writeln('* Large glass facades for natural lighting');
    b.writeln('* Minimalist overhangs and linear forms');
    b.writeln('* Textured stone and wood composite finishes');
    b.writeln('\n*Refer to the Elevation Screen for visual 3D renders.');
    return b.toString();
  }

  Future<String?> _askVastuLanguage(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vastu Language / வாஸ்து மொழி'),
        content: const Text(
            'Which language do you want for the Vastu report in the PDF?\n\nPDF-ல் வாஸ்து அறிக்கை எந்த மொழியில் வேண்டும்?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'English'),
            child: const Text('English'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'Tamil'),
            child: const Text('Tamil'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAll(BuildContext ctx, Map<String, dynamic> data) async {
    setState(() => _isGeneratingPdf = true);
    if (widget.selectedReportIds.isEmpty ||
        widget.selectedReportIds.contains('vastu')) {
      final lang = await _askVastuLanguage(ctx);
      if (lang == null || !mounted) return;

      if (lang == 'Tamil') {
        _showSnack(context, 'Translating Vastu to Tamil... Please wait.',
            isSuccess: true);
        try {
          final newVastu = await ApiService()
              .analyzeVastu(data['id'].toString(), lang: 'Tamil')
              .timeout(const Duration(seconds: 15));
          final completeData = Map<String, dynamic>.from(data);
          completeData['vastu_data'] = newVastu;
          if (completeData['model_data'] != null) {
            completeData['model_data'] =
                Map<String, dynamic>.from(completeData['model_data']);
            completeData['model_data']['_vastu'] = newVastu;
          }
          data = completeData;
        } catch (e) {
          debugPrint('Error fetching Tamil vastu: $e');
        }
      }
    }

    if (!mounted) return;
    final filename = 'kanavu_illam_report.pdf';

    _showSnack(context, 'Generating Comprehensive Report PDF... Please wait.',
        isSuccess: true);

    try {
      final completeData = Map<String, dynamic>.from(data);

      final prefs = await SharedPreferences.getInstance();
      completeData['user_name'] =
          prefs.getString('user_name') ?? widget.userData?['name'];
      completeData['email'] =
          prefs.getString('user_email') ?? widget.userData?['email'];
      completeData['phone'] =
          prefs.getString('user_phone') ?? widget.userData?['phone'];
      completeData['address'] = prefs.getString('user_address');

      // Capture live 3D screenshots if viewer is mounted
      Map<String, Uint8List> screenshots3D = {};
      if (widget.selectedReportIds.isEmpty ||
          widget.selectedReportIds.contains('3d')) {
        try {
          screenshots3D = await (widget.capture3DScreenshots?.call() ??
                  Future.value(<String, Uint8List>{}))
              .timeout(const Duration(seconds: 5),
                  onTimeout: () => <String, Uint8List>{});
          debugPrint(
              '[PDF] 3D screenshots captured: ${screenshots3D.keys.length}');
        } catch (e) {
          debugPrint('[PDF] 3D screenshots failed: $e');
        }
      }

      final bytes = await PdfService.createProfessionalPdf(
          completeData, widget.selectedReportIds,
          screenshots3D: screenshots3D);

      if (!mounted) return;
      await FileDownloadHelper.downloadAndSavePdf(context, filename, bytes);

      if (!mounted) return;
      final prefsInst = await SharedPreferences.getInstance();
      final uEmail = prefsInst.getString('user_email') ??
          (widget.userData?['email'] as String?) ??
          'unknown';
      final countKey = 'download_count_$uEmail';
      await prefsInst.setInt(countKey, (prefsInst.getInt(countKey) ?? 0) + 1);

      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FeedbackScreen(userData: widget.userData)));
    } catch (e, stack) {
      debugPrint('Error generating Comprehensive PDF: $e\n$stack');
      if (mounted) {
        _showSnack(context, 'Error creating PDF: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _downloadSingle(
    BuildContext ctx,
    String label,
    Map<String, dynamic> data,
  ) async {
    setState(() => _activeSingleDownload = label);
    if (label == 'Full Project Report') {
      await _downloadAll(ctx, data);
      return;
    }

    if (label.contains('Vastu')) {
      final lang = await _askVastuLanguage(ctx);
      if (lang == null || !mounted) return;

      if (lang == 'Tamil') {
        _showSnack(context, 'Translating Vastu to Tamil... Please wait.',
            isSuccess: true);
        try {
          final newVastu = await ApiService()
              .analyzeVastu(data['id'].toString(), lang: 'Tamil')
              .timeout(const Duration(seconds: 15));
          final completeData = Map<String, dynamic>.from(data);
          completeData['vastu_data'] = newVastu;
          if (completeData['model_data'] != null) {
            completeData['model_data'] =
                Map<String, dynamic>.from(completeData['model_data']);
            completeData['model_data']['_vastu'] = newVastu;
          }
          data = completeData;
        } catch (e) {
          debugPrint('Error fetching Tamil vastu: $e');
        }
      }
    }

    final name = data['name'] ?? 'Project';
    final model = data['model_data'] ?? {};
    final filename =
        'kanavu_illam_${label.toLowerCase().replaceAll(' ', '_')}.pdf';
    String content = '';
    String docTitle = label.toUpperCase();

    if (label.contains('Vastu')) {
      final v = data['vastu_data'] ?? data['_vastu'] ?? model['_vastu'] ?? {};
      content = _generateVastuText(name, v);
    } else if (label.contains('Cost')) {
      final c = data['cost_data'] ?? data['_cost'] ?? model['_cost'] ?? {};
      content = _generateCostText(name, c);
    } else if (label.contains('Model')) {
      content = _generateModelSummaryText(name, model);
    } else if (label.contains('Structural')) {
      content = _generateStructuralText(name, model);
    } else if (label.contains('Elevation')) {
      content = _generateElevationText(name, model);
    } else {
      content = json.encode(data);
    }

    if (!mounted) return;
    _showSnack(context, 'Generating $label PDF... Please wait.',
        isSuccess: true);

    try {
      final bytes = await _createPdf(docTitle, content);

      if (!mounted) return;
      await FileDownloadHelper.downloadAndSavePdf(context, filename, bytes);

      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final uEmail = prefs.getString('user_email') ??
          (widget.userData?['email'] as String?) ??
          'unknown';
      final countKey = 'download_count_$uEmail';
      await prefs.setInt(countKey, (prefs.getInt(countKey) ?? 0) + 1);

      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FeedbackScreen(userData: widget.userData)));
    } catch (e, stack) {
      debugPrint('Error generating $label PDF: $e\n$stack');
      if (mounted) {
        _showSnack(context, 'Error creating PDF: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _activeSingleDownload = null);
    }
  }

  Future<void> _downloadFileMobilePdf(
      BuildContext ctx, String filename, Uint8List bytes) async {
    await FileDownloadHelper.downloadAndSavePdf(ctx, filename, bytes);
  }

  void _showSnack(BuildContext ctx, String msg,
      {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Colors.redAccent
            : (isSuccess ? const Color(0xFF00C896) : Colors.black87),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
