import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/material_search_widget.dart';

const _bg = Color(0xFFF4F7FB);
const _surface = Colors.white;
const _accent = Color(0xFF6366F1); // Indigo
const _textPri = Color(0xFF0F172A);
const _textSec = Color(0xFF64748B);
const _success = Color(0xFF10B981);



class EstimationScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  const EstimationScreen({super.key, required this.projectData});

  @override
  State<EstimationScreen> createState() => _EstimationScreenState();
}

class _EstimationScreenState extends State<EstimationScreen> {
  String _selectedFloor = 'total';
  final Map<String, double> _customMaterialPrices = {};
  final Map<String, String> _customMaterialBrands = {};
  final Map<String, MaterialBrand> _customBrandsObjects = {};

  void _onBrandSelected(MaterialBrand brand) {
    setState(() {
      _customMaterialPrices[brand.type] = brand.price;
      _customMaterialBrands[brand.type] = brand.name;
      _customBrandsObjects[brand.type] = brand;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF6366F1),
      content: Text('✓ Applied ${brand.name} — ₹${brand.price}/${brand.unit}'),
    ));
  }



  @override
  Widget build(BuildContext context) {
    final rootCost = widget.projectData['cost_data'] as Map<String, dynamic>? ?? {};
    final bool isMultiFloor = rootCost.containsKey('first') || rootCost.containsKey('total');
    if (!rootCost.containsKey(_selectedFloor) && rootCost.isNotEmpty) _selectedFloor = rootCost.keys.first;

    final cost = isMultiFloor ? (rootCost[_selectedFloor] as Map<String, dynamic>? ?? {}) : rootCost;
    final totalArea = cost['total_area_sqft'] ?? 0;
    final materials = cost['materials'] as Map<String, dynamic>? ?? {};

    double materialCostDiff = 0;
    Map<String, dynamic> updatedMaterials = {};
    materials.forEach((key, val) {
      final v = Map<String, dynamic>.from(val);
      if (_customMaterialPrices.containsKey(key)) {
        double oldPrice = (v['price'] as num).toDouble();
        double newPrice = _customMaterialPrices[key]!;
        double qty = (v['quantity'] as num).toDouble();
        materialCostDiff += (newPrice - oldPrice) * qty;
        v['price'] = newPrice;
      }
      updatedMaterials[key] = v;
    });

    _customBrandsObjects.forEach((key, brand) {
      if (!materials.containsKey(key)) {
        updatedMaterials[key] = {
           'name': brand.name,
           'quantity': 1,
           'price': brand.price,
           'unit': brand.unit,
           'is_new_custom': true,
           'custom_brand': brand,
        };
        materialCostDiff += brand.price * 1;
      }
    });

    final estimates = Map<String, dynamic>.from(cost['estimates'] as Map<String, dynamic>? ?? {});
    if (materialCostDiff != 0) {
      estimates['basic'] = ((estimates['basic'] as num?) ?? 0) + materialCostDiff;
      estimates['standard'] = ((estimates['standard'] as num?) ?? 0) + materialCostDiff;
      estimates['premium'] = ((estimates['premium'] as num?) ?? 0) + materialCostDiff;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: isDesktop 
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 // Left Column
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isMultiFloor, rootCost, totalArea),
                      const SizedBox(height: 24),
                      _buildTierCards(estimates),
                      const SizedBox(height: 36),
                      _buildSearchSection(),
                      const SizedBox(height: 20),
                      _buildMaterialList(updatedMaterials),
                    ],
                  ),
                ),
                const SizedBox(width: 40),
                // Right Column
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFloorTable(rootCost),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMultiFloor, rootCost, totalArea),
                const SizedBox(height: 24),
                _buildTierCards(estimates),
                const SizedBox(height: 36),
                _buildSearchSection(),
                const SizedBox(height: 20),
                _buildMaterialList(updatedMaterials),
                const SizedBox(height: 36),
                _buildFloorTable(rootCost),
              ],
            ),
      ),
    );
  }

  Widget _buildHeader(bool isMultiFloor, Map rootCost, dynamic totalArea) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cost Estimation',
                style: TextStyle(color: _textPri, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0),
              ).animate().fadeIn(),
              const SizedBox(height: 8),
              Text(
                'Total area: $totalArea sq ft  ·  2026 Live Rates',
                style: const TextStyle(color: _textSec, fontSize: 14, fontWeight: FontWeight.w600),
              ).animate().fadeIn(delay: 80.ms),
            ]
          ),
        ),
        if (isMultiFloor) const SizedBox(width: 16),
        if (isMultiFloor)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              border: Border.all(color: _accent.withValues(alpha: 0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFloor,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: _accent),
                style: const TextStyle(color: _accent, fontSize: 14, fontWeight: FontWeight.w800),
                items: rootCost.keys.map<DropdownMenuItem<String>>((k) => DropdownMenuItem<String>(value: k.toString(), child: Text(k.toString().toUpperCase()))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() { _selectedFloor = val; });
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTierCards(Map estimates) {
    return Row(
      children: [
        _TierCard(label: 'BASIC', amount: estimates['basic'], colors: const [Color(0xFF64748B), Color(0xFF475569)]),
        const SizedBox(width: 16),
        _TierCard(label: 'STANDARD', amount: estimates['standard'], colors: const [Color(0xFF3B82F6), Color(0xFF2563EB)], isFeatured: true),
        const SizedBox(width: 16),
        _TierCard(label: 'PREMIUM', amount: estimates['premium'], colors: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
      ],
    );
  }

  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Materials & Live Market Search',
          style: TextStyle(color: _textPri, fontSize: 28, fontWeight: FontWeight.w900),
        ).animate().fadeIn(),
        const SizedBox(height: 6),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        MaterialSearchWidget(onSelected: _onBrandSelected),
      ],
    );
  }



  Widget _buildMaterialList(Map<String, dynamic> updatedMaterials) {
    if (updatedMaterials.isEmpty) return const SizedBox.shrink();

    String _formatIndianCurrency(int value) {
      String str = value.toString();
      if (str.length <= 3) return str;
      String lastThree = str.substring(str.length - 3);
      String otherNumbers = str.substring(0, str.length - 3);
      if (otherNumbers.isNotEmpty) {
        otherNumbers = otherNumbers.replaceAllMapped(RegExp(r".{1,2}(?=(.{2})+(?!.))"), (Match m) => "${m[0]},");
        return "$otherNumbers,$lastThree";
      }
      return lastThree;
    }

    return Column(
      children: updatedMaterials.entries.map((e) {
        final m = e.value;
        final t = ((m['quantity'] as num) * (m['price'] as num)).toInt();
        final isCustom = _customMaterialPrices.containsKey(e.key);
        final customBrandName = _customMaterialBrands[e.key];
        final isNewCustom = m['is_new_custom'] == true;
        final MaterialBrand? customBrandObj = isNewCustom ? m['custom_brand'] as MaterialBrand : null;
        
        IconData icon = Icons.inventory_2;
        if (isNewCustom && customBrandObj != null) {
          icon = customBrandObj.icon;
        } else {
          if (e.key == 'cement') icon = Icons.shopping_bag;
          if (e.key == 'steel') icon = Icons.view_headline;
          if (e.key == 'sand') icon = Icons.landscape;
          if (e.key == 'paint') icon = Icons.format_paint;
          if (e.key == 'tiles') icon = Icons.grid_on;
          if (e.key == 'bricks') icon = Icons.view_comfy;
        }

        String displayName = isNewCustom 
            ? '$customBrandName' 
            : (isCustom ? '${m['name']} ($customBrandName)' : m['name']);
            
        if (displayName.isNotEmpty) {
          displayName = displayName[0].toUpperCase() + displayName.substring(1);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isCustom ? Border.all(color: _accent.withValues(alpha: 0.3), width: 1.5) : Border.all(color: Colors.transparent, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: isCustom ? const Color(0xFFEEF2FF) : _bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: isCustom ? _accent : _textSec, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total $displayName Cost',
                      style: TextStyle(color: isCustom ? _accent : _textPri, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'For your 2D Plan: ${m['quantity']} ${m['unit']} @ ₹${m['price']}/${m['unit']}',
                      style: const TextStyle(color: _textSec, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '₹${_formatIndianCurrency(t)}',
                  style: const TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ).animate().fadeIn().slideX(begin: 0.05, end: 0);
      }).toList(),
    );
  }



  Widget _buildFloorTable(Map rootCost) {
    final g = rootCost['ground'] ?? {};
    final f = rootCost['first'] ?? {};
    final t = rootCost['total'] ?? {};

    String gm(String k) => g['materials']?[k]?['quantity']?.toString() ?? '-';
    String fm(String k) => f['materials']?[k]?['quantity']?.toString() ?? '-';
    String tm(String k) => t['materials']?[k]?['quantity']?.toString() ?? '-';

    double getEst(Map floor) {
      if (floor.isEmpty || floor['estimates']?['basic'] == null) return 0;
      double diff = 0;
      final mats = floor['materials'] as Map<String, dynamic>? ?? {};
      mats.forEach((k, v) {
        if (_customMaterialPrices.containsKey(k)) {
          double old = (v['price'] as num).toDouble();
          double next = _customMaterialPrices[k]!;
          double q = (v['quantity'] as num).toDouble();
          diff += (next - old) * q;
        }
      });
      _customBrandsObjects.forEach((key, brand) {
        if (!mats.containsKey(key)) {
          diff += brand.price * 1;
        }
      });
      return ((floor['estimates']['basic'] as num) + diff).toDouble();
    }

    String fmt(double val) => val == 0 ? '-' : '₹${(val/100000).toStringAsFixed(2)}L';

    String ge() => fmt(getEst(g));
    String fe() => fmt(getEst(f));
    String te() => fmt(getEst(t));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Floor Wise Estimation',
          style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w900),
        ).animate().fadeIn(),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _selectedFloor = 'ground'),
                      child: _tableTab('Ground Floor', _selectedFloor == 'ground'),
                    ),
                    const SizedBox(width: 8),
                    if (f.isNotEmpty) ...[
                      InkWell(
                        onTap: () => setState(() => _selectedFloor = 'first'),
                        child: _tableTab('First Floor', _selectedFloor == 'first'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    InkWell(
                      onTap: () => setState(() => _selectedFloor = 'total'),
                      child: _tableTab('Total Project', _selectedFloor == 'total'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _bg),
              _buildTableRow('Description', 'Ground Floor', 'First Floor', 'Total', isHeader: true),
              _buildTableRow('Built-up Area (sq ft)', g['total_area_sqft']?.toString() ?? '-', f['total_area_sqft']?.toString() ?? '-', t['total_area_sqft']?.toString() ?? '-'),
              _buildTableRow('Cement (Bags)', gm('cement'), fm('cement'), tm('cement')),
              _buildTableRow('Steel (KG)', gm('steel'), fm('steel'), tm('steel')),
              _buildTableRow('Sand (CFT)', gm('sand'), fm('sand'), tm('sand')),
              _buildTableRow('Bricks (Nos)', gm('bricks'), fm('bricks'), tm('bricks')),
              _buildTableRow('Tiles (Sq ft)', gm('tiles'), fm('tiles'), tm('tiles')),
              Container(
                decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
                child: _buildTableRow('Total Estimated Cost', ge(), fe(), te(), isBold: true, color: _accent),
              )
            ],
          ),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Widget _tableTab(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? _accent : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: active ? null : Border.all(color: _bg, width: 2)
      ),
      child: Text(label, style: TextStyle(color: active ? Colors.white : _textSec, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTableRow(String col1, String col2, String col3, String col4, {bool isHeader = false, bool isBold = false, Color? color}) {
    final style = TextStyle(
      color: color ?? (isHeader ? _textSec : _textPri),
      fontSize: isHeader ? 12 : 14,
      fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.w500,
    );
    String displayValue = col4;
    if (_selectedFloor == 'ground') displayValue = col2;
    if (_selectedFloor == 'first') displayValue = col3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 3, child: Text(col1, style: style)),
          Expanded(flex: 2, child: Text(displayValue, style: style.copyWith(fontWeight: isHeader ? FontWeight.bold : FontWeight.w900), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final String label;
  final dynamic amount;
  final List<Color> colors;
  final bool isFeatured;

  const _TierCard({required this.label, required this.amount, required this.colors, this.isFeatured = false});

  @override
  Widget build(BuildContext context) {
    final val = (amount as num?)?.toInt() ?? 0;
    String formatted = '₹$val';
    if (val >= 10000000) {
      formatted = '₹${(val / 10000000).toStringAsFixed(2)}Cr';
    } else if (val >= 100000) formatted = '₹${(val / 100000).toStringAsFixed(1)}L';

    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isFeatured ? 32 : 24, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.3), blurRadius: isFeatured ? 20 : 10, offset: Offset(0, isFeatured ? 10 : 4))],
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(formatted, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }
}
