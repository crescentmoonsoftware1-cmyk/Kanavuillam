import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decor.dart';
import 'direction_screen.dart';

class _WorkflowStepItem {
  final String titleEn;
  final String titleTa;
  final String subtitleEn;
  final String subtitleTa;
  final IconData icon;
  final int step;
  const _WorkflowStepItem({
    required this.titleEn,
    required this.titleTa,
    required this.subtitleEn,
    required this.subtitleTa,
    required this.icon,
    required this.step,
  });
}

class UploadScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> project, Set<String> selectedIds)? onProjectLoaded;
  final Function(XFile ground, XFile? first, XFile? second, int floors, Set<String> selectedIds, String orientation)? onStartGeneration;
  final bool isExternalLoading;
  const UploadScreen({super.key, this.onProjectLoaded, this.onStartGeneration, this.isExternalLoading = false});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  static const int _initialVirtualPage = 1000;
  late PageController _pageController;
  Timer? _autoPlayTimer;
  XFile? _groundFile;
  Uint8List? _groundFileBytes;
  XFile? _firstFloorFile;
  XFile? _secondFloorFile;
  final int _selectedFloors = 0;

  static const List<_WorkflowStepItem> _workflowSteps = [
    _WorkflowStepItem(titleEn:'Upload',titleTa:'பதிவேற்றம்',subtitleEn:'Add 2D architectural blueprint from camera or files',subtitleTa:'கேமரா அல்லது கோப்புகளிலிருந்து 2D வரைபடம்',icon:Icons.cloud_upload_outlined,step:1),
    _WorkflowStepItem(titleEn:'Plan Analysis',titleTa:'திட்ட பகுப்பாய்வு',subtitleEn:'Instant structural, spatial & Vastu room analysis',subtitleTa:'உடனடி கட்டமைப்பு மற்றும் வாஸ்து பகுப்பாய்வு',icon:Icons.document_scanner_outlined,step:2),
    _WorkflowStepItem(titleEn:'Pay',titleTa:'கட்டணம்',subtitleEn:'Transparent pricing with instant unlock',subtitleTa:'வெளிப்படையான விலை நிர்ணயம்',icon:Icons.payments_outlined,step:3),
    _WorkflowStepItem(titleEn:'Reports',titleTa:'அறிக்கைகள்',subtitleEn:'Comprehensive Vastu, Cost & Structure reports',subtitleTa:'வாஸ்து, செலவு மற்றும் கட்டமைப்பு அறிக்கைகள்',icon:Icons.view_in_ar_outlined,step:4),
    _WorkflowStepItem(titleEn:'Download',titleTa:'பதிவிறக்கு',subtitleEn:'Export high-resolution deliverables & CAD files',subtitleTa:'உயர்தர PDF மற்றும் CAD கோப்புகளை பதிவிறக்கு',icon:Icons.file_download_outlined,step:5),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialVirtualPage);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 3600), (timer) {
      if (_pageController.hasClients) {
        final current = _pageController.page?.round() ?? _initialVirtualPage;
        _pageController.animateToPage(current + 1, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
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
      final img = await ImagePicker().pickImage(source: source, maxWidth: 4096, maxHeight: 4096, imageQuality: 100);
      if (img != null) {
        final bytes = await img.readAsBytes();
        if (!mounted) return;
        setState(() { _groundFile = img; _groundFileBytes = bytes; });
        _navigateToDirectionScreen();
      }
    } catch (e) { debugPrint('Error picking image: $e'); }
  }

  void _showPickSourceModal(AppConfigProvider config) {
    showModalBottomSheet(
      context: context,
      backgroundColor: config.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 44, height: 4, decoration: BoxDecoration(color: config.borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text(config.tr('Choose 2D Plan Source', 'வரைபடத்தைத் தேர்ந்தெடுக்கவும்'), style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: config.primaryTextColor)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _buildSourceOption(icon: Icons.photo_library_outlined, title: config.tr('Gallery', 'கேலரி'), subtitle: config.tr('Photos & Scans', 'புகைப்படங்கள்'), onTap: () { Navigator.pop(ctx); _pickBlueprint(ImageSource.gallery); }, config: config)),
                const SizedBox(width: 14),
                Expanded(child: _buildSourceOption(icon: Icons.camera_alt_outlined, title: config.tr('Camera', 'கேமரா'), subtitle: config.tr('Take photo of plan', 'நேரடி படம்'), onTap: () { Navigator.pop(ctx); _pickBlueprint(ImageSource.camera); }, config: config)),
              ]),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, required AppConfigProvider config}) {
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
        child: Column(children: [
          AppDecor.darkIconTile(icon: icon, size: 48, iconSize: 22),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: config.primaryTextColor)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: config.secondaryTextColor), textAlign: TextAlign.center),
        ]),
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
    try { config = context.watch<AppConfigProvider>(); } catch (_) { config = AppConfigProvider(); }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: config.canvasGradient),
        child: Stack(children: [
          Positioned.fill(child: SafeArea(bottom: false, child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
              child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  width: double.infinity,
                  height: 316,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B212F),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: config.isDarkMode ? const Color(0xFF2E384D) : const Color(0xFFFCFDFF),
                      width: config.isDarkMode ? 2.5 : 6,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x381B212F),
                        blurRadius: 40,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFF1B212F),
                            Color(0xFF222A3A),
                            Color(0xFF364050),
                          ],
                        ),
                      ),
                      child: PageView.builder(
                        controller: _pageController,
                        itemBuilder: (_, index) {
                          final step = _workflowSteps[index % _workflowSteps.length];
                          return _WorkflowSlide(step: step);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: config.cardColor,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: config.borderColor, width: 1),
                    boxShadow: config.isDarkMode
                        ? const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8))]
                        : const [BoxShadow(color: Color(0x141B212F), blurRadius: 32, offset: Offset(0, 12))],
                  ),
                  child: _groundFile == null ? _buildUploadPrompt(config) : _buildFilePreview(config),
                ),
              ]),
            ),
          )))),
          if (widget.isExternalLoading) Positioned.fill(child: Container(
            color: Colors.black.withValues(alpha: 0.65),
            child: Center(child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(28)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 3.5, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE58A18)), backgroundColor: Color(0x33E58A18))),
                const SizedBox(height: 20),
                Text(config.tr('Generating 3D Villa & Reports...','3D வில்லா & அறிக்கைகள் உருவாகிறது...'), style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.deepInk), textAlign: TextAlign.center),
              ]),
            )),
          )),
        ]),
      ),
    );
  }

  Widget _buildUploadPrompt(AppConfigProvider config) {
    return Column(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFF1B212F), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE58A18), width: 1)), child: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 22)),
      const SizedBox(height: 12),
      Text(config.tr('Upload 2D Floor Plan', '2D வரைபடத்தைப் பதிவேற்றவும்'), style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: config.primaryTextColor, letterSpacing: -0.2), textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text(config.tr('Tap here to browse blueprint from Gallery or Camera', 'கேலரி அல்லது கேமராவிலிருந்து வரைபடத்தைத் தேர்ந்தெடுக்கவும்'), style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w400, color: config.secondaryTextColor, height: 1.4), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _fmtPill('JPG', config),
            const SizedBox(width: 6),
            _fmtPill('PNG', config),
            const SizedBox(width: 6),
            _fmtPill('PDF', config),
            const SizedBox(width: 6),
            _fmtPill('MAX 25MB', config),
          ],
        ),
      ),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: () => _showPickSourceModal(config),
        child: Container(
          height: 50, width: double.infinity,
          decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFBA73B), Color(0xFFE58A18)]), borderRadius: BorderRadius.circular(100), boxShadow: const [BoxShadow(color: Color(0x59E58A18), blurRadius: 24, offset: Offset(0, 8))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(config.tr('Select Floor Plan', 'வரைபடம் தேர்வு செய்க'), style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1E252D))),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF1E252D)),
          ]),
        ),
      ),
    ]);
  }

  Widget _fmtPill(String label, AppConfigProvider config) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: config.isDarkMode ? const Color(0xFF242C3D) : const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: config.isDarkMode ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildFilePreview(AppConfigProvider config) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity, height: 170,
        decoration: BoxDecoration(color: const Color(0xFF1B212F), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
        child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Stack(children: [
          if (_groundFileBytes != null) Positioned.fill(child: Padding(padding: const EdgeInsets.all(8), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(_groundFileBytes!, fit: BoxFit.contain))))
          else const Center(child: Icon(Icons.insert_drive_file_outlined, size: 56, color: Colors.white70)),
          Positioned(top: 10, right: 10, child: Row(children: [
            _actionBtn(Icons.refresh_rounded, Colors.white, () => _showPickSourceModal(config)),
            const SizedBox(width: 6),
            _actionBtn(Icons.close_rounded, const Color(0xFFEF4444), () { setState(() { _groundFile = null; _groundFileBytes = null; }); }),
          ])),
        ])),
      ),
      const SizedBox(height: 18),
      GestureDetector(
        onTap: _navigateToDirectionScreen,
        child: Container(
          height: 50, width: double.infinity,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFBA73B), Color(0xFFE58A18)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(100), boxShadow: const [BoxShadow(color: Color(0x59E58A18), blurRadius: 24, offset: Offset(0, 8))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(config.tr('Proceed to Generate', 'உருவாக்க தொடர்க'), style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1E252D))),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF1E252D)),
          ]),
        ),
      ),
    ]);
  }

  Widget _actionBtn(IconData icon, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFF2E3744), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.2))), child: Icon(icon, size: 16, color: iconColor)),
    );
  }
}

// ─── Workflow Carousel Slide (Horizontal 2-Column with 3D Float Animation) ────
class _WorkflowSlide extends StatefulWidget {
  final _WorkflowStepItem step;
  const _WorkflowSlide({required this.step});

  @override
  State<_WorkflowSlide> createState() => _WorkflowSlideState();
}

class _WorkflowSlideState extends State<_WorkflowSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppConfigProvider config;
    try { config = context.watch<AppConfigProvider>(); } catch (_) { config = AppConfigProvider(); }
    final title = config.isTamil ? widget.step.titleTa : widget.step.titleEn;
    final subtitle = config.isTamil ? widget.step.subtitleTa : widget.step.subtitleEn;
    final stepNumStr = widget.step.step.toString().padLeft(2, '0');

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final leftWidth = (w * 0.48).clamp(130.0, 200.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Left side - Title, Subtitle and Step counter
            SizedBox(
              width: leftWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: widget.step.step == 2 ? 22 : 25,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFCFDFF),
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xBFFCFDFF),
                            height: 1.35,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          stepNumStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFCFDFF),
                            letterSpacing: -0.5,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/05',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0x99FCFDFF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2. Right side - 3D Isometric Floating Illustration
            Expanded(
              child: AnimatedBuilder(
                animation: _floatAnim,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatAnim.value),
                    child: child,
                  );
                },
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 175,
                      height: 175,
                      child: CustomPaint(
                        painter: _StepIllustrationPainter(step: widget.step.step),
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
  }
}


class _StepIllustrationPainter extends CustomPainter {
  final int step;
  const _StepIllustrationPainter({required this.step});
  static const Color _w = Color(0xFFFCFDFF);
  static const Color _bd = Color(0xFFCBD5E1);
  static const Color _sl = Color(0xFF94A3B8);
  static const Color _dk = Color(0xFF364050);
  static const Color _ink = Color(0xFF1B212F);
  static const Color _al = Color(0xFFFBA73B);
  static const Color _ad = Color(0xFFE58A18);
  Paint _f(Color c) => Paint()..color=c..style=PaintingStyle.fill;
  Paint _s(Color c,double sw) => Paint()..color=c..style=PaintingStyle.stroke..strokeWidth=sw..strokeCap=StrokeCap.round;
  Paint _ag(Rect r) => Paint()..shader=ui.Gradient.linear(r.topLeft,r.bottomRight,[_al,_ad])..style=PaintingStyle.fill;
  Path _poly(double w,double h,List<List<double>> pts) {
    final p=Path();
    for(int i=0;i<pts.length;i++){
      if(i==0) {
        p.moveTo(pts[i][0]*w,pts[i][1]*h);
      } else {
        p.lineTo(pts[i][0]*w,pts[i][1]*h);
      }
    }
    p.close(); return p;
  }
  @override
  void paint(Canvas canvas,Size size){
    final w=size.width,h=size.height;
    switch(step){case 1:_up(canvas,w,h);break;case 2:_an(canvas,w,h);break;case 3:_pay(canvas,w,h);break;case 4:_rep(canvas,w,h);break;case 5:_dl(canvas,w,h);break;}
  }
  void _up(Canvas canvas,double w,double h){
    canvas.drawPath(_poly(w,h,[[0.183,0.567],[0.583,0.35],[0.850,0.50],[0.450,0.733]]),_f(_sl.withValues(alpha:0.30)));
    final dp=_poly(w,h,[[0.167,0.533],[0.567,0.317],[0.833,0.467],[0.433,0.70]]);
    canvas.drawPath(dp,_f(_w)); canvas.drawPath(dp,_s(_bd,1.5));
    canvas.drawPath(_poly(w,h,[[0.283,0.50],[0.483,0.383],[0.633,0.467],[0.433,0.583]]),_f(const Color(0xFFF1F5F9)));
    final ox=14.0/120.0*w;
    final cl=Path()..moveTo(w*0.35+ox,h*0.383)..conicTo(w*0.267+ox,h*0.383,w*0.267+ox,h*0.30,1)..conicTo(w*0.267+ox,h*0.225,w*0.342+ox,h*0.225,1)..conicTo(w*0.358+ox,h*0.142,w*0.467+ox,h*0.142,1)..conicTo(w*0.567+ox,h*0.142,w*0.60+ox,h*0.242,1)..conicTo(w*0.642+ox,h*0.242,w*0.675+ox,h*0.317,1)..conicTo(w*0.675+ox,h*0.383,w*0.60+ox,h*0.383,1)..close();
    canvas.drawPath(cl,_f(_w)); canvas.drawPath(cl,_s(_bd,1));
    final ar=Rect.fromLTWH(w*0.38+ox,h*0.10,w*0.18,h*0.20);
    canvas.drawPath(Path()..moveTo(w*0.475+ox,h*0.117)..lineTo(w*0.567+ox,h*0.208)..lineTo(w*0.513+ox,h*0.208)..lineTo(w*0.513+ox,h*0.308)..lineTo(w*0.438+ox,h*0.308)..lineTo(w*0.438+ox,h*0.208)..lineTo(w*0.383+ox,h*0.208)..close(),_ag(ar));
  }
  void _an(Canvas canvas,double w,double h){
    final dp=_poly(w,h,[[0.15,0.533],[0.55,0.317],[0.817,0.467],[0.417,0.70]]);
    canvas.drawPath(dp,_f(_w)); canvas.drawPath(dp,_s(_bd,1.5));
    for(final y in [0.383,0.433,0.483]){canvas.drawLine(Offset(w*0.25,h*y),Offset(w*0.70,h*y),Paint()..color=_sl.withValues(alpha:0.8)..strokeWidth=1.5..style=PaintingStyle.stroke);}
    final cx=w*0.56,cy=h*0.38,r=w*0.15;
    canvas.drawCircle(Offset(cx,cy),r,_f(_w.withValues(alpha:0.55)));
    canvas.drawCircle(Offset(cx,cy),r,Paint()..shader=ui.Gradient.linear(Offset(cx-r,cy-r),Offset(cx+r,cy+r),[_al,_ad])..style=PaintingStyle.stroke..strokeWidth=4);
    canvas.drawCircle(Offset(cx,cy),r*0.7,_s(_sl,1));
    canvas.drawCircle(Offset(cx,cy),3.5,_f(_ad));
    canvas.drawPath(Path()..moveTo(cx+r*0.7,cy+r*0.7)..lineTo(cx+r*1.3,cy+r*1.3)..lineTo(cx+r*1.1,cy+r*1.5)..lineTo(cx+r*0.5,cy+r*0.9)..close(),_f(_dk));
  }
  void _pay(Canvas canvas,double w,double h){
    const ox=0.083;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*(0.183+ox),h*0.20,w*0.383,h*0.567),const Radius.circular(10)),_f(_ink));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*(0.167+ox),h*0.167,w*0.383,h*0.567),const Radius.circular(10)),Paint()..shader=ui.Gradient.linear(Offset(w*(0.25+ox),h*0.167),Offset(w*(0.25+ox),h*0.733),[_dk,_ink])..style=PaintingStyle.fill);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*(0.192+ox),h*0.20,w*0.333,h*0.50),const Radius.circular(7)),_f(const Color(0xFFE9EEF4)));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*(0.308+ox),h*0.225,w*0.10,h*0.017),const Radius.circular(1)),_f(_sl));
    canvas.drawCircle(Offset(w*(0.358+ox),h*0.433),w*0.117,_f(_dk));
    canvas.drawPath(Path()..moveTo(w*(0.25+ox),h*0.433)..lineTo(w*(0.325+ox),h*0.475)..lineTo(w*(0.467+ox),h*0.383),Paint()..color=_al..strokeWidth=3.5..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round..style=PaintingStyle.stroke);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*(0.258+ox),h*0.583,w*0.20,h*0.033),const Radius.circular(2)),_f(const Color(0xFFD8DFE9)));
    const ocx=0.017;
    canvas.drawOval(Rect.fromLTWH(w*(0.567+ocx),h*0.617,w*0.217,h*0.167),_f(const Color(0xFFB46205)));
    canvas.drawOval(Rect.fromLTWH(w*(0.567+ocx),h*0.583,w*0.217,h*0.167),_ag(Rect.fromLTWH(w*(0.567+ocx),h*0.583,w*0.217,h*0.167)));
    final tp=TextPainter(text:const TextSpan(text:'\u20B9',style:TextStyle(fontSize:13,fontWeight:FontWeight.bold,color:Color(0xFF1E252D))),textDirection:TextDirection.ltr)..layout();
    tp.paint(canvas,Offset(w*(0.658+ocx),h*0.606));
  }
  void _rep(Canvas canvas,double w,double h){
    canvas.drawPath(_poly(w,h,[[0.183,0.55],[0.55,0.35],[0.783,0.483],[0.417,0.683]]),_f(_sl.withValues(alpha:0.40)));
    canvas.drawPath(_poly(w,h,[[0.167,0.50],[0.533,0.30],[0.767,0.433],[0.40,0.633]]),_f(const Color(0xFFD8DFE9)));
    final fp=_poly(w,h,[[0.15,0.433],[0.517,0.233],[0.75,0.367],[0.383,0.567]]);
    canvas.drawPath(fp,_f(_w)); canvas.drawPath(fp,_s(_bd,1.5));
    final bx=10.0/120.0*w,by=4.0/120.0*h;
    canvas.drawRect(Rect.fromLTWH(w*0.35+bx,h*0.375+by,w*0.033,h*0.125),_f(_sl));
    canvas.drawRect(Rect.fromLTWH(w*0.408+bx,h*0.258+by,w*0.04,h*0.242),_ag(Rect.fromLTWH(w*0.408+bx,h*0.258+by,w*0.04,h*0.242)));
    canvas.drawPath(_poly(w,h,[[0.408+bx/w,0.258+by/h],[0.441+bx/w,0.242+by/h],[0.467+bx/w,0.258+by/h],[0.433+bx/w,0.275+by/h]]),_f(_al));
    canvas.drawRect(Rect.fromLTWH(w*0.475+bx,h*0.275+by,w*0.033,h*0.192),_f(_dk));
  }
  void _dl(Canvas canvas, double w, double h) {
    // 1. Dark 3D Isometric Base Pedestal
    final tp = _poly(w, h, [[0.18, 0.58], [0.52, 0.40], [0.82, 0.54], [0.48, 0.72]]);
    canvas.drawPath(
      tp,
      Paint()
        ..shader = ui.Gradient.linear(Offset(w * 0.18, h * 0.58), Offset(w * 0.82, h * 0.72), [_dk, _ink])
        ..style = PaintingStyle.fill,
    );
    // 3D Bevel edge of the base
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.18, h * 0.58)
        ..lineTo(w * 0.18, h * 0.62)
        ..lineTo(w * 0.48, h * 0.76)
        ..lineTo(w * 0.82, h * 0.58)
        ..lineTo(w * 0.82, h * 0.54)
        ..lineTo(w * 0.48, h * 0.72)
        ..close(),
      _f(_ink),
    );

    // 2. White Glossy Isometric Document Sheet floating on the pedestal
    final ox = w * 0.03, oy = -h * 0.06;
    final dp = _poly(w, h, [[0.22 + ox / w, 0.46 + oy / h], [0.54 + ox / w, 0.29 + oy / h], [0.78 + ox / w, 0.41 + oy / h], [0.46 + ox / w, 0.58 + oy / h]]);
    canvas.drawPath(dp, _f(_w));
    canvas.drawPath(dp, _s(_bd, 1.5));

    // Document blueprint content lines
    canvas.drawLine(Offset(w * 0.34 + ox, h * 0.41 + oy), Offset(w * 0.60 + ox, h * 0.34 + oy), _s(_sl.withValues(alpha: 0.7), 2.5));
    canvas.drawLine(Offset(w * 0.38 + ox, h * 0.45 + oy), Offset(w * 0.64 + ox, h * 0.38 + oy), _s(_sl.withValues(alpha: 0.7), 2.5));
    canvas.drawLine(Offset(w * 0.42 + ox, h * 0.49 + oy), Offset(w * 0.68 + ox, h * 0.42 + oy), _s(_sl.withValues(alpha: 0.7), 2.5));

    // 3. Large Downward Amber Arrow pointing directly onto the document (matching screen.png)
    final ar = Rect.fromLTWH(w * 0.48, h * 0.08, w * 0.22, h * 0.28);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.54, h * 0.08)
        ..lineTo(w * 0.64, h * 0.08)
        ..lineTo(w * 0.64, h * 0.20)
        ..lineTo(w * 0.71, h * 0.20)
        ..lineTo(w * 0.59, h * 0.32)
        ..lineTo(w * 0.47, h * 0.20)
        ..lineTo(w * 0.54, h * 0.20)
        ..close(),
      _ag(ar),
    );
  }
  @override
  bool shouldRepaint(covariant _StepIllustrationPainter old) => old.step != step;
}