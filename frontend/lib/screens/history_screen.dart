import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  Future<List<dynamic>>? _projectsFuture;

  @override
  void initState() {
    super.initState();
    _loadUserHistory();
  }

  Future<void> _loadUserHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    setState(() {
      _projectsFuture = _apiService.getAllProjects(email);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        title: const Text(
          "Project History",
          style: TextStyle(
            color: Color(0xFFFCD34D),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFFFCD34D),
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. Luxury Architectural Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/luxury_villa_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/images/architectural_bg.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                );
              },
            ),
          ),

          // 2. Dark Scrim Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.75),
                    const Color(0xFF090D16).withValues(alpha: 0.98),
                  ],
                ),
              ),
            ),
          ),

          // 3. Ambient Gold Glow Bulbs
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
              ),
            ),
          ),

          // 4. Main Scrollable List
          Positioned.fill(
            child: FutureBuilder<List<dynamic>>(
              future: _projectsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFCD34D),
                    ),
                  );
                }
                if (snapshot.hasError ||
                    (snapshot.data != null && snapshot.data!.isEmpty)) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.history_toggle_off_rounded,
                              size: 48,
                              color: Color(0xFFFCD34D),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No History Records Yet",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Your generated 3D blueprints & architectural reports will appear here.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final projects = snapshot.data ?? [];

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];

                    bool isValidData(dynamic data) {
                      if (data == null) return false;
                      if (data is Map && data.isEmpty) return false;
                      if (data is String && data.isEmpty) return false;
                      if (data is List && data.isEmpty) return false;
                      return true;
                    }

                    String rawName = project['name'] ?? 'Project';
                    String displayProjectName = rawName;
                    Set<String> selectedReports = {};
                    double amountPaid = 99.0;
                    bool isLegacy = true;

                    if (rawName.contains('|')) {
                      final parts = rawName.split('|');
                      displayProjectName = parts[0];
                      if (parts.length > 1 && parts[1].isNotEmpty) {
                        selectedReports = parts[1].split(',').toSet();
                        isLegacy = false;
                      }
                      if (parts.length > 2) {
                        amountPaid = double.tryParse(parts[2]) ?? amountPaid;
                      }
                    }

                    final model = project['model_data'] ?? {};
                    bool has3D = isLegacy
                        ? (isValidData(project['visual_data']) ||
                            isValidData(model['_visual']))
                        : selectedReports.contains('3d');
                    bool hasElevation = isLegacy
                        ? (isValidData(project['elevation_data']) ||
                            isValidData(model['_elevation']))
                        : selectedReports.contains('elevation');
                    bool hasVastu = isLegacy
                        ? (isValidData(project['vastu_data']) ||
                            isValidData(model['_vastu']))
                        : selectedReports.contains('vastu');
                    bool hasCost = isLegacy
                        ? (isValidData(project['cost_data']) ||
                            isValidData(model['_cost']))
                        : selectedReports.contains('cost') ||
                            selectedReports.contains('boq');
                    bool hasStructural = isLegacy
                        ? (isValidData(project['structural_data']) ||
                            isValidData(model['_structural']))
                        : selectedReports.contains('structural');

                    int totalPrice = isLegacy
                        ? (() {
                            int p = 0;
                            if (has3D) p += 30;
                            if (hasElevation) p += 29;
                            if (hasVastu) p += 20;
                            if (hasCost) p += 20;
                            if (hasStructural) p += 29;
                            return p;
                          })()
                        : amountPaid.round();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            color: Colors.white.withValues(alpha: 0.08),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayProjectName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFBBF24),
                                            Color(0xFFF59E0B),
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        'Paid ₹$totalPrice',
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 13,
                                      color: Color(0xFFFCD34D),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Created: ${project['created_at']?.toString().split('T')[0] ?? 'N/A'}",
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.65),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (has3D)
                                      _buildGlassBadge(
                                          Icons.view_in_ar_rounded,
                                          '3D View',
                                          const Color(0xFF60A5FA)),
                                    if (hasElevation)
                                      _buildGlassBadge(
                                          Icons.apartment_rounded,
                                          'Elevation',
                                          const Color(0xFFF472B6)),
                                    if (hasVastu)
                                      _buildGlassBadge(
                                          Icons.explore_outlined,
                                          'Vastu Score',
                                          const Color(0xFF34D399)),
                                    if (hasCost)
                                      _buildGlassBadge(
                                          Icons.payments_outlined,
                                          'Cost Estimate',
                                          const Color(0xFFFBBF24)),
                                    if (hasStructural)
                                      _buildGlassBadge(
                                          Icons.domain_rounded,
                                          'Structural',
                                          const Color(0xFFA78BFA)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: (index * 80).ms)
                        .slideY(begin: 0.1, end: 0);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.40)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
