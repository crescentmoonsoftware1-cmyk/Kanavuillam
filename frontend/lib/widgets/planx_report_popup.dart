import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ReportOption {
  final String id;
  final String title;
  final String description;
  final int price;
  final IconData icon;
  final Color iconColor;

  ReportOption({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.icon,
    required this.iconColor,
  });
}

class PlanXReportPopup extends StatefulWidget {
  final void Function(Set<String> selectedIds) onContinue;
  const PlanXReportPopup({super.key, required this.onContinue});

  @override
  State<PlanXReportPopup> createState() => _PlanXReportPopupState();
}

class _PlanXReportPopupState extends State<PlanXReportPopup> {
  final List<ReportOption> _options = [
    ReportOption(
      id: '3d',
      title: '3D Walkthrough & View',
      description: 'Realistic 3D model visualization & 360° orbit',
      price: 500,
      icon: Icons.view_in_ar_rounded,
      iconColor: const Color(0xFF38BDF8), // Cyan
    ),
    ReportOption(
      id: 'vastu',
      title: 'Vastu Shastra Score',
      description: 'Directional balance & cosmic energy alignment',
      price: 500,
      icon: Icons.explore_rounded,
      iconColor: const Color(0xFFF59E0B), // Amber Gold
    ),
    ReportOption(
      id: 'cost',
      title: 'Cost Estimation & BOQ',
      description: 'Material quantities & labor cost breakdown',
      price: 500,
      icon: Icons.calculate_rounded,
      iconColor: const Color(0xFF34D399), // Emerald
    ),
    ReportOption(
      id: 'structural',
      title: 'Structural Safety Specs',
      description: 'Beam, column & foundation load specs',
      price: 500,
      icon: Icons.architecture_rounded,
      iconColor: const Color(0xFFA855F7), // Purple
    ),
  ];

  final Set<String> _selectedIds = {'3d', 'vastu', 'cost', 'structural', 'elevation'};
  final int _totalPrice = 500; // Fixed total amount for all projects

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width > 500 ? 460.0 : screenSize.width * 0.92;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Center(
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(
            maxHeight: screenSize.height * 0.90,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0F172A).withValues(alpha: 0.96),
                const Color(0xFF1E1B4B).withValues(alpha: 0.96),
                const Color(0xFF090D16).withValues(alpha: 0.98),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.20),
                blurRadius: 32,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                // Top Right Warm Ambient Glow
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTopHeader(),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildGrid(),
                      ),
                    ),
                    _buildBottomActionSection(),
                  ],
                ),
              ],
            ),
          ),
        )
            .animate()
            .scale(
              duration: 400.ms,
              curve: Curves.easeOutBack,
              begin: const Offset(0.88, 0.88),
            )
            .fadeIn(duration: 300.ms),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 22.0, left: 16, right: 16, bottom: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Gold Badge Icon
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFCD34D).withValues(alpha: 0.3),
                  const Color(0xFFF59E0B).withValues(alpha: 0.15),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFCD34D).withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFCD34D).withValues(alpha: 0.3),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: Color(0xFFFCD34D),
              size: 28,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.95, end: 1.05, duration: 2000.ms),
          const SizedBox(height: 10),

          const Text(
            'Blueprint Uploaded!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
              shadows: [
                Shadow(color: Colors.black54, blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // All-inclusive Badge Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFCD34D).withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars_rounded, color: Color(0xFFFCD34D), size: 14),
                  SizedBox(width: 5),
                  Text(
                    'ALL 4 REPORTS AUTOMATICALLY INCLUDED',
                    style: TextStyle(
                      color: Color(0xFFFCD34D),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.76, // Taller cards to ensure zero bottom overflow
      ),
      itemBuilder: (context, index) {
        final opt = _options[index];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: opt.iconColor.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: opt.iconColor.withValues(alpha: 0.12),
                blurRadius: 12,
                spreadRadius: -2,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: opt.iconColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: opt.iconColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(opt.icon, color: opt.iconColor, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF34D399),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 11,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                opt.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                opt.description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 9.5,
                  height: 1.25,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'FULL ACCESS ✓',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: (index * 45).ms, duration: 300.ms)
            .slideY(begin: 0.08, end: 0);
      },
    );
  }

  Widget _buildBottomActionSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Left Total Budget Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCD34D).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.workspace_premium,
                            color: Color(0xFFFCD34D), size: 16),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Complete Package',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  const Text(
                                    'Total: ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '₹$_totalPrice',
                                    style: const TextStyle(
                                      color: Color(0xFFFCD34D),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Right Security Notice Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Color(0x2034D399),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_rounded,
                            color: Color(0xFF34D399), size: 15),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instant Unlock',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '100% Protected',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 8.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Glowing Action Button
          GestureDetector(
            onTap: () => widget.onContinue(_selectedIds),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFCD34D),
                    Color(0xFFF59E0B),
                    Color(0xFFD97706),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Unlock All Reports & Continue (₹$_totalPrice)',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFFFCD34D),
                      size: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
