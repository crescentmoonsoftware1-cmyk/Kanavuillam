import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';

const _accent = Color(0xFF6366F1);
const _textPri = Color(0xFF0F172A);
const _textSec = Color(0xFF64748B);

// ─── Local Baseline Construction Material Database ───────────────────────────
final List<MaterialBrand> allMaterials = [
  // CEMENT
  MaterialBrand(
      name: 'Priya Cement 53 Grade',
      brand: 'Priya Cements',
      type: 'cement',
      price: 390,
      unit: 'bag',
      location: 'Tamil Nadu',
      icon: Icons.shopping_bag_outlined,
      color: const Color(0xFF8B5CF6)),
  MaterialBrand(
      name: 'UltraTech Premium',
      brand: 'UltraTech',
      type: 'cement',
      price: 440,
      unit: 'bag',
      location: 'All India',
      icon: Icons.shopping_bag_outlined,
      color: const Color(0xFF2563EB)),
  MaterialBrand(
      name: 'ACC Gold Water Shield',
      brand: 'ACC',
      type: 'cement',
      price: 435,
      unit: 'bag',
      location: 'All India',
      icon: Icons.shopping_bag_outlined,
      color: const Color(0xFF059669)),
  MaterialBrand(
      name: 'Ambuja Plus',
      brand: 'Ambuja Cements',
      type: 'cement',
      price: 430,
      unit: 'bag',
      location: 'North India',
      icon: Icons.shopping_bag_outlined,
      color: const Color(0xFFDC2626)),
  MaterialBrand(
      name: 'Ramco Super Grade',
      brand: 'Ramco',
      type: 'cement',
      price: 410,
      unit: 'bag',
      location: 'South India',
      icon: Icons.shopping_bag_outlined,
      color: const Color(0xFF0891B2)),
  MaterialBrand(
      name: 'Dalmia DSP Cement',
      brand: 'Dalmia',
      type: 'cement',
      price: 420,
      unit: 'bag',
      location: 'South India',
      icon: Icons.shopping_bag_outlined,
      color: const Color(0xFF059669)),

  // STEEL
  MaterialBrand(
      name: 'Tata Tiscon 550SD',
      brand: 'Tata Steel',
      type: 'steel',
      price: 88,
      unit: 'kg',
      location: 'Pan India',
      icon: Icons.view_headline_rounded,
      color: const Color(0xFF1E40AF)),
  MaterialBrand(
      name: 'JSW Neosteel 550D',
      brand: 'JSW Steel',
      type: 'steel',
      price: 84,
      unit: 'kg',
      location: 'Pan India',
      icon: Icons.view_headline_rounded,
      color: const Color(0xFF166534)),
  MaterialBrand(
      name: 'SAIL TMT EQR',
      brand: 'SAIL',
      type: 'steel',
      price: 80,
      unit: 'kg',
      location: 'Pan India',
      icon: Icons.view_headline_rounded,
      color: const Color(0xFF991B1B)),
  MaterialBrand(
      name: 'Jindal Panther 550D',
      brand: 'Jindal Steel',
      type: 'steel',
      price: 83,
      unit: 'kg',
      location: 'Pan India',
      icon: Icons.view_headline_rounded,
      color: const Color(0xFF7C3AED)),
  MaterialBrand(
      name: 'Kamachi TMT 550D',
      brand: 'Kamachi Steel',
      type: 'steel',
      price: 76,
      unit: 'kg',
      location: 'Tamil Nadu',
      icon: Icons.view_headline_rounded,
      color: const Color(0xFFB45309)),

  // SAND & AGGREGATES
  MaterialBrand(
      name: 'M-Sand (Manufactured Sand)',
      brand: 'Quarry Direct',
      type: 'sand',
      price: 65,
      unit: 'cft',
      location: 'Tamil Nadu',
      icon: Icons.grain_rounded,
      color: const Color(0xFFD97706)),
  MaterialBrand(
      name: 'P-Sand (Plastering Sand)',
      brand: 'Quarry Direct',
      type: 'sand',
      price: 75,
      unit: 'cft',
      location: 'Tamil Nadu',
      icon: Icons.grain_rounded,
      color: const Color(0xFFB45309)),
  MaterialBrand(
      name: 'River Sand (Govt Verified)',
      brand: 'TN PWD Depot',
      type: 'sand',
      price: 125,
      unit: 'cft',
      location: 'Tamil Nadu',
      icon: Icons.grain_rounded,
      color: const Color(0xFF92400E)),
  MaterialBrand(
      name: '20mm Blue Metal Jelly',
      brand: 'Crusher Direct',
      type: 'aggregate',
      price: 45,
      unit: 'cft',
      location: 'Tamil Nadu',
      icon: Icons.grain_rounded,
      color: const Color(0xFF475569)),

  // BRICKS
  MaterialBrand(
      name: 'Wire-cut Red Bricks',
      brand: 'Chamber Kiln',
      type: 'bricks',
      price: 12.5,
      unit: 'pcs',
      location: 'Tamil Nadu',
      icon: Icons.view_in_ar_rounded,
      color: const Color(0xFFDC2626)),
  MaterialBrand(
      name: 'Country Red Clay Bricks',
      brand: 'Local Kiln',
      type: 'bricks',
      price: 9.5,
      unit: 'pcs',
      location: 'Tamil Nadu',
      icon: Icons.view_in_ar_rounded,
      color: const Color(0xFFB91C1C)),
  MaterialBrand(
      name: 'AAC Lightweight Blocks 6"',
      brand: 'Siporex / Magicrete',
      type: 'bricks',
      price: 65,
      unit: 'pcs',
      location: 'South India',
      icon: Icons.view_in_ar_rounded,
      color: const Color(0xFF64748B)),

  // PAINTS
  MaterialBrand(
      name: 'Asian Paints Royale Luxury',
      brand: 'Asian Paints',
      type: 'paint',
      price: 520,
      unit: 'liter',
      location: 'Pan India',
      icon: Icons.format_paint_rounded,
      color: const Color(0xFF059669)),
  MaterialBrand(
      name: 'Asian Paints Apex WeatherProof',
      brand: 'Asian Paints',
      type: 'paint',
      price: 380,
      unit: 'liter',
      location: 'Pan India',
      icon: Icons.format_paint_rounded,
      color: const Color(0xFF10B981)),
  MaterialBrand(
      name: 'Berger WeatherCoat All Guard',
      brand: 'Berger',
      type: 'paint',
      price: 350,
      unit: 'liter',
      location: 'Pan India',
      icon: Icons.format_paint_rounded,
      color: const Color(0xFF047857)),
  MaterialBrand(
      name: 'Birla White Wall Care Putty',
      brand: 'Birla White',
      type: 'paint',
      price: 28,
      unit: 'kg',
      location: 'Pan India',
      icon: Icons.format_paint_rounded,
      color: const Color(0xFF0284C7)),

  // TILES & GRANITE
  MaterialBrand(
      name: 'Kajaria 2x2 Glazed Vitrified Tiles',
      brand: 'Kajaria',
      type: 'tiles',
      price: 68,
      unit: 'sqft',
      location: 'Pan India',
      icon: Icons.grid_on_rounded,
      color: const Color(0xFF0891B2)),
  MaterialBrand(
      name: 'Somany Polished Vitrified Tiles',
      brand: 'Somany',
      type: 'tiles',
      price: 62,
      unit: 'sqft',
      location: 'Pan India',
      icon: Icons.grid_on_rounded,
      color: const Color(0xFF0E7490)),
  MaterialBrand(
      name: 'Black Galaxy Granite 18mm',
      brand: 'South Indian Granite',
      type: 'tiles',
      price: 180,
      unit: 'sqft',
      location: 'Tamil Nadu',
      icon: Icons.grid_on_rounded,
      color: const Color(0xFF1E293B)),

  // ELECTRICAL
  MaterialBrand(
      name: 'Polycab FR-LSH Copper Wire 1.5mm',
      brand: 'Polycab',
      type: 'electrical',
      price: 1450,
      unit: 'coil',
      location: 'Pan India',
      icon: Icons.electrical_services_rounded,
      color: const Color(0xFFEAB308)),
  MaterialBrand(
      name: 'Finolex Flame Retardant 1.5mm',
      brand: 'Finolex',
      type: 'electrical',
      price: 1480,
      unit: 'coil',
      location: 'Pan India',
      icon: Icons.electrical_services_rounded,
      color: const Color(0xFFCA8A04)),
  MaterialBrand(
      name: 'Legrand Mylinc 6A Modular Switch',
      brand: 'Legrand',
      type: 'electrical',
      price: 85,
      unit: 'pcs',
      location: 'Pan India',
      icon: Icons.electrical_services_rounded,
      color: const Color(0xFFA16207)),

  // PLUMBING
  MaterialBrand(
      name: 'Astral CPVC Pro Pipe 1" SDR 11',
      brand: 'Astral Pipes',
      type: 'plumbing',
      price: 540,
      unit: 'length',
      location: 'Pan India',
      icon: Icons.plumbing_rounded,
      color: const Color(0xFF2563EB)),
  MaterialBrand(
      name: 'Supreme PVC SWR Drainage Pipe 4"',
      brand: 'Supreme Pipes',
      type: 'plumbing',
      price: 680,
      unit: 'length',
      location: 'Pan India',
      icon: Icons.plumbing_rounded,
      color: const Color(0xFF1D4ED8)),
  MaterialBrand(
      name: 'Parryware Floor-Mount Western EWC',
      brand: 'Parryware',
      type: 'plumbing',
      price: 3800,
      unit: 'unit',
      location: 'South India',
      icon: Icons.plumbing_rounded,
      color: const Color(0xFF1E40AF)),

  // DOORS & WINDOWS
  MaterialBrand(
      name: '1st Quality Burma Teak Wood',
      brand: 'TN Timber Depot',
      type: 'doors',
      price: 4800,
      unit: 'cft',
      location: 'Tamil Nadu',
      icon: Icons.door_front_door_outlined,
      color: const Color(0xFF92400E)),
  MaterialBrand(
      name: 'Teak Wood Carved Main Entrance Door',
      brand: 'Custom Carpentry',
      type: 'doors',
      price: 28000,
      unit: 'unit',
      location: 'Tamil Nadu',
      icon: Icons.door_front_door_outlined,
      color: const Color(0xFF78350F)),
  MaterialBrand(
      name: 'UPVC 2-Track Sliding Window',
      brand: 'Fenesta / Kommerling',
      type: 'windows',
      price: 420,
      unit: 'sqft',
      location: 'Pan India',
      icon: Icons.window_outlined,
      color: const Color(0xFF0F766E)),
];

class MaterialBrand {
  final String name, brand, type, unit, location;
  final double price;
  final IconData icon;
  final Color color;
  final bool isLiveResult;

  MaterialBrand({
    required this.name,
    required this.brand,
    required this.type,
    required this.price,
    required this.unit,
    required this.location,
    required this.icon,
    required this.color,
    this.isLiveResult = false,
  });

  String get updatedTime => '🟢 Live Market Price';
  bool get inStock => true;
}

class MaterialSearchWidget extends StatefulWidget {
  final void Function(MaterialBrand brand) onSelected;
  const MaterialSearchWidget({super.key, required this.onSelected});

  @override
  State<MaterialSearchWidget> createState() => _MaterialSearchWidgetState();
}

class _MaterialSearchWidgetState extends State<MaterialSearchWidget> {
  final TextEditingController _textController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  List<MaterialBrand> _liveResults = [];

  List<MaterialBrand> get _filteredMaterials {
    if (_searchQuery.trim().isEmpty) return [];
    final q = _searchQuery.toLowerCase().trim();
    return allMaterials.where((b) {
      return b.name.toLowerCase().contains(q) ||
          b.brand.toLowerCase().contains(q) ||
          b.type.toLowerCase().contains(q);
    }).toList();
  }

  static IconData _getIconForType(String? type) {
    if (type == null) return Icons.construction_rounded;
    switch (type.toLowerCase()) {
      case 'cement':
        return Icons.shopping_bag_outlined;
      case 'steel':
        return Icons.view_headline_rounded;
      case 'sand':
      case 'aggregate':
        return Icons.grain_rounded;
      case 'bricks':
        return Icons.view_in_ar_rounded;
      case 'paint':
        return Icons.format_paint_rounded;
      case 'tiles':
        return Icons.grid_on_rounded;
      case 'electrical':
        return Icons.electrical_services_rounded;
      case 'plumbing':
        return Icons.plumbing_rounded;
      case 'doors':
        return Icons.door_front_door_outlined;
      case 'windows':
        return Icons.window_outlined;
      case 'roofing':
        return Icons.roofing_rounded;
      default:
        return Icons.construction_rounded;
    }
  }

  static Color _getColorForType(String? type) {
    if (type == null) return const Color(0xFF6366F1);
    switch (type.toLowerCase()) {
      case 'cement':
        return const Color(0xFF8B5CF6);
      case 'steel':
        return const Color(0xFF1E40AF);
      case 'sand':
      case 'aggregate':
        return const Color(0xFFD97706);
      case 'bricks':
        return const Color(0xFFDC2626);
      case 'paint':
        return const Color(0xFF059669);
      case 'tiles':
        return const Color(0xFF0891B2);
      case 'electrical':
        return const Color(0xFFEAB308);
      case 'plumbing':
        return const Color(0xFF2563EB);
      case 'doors':
      case 'windows':
        return const Color(0xFF92400E);
      default:
        return const Color(0xFF6366F1);
    }
  }

  void _searchLiveMarket(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
      _liveResults = [];
    });

    try {
      final res = await ApiService().searchMaterial(cleanQuery);
      if (res.isNotEmpty && mounted) {
        final List<MaterialBrand> parsed = [];
        for (var item in res) {
          if (item != null && item['brand'] != null) {
            final String brandName = item['brand'].toString();
            final String rawType = item['type']?.toString() ?? 'custom';
            final double price =
                double.tryParse(item['price']?.toString() ?? '500') ?? 500.0;
            final String unit = item['unit']?.toString() ?? 'unit';
            final String mfg = item['manufacturer']?.toString() ??
                item['source']?.toString() ??
                '🟢 Live Market Rate';
            final String loc =
                item['location']?.toString() ?? 'Tamil Nadu, India';

            parsed.add(MaterialBrand(
              name: brandName,
              brand: mfg,
              type: rawType,
              price: price,
              unit: unit,
              location: loc,
              color: _getColorForType(rawType),
              icon: _getIconForType(rawType),
              isLiveResult: true,
            ));
          }
        }
        setState(() {
          _liveResults = parsed;
        });
      }
    } catch (_) {
      // Backend gracefully handles fallbacks; ignore transient exceptions
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localMatches = _filteredMaterials;
    final hasResults = localMatches.isNotEmpty || _liveResults.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Search materials (e.g. cement, steel, sand, paint...)',
              style: TextStyle(
                color: _textSec,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF059669)),
                  SizedBox(width: 3),
                  Text(
                    'TN Live Market',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Search Input Bar
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _accent.withValues(alpha: 0.18),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.search_rounded, color: _textSec, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _textController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _liveResults = [];
                    });
                  },
                  onSubmitted: (val) => _searchLiveMarket(val),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: _textPri,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type brand or material (e.g. Priya, UltraTech)...',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _textController.clear();
                    setState(() {
                      _searchQuery = '';
                      _liveResults = [];
                    });
                  },
                ),
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.only(right: 14.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accent,
                    ),
                  ),
                )
              else if (_searchQuery.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.search_rounded, size: 14),
                    label: const Text(
                      'Live',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _searchLiveMarket(_searchQuery),
                  ),
                ),
            ],
          ),
        ).animate().fadeIn(delay: 50.ms),

        // Results Container
        if (hasResults) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _accent.withValues(alpha: 0.12),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _liveResults.length + localMatches.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final isLive = index < _liveResults.length;
                final b = isLive
                    ? _liveResults[index]
                    : localMatches[index - _liveResults.length];

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: b.color.withValues(alpha: 0.12),
                    child: Icon(b.icon, color: b.color, size: 20),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.name.toUpperCase(),
                          style: const TextStyle(
                            color: _textPri,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (b.isLiveResult)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${b.brand} • ₹${b.price.toInt()}/${b.unit} (${b.location})',
                    style: const TextStyle(
                      color: _textSec,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      widget.onSelected(b);
                      _textController.clear();
                      setState(() {
                        _searchQuery = '';
                        _liveResults = [];
                      });
                      FocusScope.of(context).unfocus();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ).animate().fadeIn(delay: 100.ms),
        ] else if (_searchQuery.trim().isNotEmpty && !_isSearching) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Column(
                children: [
                  const Text(
                    'No local match found. Search live Tamil Nadu market rates?',
                    style: TextStyle(
                      color: _textSec,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => _searchLiveMarket(_searchQuery),
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: Text('Fetch Live Rates for "$_searchQuery"'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
