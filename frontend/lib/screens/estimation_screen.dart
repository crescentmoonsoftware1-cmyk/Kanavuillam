import 'package:flutter/material.dart';
import '../widgets/material_search_widget.dart';
import '../services/api_service.dart';

const _bg = Color(0xFFF1F5F9);
const _primary = Color(0xFF0F172A); // Dark Slate/Navy
const _accent = Color(0xFF6366F1); // Indigo Accent
const _accentLight = Color(0xFFEEF2FF);
const _textPri = Color(0xFF0F172A);
const _textSec = Color(0xFF64748B);
const _success = Color(0xFF10B981);
const _warning = Color(0xFFF59E0B);
const _purple = Color(0xFF8B5CF6);
const _rose = Color(0xFFF43F5E);
const _cyan = Color(0xFF06B6D4);

class EstimationScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  const EstimationScreen({super.key, required this.projectData});

  @override
  State<EstimationScreen> createState() => _EstimationScreenState();
}

class _EstimationScreenState extends State<EstimationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Active State Selection
  String _selectedFloor = 'total';
  String _selectedTier = 'standard'; // 'basic', 'standard', 'premium'
  String _selectedContractMode = 'turnkey'; // 'turnkey', 'labor', 'self'
  String _selectedLocation = 'tier2'; // 'metro', 'tier2', 'rural'
  String _selectedSoil = 'normal'; // 'normal', 'soft_silt', 'hard_rock'

  // Live Market State
  bool _isFetchingLiveMarket = false;
  String _marketLocation = 'Tamil Nadu Live Market';

  // Custom user overrides
  final Map<String, double> _customMaterialPrices = {};
  final Map<String, double> _customMaterialQty = {};
  final Map<String, String> _customMaterialBrands = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchLiveMarketPrices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveMarketPrices() async {
    setState(() => _isFetchingLiveMarket = true);
    try {
      final liveData =
          await ApiService().getLiveMarketPrices(location: _marketLocation);
      if (liveData.containsKey('materials') && liveData['materials'] is Map) {
        if (mounted) {
          setState(() {
            if (liveData['location'] != null) {
              _marketLocation = liveData['location'].toString();
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content:
                const Text('✓ Live market material rates updated successfully!'),
          ));
        }
      }
    } catch (e) {
      debugPrint('[EstimationScreen] Live market fetch notice: $e');
    } finally {
      if (mounted) setState(() => _isFetchingLiveMarket = false);
    }
  }

  // Baseline Rates (2026 Tamil Nadu & Indian Construction)
  static const Map<String, double> _tierSqftRates = {
    'basic': 1750.0,
    'standard': 2250.0,
    'premium': 3350.0,
  };

  // Multipliers
  double get _locationMultiplier {
    if (_selectedLocation == 'metro') return 1.10; // Chennai Metro +10%
    if (_selectedLocation == 'rural') return 0.95; // Rural -5%
    return 1.0; // Tier 2 Towns
  }

  double get _soilMultiplier {
    if (_selectedSoil == 'soft_silt') return 1.12; // Pile Foundation +12%
    if (_selectedSoil == 'hard_rock') return 1.08; // Rock Breaker +8%
    return 1.0; // Normal Red Clay
  }

  double get _contractMultiplier {
    if (_selectedContractMode == 'labor') return 0.40; // Labor Only ~40%
    if (_selectedContractMode == 'self') return 0.88; // Self Build saves 12%
    return 1.0; // Turnkey
  }

  final List<MaterialBrand> _addedCustomMaterials = [];

  void _onBrandSelected(MaterialBrand brand) {
    setState(() {
      _customMaterialPrices[brand.type] = brand.price;
      _customMaterialBrands[brand.type] = brand.name;

      if (_materialBrands.containsKey(brand.type)) {
        final list = _materialBrands[brand.type]!;
        if (!list.any((b) => b['name'] == brand.name)) {
          list.add({'name': brand.name, 'price': brand.price, 'unit': brand.unit});
        }
      } else {
        if (!_addedCustomMaterials.any((b) => b.name == brand.name)) {
          _addedCustomMaterials.add(brand);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: Text(
          '✓ Added ${brand.name} (₹${brand.price.toInt()}/${brand.unit}) to estimation cost!'),
    ));
  }

  void _resetCustomizations() {
    setState(() {
      _customMaterialPrices.clear();
      _customMaterialQty.clear();
      _customMaterialBrands.clear();
      _addedCustomMaterials.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _textPri,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: const Text('Reset material prices to baseline market rates.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final rootCost =
        widget.projectData['cost_data'] as Map<String, dynamic>? ?? {};
    final bool isMultiFloor =
        rootCost.containsKey('first') || rootCost.containsKey('total');
    if (!rootCost.containsKey(_selectedFloor) && rootCost.isNotEmpty) {
      _selectedFloor = rootCost.keys.first;
    }

    final costMap = isMultiFloor
        ? (rootCost[_selectedFloor] as Map<String, dynamic>? ?? {})
        : rootCost;

    // Total area calculation
    double totalArea = (costMap['total_area_sqft'] as num?)?.toDouble() ??
        (widget.projectData['cost_data']?['total_area_sqft'] as num?)
            ?.toDouble() ??
        (widget.projectData['total_area_sqft'] as num?)?.toDouble() ??
        0.0;

    if (totalArea <= 0) {
      final modelData =
          widget.projectData['model_data'] as Map<String, dynamic>?;
      final overallDims = (modelData?['overall_dimensions']
              as Map<String, dynamic>?) ??
          (widget.projectData['overall_dimensions'] as Map<String, dynamic>?);
      final w = (overallDims?['width_ft'] as num?)?.toDouble() ??
          (modelData?['project']?['width'] as num?)?.toDouble() ??
          0.0;
      final l = (overallDims?['length_ft'] as num?)?.toDouble() ??
          (modelData?['project']?['height'] as num?)?.toDouble() ??
          0.0;
      if (w > 0 && l > 0) totalArea = w * l;
    }
    if (totalArea <= 0) totalArea = 1200.0; // Realistic Default Ground Plan

    // Calculated base rate per sqft with multipliers
    double baseRate = (_tierSqftRates[_selectedTier] ?? 2250.0) *
        _locationMultiplier *
        _soilMultiplier *
        _contractMultiplier;

    // Base estimated quantities for totalArea
    final Map<String, double> baseQuantities = {
      'cement': (totalArea * 0.40).roundToDouble(),
      'steel': (totalArea * 3.8).roundToDouble(),
      'sand': (totalArea * 1.7).roundToDouble(),
      'aggregate': (totalArea * 1.2).roundToDouble(),
      'bricks': (totalArea * 16.0).roundToDouble(),
      'tiles': (totalArea * 1.05).roundToDouble(),
      'paint': (totalArea * 0.12).roundToDouble(),
      'electrical': totalArea,
      'plumbing': totalArea,
    };

    // Calculate baseline vs custom material brand price difference
    double customMaterialAdjustment = 0.0;
    _customMaterialPrices.forEach((key, customPrice) {
      final defaultBrands = _materialBrands[key];
      if (defaultBrands != null && defaultBrands.isNotEmpty) {
        double defaultPrice = (defaultBrands.first['price'] as num).toDouble();
        double qty = _customMaterialQty[key] ?? baseQuantities[key] ?? (totalArea * 0.5);
        customMaterialAdjustment += (customPrice - defaultPrice) * qty;
      }
    });

    // Add cost of newly added custom materials that are not in standard categories
    double addedCustomMaterialsCost = 0.0;
    for (var customItem in _addedCustomMaterials) {
      if (!_materialBrands.containsKey(customItem.type)) {
        double price = _customMaterialPrices[customItem.type] ?? customItem.price;
        double qty = _customMaterialQty[customItem.type] ?? 1.0;
        addedCustomMaterialsCost += price * qty;
      }
    }

    double calculatedTotal = totalArea * baseRate + customMaterialAdjustment + addedCustomMaterialsCost;
    double effectivePerSqft = calculatedTotal / totalArea;
    double materialCost = calculatedTotal * 0.62;
    double laborCost = calculatedTotal * 0.38;

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Container(
      color: _bg,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // 🌟 Executive Dark Hero Header
            _buildExecutiveHeroHeader(
                totalArea, calculatedTotal, effectivePerSqft, isMultiFloor, rootCost),

            // 🌟 Control Bar (Contract Mode, Location & Soil Calibrator)
            _buildCalibratorControlBar(),

            // 🌟 Navigation Tab Bar (4 Tabs)
            _buildTabBar(),

            // 🌟 Main Dynamic Tab View Body
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildSelectedTabContent(
                    totalArea, calculatedTotal, materialCost, laborCost, isDesktop),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. Executive Dark Hero Header ──────────────────────────────────────────
  Widget _buildExecutiveHeroHeader(double totalArea, double totalCost,
      double perSqft, bool isMultiFloor, Map rootCost) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges Row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.amber, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Professional Civil Engineer BOQ',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _fetchLiveMarketPrices,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _success.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isFetchingLiveMarket
                            ? Icons.sync_rounded
                            : Icons.sensors_rounded,
                        color: _success,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isFetchingLiveMarket
                            ? 'Syncing Live Market...'
                            : 'Live TN Market Rates',
                        style: const TextStyle(
                            color: _success,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Estimated Budget Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 650;
              return isSmall
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimated Construction Budget',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${_formatIndianCurrency(totalCost.round())}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '₹${perSqft.round()} / sq.ft · ${totalArea.toInt()} Sq.Ft Area',
                            style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Executive Cost Estimation & BOQ',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${_formatIndianCurrency(totalCost.round())}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${perSqft.round()} / sq.ft',
                                style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${totalArea.toInt()} Sq.Ft Calibrated Area',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  // ── 2. Calibrator Control Bar (Contract, Location, Soil) ───────────────────
  Widget _buildCalibratorControlBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              const Text(
                'Construction Factors & Cost Calibrator',
                style: TextStyle(
                    color: _textPri, fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Contract Mode Chip Selector
                  _buildDropdownChip(
                    icon: Icons.assignment_rounded,
                    label: 'Contract',
                    value: _selectedContractMode,
                    items: const {
                      'turnkey': 'Turnkey (Material + Labor)',
                      'labor': 'Labor Contract Only',
                      'self': 'Direct Procurement (Self Build)',
                    },
                    onChanged: (val) =>
                        setState(() => _selectedContractMode = val!),
                  ),

                  // Location Selector
                  _buildDropdownChip(
                    icon: Icons.location_city_rounded,
                    label: 'Location',
                    value: _selectedLocation,
                    items: const {
                      'metro': 'Chennai / Metro (+10%)',
                      'tier2': 'Tier 2 Town / District (Std)',
                      'rural': 'Rural / Village (-5%)',
                    },
                    onChanged: (val) =>
                        setState(() => _selectedLocation = val!),
                  ),

                  // Soil Condition Selector
                  _buildDropdownChip(
                    icon: Icons.landscape_rounded,
                    label: 'Soil Type',
                    value: _selectedSoil,
                    items: const {
                      'normal': 'Normal Clay / Red Soil',
                      'soft_silt': 'Soft Silt / Black Cotton (+12% Pile)',
                      'hard_rock': 'Hard Rock / Hilly (+8%)',
                    },
                    onChanged: (val) => setState(() => _selectedSoil = val!),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  Widget _buildDropdownChip({
    required IconData icon,
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: _accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _accent, size: 15),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
                color: _textSec, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 6,
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: _accent, size: 16),
              style: const TextStyle(
                  color: _primary, fontSize: 11, fontWeight: FontWeight.w800),
              items: items.entries.map((e) {
                return DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(
                    e.value,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Navigation Tab Bar ──────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: _accent,
        indicatorWeight: 3,
        labelColor: _accent,
        unselectedLabelColor: _textSec,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(
              icon: Icon(Icons.dashboard_rounded, size: 18),
              text: 'Overview & Tiers'),
          Tab(
              icon: Icon(Icons.table_chart_rounded, size: 18),
              text: 'Detailed BOQ Table'),
          Tab(
              icon: Icon(Icons.tune_rounded, size: 18),
              text: 'Material Customizer'),
        ],
      ),
    );
  }

  // ── 4. Main Tab View Router ────────────────────────────────────────────────
  Widget _buildSelectedTabContent(double totalArea, double totalCost,
      double materialCost, double laborCost, bool isDesktop) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        final index = _tabController.index;
        if (index == 1) {
          return _buildBOQTableTab(totalCost, totalArea);
        } else if (index == 2) {
          return _buildMaterialCustomizerTab(totalArea);
        }
        return _buildOverviewTab(
            totalArea, totalCost, materialCost, laborCost, isDesktop);
      },
    );
  }

  // ── Tab 1: Overview & Package Tiers ──────────────────────────────────────
  Widget _buildOverviewTab(double totalArea, double totalCost,
      double materialCost, double laborCost, bool isDesktop) {
    final estimates = {
      'basic': totalArea *
          _tierSqftRates['basic']! *
          _locationMultiplier *
          _soilMultiplier *
          _contractMultiplier,
      'standard': totalArea *
          _tierSqftRates['standard']! *
          _locationMultiplier *
          _soilMultiplier *
          _contractMultiplier,
      'premium': totalArea *
          _tierSqftRates['premium']! *
          _locationMultiplier *
          _soilMultiplier *
          _contractMultiplier,
    };

    return Column(
      key: const ValueKey('tab_overview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tier Selection Cards
        _buildTierCards(estimates, totalArea),
        const SizedBox(height: 24),

        // Stage Budget Split Bar
        _buildStageBreakdown(totalCost, materialCost, laborCost),
        const SizedBox(height: 24),

        // 2D Plan Summary Card
        _buildSqftAnalyticsCard(totalArea, totalCost),
      ],
    );
  }

  Widget _buildTierCards(Map<String, dynamic> estimates, double totalArea) {
    final basicCard = _buildTierCard(
      id: 'basic',
      label: 'BASIC PACKAGE',
      sqftRate: _tierSqftRates['basic']! *
          _locationMultiplier *
          _soilMultiplier *
          _contractMultiplier,
      amount: estimates['basic'],
      colors: const [Color(0xFF64748B), Color(0xFF475569)],
      specs:
          '• Red Bricks / Solid Blocks\n• Ceramic Tiles 2x2\n• Flush Doors & UPVC Windows\n• CPVC Plumbing & Finolex Wiring\n• Tractor Emulsion Paint',
    );

    final standardCard = _buildTierCard(
      id: 'standard',
      label: 'STANDARD PACKAGE',
      sqftRate: _tierSqftRates['standard']! *
          _locationMultiplier *
          _soilMultiplier *
          _contractMultiplier,
      amount: estimates['standard'],
      colors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      isFeatured: true,
      specs:
          '• AAC Blocks / Wirecut Bricks\n• Vitrified Tiles 4x2 (Kajaria/Somany)\n• Heavy UPVC Windows with Mesh\n• Astral Plumbing & Polycab Wires\n• Asian Paints Apex Exterior & Emulsion',
    );

    final premiumCard = _buildTierCard(
      id: 'premium',
      label: 'PREMIUM LUXURY',
      sqftRate: _tierSqftRates['premium']! *
          _locationMultiplier *
          _soilMultiplier *
          _contractMultiplier,
      amount: estimates['premium'],
      colors: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      specs:
          '• Porotherm Thermal Blocks\n• GVT Vitrified / Italian Marble Look\n• Teak Wood Main Door & System Aluminum\n• Kohler / Jaquar Luxury Sanitaryware\n• Asian Royale Luxury Paint & Smart Switches',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Construction Quality Packages',
            style: TextStyle(
                color: _textPri, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 750) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    SizedBox(width: 250, child: basicCard),
                    const SizedBox(width: 14),
                    SizedBox(width: 250, child: standardCard),
                    const SizedBox(width: 14),
                    SizedBox(width: 250, child: premiumCard),
                  ],
                ),
              );
            } else {
              return Row(
                children: [
                  Expanded(child: basicCard),
                  const SizedBox(width: 16),
                  Expanded(child: standardCard),
                  const SizedBox(width: 16),
                  Expanded(child: premiumCard),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildTierCard({
    required String id,
    required String label,
    required double sqftRate,
    required dynamic amount,
    required List<Color> colors,
    bool isFeatured = false,
    required String specs,
  }) {
    final bool isSelected = _selectedTier == id;
    final val = (amount as num?)?.toInt() ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedTier = id),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isFeatured
                      ? _accent.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.08)),
              width: isSelected ? 0 : (isFeatured ? 2 : 1),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: colors.first.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ]
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.9)
                            : _textSec,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.check, size: 12, color: _accent),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '₹${_formatIndianCurrency(val)}',
                style: TextStyle(
                  color: isSelected ? Colors.white : _textPri,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${sqftRate.round()} / sq ft',
                style: TextStyle(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.8)
                      : _accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: Text('$label Specs',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      content: Text(specs,
                          style: const TextStyle(fontSize: 14, height: 1.6)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        )
                      ],
                    ),
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.9)
                            : _textSec),
                    const SizedBox(width: 4),
                    Text(
                      'View Specs',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.9)
                            : _textSec,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageBreakdown(
      double totalCost, double materialCost, double laborCost) {
    final stages = [
      {
        'name': '1. Earthwork & Foundation',
        'pct': 0.15,
        'color': const Color(0xFF3B82F6)
      },
      {
        'name': '2. RCC Framing & Columns',
        'pct': 0.30,
        'color': const Color(0xFF6366F1)
      },
      {
        'name': '3. Brickwork & Walls',
        'pct': 0.18,
        'color': const Color(0xFF10B981)
      },
      {
        'name': '4. Plastering & Weathering',
        'pct': 0.12,
        'color': const Color(0xFFF59E0B)
      },
      {
        'name': '5. Flooring & Tiling',
        'pct': 0.10,
        'color': const Color(0xFF8B5CF6)
      },
      {
        'name': '6. Plumbing & Electrical',
        'pct': 0.09,
        'color': const Color(0xFFEC4899)
      },
      {
        'name': '7. Painting & Handover',
        'pct': 0.06,
        'color': const Color(0xFF06B6D4)
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Text('Civil Engineering Stage Breakdown',
                  style: TextStyle(
                      color: _textPri,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text(
                  'Material: ₹${_formatIndianCurrency(materialCost.round())} · Labor: ₹${_formatIndianCurrency(laborCost.round())}',
                  style: const TextStyle(
                      color: _textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: stages.map((s) {
                  return Expanded(
                    flex: ((s['pct'] as double) * 100).round(),
                    child: Container(color: s['color'] as Color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: stages.map((s) {
              double stageAmt = totalCost * (s['pct'] as double);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: s['color'] as Color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('${s['name']}: ',
                      style: const TextStyle(color: _textSec, fontSize: 12)),
                  Text('₹${_formatIndianCurrency(stageAmt.round())}',
                      style: const TextStyle(
                          color: _textPri,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Detailed Itemized BOQ Table ──────────────────────────────────
  Widget _buildBOQTableTab(double totalCost, double totalArea) {
    final boqStages = [
      {
        'stage': 'Stage 1: Earthwork & Foundation',
        'pct': 0.15,
        'items': [
          {'name': 'Excavation & Earthwork in Trenches', 'unit': 'cft', 'qty': totalArea * 1.5, 'rate': 35.0},
          {'name': 'PCC 1:4:8 Plain Cement Concrete Base', 'unit': 'cft', 'qty': totalArea * 0.25, 'rate': 160.0},
          {'name': 'Anti-Termite Chemical Soil Treatment', 'unit': 'sqft', 'qty': totalArea, 'rate': 12.0},
          {'name': 'Footing RCC M20 Concrete & Steel', 'unit': 'cft', 'qty': totalArea * 0.40, 'rate': 340.0},
        ]
      },
      {
        'stage': 'Stage 2: RCC Framing & Columns',
        'pct': 0.30,
        'items': [
          {'name': 'Plinth Beam & Tie Beams RCC M20', 'unit': 'cft', 'qty': totalArea * 0.30, 'rate': 350.0},
          {'name': 'RCC Columns 9"x12" / 9"x15"', 'unit': 'cft', 'qty': totalArea * 0.35, 'rate': 380.0},
          {'name': 'Roof Slab Concrete 5" Thick M20', 'unit': 'sqft', 'qty': totalArea * 1.05, 'rate': 210.0},
          {'name': 'TMT Steel Rebars (Fe 550D Grade)', 'unit': 'kg', 'qty': totalArea * 3.8, 'rate': 84.0},
        ]
      },
      {
        'stage': 'Stage 3: Superstructure Brick Masonry',
        'pct': 0.18,
        'items': [
          {'name': 'Outer Perimeter Wall (9" Wirecut/AAC)', 'unit': 'sqft', 'qty': totalArea * 1.2, 'rate': 140.0},
          {'name': 'Inner Partition Walls (4.5" Thickness)', 'unit': 'sqft', 'qty': totalArea * 0.8, 'rate': 85.0},
          {'name': 'Lintel & Sunshade Beams RCC', 'unit': 'cft', 'qty': totalArea * 0.15, 'rate': 330.0},
        ]
      },
      {
        'stage': 'Stage 4: Plastering & Waterproofing',
        'pct': 0.12,
        'items': [
          {'name': 'Internal Wall & Ceiling Plastering (1:4)', 'unit': 'sqft', 'qty': totalArea * 2.8, 'rate': 32.0},
          {'name': 'External Double Coat Sponge Plastering', 'unit': 'sqft', 'qty': totalArea * 1.6, 'rate': 45.0},
          {'name': 'Terrace Weathering Tiles & Waterproofing', 'unit': 'sqft', 'qty': totalArea, 'rate': 65.0},
        ]
      },
      {
        'stage': 'Stage 5: Flooring & Wall Tiling',
        'pct': 0.10,
        'items': [
          {'name': 'Living & Bedroom Vitrified Tiles 4x2', 'unit': 'sqft', 'qty': totalArea * 0.85, 'rate': 120.0},
          {'name': 'Toilet Anti-skid Flooring & Dado Tiles', 'unit': 'sqft', 'qty': totalArea * 0.25, 'rate': 95.0},
          {'name': 'Staircase Granite Steps & Kitchen Slab', 'unit': 'sqft', 'qty': 120, 'rate': 180.0},
        ]
      },
      {
        'stage': 'Stage 6: Plumbing & Electrical',
        'pct': 0.09,
        'items': [
          {'name': 'Concealed CPVC/PVC Pipes (Astral/Finolex)', 'unit': 'sqft', 'qty': totalArea, 'rate': 65.0},
          {'name': 'Modular Switches & FR Copper Wires', 'unit': 'sqft', 'qty': totalArea, 'rate': 75.0},
          {'name': 'Sanitary Fittings (Jaquar / Parryware)', 'unit': 'set', 'qty': 3, 'rate': 18500.0},
        ]
      },
      {
        'stage': 'Stage 7: Painting & Woodwork Handover',
        'pct': 0.06,
        'items': [
          {'name': 'Wall Putty 2 Coats & Primer', 'unit': 'sqft', 'qty': totalArea * 2.8, 'rate': 14.0},
          {'name': 'Asian Paints Interior & Exterior Emulsion', 'unit': 'sqft', 'qty': totalArea * 2.8, 'rate': 24.0},
          {'name': 'Teak Main Door & Room Flush Doors', 'unit': 'nos', 'qty': 5, 'rate': 12500.0},
        ]
      },
    ];

    return Column(
      key: const ValueKey('tab_boq'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detailed Bill of Quantities (BOQ)',
                style: TextStyle(
                    color: _textPri,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 2),
            Text('Itemized quantities and rates calibrated for your plan',
                style: TextStyle(color: _textSec, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 16),
        ...boqStages.map((stageData) {
          final String stageName = stageData['stage'] as String;
          final items = stageData['items'] as List<Map<String, dynamic>>;
          double stageTotal = 0;
          for (var item in items) {
            stageTotal +=
                (item['qty'] as num).toDouble() * (item['rate'] as num).toDouble();
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: ExpansionTile(
              initiallyExpanded: true,
              shape: const Border(),
              title: Text(
                stageName,
                style: const TextStyle(
                    color: _textPri, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              trailing: Text(
                '₹${_formatIndianCurrency(stageTotal.round())}',
                style: const TextStyle(
                    color: _accent, fontSize: 15, fontWeight: FontWeight.w900),
              ),
              children: [
                const Divider(height: 1, color: _bg),
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Row(
                    children: [
                      Expanded(
                          flex: 5,
                          child: Text('Item Description',
                              style: TextStyle(
                                  color: _textSec,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold))),
                      Expanded(
                          flex: 2,
                          child: Text('Qty & Unit',
                              style: TextStyle(
                                  color: _textSec,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold))),
                      Expanded(
                          flex: 2,
                          child: Text('Rate (₹)',
                              style: TextStyle(
                                  color: _textSec,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold))),
                      Expanded(
                          flex: 3,
                          child: Text('Total (₹)',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  color: _textSec,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                ...items.map((it) {
                  double qty = (it['qty'] as num).toDouble();
                  double rate = (it['rate'] as num).toDouble();
                  double itemTot = qty * rate;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(it['name'] as String,
                              style: const TextStyle(
                                  color: _textPri,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                              '${qty.toInt()} ${it['unit']}',
                              style: const TextStyle(
                                  color: _textSec, fontSize: 12)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('₹${rate.toInt()}',
                              style: const TextStyle(
                                  color: _textSec, fontSize: 12)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            '₹${_formatIndianCurrency(itemTot.round())}',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                color: _textPri,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }



  // ── Tab 4: Live Material Customizer ──────────────────────────────────────
  Widget _buildMaterialCustomizerTab(double totalArea) {
    final Map<String, Map<String, dynamic>> activeMaterials = {
      'cement': {
        'name': 'Cement (OPC / PPC)',
        'quantity': (totalArea * 0.40).roundToDouble(),
        'unit': 'bags',
        'type': 'cement'
      },
      'steel': {
        'name': 'TMT Steel Rebars',
        'quantity': (totalArea * 3.8).roundToDouble(),
        'unit': 'kg',
        'type': 'steel'
      },
      'sand': {
        'name': 'M-Sand / P-Sand / River Sand',
        'quantity': (totalArea * 1.7).roundToDouble(),
        'unit': 'cft',
        'type': 'sand'
      },
      'aggregate': {
        'name': 'Blue Metal Aggregate',
        'quantity': (totalArea * 1.2).roundToDouble(),
        'unit': 'cft',
        'type': 'aggregate'
      },
      'bricks': {
        'name': 'Bricks / AAC Blocks / Clay Blocks',
        'quantity': (totalArea * 16.0).roundToDouble(),
        'unit': 'pcs',
        'type': 'bricks'
      },
      'tiles': {
        'name': 'Flooring Tiles & Marble',
        'quantity': (totalArea * 1.05).roundToDouble(),
        'unit': 'sqft',
        'type': 'tiles'
      },
      'paint': {
        'name': 'Wall Paint & Putty',
        'quantity': (totalArea * 0.12).roundToDouble(),
        'unit': 'liters',
        'type': 'paint'
      },
      'electrical': {
        'name': 'Electrical Wires & Switches',
        'quantity': totalArea,
        'unit': 'sqft',
        'type': 'electrical'
      },
      'plumbing': {
        'name': 'Plumbing Pipes & Sanitaryware',
        'quantity': totalArea,
        'unit': 'sqft',
        'type': 'plumbing'
      },
    };

    return Column(
      key: const ValueKey('tab_customizer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInteractiveMaterialHeader(),
        const SizedBox(height: 16),
        _buildSearchSection(),
        const SizedBox(height: 20),
        _buildMaterialInteractiveList(activeMaterials),
      ],
    );
  }

  Widget _buildInteractiveMaterialHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Material Brand Customizer',
                style: TextStyle(
                    color: _textPri,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 2),
            Text('Select any brand to dynamically recalculate total budget & per sqft cost',
                style: TextStyle(color: _textSec, fontSize: 13)),
          ],
        ),
        if (_customMaterialPrices.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _resetCustomizations,
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Reset Rates'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accent,
              side: const BorderSide(color: _accent),
            ),
          ),
      ],
    );
  }

  static final Map<String, List<Map<String, dynamic>>> _materialBrands = {
    'cement': [
      {'name': 'UltraTech Premium PPC', 'price': 460.0, 'unit': 'bag'},
      {'name': 'ACC Gold Water Shield', 'price': 445.0, 'unit': 'bag'},
      {'name': 'Ramco Supergrade 53', 'price': 435.0, 'unit': 'bag'},
      {'name': 'Dalmia DSP Cement', 'price': 450.0, 'unit': 'bag'},
      {'name': 'Chettinad Royal Cement', 'price': 420.0, 'unit': 'bag'},
      {'name': 'Priya Cement 53 Grade', 'price': 410.0, 'unit': 'bag'},
    ],
    'steel': [
      {'name': 'TATA Tiscon 550SD', 'price': 92.0, 'unit': 'kg'},
      {'name': 'JSW Neosteel 550D', 'price': 85.0, 'unit': 'kg'},
      {'name': 'Vizag Steel TMT', 'price': 82.0, 'unit': 'kg'},
      {'name': 'SAIL TMT Rebars', 'price': 80.0, 'unit': 'kg'},
      {'name': 'Prime Gold TMT', 'price': 77.0, 'unit': 'kg'},
      {'name': 'Agni Steels 550D', 'price': 75.0, 'unit': 'kg'},
    ],
    'sand': [
      {'name': 'M-Sand (Double Washed)', 'price': 75.0, 'unit': 'cft'},
      {'name': 'P-Sand (Plastering Grade)', 'price': 85.0, 'unit': 'cft'},
      {'name': 'Natural River Sand', 'price': 120.0, 'unit': 'cft'},
      {'name': 'M-Sand (Standard Concrete)', 'price': 68.0, 'unit': 'cft'},
    ],
    'aggregate': [
      {'name': '20mm Blue Metal Granite', 'price': 64.0, 'unit': 'cft'},
      {'name': '40mm Sub-base Aggregate', 'price': 58.0, 'unit': 'cft'},
      {'name': '12mm Chips Aggregate', 'price': 70.0, 'unit': 'cft'},
    ],
    'bricks': [
      {'name': 'First Class Red Bricks', 'price': 13.0, 'unit': 'pcs'},
      {'name': 'Machine Wirecut Bricks', 'price': 16.0, 'unit': 'pcs'},
      {'name': 'AAC Blocks (Lightweight 4")', 'price': 65.0, 'unit': 'pcs'},
      {'name': 'Solid Concrete Blocks (6")', 'price': 42.0, 'unit': 'pcs'},
      {'name': 'Porotherm Clay Thermal Blocks', 'price': 85.0, 'unit': 'pcs'},
      {'name': 'Fly Ash Bricks', 'price': 9.0, 'unit': 'pcs'},
    ],
    'tiles': [
      {'name': 'Kajaria Vitrified 4x2', 'price': 160.0, 'unit': 'sqft'},
      {'name': 'Somany GVT Tiles', 'price': 145.0, 'unit': 'sqft'},
      {'name': 'Orientbell Vitrified', 'price': 130.0, 'unit': 'sqft'},
      {'name': 'Nitco Luxury Tiles', 'price': 155.0, 'unit': 'sqft'},
      {'name': 'Italian Look Marble Slab', 'price': 280.0, 'unit': 'sqft'},
      {'name': 'Johnson Ceramic Tiles', 'price': 95.0, 'unit': 'sqft'},
    ],
    'paint': [
      {'name': 'Asian Paints Royale Luxury', 'price': 520.0, 'unit': 'liter'},
      {'name': 'Asian Paints Apex Exterior', 'price': 380.0, 'unit': 'liter'},
      {'name': 'Berger Silk Glamor', 'price': 480.0, 'unit': 'liter'},
      {'name': 'Dulux Velvet Touch', 'price': 460.0, 'unit': 'liter'},
      {'name': 'Nerolac Impressions', 'price': 430.0, 'unit': 'liter'},
      {'name': 'Tractor Emulsion Interior', 'price': 220.0, 'unit': 'liter'},
    ],
    'electrical': [
      {'name': 'Polycab Wires + Modular Switches', 'price': 155.0, 'unit': 'sqft'},
      {'name': 'Finolex Wires + Switches', 'price': 140.0, 'unit': 'sqft'},
      {'name': 'Havells Crabtree Luxury', 'price': 210.0, 'unit': 'sqft'},
      {'name': 'Legrand Allzy Modular', 'price': 185.0, 'unit': 'sqft'},
      {'name': 'Anchor by Panasonic', 'price': 125.0, 'unit': 'sqft'},
      {'name': 'L&T Engaged Modular', 'price': 165.0, 'unit': 'sqft'},
    ],
    'plumbing': [
      {'name': 'Kohler Luxury Sanitaryware', 'price': 240.0, 'unit': 'sqft'},
      {'name': 'Jaquar Prime Fittings', 'price': 180.0, 'unit': 'sqft'},
      {'name': 'Astral CPVC & Pipes', 'price': 140.0, 'unit': 'sqft'},
      {'name': 'Supreme Heavy Duty Pipes', 'price': 120.0, 'unit': 'sqft'},
      {'name': 'Parryware Sanitaryware', 'price': 110.0, 'unit': 'sqft'},
      {'name': 'Hindware Italian Collection', 'price': 195.0, 'unit': 'sqft'},
    ],
  };

  Widget _buildMaterialInteractiveList(
      Map<String, Map<String, dynamic>> materials) {
    return Column(
      children: [
        ...materials.entries.map((e) {
        final key = e.key;
        final m = e.value;
        final double qty = (m['quantity'] as num).toDouble();
        final availableBrands = _materialBrands[key] ?? [];
        final defaultPrice = availableBrands.isNotEmpty
            ? (availableBrands.first['price'] as num).toDouble()
            : 100.0;
        final double price = _customMaterialPrices[key] ?? defaultPrice;
        final double itemTotal = qty * price;
        final String selectedBrandName = _customMaterialBrands[key] ??
            (availableBrands.isNotEmpty ? availableBrands.first['name'] : '');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _customMaterialPrices.containsKey(key)
                    ? _accent.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.05),
                width: _customMaterialPrices.containsKey(key) ? 1.5 : 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['name'],
                            style: const TextStyle(
                                color: _textPri,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          'Est. Qty: ${qty.toInt()} ${m['unit']} · ₹${price.toInt()}/${m['unit']}',
                          style: const TextStyle(color: _textSec, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text('₹${_formatIndianCurrency(itemTotal.round())}',
                      style: const TextStyle(
                          color: _accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                ],
              ),
              if (availableBrands.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: availableBrands.any((b) => b['name'] == selectedBrandName)
                          ? selectedBrandName
                          : availableBrands.first['name'],
                      isDense: true,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 6,
                      style: const TextStyle(
                          color: _textPri,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                      items: availableBrands.map((b) {
                        return DropdownMenuItem<String>(
                          value: b['name'] as String,
                          child: Text(
                            '${b['name']} — ₹${(b['price'] as num).toInt()} / ${b['unit']}',
                            style: const TextStyle(
                              color: _textPri,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (brandName) {
                        if (brandName != null) {
                          final chosen = availableBrands
                              .firstWhere((b) => b['name'] == brandName);
                          setState(() {
                            _customMaterialPrices[key] =
                                (chosen['price'] as num).toDouble();
                            _customMaterialBrands[key] = brandName;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),

        if (_addedCustomMaterials.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                Icon(Icons.add_shopping_cart_rounded, color: _success, size: 18),
                SizedBox(width: 8),
                Text('User Selected Custom Added Materials',
                    style: TextStyle(
                        color: _textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ..._addedCustomMaterials.map((item) {
            final double price = _customMaterialPrices[item.type] ?? item.price;
            final double qty = _customMaterialQty[item.type] ?? 1.0;
            final double subtotal = price * qty;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _success.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _success.withValues(alpha: 0.15),
                    child: Icon(item.icon, color: _success, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                  color: _textPri,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _success,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('✓ Added',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Qty: ${qty.toInt()} ${item.unit} · ₹${price.toInt()}/${item.unit}',
                          style: const TextStyle(color: _textSec, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${_formatIndianCurrency(subtotal.round())}',
                    style: const TextStyle(
                        color: _success, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () {
                      setState(() {
                        _addedCustomMaterials.remove(item);
                        _customMaterialPrices.remove(item.type);
                        _customMaterialBrands.remove(item.type);
                        _customMaterialQty.remove(item.type);
                      });
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Search & Select Specific Material Brands',
            style: TextStyle(
                color: _textPri, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        MaterialSearchWidget(onSelected: _onBrandSelected),
      ],
    );
  }

  Widget _buildSqftAnalyticsCard(double totalArea, double currentTotal) {
    double perSqft = currentTotal / totalArea;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: _accent, size: 20),
              SizedBox(width: 8),
              Text('2D Blueprint Calibrated Summary',
                  style: TextStyle(
                      color: _textPri,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAnalyticsMetric(
                  'Total Builtup Area', '${totalArea.toInt()} sq ft'),
              _buildAnalyticsMetric(
                  'Effective Cost/Sq.Ft', '₹${perSqft.round()}/sq ft'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _textSec, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: _textPri, fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }

  String _formatIndianCurrency(int value) {
    String str = value.toString();
    if (str.length <= 3) return str;
    String lastThree = str.substring(str.length - 3);
    String otherNumbers = str.substring(0, str.length - 3);
    if (otherNumbers.isNotEmpty) {
      otherNumbers = otherNumbers.replaceAllMapped(
          RegExp(r".{1,2}(?=(.{2})+(?!.))"), (Match m) => "${m[0]},");
      return "$otherNumbers,$lastThree";
    }
    return lastThree;
  }
}
