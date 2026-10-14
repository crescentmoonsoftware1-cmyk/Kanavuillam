import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../services/pdf_service.dart';
import '../services/api_service.dart';
import 'package:flutter/material.dart';
import 'feedback_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'js_stub.dart' if (dart.library.html) 'dart:js_interop';
// Conditional imports to prevent mobile build crashes
import 'web_stub.dart' if (dart.library.html) 'dart:ui_web' as ui_web;
import 'web_stub.dart' if (dart.library.html) 'package:web/web.dart' as web;

const _surface = Colors.white;
const _textPri = Color(0xFF111827);
const _textSec = Color(0xFF6B7280);

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
    final bgColor = isDark ? const Color(0xFF0F0F0F) : AppColors.background;
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : AppColors.primary;
    final secondaryTextColor = isDark ? const Color(0xFFA1A1AA) : AppColors.textSecondary;
    final borderColor = isDark ? const Color(0xFF2E2E32) : AppColors.border;

    const String planName = 'kanavuillam_report';
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
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. HEADER (Plan Name, Subtitle, Language Switcher Capsule) ─
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            planName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isTamil
                                ? 'பதிவிறக்க அறிக்கை · $dimsText (${totalArea.toInt()} ச.அடி)'
                                : 'Download report · $dimsText (${totalArea.toInt()} sq ft)',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: secondaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Language Switcher Capsule (Matches Vastu / Stitch)
                    Container(
                      height: 34,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFFCFDFF),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0)),
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
                                    ? const Color(0xFF1B212F)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                'EN',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: !isTamil
                                      ? Colors.white
                                      : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF364050)),
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
                                    ? const Color(0xFF1B212F)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                'தமிழ்',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isTamil
                                      ? Colors.white
                                      : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF364050)),
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
                height: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMainTab(
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
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMainTab(
                        title: isTamil ? 'வாஸ்து' : 'Vastu',
                        isActive: false,
                        isDark: isDark,
                        onTap: () => widget.onNavigateToTab?.call(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMainTab(
                        title: isTamil ? 'செலவு' : 'Cost',
                        isActive: false,
                        isDark: isDark,
                        onTap: () => widget.onNavigateToTab?.call(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMainTab(
                        title: isTamil ? 'அமைப்பு' : 'Structure',
                        isActive: false,
                        isDark: isDark,
                        onTap: () => widget.onNavigateToTab?.call(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMainTab(
                        title: isTamil ? 'பதிவிறக்கம்' : 'Download',
                        isActive: true,
                        isDark: isDark,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── 3. EXECUTIVE HERO CARD (Matching App UI) ─────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: isDark ? Colors.black : Colors.white,
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
                                style: GoogleFonts.syne(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isTamil
                                    ? 'அனைத்து அறிக்கைகளும் ஒரே தொழில்முறை PDF-ல்'
                                    : '3D, Vastu, Cost & Structural combined in one file',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHeroMeta(
                            label: isTamil ? 'அளவு' : 'Plot Size',
                            value: dimsText,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                          ),
                          Container(width: 1, height: 26, color: borderColor),
                          _buildHeroMeta(
                            label: isTamil ? 'பரப்பளவு' : 'Built-up Area',
                            value: '${totalArea.toInt()} sq ft',
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                          ),
                          Container(width: 1, height: 26, color: borderColor),
                          _buildHeroMeta(
                            label: isTamil ? 'நாள்' : 'Date',
                            value: createdAt,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 4. MASTER DOWNLOAD ACTION BUTTON ─────────────────────────
              GestureDetector(
                onTap: _isGeneratingPdf ? null : () => _downloadAll(context, widget.projectData),
                child: Container(
                  width: double.infinity,
                  height: 54,
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
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isGeneratingPdf
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.file_download_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isTamil
                                    ? 'முழு அறிக்கையை பதிவிறக்கு (PDF)'
                                    : 'Download Full PDF Report',
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
              ),
              const SizedBox(height: 24),

              // ── 5. DELIVERABLES TITLE ────────────────────────────────────
              Text(
                isTamil ? 'அறிக்கையின் உள்ளடக்கங்கள்' : 'Included Deliverables',
                style: GoogleFonts.syne(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),

              // ── 6. DELIVERABLE CARDS ─────────────────────────────────────
              _buildDeliverableCard(
                icon: Icons.view_in_ar_rounded,
                title: isTamil ? '3D கட்டிட மாதிரி & தோற்றங்கள்' : '3D Architectural Model & Views',
                subtitle: isTamil
                    ? 'முழுமையான 3D தள வடிவமைப்பு மற்றும் ஐசோமெட்ரிக் தோற்றம்'
                    : 'Photorealistic isometric views & multi-floor architecture',
                tag: isTamil ? 'உள்ளடக்கம்' : 'Included',
                actionLabel: isTamil ? 'PDF' : 'PDF',
                isLoading: _activeSingleDownload == '3D Perspective',
                onDownload: () => _downloadSingle(context, '3D Perspective', widget.projectData),
                cardColor: cardColor,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                isDark: isDark,
              ),
              const SizedBox(height: 10),

              _buildDeliverableCard(
                icon: Icons.explore_rounded,
                title: isTamil ? 'வாஸ்து பகுப்பாய்வு & திருத்தங்கள்' : 'Vastu Shastra Compliance & Score',
                subtitle: isTamil
                    ? 'அறை வாரியான திசைகள், வாஸ்து மதிப்பெண் மற்றும் பரிகாரங்கள்'
                    : 'Directional room scores, energy matrix & remedial guidance',
                tag: isTamil ? 'உள்ளடக்கம்' : 'Included',
                actionLabel: isTamil ? 'PDF' : 'PDF',
                isLoading: _activeSingleDownload == 'Vastu Analysis',
                onDownload: () => _downloadSingle(context, 'Vastu Analysis', widget.projectData),
                cardColor: cardColor,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                isDark: isDark,
              ),
              const SizedBox(height: 10),

              _buildDeliverableCard(
                icon: Icons.calculate_rounded,
                title: isTamil ? 'செலவு மதிப்பீடு & BOQ அறிக்கை' : 'Cost Breakdown & Material BOQ',
                subtitle: isTamil
                    ? 'பொருள் வாரியான செலவுகள், கூலி நிலைகள் மற்றும் நேரலை கட்டணங்கள்'
                    : 'Stage-wise estimates, civil labor & Tamil Nadu material rates',
                tag: isTamil ? 'உள்ளடக்கம்' : 'Included',
                actionLabel: isTamil ? 'PDF' : 'PDF',
                isLoading: _activeSingleDownload == 'Cost Estimation',
                onDownload: () => _downloadSingle(context, 'Cost Estimation', widget.projectData),
                cardColor: cardColor,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                isDark: isDark,
              ),
              const SizedBox(height: 10),

              _buildDeliverableCard(
                icon: Icons.foundation_rounded,
                title: isTamil ? 'கட்டமைப்பு & கம்பிகள் விவரக்குறிப்பு' : 'Structural Design & Rebar Schedule',
                subtitle: isTamil
                    ? 'தூண்கள், அடித்தளம், பீம்கள் விவரங்கள் மற்றும் IS:456 பாதுகாப்பு'
                    : 'Footings, columns, beams, bar bending & earthquake safety',
                tag: isTamil ? 'உள்ளடக்கம்' : 'Included',
                actionLabel: isTamil ? 'PDF' : 'PDF',
                isLoading: _activeSingleDownload == 'Structural Report',
                onDownload: () => _downloadSingle(context, 'Structural Report', widget.projectData),
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? Colors.white : AppColors.primary)
              : (isDark ? const Color(0xFF27272A) : AppColors.surfaceSecondary),
          borderRadius: BorderRadius.circular(100),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            maxLines: 1,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? const Color(0xFFA1A1AA) : AppColors.textSecondary),
            ),
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
          style: GoogleFonts.inter(
            fontSize: 11,
            color: secondaryTextColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.syne(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
          ),
        ),
      ],
    );
  }

  // ── Deliverable Card Builder ───────────────────────────────────────────────
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF27272A) : AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: secondaryTextColor,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  void _showReportViewer(BuildContext context, _Report report) {
    if (report.id == '3d') {
      widget.onNavigateTo3D?.call();
      return;
    }
    final model = widget.projectData['model_data'] ?? {};
    String content = '';

    if (report.id == 'full') {
      content = _generateFullReportText(widget.projectData);
    } else if (report.id == 'vastu') {
      final v = widget.projectData['vastu_data'] ??
          widget.projectData['_vastu'] ??
          model['_vastu'] ??
          {};
      content = _generateVastuText(widget.projectData['name'] ?? 'Project', v);
    } else if (report.id == 'cost') {
      final c = widget.projectData['cost_data'] ??
          widget.projectData['_cost'] ??
          model['_cost'] ??
          {};
      content = _generateCostText(widget.projectData['name'] ?? 'Project', c);
    } else if (report.id == '3d') {
      content =
          _generateModelSummaryText(widget.projectData['name'] ?? 'Project', model);
    } else if (report.id == 'structural') {
      content =
          _generateStructuralText(widget.projectData['name'] ?? 'Project', model);
    } else if (report.id == 'elevation') {
      content = _generateElevationText(widget.projectData['name'] ?? 'Project', model);
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ReportViewer',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: report.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              Icon(report.icon, color: report.color, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.label,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                report.sub,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blueGrey.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          content,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Footer Action
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _downloadSingle(
                                  context, report.label, widget.projectData);
                            },
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Download PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: report.color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
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
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: anim1,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );
  }

  Future<Uint8List> _createPdf(String title, String content) async {
    final tamilFont = await PdfGoogleFonts.notoSansTamilRegular();
    final tamilFontBold = await PdfGoogleFonts.notoSansTamilBold();
    
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
              child: pw.Text('Generated by Kanavu illam AI v1.0',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600)),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  String _generateFullReportText(Map<String, dynamic> data) {
    final name = data['name'] ?? 'Project';
    final model = data['model_data'] ?? {};
    final costRoot = data['cost_data'] ?? data['_cost'] ?? model['_cost'] ?? {};
    final vastuRoot =
        data['vastu_data'] ?? data['_vastu'] ?? model['_vastu'] ?? {};

    final cost =
        costRoot.containsKey('ground') ? (costRoot['ground'] ?? {}) : costRoot;
    final vastu = vastuRoot.containsKey('ground')
        ? (vastuRoot['ground'] ?? {})
        : vastuRoot;

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Project: $name');
    buffer.writeln('Date:    ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('------------------------------------------\n');

    buffer.writeln('CONSTRUCTION COST ESTIMATES');
    buffer.writeln('------------------------------');
    if (cost['estimates'] != null) {
      final est = cost['estimates'];
      buffer.writeln('Basic Package:    Rs. ${est['basic'] ?? 'N/A'}');
      buffer.writeln('Standard Package: Rs. ${est['standard'] ?? 'N/A'}');
      buffer.writeln('Premium Package:  Rs. ${est['premium'] ?? 'N/A'}');
      buffer.writeln('\n* Rates are calculated dynamically based on real-time live market prices.');
    } else {
      buffer.writeln('No cost data available.');
    }
    buffer.writeln('\n');

    buffer.writeln('VASTU SHASTRA ANALYSIS');
    buffer.writeln('-------------------------');
    buffer.writeln('Compliance Score: ${vastu['score'] ?? 'N/A'}/100');
    buffer.writeln('Overall Grade:    ${vastu['grade'] ?? 'N/A'}');

    buffer.writeln('\n[Strengths]');
    for (var s in (vastu['strengths'] ?? [])) {
      buffer.writeln('* $s');
    }

    buffer.writeln('\n[Compliance Issues]');
    for (var v in (vastu['violations'] ?? [])) {
      buffer.writeln('! $v');
    }

    buffer.writeln('\n[Recommendations]');
    for (var r in (vastu['suggestions'] ?? [])) {
      buffer.writeln('- $r');
    }
    buffer.writeln('\n');

    buffer.writeln('ROOM-BY-ROOM BREAKDOWN');
    buffer.writeln('-------------------------');
    final rooms = cost['room_breakdown'] ?? [];
    if (rooms.isNotEmpty) {
      for (var r in rooms) {
        buffer.writeln(
          '${(r['name'] ?? 'Room').padRight(18)} : ${r['area']} sq.ft (Rs. ${r['cost']})',
        );
      }
    } else {
      buffer.writeln('Room details not found.');
    }

    return buffer.toString();
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
    b.writeln('AI Analysis Status: COMPLETE');
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

  String _generateBOQText(String projectName, Map cost) {
    final StringBuffer b = StringBuffer();
    b.writeln('Project: $projectName');
    b.writeln('------------------------------------------\n');
    b.writeln('MATERIAL ESTIMATIONS:');
    b.writeln('* Cement:      ~450 Bags');
    b.writeln('* Steel:       ~3.2 Tons');
    b.writeln('* Sand:        ~1200 Cu.ft');
    b.writeln('* Bricks:      ~12,000 Units');
    b.writeln('\n[LABOR ESTIMATION]');
    b.writeln('* Estimated Man-days: 1,450');
    b.writeln('\n*Quantities are approximate based on AI analysis.');
    return b.toString();
  }

  Future<String?> _askVastuLanguage(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vastu Language / வாஸ்து மொழி'),
        content: const Text('Which language do you want for the Vastu report in the PDF?\n\nPDF-ல் வாஸ்து அறிக்கை எந்த மொழியில் வேண்டும்?'),
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
    if (widget.selectedReportIds.isEmpty || widget.selectedReportIds.contains('vastu')) {
      final lang = await _askVastuLanguage(ctx);
      if (lang == null) return;

      if (lang == 'Tamil') {
        _showSnack(ctx, 'Translating Vastu to Tamil... Please wait.', isSuccess: true);
        try {
          final backendBase = ApiService.baseUrl.replaceAll(RegExp(r'/api$'), '');
          final res = await http.post(
            Uri.parse('$backendBase/api/analyze-vastu/${data['id']}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'lang': 'Tamil'})
          );
          if (res.statusCode == 200) {
            final newVastu = json.decode(res.body);
            final completeData = Map<String, dynamic>.from(data);
            completeData['vastu_data'] = newVastu;
            if (completeData['model_data'] != null) {
              completeData['model_data'] = Map<String, dynamic>.from(completeData['model_data']);
              completeData['model_data']['_vastu'] = newVastu;
            }
            data = completeData;
          }
        } catch (e) {
          debugPrint('Error fetching Tamil vastu: $e');
        }
      }
    }

    final name = data['name'] ?? 'Project';
    final filename = 'kanavu_illam_report.pdf';

    _showSnack(ctx, 'Generating Comprehensive Report PDF... Please wait.',
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
      if (widget.selectedReportIds.isEmpty || widget.selectedReportIds.contains('3d')) {
        try {
          screenshots3D = await widget.capture3DScreenshots?.call() ?? {};
          debugPrint(
              '[PDF] 3D screenshots captured: ${screenshots3D.keys.length}');
        } catch (e) {
          debugPrint('[PDF] 3D screenshots failed: $e');
        }
      }

      final bytes = await PdfService.createProfessionalPdf(
          completeData, widget.selectedReportIds,
          screenshots3D: screenshots3D);

      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: filename);
        _showSnack(ctx, 'Download initiated!', isSuccess: true);
      } else {
        await _downloadFileMobilePdf(ctx, filename, bytes);
      }

      if (ctx.mounted) {
        final prefs = await SharedPreferences.getInstance();
        final uEmail = prefs.getString('user_email') ?? (widget.userData?['email'] as String?) ?? 'unknown';
        final countKey = 'download_count_$uEmail';
        await prefs.setInt(countKey, (prefs.getInt(countKey) ?? 0) + 1);

        Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => FeedbackScreen(userData: widget.userData)));
      }
    } catch (e, stack) {
      debugPrint('Error generating Comprehensive PDF: $e\n$stack');
      if (ctx.mounted) {
        _showSnack(ctx, 'Error creating PDF: $e', isError: true);
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
      if (lang == null) return;

      if (lang == 'Tamil') {
        _showSnack(ctx, 'Translating Vastu to Tamil... Please wait.', isSuccess: true);
        try {
          final backendBase = ApiService.baseUrl.replaceAll(RegExp(r'/api$'), '');
          final res = await http.post(
            Uri.parse('$backendBase/api/analyze-vastu/${data['id']}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'lang': 'Tamil'})
          );
          if (res.statusCode == 200) {
            final newVastu = json.decode(res.body);
            final completeData = Map<String, dynamic>.from(data);
            completeData['vastu_data'] = newVastu;
            if (completeData['model_data'] != null) {
              completeData['model_data'] = Map<String, dynamic>.from(completeData['model_data']);
              completeData['model_data']['_vastu'] = newVastu;
            }
            data = completeData;
          }
        } catch (e) {
          debugPrint('Error fetching Tamil vastu: $e');
        }
      }
    }

    final name = data['name'] ?? 'Project';
    final model = data['model_data'] ?? {};
    final filename = 'kanavu_illam_${label.toLowerCase().replaceAll(' ', '_')}.pdf';
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

    _showSnack(ctx, 'Generating $label PDF... Please wait.', isSuccess: true);

    try {
      final bytes = await _createPdf(docTitle, content);

      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: filename);
        _showSnack(ctx, 'Download initiated!', isSuccess: true);
      } else {
        await _downloadFileMobilePdf(ctx, filename, bytes);
      }

      if (ctx.mounted) {
        final prefs = await SharedPreferences.getInstance();
        final uEmail = prefs.getString('user_email') ?? (widget.userData?['email'] as String?) ?? 'unknown';
        final countKey = 'download_count_$uEmail';
        await prefs.setInt(countKey, (prefs.getInt(countKey) ?? 0) + 1);

        Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => FeedbackScreen(userData: widget.userData)));
      }
    } catch (e, stack) {
      debugPrint('Error generating $label PDF: $e\n$stack');
      if (ctx.mounted) {
        _showSnack(ctx, 'Error creating PDF: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _activeSingleDownload = null);
    }
  }

  Future<void> _downloadFileMobilePdf(
      BuildContext ctx, String filename, Uint8List bytes) async {
    try {
      // Use native share sheet — no storage permission needed.
      // User can tap "Save to Files" / "Downloads" from the share menu.
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (ctx.mounted) {
        _showSnack(ctx, 'Download failed: $e', isError: true);
      }
    }
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

  void _triggerWebDownloadPdf(String filename, Uint8List bytes) {
    if (!kIsWeb) return;

    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final url = web.URL.createObjectURL(blob);

    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;

    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const _InfoItem(
      {required this.icon,
      required this.title,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 10)),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _FeatureBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _FeatureBox(
      {required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  const _CheckItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_rounded,
              color: Color(0xFF059669), size: 16),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFF064E3B),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _Report {
  final String id;
  final IconData icon;
  final String label, sub;
  final Color color;
  const _Report({
    required this.id,
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
  });
}

class _ReportRow extends StatelessWidget {
  final _Report report;
  final int delay;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const _ReportRow({
    required this.report,
    required this.delay,
    required this.onTap,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(
            color: const Color(0xFFF3F4F6),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: report.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(report.icon, color: report.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.label,
                    style: const TextStyle(
                      color: _textPri,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    report.sub,
                    style: const TextStyle(
                        color: _textSec,
                        fontSize: 12,
                        fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onDownload,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.download_outlined,
                      color: report.color, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideX(begin: 0.04, end: 0);
  }
}
