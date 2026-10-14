import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decor.dart';
import 'secure_payment_screen.dart';

/// Screen converted from dircetion/code.html & screen.png.
/// Displays the uploaded 2D floor plan card and the "Choose Plot Facing Direction" dialog.
class DirectionScreen extends StatefulWidget {
  final XFile groundFile;
  final Uint8List? groundFileBytes;
  final XFile? firstFloorFile;
  final XFile? secondFloorFile;
  final int selectedFloors;
  final Function(
    XFile ground,
    XFile? first,
    XFile? second,
    int floors,
    Set<String> selectedIds,
    String orientation,
  )? onStartGeneration;

  const DirectionScreen({
    super.key,
    required this.groundFile,
    this.groundFileBytes,
    this.firstFloorFile,
    this.secondFloorFile,
    this.selectedFloors = 0,
    this.onStartGeneration,
  });

  @override
  State<DirectionScreen> createState() => _DirectionScreenState();
}

class _DirectionScreenState extends State<DirectionScreen>
    with SingleTickerProviderStateMixin {
  late XFile _currentFile;
  Uint8List? _currentBytes;
  String _selectedDirection = 'East';
  bool _isDialogOpen = true;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.groundFile;
    _currentBytes = widget.groundFileBytes;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _openDialog() {
    setState(() => _isDialogOpen = true);
    _animController.forward(from: 0.0);
  }

  void _closeDialog() {
    _animController.reverse().then((_) {
      if (mounted) setState(() => _isDialogOpen = false);
    });
  }

  Future<void> _pickNewFile(ImageSource source) async {
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
          _currentFile = img;
          _currentBytes = bytes;
        });
        _openDialog();
      }
    } catch (e) {
      debugPrint('Error picking replacement image: $e');
    }
  }

  void _showChangeSourceModal(AppConfigProvider config) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
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
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                config.tr('Change 2D Plan Source', 'வரைபடத்தை மாற்றவும்'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildModalSourceOption(
                      icon: Icons.photo_library_outlined,
                      title: config.tr('Gallery', 'கேலரி'),
                      subtitle: config.tr('Photos & Scans', 'புகைப்படங்கள்'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickNewFile(ImageSource.gallery);
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildModalSourceOption(
                      icon: Icons.camera_alt_outlined,
                      title: config.tr('Camera', 'கேமரா'),
                      subtitle: config.tr('Take photo of plan', 'நேரடி படம்'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickNewFile(ImageSource.camera);
                      },
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

  Widget _buildModalSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.innerPanel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.cardBorder),
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
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onConfirmAndContinue() async {
    final selectedIdsSet = {'3d', 'vastu', 'cost', 'structural'};

    final bool? completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SecurePaymentScreen(
          amount: 500.0,
          selectedItems: const [
            '3D VISUALIZATION',
            'VASTU ANALYSIS',
            'COST ESTIMATION',
            'STRUCTURAL DESIGN',
          ],
          file: _currentFile,
          fileName: _currentFile.name,
          onFinish: () {
            widget.onStartGeneration?.call(
              _currentFile,
              widget.firstFloorFile,
              widget.secondFloorFile,
              widget.selectedFloors,
              selectedIdsSet,
              _selectedDirection,
            );
          },
        ),
      ),
    );

    if (mounted && completed == true) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    }
  }

  String _formatFileSize() {
    if (_currentBytes != null && _currentBytes!.isNotEmpty) {
      final mb = _currentBytes!.lengthInBytes / (1024 * 1024);
      if (mb >= 0.1) return '${mb.toStringAsFixed(1)} MB';
      final kb = _currentBytes!.lengthInBytes / 1024;
      return '${kb.toStringAsFixed(0)} KB';
    }
    return '3.8 MB';
  }

  @override
  Widget build(BuildContext context) {
    AppConfigProvider config;
    try {
      config = context.watch<AppConfigProvider>();
    } catch (_) {
      config = AppConfigProvider();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE9EEF4), Color(0xFFD8DFE9)],
          ),
        ),
        child: Stack(
          children: [
            // ── 1. UNDERLYING UPLOAD SCREEN LAYER ──────────────────────────
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top bar with Back Button, Title, and Brand Logo
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: () => Navigator.pop(context),
                                    borderRadius: BorderRadius.circular(100),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(
                                            0xFFCBD5E1,
                                          ).withValues(alpha: 0.6),
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x101B212F),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.arrow_back_ios_new_rounded,
                                          size: 16,
                                          color: Color(0xFF364050),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    config.tr(
                                      'Upload Floor Plan',
                                      'வரைபடம் பதிவேற்றம்',
                                    ),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E252D),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 40),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Image.asset(
                                'assets/images/logo.png',
                                height: 74,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.home_work_rounded,
                                  size: 48,
                                  color: Color(0xFFE58A18),
                                ),
                              ),
                            ],
                          ),

                          // Middle: Selected File Preview Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCFDFF),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1).withValues(
                                  alpha: 0.8,
                                ),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x181B212F),
                                  blurRadius: 28,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // File Header Row
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F4F8),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.description_outlined,
                                        size: 24,
                                        color: Color(0xFF364050),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _currentFile.name,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF18191D),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_formatFileSize()} • ${config.tr("Uploaded successfully", "வெற்றிகரமாக பதிவேற்றப்பட்டது")}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFDEBCB),
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFE58A18,
                                          ).withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        config.tr('Ready', 'தயார்'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFB46205),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Blueprint thumbnail preview
                                Container(
                                  height: 112,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (_currentBytes != null &&
                                          _currentBytes!.isNotEmpty)
                                        Positioned.fill(
                                          child: Opacity(
                                            opacity: 0.75,
                                            child: Image.memory(
                                              _currentBytes!,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        )
                                      else
                                        Positioned.fill(
                                          child: Container(
                                            color: const Color(0xFF2E3744),
                                            child: const Icon(
                                              Icons.architecture_rounded,
                                              size: 40,
                                              color: Colors.white24,
                                            ),
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF1B212F,
                                          ).withValues(alpha: 0.85),
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                        ),
                                        child: Text(
                                          config.tr(
                                            '2D Architectural Plan',
                                            '2D வரைபட திட்டம்',
                                          ),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Change Floor Plan Button
                                InkWell(
                                  onTap: () => _showChangeSourceModal(config),
                                  borderRadius: BorderRadius.circular(100),
                                  child: Container(
                                    height: 48,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F4F8),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Center(
                                      child: Text(
                                        config.tr(
                                          'Change Floor Plan File',
                                          'வரைபடத்தை மாற்றவும்',
                                        ),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Bottom Proceed button & nav bar underneath
                          Column(
                            children: [
                              GestureDetector(
                                onTap: _openDialog,
                                child: Container(
                                  height: 56,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFBA73B),
                                        Color(0xFFE58A18),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(100),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x59E58A18),
                                        blurRadius: 24,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        config.tr(
                                          'Proceed to Generate',
                                          'உருவாக்க தொடர்க',
                                        ),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1E252D),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                        color: Color(0xFF1E252D),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Static preview nav pill
                              Container(
                                width: 320,
                                height: 56,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFCBD5E1,
                                    ).withValues(alpha: 0.6),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x101B212F),
                                      blurRadius: 20,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStaticNavItem(
                                      Icons.home_rounded,
                                      'Home',
                                      true,
                                    ),
                                    _buildStaticNavItem(
                                      Icons.history_rounded,
                                      'History',
                                      false,
                                    ),
                                    _buildStaticNavItem(
                                      Icons.person_rounded,
                                      'Profile',
                                      false,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── 2. DIMMED BACKDROP OVERLAY ────────────────────────────────
            if (_isDialogOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeDialog,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: const Color(0xFF1B212F).withValues(alpha: 0.45),
                  ),
                ),
              ),

            // ── 3. CHOOSE PLOT FACING DIRECTION DIALOG ────────────────────
            if (_isDialogOpen)
              Positioned.fill(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            width: 350,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCFDFF),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: const Color(0xFFE9EAEC),
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x4D1B212F),
                                  blurRadius: 60,
                                  offset: Offset(0, 24),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // A. Header Band with Compass Needle
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF364050),
                                        Color(0xFF1B212F),
                                      ],
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Compass Icon Circle
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2E3744),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFFBA73B),
                                            width: 1.5,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x33000000),
                                              blurRadius: 8,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: CustomPaint(
                                          painter: _CompassNeedlePainter(),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              config.tr(
                                                'Choose Plot Facing Direction',
                                                'மனையின் திசையைத் தேர்வுசெய்க',
                                              ),
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                fontSize: 19,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                letterSpacing: -0.3,
                                                height: 1.25,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              config.tr(
                                                'Which direction does your main entrance face?',
                                                'உங்கள் வீட்டின் பிரதான வாசல் எந்தத் திசையை நோக்கியுள்ளது?',
                                              ),
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                color: Colors.white
                                                    .withValues(alpha: 0.7),
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // B. 2x2 Direction Grid & Controls
                                Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    children: [
                                      // 2x2 Grid
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildDirectionCard(
                                              direction: 'East',
                                              name: config.tr(
                                                'East',
                                                'கிழக்கு',
                                              ),
                                              caption: config.tr(
                                                'Sunrise / Prosperity',
                                                'சூரிய உதயம் / வளம்',
                                              ),
                                              icon: Icons.wb_sunny_outlined,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildDirectionCard(
                                              direction: 'North',
                                              name: config.tr(
                                                'North',
                                                'வடக்கு',
                                              ),
                                              caption: config.tr(
                                                'Kubera / Wealth Zone',
                                                'குபேர மூலை / செல்வம்',
                                              ),
                                              icon: Icons.explore_outlined,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildDirectionCard(
                                              direction: 'West',
                                              name: config.tr(
                                                'West',
                                                'மேற்கு',
                                              ),
                                              caption: config.tr(
                                                'Vayu Moolai / Wind',
                                                'வாயு மூலை / காற்று',
                                              ),
                                              icon: Icons.air_rounded,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildDirectionCard(
                                              direction: 'South',
                                              name: config.tr(
                                                'South',
                                                'தெற்கு',
                                              ),
                                              caption: config.tr(
                                                'Yama / Strength',
                                                'எம மூலை / வலிமை',
                                              ),
                                              icon: Icons
                                                  .local_fire_department_outlined,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      // C. Info Note
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: const Color(
                                              0xFFCBD5E1,
                                            ).withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.info_outline_rounded,
                                              size: 16,
                                              color: Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                config.tr(
                                                  'Vastu score is calculated based on your entrance direction. Correct selection = accurate report.',
                                                  'உங்கள் வாசல் திசையை அடிப்படையாகக் கொண்டு வாஸ்து மதிப்பெண் கணக்கிடப்படுகிறது.',
                                                ),
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 11.5,
                                                  color: const Color(
                                                    0xFF364050,
                                                  ),
                                                  height: 1.35,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // D. Confirm CTA Button
                                      GestureDetector(
                                        onTap: _onConfirmAndContinue,
                                        child: Container(
                                          height: 54,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFFFBA73B),
                                                Color(0xFFE58A18),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x59E58A18),
                                                blurRadius: 20,
                                                offset: Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                config.tr(
                                                  'Confirm & Continue',
                                                  'உறுதி செய்து தொடர்க',
                                                ),
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(
                                                    0xFF1E252D,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 20,
                                                color: Color(0xFF1E252D),
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
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionCard({
    required String direction,
    required String name,
    required String caption,
    required IconData icon,
  }) {
    final isSelected = _selectedDirection == direction;

    return GestureDetector(
      onTap: () => setState(() => _selectedDirection = direction),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFDEBCB) : const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFE58A18) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x26E58A18),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Check badge
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE58A18),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Color(0xFF1E252D),
                    ),
                  ),
                ),
              ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Icon Circle
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : const Color(0xFFE9EEF4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: isSelected
                        ? const Color(0xFFB46205)
                        : const Color(0xFF364050),
                  ),
                ),

                // Name & Caption
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF18191D),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? const Color(0xFFB46205)
                            : const Color(0xFF8E94A0),
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticNavItem(IconData icon, String label, bool isSelected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: isSelected ? const Color(0xFF1E252D) : const Color(0xFF8E94A0),
        ),
        if (isSelected) ...[
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E252D),
            ),
          ),
        ],
      ],
    );
  }
}

/// Custom painter to draw the circular compass with amber & white needle
class _CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.38, circlePaint);

    // North Pointer (Amber)
    final northPath = Path()
      ..moveTo(cx, cy - 13)
      ..lineTo(cx + 4.5, cy)
      ..lineTo(cx, cy - 2.5)
      ..lineTo(cx - 4.5, cy)
      ..close();
    final northPaint = Paint()
      ..color = const Color(0xFFFBA73B)
      ..style = PaintingStyle.fill;
    canvas.drawPath(northPath, northPaint);

    // South Pointer (White)
    final southPath = Path()
      ..moveTo(cx, cy + 13)
      ..lineTo(cx + 4.5, cy)
      ..lineTo(cx, cy + 2.5)
      ..lineTo(cx - 4.5, cy)
      ..close();
    final southPaint = Paint()
      ..color = const Color(0xFFFCFDFF)
      ..style = PaintingStyle.fill;
    canvas.drawPath(southPath, southPaint);

    // Center pivot
    final pivotPaint = Paint()
      ..color = const Color(0xFF1B212F)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 2.2, pivotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
