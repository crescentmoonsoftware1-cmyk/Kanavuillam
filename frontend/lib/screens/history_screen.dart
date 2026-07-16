import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'viewer_screen.dart';

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
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        title: Text("Project History", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue[900]),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _projectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || (snapshot.data != null && snapshot.data!.isEmpty)) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 64, color: Colors.blue.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text(
                    "No history data available",
                    style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }
          final projects = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
                ? (isValidData(project['visual_data']) || isValidData(project['elevation_data']) || isValidData(model['_visual']) || isValidData(model['_elevation']))
                : selectedReports.contains('3d') || selectedReports.contains('elevation');
              bool hasVastu = isLegacy ? (isValidData(project['vastu_data']) || isValidData(model['_vastu'])) : selectedReports.contains('vastu');
              bool hasCost = isLegacy ? (isValidData(project['cost_data']) || isValidData(model['_cost'])) : selectedReports.contains('cost') || selectedReports.contains('boq');
              bool hasStructural = isLegacy ? (isValidData(project['structural_data']) || isValidData(model['_structural'])) : selectedReports.contains('structural');

              int totalPrice = isLegacy ? (() {
                int p = 0;
                if (has3D) p += 30;
                if (hasVastu) p += 20;
                if (hasCost) p += 20;
                if (hasStructural) p += 29;
                return p;
              })() : amountPaid.round();
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              displayProjectName, 
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.blue[900])
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Paid: ₹$totalPrice', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text("Created: ${project['created_at']?.toString().split('T')[0] ?? 'N/A'}", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (has3D) _buildBadge(Icons.view_in_ar, '3D View', Colors.blue),
                          if (hasVastu) _buildBadge(Icons.explore, 'Vastu', Colors.orange),
                          if (hasCost) _buildBadge(Icons.calculate, 'Estimation', Colors.purple),
                          if (hasStructural) _buildBadge(Icons.foundation, 'Structural', Colors.redAccent),
                        ],
                      ),
                    ],
                  ),
                )
              ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1, end: 0);
            },
          );
        },
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

}
