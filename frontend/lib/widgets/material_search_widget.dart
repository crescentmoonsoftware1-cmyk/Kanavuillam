import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';

const _accent = Color(0xFF6366F1);
const _textPri = Color(0xFF0F172A);
const _textSec = Color(0xFF64748B);
const _bg = Color(0xFFF4F7FB);

// ─── Full Material Database ──────────────────────────────────────────────────
final List<MaterialBrand> allMaterials = [
  // CEMENT
  MaterialBrand(name: 'Priya Cement 53 Grade', brand: 'Priya Cements', type: 'cement', price: 390, unit: 'bag', location: 'Tamil Nadu', icon: Icons.shopping_bag, color: const Color(0xFF8B5CF6)),
  MaterialBrand(name: 'UltraTech Premium', brand: 'UltraTech', type: 'cement', price: 450, unit: 'bag', location: 'All India', icon: Icons.shopping_bag, color: const Color(0xFF2563EB)),
  MaterialBrand(name: 'ACC Gold Water Shield', brand: 'ACC', type: 'cement', price: 440, unit: 'bag', location: 'All India', icon: Icons.shopping_bag, color: const Color(0xFF059669)),
  MaterialBrand(name: 'Ambuja Plus', brand: 'Ambuja Cements', type: 'cement', price: 430, unit: 'bag', location: 'North India', icon: Icons.shopping_bag, color: const Color(0xFFDC2626)),
  MaterialBrand(name: 'Ramco Super Grade', brand: 'Ramco', type: 'cement', price: 410, unit: 'bag', location: 'South India', icon: Icons.shopping_bag, color: const Color(0xFF0891B2)),
  MaterialBrand(name: 'Dalmia', brand: 'Dalmia', type: 'cement', price: 400, unit: 'bag', location: 'South India', icon: Icons.shopping_bag, color: Color.fromARGB(255, 8, 178, 152)),

  // STEEL
  MaterialBrand(name: 'Tata Tiscon 550SD', brand: 'Tata Steel', type: 'steel', price: 88, unit: 'kg', location: 'Pan India', icon: Icons.view_headline, color: const Color(0xFF1E40AF)),
  MaterialBrand(name: 'JSW Neosteel 550D', brand: 'JSW Steel', type: 'steel', price: 85, unit: 'kg', location: 'Pan India', icon: Icons.view_headline, color: const Color(0xFF166534)),
  MaterialBrand(name: 'SAIL TMT', brand: 'SAIL', type: 'steel', price: 82, unit: 'kg', location: 'Pan India', icon: Icons.view_headline, color: const Color(0xFF991B1B)),
  MaterialBrand(name: 'Jindal Panther', brand: 'Jindal Steel', type: 'steel', price: 84, unit: 'kg', location: 'Pan India', icon: Icons.view_headline, color: const Color(0xFF1E3A5F)),

  // SAND
  MaterialBrand(name: 'River Sand', brand: 'Local Supplier', type: 'sand', price: 110, unit: 'cft', location: 'Chennai, TN', icon: Icons.landscape, color: const Color(0xFFB45309)),
  MaterialBrand(name: 'M-Sand (Washed)', brand: 'M-Sand Supplier', type: 'sand', price: 75, unit: 'cft', location: 'South India', icon: Icons.landscape, color: const Color(0xFFB45309)),
  MaterialBrand(name: 'P-Sand Plastering', brand: 'P-Sand Supplier', type: 'sand', price: 85, unit: 'cft', location: 'South India', icon: Icons.landscape, color: const Color(0xFFB45309)),
  MaterialBrand(name: '20mm Blue Metal', brand: 'Quarry Supplier', type: 'sand', price: 65, unit: 'cft', location: 'Chennai, TN', icon: Icons.landscape, color: const Color(0xFF475569)),
  MaterialBrand(name: 'Desert Sand', brand: 'Desert Supplier', type: 'sand', price: 150, unit: 'cft', location: 'Rajasthan', icon: Icons.landscape, color: const Color(0xFFB45309)),

  // BRICKS
  MaterialBrand(name: 'First Class Red Bricks', brand: 'Local Kiln', type: 'bricks', price: 12, unit: 'pcs', location: 'Local', icon: Icons.apps, color: const Color(0xFFB91C1C)),
  MaterialBrand(name: 'AAC Blocks (Aerocon)', brand: 'Aerocon', type: 'bricks', price: 65, unit: 'pcs', location: 'Pan India', icon: Icons.apps, color: const Color(0xFF0369A1)),
  MaterialBrand(name: 'Fly Ash Bricks', brand: 'Fly Ash India', type: 'bricks', price: 8, unit: 'pcs', location: 'Pan India', icon: Icons.apps, color: const Color(0xFF6B7280)),
  MaterialBrand(name: 'Porotherm Blocks', brand: 'Wienerberger', type: 'bricks', price: 85, unit: 'pcs', location: 'Pan India', icon: Icons.apps, color: const Color(0xFFD97706)),

  // TILES
  MaterialBrand(name: 'Kajaria Vitrified', brand: 'Kajaria', type: 'tiles', price: 65, unit: 'sqft', location: 'Pan India', icon: Icons.grid_on, color: const Color(0xFF7C3AED)),
  MaterialBrand(name: 'Somany Ceramics', brand: 'Somany', type: 'tiles', price: 60, unit: 'sqft', location: 'Pan India', icon: Icons.grid_on, color: const Color(0xFF0891B2)),
  MaterialBrand(name: 'Italian Marble', brand: 'Imported', type: 'tiles', price: 350, unit: 'sqft', location: 'Mumbai', icon: Icons.grid_on, color: const Color(0xFF6366F1)),
  MaterialBrand(name: 'RAK Ceramics', brand: 'RAK', type: 'tiles', price: 85, unit: 'sqft', location: 'Pan India', icon: Icons.grid_on, color: const Color(0xFF059669)),

  // PAINT
  MaterialBrand(name: 'Asian Paints Royale', brand: 'Asian Paints', type: 'paint', price: 320, unit: 'liter', location: 'Pan India', icon: Icons.format_paint, color: const Color(0xFFDC2626)),
  MaterialBrand(name: 'Berger WeatherCoat', brand: 'Berger Paints', type: 'paint', price: 280, unit: 'liter', location: 'Pan India', icon: Icons.format_paint, color: const Color(0xFF0284C7)),
  MaterialBrand(name: 'Dulux Velvet Touch', brand: 'Dulux', type: 'paint', price: 340, unit: 'liter', location: 'Pan India', icon: Icons.format_paint, color: const Color(0xFF7C3AED)),
  MaterialBrand(name: 'Nerolac Impressions', brand: 'Nerolac', type: 'paint', price: 300, unit: 'liter', location: 'Pan India', icon: Icons.format_paint, color: const Color(0xFF059669)),

  // ELECTRICAL
  MaterialBrand(name: 'Havells Wires 1.5mm', brand: 'Havells', type: 'electrical', price: 1500, unit: 'coil', location: 'Pan India', icon: Icons.electrical_services, color: const Color(0xFFDC2626)),
  MaterialBrand(name: 'Polycab Wires', brand: 'Polycab', type: 'electrical', price: 1350, unit: 'coil', location: 'Pan India', icon: Icons.electrical_services, color: const Color(0xFF0284C7)),
  MaterialBrand(name: 'Finolex Cables', brand: 'Finolex', type: 'electrical', price: 1400, unit: 'coil', location: 'Pan India', icon: Icons.electrical_services, color: const Color(0xFF059669)),
  MaterialBrand(name: 'Legrand Switches', brand: 'Legrand', type: 'electrical', price: 250, unit: 'pcs', location: 'Pan India', icon: Icons.electrical_services, color: const Color(0xFF6366F1)),

  // PLUMBING
  MaterialBrand(name: 'Astral CPVC Pipes', brand: 'Astral', type: 'plumbing', price: 550, unit: 'length', location: 'Pan India', icon: Icons.plumbing, color: const Color(0xFF0369A1)),
  MaterialBrand(name: 'Ashirvad CPVC Pipes', brand: 'Ashirvad', type: 'plumbing', price: 580, unit: 'length', location: 'Pan India', icon: Icons.plumbing, color: const Color(0xFF059669)),
  MaterialBrand(name: 'Supreme PVC Pipes', brand: 'Supreme', type: 'plumbing', price: 450, unit: 'length', location: 'Pan India', icon: Icons.plumbing, color: const Color(0xFF7C3AED)),
  MaterialBrand(name: 'Jaquar Faucets', brand: 'Jaquar', type: 'plumbing', price: 3500, unit: 'unit', location: 'Pan India', icon: Icons.plumbing, color: const Color(0xFF92400E)),
];

class MaterialBrand {
  final String name, brand, type, unit, location;
  final double price;
  final IconData icon;
  final Color color;

  MaterialBrand({
    required this.name,
    required this.brand,
    required this.type,
    required this.price,
    required this.unit,
    required this.location,
    required this.icon,
    required this.color,
  });

  String get updatedTime {
    
    return 'Updated  min ago';
  }

  bool get inStock => name.hashCode.abs() % 5 != 0;
}

class MaterialSearchWidget extends StatefulWidget {
  final void Function(MaterialBrand brand) onSelected;
  const MaterialSearchWidget({super.key, required this.onSelected});

  @override
  State<MaterialSearchWidget> createState() => _MaterialSearchWidgetState();
}

class _MaterialSearchWidgetState extends State<MaterialSearchWidget> {
  String _searchQuery = '';
  bool _isSearching = false;
  List<MaterialBrand> _aiResults = [];

  List<MaterialBrand> get _filteredMaterials {
    if (_searchQuery.isEmpty) return [];
    return allMaterials.where((b) {
      return b.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.brand.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.type.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _searchAI(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _aiResults = [];
    });
    try {
      final res = await ApiService().searchMaterial(query);
      if (res.isNotEmpty) {
        setState(() {
          for (var item in res) {
            if (item['brand'] != null) {
              _aiResults.add(MaterialBrand(
                name: item['brand'].toString(),
                brand: 'AI Matched',
                price: double.tryParse(item['price']?.toString() ?? '500') ?? 500.0,
                unit: item['unit'] ?? 'unit',
                type: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                location: 'India',
                color: const Color(0xFF8B5CF6),
                icon: Icons.auto_awesome,
              ));
            }
          }
        });
      }
    } catch (e) {
      // Ignore errors for now
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredMaterials;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Search materials (e.g. cement, steel, sand, paint...)',
          style: TextStyle(
              color: _textSec, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accent.withValues(alpha: 0.1), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: _accent.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.search_rounded, color: _textSec, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _aiResults = []; // Clear AI result on new type
                    });
                  },
                  onSubmitted: (val) => _searchAI(val),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPri),
                  decoration: const InputDecoration(
                    hintText: 'Type to search material... (Press Enter for AI Search)',
                    hintStyle: TextStyle(
                        color: Color(0xFFCBD5E1), fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _accent)),
                ),
            ],
          ),
        ).animate().fadeIn(delay: 50.ms),
        
        if (results.isNotEmpty || _aiResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withValues(alpha: 0.1), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: results.length + _aiResults.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF4F7FB)),
              itemBuilder: (context, index) {
                final b = index < _aiResults.length ? _aiResults[index] : results[index - _aiResults.length];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: b.color.withValues(alpha: 0.1),
                    child: Icon(b.icon, color: b.color, size: 20),
                  ),
                  title: Text(b.name.toUpperCase(), style: const TextStyle(color: _textPri, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${b.brand} • ₹${b.price}/${b.unit}', style: const TextStyle(color: _textSec, fontSize: 12)),
                  trailing: OutlinedButton(
                    onPressed: () {
                      widget.onSelected(b);
                      setState(() {
                        _searchQuery = '';
                      });
                      FocusScope.of(context).unfocus();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Add', style: TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ).animate().fadeIn(delay: 100.ms),
        ] else if (_searchQuery.isNotEmpty && !_isSearching) ...[
           Padding(
             padding: const EdgeInsets.all(16.0),
             child: Column(
               children: [
                 const Text('No local material found.', style: TextStyle(color: _textSec)),
                 const SizedBox(height: 8),
                 ElevatedButton.icon(
                   onPressed: () => _searchAI(_searchQuery),
                   icon: const Icon(Icons.auto_awesome, size: 16),
                   label: const Text('Search Market Prices with AI'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: const Color(0xFF8B5CF6),
                     foregroundColor: Colors.white,
                     elevation: 0,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                   ),
                 ),
               ],
             ),
           )
        ]
      ],
    );
  }
}
