import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/providers/app_config_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_decor.dart';
import '../services/api_service.dart';
import '../widgets/material_search_widget.dart';

class EstimationScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  final void Function(int tabIndex)? onNavigateToTab;
  final VoidCallback? onNavigateToNext;
  final VoidCallback? onBack;

  const EstimationScreen({
    super.key,
    required this.projectData,
    this.onNavigateToTab,
    this.onNavigateToNext,
    this.onBack,
  });

  @override
  State<EstimationScreen> createState() => _EstimationScreenState();
}

class _EstimationScreenState extends State<EstimationScreen> {
  // Subtabs: 0 = Tiers, 1 = Stages, 2 = BOQ, 3 = Materials
  int _currentSubTab = 0;

  // Active Cost Factors
  String _selectedTier = 'standard'; // 'basic', 'standard', 'premium'
  String _selectedContractMode = 'turnkey'; // 'turnkey', 'labor', 'self'
  String _selectedSoil = 'normal'; // 'normal', 'soft_silt', 'hard_rock'
  String _selectedLocation = 'tier2'; // 'metro', 'tier2', 'rural'
  int _activeBoqStage = 0; // 0 to 6

  int get _safeBoqStage {
    dynamic val = _activeBoqStage;
    if (val == null || val is! int || val < 0 || val >= 7) {
      _activeBoqStage = 0;
      return 0;
    }
    return val;
  }

  // Live Market State
  bool _isFetchingLiveMarket = false;
  String _marketLocation = 'Tamil Nadu Live Market';

  // Custom user overrides
  final Map<String, double> _customMaterialPrices = {};
  final Map<String, double> _customMaterialQty = {};
  final Map<String, String> _customMaterialBrands = {};
  final List<MaterialBrand> _addedCustomMaterials = [];

  // Baseline Rates (Tamil Nadu 2026 Construction Standards)
  static const Map<String, double> _tierSqftRates = {
    'basic': 1750.0,
    'standard': 2250.0,
    'premium': 3350.0,
  };

  @override
  void initState() {
    super.initState();
    _currentSubTab = 0;
    _activeBoqStage = 0;
    _fetchLiveMarketPrices();
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
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: const Text(
                '✓ Live Tamil Nadu market rates updated successfully!'),
          ));
        }
      }
    } catch (e) {
      debugPrint('[EstimationScreen] Live market fetch notice: $e');
    } finally {
      if (mounted) setState(() => _isFetchingLiveMarket = false);
    }
  }

  // Factor Multipliers
  double get _locationMultiplier {
    if (_selectedLocation == 'metro') return 1.10; // Chennai Metro +10%
    if (_selectedLocation == 'rural') return 0.95; // Rural -5%
    return 1.0; // Tier 2 Towns
  }

  double get _soilMultiplier {
    if (_selectedSoil == 'soft_silt') return 1.12; // Pile Foundation +12%
    if (_selectedSoil == 'hard_rock') return 1.08; // Rock Breaker +8%
    return 1.0; // Normal Clay / Red Soil
  }

  double get _contractMultiplier {
    if (_selectedContractMode == 'labor') return 0.40; // Labor Only ~40%
    if (_selectedContractMode == 'self')
      return 0.88; // Direct / Self Build saves 12%
    return 1.0; // Turnkey
  }

  void _onBrandSelected(MaterialBrand brand) {
    setState(() {
      _customMaterialPrices[brand.type] = brand.price;
      _customMaterialBrands[brand.type] = brand.name;

      if (_materialBrands.containsKey(brand.type)) {
        final list = _materialBrands[brand.type]!;
        if (!list.any((b) => b['name'] == brand.name)) {
          list.add(
              {'name': brand.name, 'price': brand.price, 'unit': brand.unit});
        }
      } else {
        if (!_addedCustomMaterials.any((b) => b.name == brand.name)) {
          _addedCustomMaterials.add(brand);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: Text(
          '✓ Selected ${brand.name} (₹${brand.price.toInt()}/${brand.unit}) for estimation!'),
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
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: const Text(
          'Reset material rates to baseline Tamil Nadu market rates.'),
    ));
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

    // Failsafe state checks across hot reloads
    dynamic curTab = _currentSubTab;
    if (curTab == null || curTab is! int || curTab < 0 || curTab > 3) {
      _currentSubTab = 0;
    }
    dynamic curStage = _activeBoqStage;
    if (curStage == null || curStage is! int || curStage < 0 || curStage > 6) {
      _activeBoqStage = 0;
    }

    // Blueprint & Dimensions data
    final rootCost =
        widget.projectData['cost_data'] as Map<String, dynamic>? ?? {};
    final modelData = widget.projectData['model_data'] as Map<String, dynamic>?;
    final overallDims =
        (modelData?['overall_dimensions'] as Map<String, dynamic>?) ??
            (widget.projectData['overall_dimensions'] as Map<String, dynamic>?);
    final w = (overallDims?['width_ft'] as num?)?.toDouble() ??
        (modelData?['project']?['width'] as num?)?.toDouble() ??
        0.0;
    final l = (overallDims?['length_ft'] as num?)?.toDouble() ??
        (modelData?['project']?['height'] as num?)?.toDouble() ??
        0.0;

    // Total area calculation
    double totalArea = (rootCost['total_area_sqft'] as num?)?.toDouble() ??
        (widget.projectData['total_area_sqft'] as num?)?.toDouble() ??
        0.0;
    if (totalArea <= 0 && w > 0 && l > 0) {
      totalArea = w * l;
    }
    if (totalArea <= 0) totalArea = 1200.0; // Default Standard Plan

    const planName = 'kanavuillam_report';

    final String dimsText =
        (w > 0 && l > 0) ? '${w.toInt()}\' × ${l.toInt()}\'' : 'Standard Floor';

    // Base Rate with dynamic calibrator factors
    double baseRate = (_tierSqftRates[_selectedTier] ?? 2250.0) *
        _locationMultiplier *
        _soilMultiplier *
        _contractMultiplier;

    // Base quantities
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

    // Custom material brand price differences
    double customMaterialAdjustment = 0.0;
    _customMaterialPrices.forEach((key, customPrice) {
      final defaultBrands = _materialBrands[key];
      if (defaultBrands != null && defaultBrands.isNotEmpty) {
        double defaultPrice = (defaultBrands.first['price'] as num).toDouble();
        double qty =
            _customMaterialQty[key] ?? baseQuantities[key] ?? (totalArea * 0.5);
        customMaterialAdjustment += (customPrice - defaultPrice) * qty;
      }
    });

    // Added custom items
    double addedCustomMaterialsCost = 0.0;
    for (var customItem in _addedCustomMaterials) {
      if (!_materialBrands.containsKey(customItem.type)) {
        double price =
            _customMaterialPrices[customItem.type] ?? customItem.price;
        double qty = _customMaterialQty[customItem.type] ?? 1.0;
        addedCustomMaterialsCost += price * qty;
      }
    }

    double calculatedTotal = totalArea * baseRate +
        customMaterialAdjustment +
        addedCustomMaterialsCost;
    double effectivePerSqft = calculatedTotal / totalArea;
    double materialCost = calculatedTotal * 0.62;
    double laborCost = calculatedTotal * 0.38;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.canvasGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. HEADER ROW ───────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  planName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.inkPrimary,
                                    letterSpacing: -0.3,
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isTamil
                                      ? 'செலவு அறிக்கை · $dimsText (${totalArea.toInt()} ச.அடி)'
                                      : 'Cost report · $dimsText (${totalArea.toInt()} sq ft)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.inkQuiet,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Language Switcher Capsule
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: AppColors.borderLight),
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
                                          ? AppColors.inkDark
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      'EN',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: !isTamil
                                            ? Colors.white
                                            : AppColors.inkMuted,
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
                                          ? AppColors.inkDark
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      'தமிழ்',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isTamil
                                            ? Colors.white
                                            : AppColors.inkMuted,
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

                    // ── 2. MAIN TABS (3D, Vastu, Cost, Structure, Download) ──
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildMainTab(
                            title: '3D',
                            isActive: false,
                            onTap: () => widget.onNavigateToTab?.call(1),
                          ),
                          const SizedBox(width: 6),
                          _buildMainTab(
                            title: isTamil ? 'வாஸ்து' : 'Vastu',
                            isActive: false,
                            onTap: () => widget.onNavigateToTab?.call(2),
                          ),
                          const SizedBox(width: 6),
                          _buildMainTab(
                            title: isTamil ? 'செலவு' : 'Cost',
                            isActive: true,
                            onTap: () {},
                          ),
                          const SizedBox(width: 6),
                          _buildMainTab(
                            title: isTamil ? 'அமைப்பு' : 'Structure',
                            isActive: false,
                            onTap: () => widget.onNavigateToTab?.call(4),
                          ),
                          const SizedBox(width: 6),
                          _buildMainTab(
                            title: isTamil ? 'பதிவிறக்கம்' : 'Download',
                            isActive: false,
                            onTap: () => widget.onNavigateToTab?.call(5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── 3. ESTIMATED TOTAL BUDGET CARD (Elevated Card) ────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x141B212F),
                            blurRadius: 32,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: Title, Price, Sqft Pill Badge
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isTamil
                                          ? 'மதிப்பிடப்பட்ட பட்ஜெட்'
                                          : 'Estimated budget',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '₹${_formatIndianCurrency(calculatedTotal.round())}',
                                        maxLines: 1,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                          letterSpacing: -0.5,
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: Text(
                                        '₹${effectivePerSqft.round()} / sq ft · ${totalArea.toInt()} sq ft',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Right: Engineer BOQ & Live TN rates badges
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.architecture,
                                          size: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Engineer BOQ',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: _fetchLiveMarketPrices,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius:
                                            BorderRadius.circular(100),
                                        border: Border.all(
                                            color: const Color(0xFF86EFAC)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isFetchingLiveMarket
                                                ? Icons.sync
                                                : Icons.sensors,
                                            size: 14,
                                            color: const Color(0xFF16A34A),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            _isFetchingLiveMarket
                                                ? 'Syncing...'
                                                : 'Live TN rates',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF16A34A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 12),
                          // 3 Dropdown Pills in a row
                          Row(
                            children: [
                              Expanded(
                                child: _buildFactorDropdown(
                                  label: isTamil ? 'ஒப்பந்தம்' : 'Contract',
                                  value: _selectedContractMode,
                                  items: {
                                    'turnkey': 'Turnkey',
                                    'labor': 'Labor Only',
                                    'self': 'Direct',
                                  },
                                  menuItems: {
                                    'turnkey': 'Turnkey (Material + Labor)',
                                    'labor': 'Labor Only (40%)',
                                    'self': 'Direct Procurement (Self)',
                                  },
                                  onChanged: (val) {
                                    if (val != null)
                                      setState(
                                          () => _selectedContractMode = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildFactorDropdown(
                                  label: isTamil ? 'மண்' : 'Soil',
                                  value: _selectedSoil,
                                  items: {
                                    'normal': 'Normal',
                                    'soft_silt': 'Silt (+12%)',
                                    'hard_rock': 'Rock (+8%)',
                                  },
                                  menuItems: {
                                    'normal': 'Normal / Red Clay (Std)',
                                    'soft_silt': 'Black Cotton / Silt (+12%)',
                                    'hard_rock': 'Hard Rock (+8%)',
                                  },
                                  onChanged: (val) {
                                    if (val != null)
                                      setState(() => _selectedSoil = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildFactorDropdown(
                                  label: isTamil ? 'இடம்' : 'Location',
                                  value: _selectedLocation,
                                  items: {
                                    'metro': 'Metro',
                                    'tier2': 'Town (Std)',
                                    'rural': 'Rural',
                                  },
                                  menuItems: {
                                    'metro': 'Chennai Metro (+10%)',
                                    'tier2': 'District / Town (Std)',
                                    'rural': 'Rural / Village (-5%)',
                                  },
                                  onChanged: (val) {
                                    if (val != null)
                                      setState(() => _selectedLocation = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── 4. SUB TABS (Tiers, Stages, BOQ, Materials) WITH UNDERLINE ──
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildSubTabItem(
                            index: 0,
                            title: isTamil ? 'தொகுப்புகள்' : 'Tiers',
                            isActive: _currentSubTab == 0,
                          ),
                          _buildSubTabItem(
                            index: 1,
                            title: isTamil ? 'நிலைகள்' : 'Stages',
                            isActive: _currentSubTab == 1,
                          ),
                          _buildSubTabItem(
                            index: 2,
                            title: 'BOQ',
                            isActive: _currentSubTab == 2,
                          ),
                          _buildSubTabItem(
                            index: 3,
                            title: isTamil ? 'பொருட்கள்' : 'Materials',
                            isActive: _currentSubTab == 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 5. ACTIVE TAB CONTENT VIEW ───────────────────────────
                    Expanded(
                      child: _buildSubTabContent(
                        totalArea: totalArea,
                        calculatedTotal: calculatedTotal,
                        materialCost: materialCost,
                        laborCost: laborCost,
                        effectivePerSqft: effectivePerSqft,
                        isTamil: isTamil,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Main Tab Pill Builder ──────────────────────────────────────────────────
  Widget _buildMainTab({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.inkDark : AppColors.card,
          borderRadius: BorderRadius.circular(100),
          border: isActive ? null : Border.all(color: AppColors.borderLight),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x141B212F),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }

  // ── Sub Tab Item Builder (Underline Style) ─────────────────────────────────
  Widget _buildSubTabItem({
    required int index,
    required String title,
    required bool isActive,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentSubTab = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              height: 2.5,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFE58A18) : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Calibrator Dropdown Chip ───────────────────────────────────────────────
  Widget _buildFactorDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    Map<String, String>? menuItems,
    required ValueChanged<String?> onChanged,
  }) {
    final dropdownItems = menuItems ?? items;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.containsKey(value) ? value : items.keys.first,
          isDense: true,
          isExpanded: true,
          elevation: 4,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: AppColors.inkQuiet,
          ),
          selectedItemBuilder: (BuildContext context) {
            return items.entries.map((e) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  e.value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList();
          },
          items: dropdownItems.entries.map((e) {
            return DropdownMenuItem<String>(
              value: e.key,
              child: Text(
                e.value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Router for Subtab Content ──────────────────────────────────────────────
  Widget _buildSubTabContent({
    required double totalArea,
    required double calculatedTotal,
    required double materialCost,
    required double laborCost,
    required double effectivePerSqft,
    required bool isTamil,
  }) {
    switch (_currentSubTab) {
      case 1:
        return _buildStagesTab(
          totalCost: calculatedTotal,
          materialCost: materialCost,
          laborCost: laborCost,
          isTamil: isTamil,
        );
      case 2:
        return _buildBOQTab(
          totalArea: totalArea,
          totalCost: calculatedTotal,
          isTamil: isTamil,
        );
      case 3:
        return _buildMaterialsTab(
          totalArea: totalArea,
          isTamil: isTamil,
        );
      case 0:
      default:
        return _buildTiersTab(
          totalArea: totalArea,
          calculatedTotal: calculatedTotal,
          effectivePerSqft: effectivePerSqft,
          isTamil: isTamil,
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUBTAB 1: TIERS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTiersTab({
    required double totalArea,
    required double calculatedTotal,
    required double effectivePerSqft,
    required bool isTamil,
  }) {
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildTierCard(
            id: 'basic',
            tierName: isTamil ? 'தரம் 1' : 'Tier 1',
            subtitle: isTamil ? 'நிலையான அமைப்புகள்' : 'Standard fittings',
            amount: estimates['basic']!,
            sqftRate: _tierSqftRates['basic']! *
                _locationMultiplier *
                _soilMultiplier *
                _contractMultiplier,
            specs: isTamil
                ? '• சிவப்பு செங்கல் / சாலிட் பிளாக்ஸ்\n• செராமிக் டைல்ஸ் 2x2\n• ஃப்ளஷ் கதவுகள் & UPVC ஜன்னல்கள்\n• ஃபினோலெக்ஸ் ஒயரிங் & CPVC பைப்\n• டிராக்டர் எமல்ஷன் பெயிண்ட்'
                : '• Red Bricks / Solid Blocks\n• Ceramic Tiles 2x2\n• Flush Doors & UPVC Windows\n• Finolex Wiring & CPVC Plumbing\n• Tractor Emulsion Paint',
            isTamil: isTamil,
          ),
          const SizedBox(height: 12),
          _buildTierCard(
            id: 'standard',
            tierName: isTamil ? 'தரம் 2' : 'Tier 2',
            subtitle: isTamil ? 'பிராண்டட் அமைப்புகள்' : 'Branded fittings',
            amount: estimates['standard']!,
            sqftRate: _tierSqftRates['standard']! *
                _locationMultiplier *
                _soilMultiplier *
                _contractMultiplier,
            specs: isTamil
                ? '• AAC பிளாக்ஸ் / வயர்கட் செங்கல்\n• விட்ரிஃபைட் டைல்ஸ் 4x2 (கஜாரியா)\n• ஹெவி UPVC ஜன்னல்கள் மெஷ் உடன்\n• பாலிகேப் ஒயரிங் & ஆஸ்ட்ரல் பைப்\n• ஏசியன் பெயிண்ட்ஸ் அபெக்ஸ் & எமல்ஷன்'
                : '• AAC Blocks / Wirecut Bricks\n• Vitrified Tiles 4x2 (Kajaria/Somany)\n• Heavy UPVC Windows with Mesh\n• Polycab Wires & Astral Plumbing\n• Asian Paints Apex Exterior & Emulsion',
            isRecommended: true,
            isTamil: isTamil,
          ),
          const SizedBox(height: 12),
          _buildTierCard(
            id: 'premium',
            tierName: isTamil ? 'தரம் 3' : 'Tier 3',
            subtitle: isTamil ? 'சொகுசு அமைப்புகள்' : 'Luxury fittings',
            amount: estimates['premium']!,
            sqftRate: _tierSqftRates['premium']! *
                _locationMultiplier *
                _soilMultiplier *
                _contractMultiplier,
            specs: isTamil
                ? '• போரோதெர்ம் தெர்மல் பிளாக்ஸ்\n• இத்தாலியன் மார்பிள் லுக் GVT டைல்ஸ்\n• தேக்கு மர முதன்மை கதவு & பிரீமியம் ஜன்னல்\n• கோஹ்லர் / ஜாக்குவார் சொகுசு பிட்டிங்ஸ்\n• ஏசியன் ராயல் லக்ஸரி & ஸ்மார்ட் ஸ்விட்ச்'
                : '• Porotherm Thermal Clay Blocks\n• GVT / Italian Look Marble\n• Teak Wood Main Door & System Aluminum\n• Kohler / Jaquar Luxury Sanitaryware\n• Asian Royale Luxury & Smart Switches',
            isTamil: isTamil,
          ),
          const SizedBox(height: 14),

          // Blueprint 2D Area Metric Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppDecor.card(radius: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTamil
                            ? 'மொத்த கட்டப்பட்ட பரப்பளவு'
                            : 'Total Builtup Area',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${totalArea.toInt()} sq ft',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isTamil
                            ? 'தற்போதைய சதுர அடி விலை'
                            : 'Effective Sq.Ft Rate',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${effectivePerSqft.round()} / sq ft',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required String id,
    required String tierName,
    required String subtitle,
    required double amount,
    required double sqftRate,
    required String specs,
    bool isRecommended = false,
    required bool isTamil,
  }) {
    final bool isSelected = _selectedTier == id;

    return InkWell(
      onTap: () => setState(() => _selectedTier = id),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: AppDecor.card(
          radius: 28,
          border: isSelected
              ? AppDecor.selectedBorder
              : Border.all(color: AppColors.cardBorder, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row (Tier Name + Badge + Radio)
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        tierName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTitle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '· $subtitle',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isRecommended)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.innerPanel,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Text(
                      isTamil ? 'பரிந்துரை' : 'Popular',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.orangeHighlight
                          : AppColors.cardBorder,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.orangeHighlight,
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Price & Rate Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '₹${_formatIndianCurrency(amount.round())}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTitle,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${sqftRate.round()} / sq ft',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: Text(
                          '$tierName ${isTamil ? 'விவரக்குறிப்பு' : 'Specifications'}',
                          style: GoogleFonts.syne(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTitle,
                          ),
                        ),
                        content: Text(
                          specs,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.6,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              isTamil ? 'மூடு' : 'Close',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTitle,
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.innerPanel,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 13,
                          color: AppColors.textBody,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isTamil ? 'விவரம் பார்க்க' : 'View Specs',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUBTAB 2: STAGES BREAKDOWN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStagesTab({
    required double totalCost,
    required double materialCost,
    required double laborCost,
    required bool isTamil,
  }) {
    final stages = [
      {
        'name':
            isTamil ? '1. அடித்தளம் & மண் வேலை' : '1. Earthwork & Foundation',
        'pct': 0.15,
        'color': const Color(0xFF000000),
      },
      {
        'name': isTamil
            ? '2. RCC கட்டமைப்பு & தூண்கள்'
            : '2. RCC Framing & Columns',
        'pct': 0.30,
        'color': const Color(0xFF262626),
      },
      {
        'name':
            isTamil ? '3. செங்கல் சுவர் கட்டுமானம்' : '3. Brickwork & Walls',
        'pct': 0.18,
        'color': const Color(0xFF4A4A4A),
      },
      {
        'name': isTamil ? '4. பூச்சு & தளப்பணி' : '4. Plastering & Weathering',
        'pct': 0.12,
        'color': const Color(0xFF6E6E6E),
      },
      {
        'name': isTamil ? '5. தரை டைல்ஸ் பதித்தல்' : '5. Flooring & Tiling',
        'pct': 0.10,
        'color': const Color(0xFF9E9E9E),
      },
      {
        'name':
            isTamil ? '6. குழாய் & மின்சார பணி' : '6. Plumbing & Electrical',
        'pct': 0.09,
        'color': const Color(0xFFC4C4C4),
      },
      {
        'name': isTamil
            ? '7. வர்ணம் பூசுதல் & ஒப்படைப்பு'
            : '7. Painting & Handover',
        'pct': 0.06,
        'color': const Color(0xFFE2E8F0),
      },
    ];

    final matStr = materialCost >= 100000
        ? '₹${(materialCost / 100000).toStringAsFixed(1)} L'
        : '₹${_formatIndianCurrency(materialCost.round())}';
    final labStr = laborCost >= 100000
        ? '₹${(laborCost / 100000).toStringAsFixed(1)} L'
        : '₹${_formatIndianCurrency(laborCost.round())}';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Stage Header: Title (left) & Material / Labor split (right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    isTamil ? 'கட்டுமான' : 'Stage',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      height: 1.15,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    isTamil
                        ? 'பொருட்கள் $matStr · கூலி $labStr'
                        : 'Material $matStr · Labor $labStr',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Segmented Spectrum Bar
            Container(
              height: 10,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: stages.map((s) {
                  return Expanded(
                    flex: ((s['pct'] as double) * 100).round(),
                    child: Container(color: s['color'] as Color),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Stage List Items with dots and dividers
            ...List.generate(stages.length, (index) {
              final s = stages[index];
              final double stageAmt = totalCost * (s['pct'] as double);
              final isLast = index == stages.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // Colored Dot
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: s['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Stage Name
                        Expanded(
                          child: Text(
                            s['name'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Stage Amount
                        Text(
                          '₹${_formatIndianCurrency(stageAmt.round())}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                      height: 22,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUBTAB 3: BOQ (BILL OF QUANTITIES)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBOQTab({
    required double totalArea,
    required double totalCost,
    required bool isTamil,
  }) {
    final boqStages = [
      {
        'stage': isTamil
            ? 'நிலை 1: அடித்தளம் & மண் வேலை'
            : 'Stage 1: Earthwork & Foundation',
        'pct': 0.15,
        'items': [
          {
            'name': 'Excavation & Trenches',
            'unit': 'cft',
            'qty': totalArea * 1.5,
            'rate': 35.0
          },
          {
            'name': 'PCC 1:4:8 Concrete Base',
            'unit': 'cft',
            'qty': totalArea * 0.25,
            'rate': 160.0
          },
          {
            'name': 'Anti-Termite Treatment',
            'unit': 'sqft',
            'qty': totalArea,
            'rate': 12.0
          },
          {
            'name': 'Footing RCC M20 Concrete',
            'unit': 'cft',
            'qty': totalArea * 0.40,
            'rate': 340.0
          },
        ]
      },
      {
        'stage': isTamil
            ? 'நிலை 2: RCC கட்டமைப்பு & தூண்கள்'
            : 'Stage 2: RCC Framing & Columns',
        'pct': 0.30,
        'items': [
          {
            'name': 'Plinth & Tie Beams RCC',
            'unit': 'cft',
            'qty': totalArea * 0.30,
            'rate': 350.0
          },
          {
            'name': 'RCC Columns 9"x12"',
            'unit': 'cft',
            'qty': totalArea * 0.35,
            'rate': 380.0
          },
          {
            'name': 'Roof Slab Concrete 5"',
            'unit': 'sqft',
            'qty': totalArea * 1.05,
            'rate': 210.0
          },
          {
            'name': 'TMT Steel Rebars (550D)',
            'unit': 'kg',
            'qty': totalArea * 3.8,
            'rate': 84.0
          },
        ]
      },
      {
        'stage': isTamil
            ? 'நிலை 3: செங்கல் சுவர் கட்டுமானம்'
            : 'Stage 3: Brickwork & Walls',
        'pct': 0.18,
        'items': [
          {
            'name': 'Perimeter Wall 9" Brick',
            'unit': 'sqft',
            'qty': totalArea * 1.2,
            'rate': 140.0
          },
          {
            'name': 'Partition Walls 4.5"',
            'unit': 'sqft',
            'qty': totalArea * 0.8,
            'rate': 85.0
          },
          {
            'name': 'Lintel & Sunshade Beams',
            'unit': 'cft',
            'qty': totalArea * 0.15,
            'rate': 330.0
          },
        ]
      },
      {
        'stage': isTamil
            ? 'நிலை 4: பூச்சு & தளப்பணி'
            : 'Stage 4: Plastering & Waterproofing',
        'pct': 0.12,
        'items': [
          {
            'name': 'Internal Wall Plastering',
            'unit': 'sqft',
            'qty': totalArea * 2.8,
            'rate': 32.0
          },
          {
            'name': 'External Double Plaster',
            'unit': 'sqft',
            'qty': totalArea * 1.6,
            'rate': 45.0
          },
          {
            'name': 'Terrace Weathering Tiles',
            'unit': 'sqft',
            'qty': totalArea,
            'rate': 65.0
          },
        ]
      },
      {
        'stage': isTamil
            ? 'நிலை 5: தரை டைல்ஸ் பதித்தல்'
            : 'Stage 5: Flooring & Wall Tiling',
        'pct': 0.10,
        'items': [
          {
            'name': 'Vitrified Tiles 4x2',
            'unit': 'sqft',
            'qty': totalArea * 0.85,
            'rate': 120.0
          },
          {
            'name': 'Toilet Anti-skid Tiles',
            'unit': 'sqft',
            'qty': totalArea * 0.25,
            'rate': 95.0
          },
          {
            'name': 'Granite Steps & Counter',
            'unit': 'sqft',
            'qty': 120,
            'rate': 180.0
          },
        ]
      },
      {
        'stage': isTamil
            ? 'நிலை 6: குழாய் & மின்சார பணி'
            : 'Stage 6: Plumbing & Electrical',
        'pct': 0.09,
        'items': [
          {
            'name': 'Concealed CPVC/PVC Pipes',
            'unit': 'sqft',
            'qty': totalArea,
            'rate': 65.0
          },
          {
            'name': 'Modular Wiring & Switches',
            'unit': 'sqft',
            'qty': totalArea,
            'rate': 75.0
          },
          {
            'name': 'Sanitaryware Fittings Set',
            'unit': 'set',
            'qty': 3,
            'rate': 18500.0
          },
        ]
      },
      {
        'stage': isTamil
            ? 'நிலை 7: வர்ணம் & மரவேலை ஒப்படைப்பு'
            : 'Stage 7: Painting & Woodwork',
        'pct': 0.06,
        'items': [
          {
            'name': 'Wall Putty 2 Coats + Primer',
            'unit': 'sqft',
            'qty': totalArea * 2.8,
            'rate': 14.0
          },
          {
            'name': 'Apex / Emulsion Paint',
            'unit': 'sqft',
            'qty': totalArea * 2.8,
            'rate': 24.0
          },
          {
            'name': 'Teak Main & Flush Doors',
            'unit': 'nos',
            'qty': 5,
            'rate': 12500.0
          },
        ]
      },
    ];

    final int safeIdx = _safeBoqStage.clamp(0, boqStages.length - 1);
    final currentStage = boqStages[safeIdx];
    final items = currentStage['items'] as List<Map<String, dynamic>>;
    double stageSum = 0;
    for (var item in items) {
      stageSum +=
          (item['qty'] as num).toDouble() * (item['rate'] as num).toDouble();
    }

    return Column(
      children: [
        // Horizontal Stage Selector Carousel
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: boqStages.length,
            itemBuilder: (context, idx) {
              final isStageActive = safeIdx == idx;
              return GestureDetector(
                onTap: () => setState(() => _activeBoqStage = idx),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: isStageActive
                        ? const Color(0xFF0F172A)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isStageActive
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    'Stage ${idx + 1}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight:
                          isStageActive ? FontWeight.w700 : FontWeight.w600,
                      color: isStageActive
                          ? Colors.white
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // BOQ Stage Card with Table
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header of current stage
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        currentStage['stage'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₹${_formatIndianCurrency(stageSum.round())}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Table Header Row
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          isTamil ? 'பொருள் விவரம்' : 'Item Description',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          isTamil ? 'அளவு & அலகு விலை' : 'Qty & Unit Rate',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          isTamil ? 'மொத்தம்' : 'Total (₹)',
                          textAlign: TextAlign.end,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Table Item Rows
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, i) {
                      final it = items[i];
                      double qty = (it['qty'] as num).toDouble();
                      double rate = (it['rate'] as num).toDouble();
                      double tot = qty * rate;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                it['name'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Text(
                                    '${qty.toInt()} ${it['unit']}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '₹${rate.toInt()}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '₹${_formatIndianCurrency(tot.round())}',
                                textAlign: TextAlign.end,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Pagination Row
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: safeIdx > 0
                          ? () => setState(() => _activeBoqStage = safeIdx - 1)
                          : null,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          size: 16,
                          color: safeIdx > 0
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${safeIdx + 1} / ${boqStages.length}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: List.generate(boqStages.length, (dotIdx) {
                            final bool isDotActive = dotIdx == safeIdx;
                            return Container(
                              width: isDotActive ? 14 : 4.5,
                              height: 4.5,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: isDotActive
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFCBD5E1),
                                borderRadius: isDotActive
                                    ? BorderRadius.circular(100)
                                    : null,
                                shape: isDotActive
                                    ? BoxShape.rectangle
                                    : BoxShape.circle,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: safeIdx < boqStages.length - 1
                          ? () => setState(() => _activeBoqStage = safeIdx + 1)
                          : null,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: safeIdx < boqStages.length - 1
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUBTAB 4: MATERIALS CUSTOMIZER & BRAND SEARCH
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMaterialsTab({
    required double totalArea,
    required bool isTamil,
  }) {
    final Map<String, Map<String, dynamic>> activeMaterials = {
      'cement': {
        'name': isTamil ? 'சிமெண்ட் (OPC / PPC)' : 'Cement (OPC / PPC)',
        'quantity': (totalArea * 0.40).roundToDouble(),
        'unit': 'bags',
        'type': 'cement'
      },
      'steel': {
        'name': isTamil ? 'TMT கம்பி' : 'TMT Steel Rebars',
        'quantity': (totalArea * 3.8).roundToDouble(),
        'unit': 'kg',
        'type': 'steel'
      },
      'sand': {
        'name': isTamil ? 'எம்-சாண்ட் / மணல்' : 'M-Sand / River Sand',
        'quantity': (totalArea * 1.7).roundToDouble(),
        'unit': 'cft',
        'type': 'sand'
      },
      'aggregate': {
        'name': isTamil ? 'ஜல்லி கற்கள்' : 'Blue Metal Aggregate',
        'quantity': (totalArea * 1.2).roundToDouble(),
        'unit': 'cft',
        'type': 'aggregate'
      },
      'bricks': {
        'name': isTamil ? 'செங்கல் / AAC கற்கள்' : 'Bricks / AAC Blocks',
        'quantity': (totalArea * 16.0).roundToDouble(),
        'unit': 'pcs',
        'type': 'bricks'
      },
      'tiles': {
        'name': isTamil ? 'டைல்ஸ் & மார்பிள்' : 'Flooring Tiles & Marble',
        'quantity': (totalArea * 1.05).roundToDouble(),
        'unit': 'sqft',
        'type': 'tiles'
      },
      'paint': {
        'name': isTamil ? 'வர்ணம் & புட்டி' : 'Wall Paint & Putty',
        'quantity': (totalArea * 0.12).roundToDouble(),
        'unit': 'liters',
        'type': 'paint'
      },
      'electrical': {
        'name': isTamil ? 'மின்சார ஒயரிங் & ஸ்விட்ச்' : 'Electrical Wiring',
        'quantity': totalArea,
        'unit': 'sqft',
        'type': 'electrical'
      },
      'plumbing': {
        'name': isTamil ? 'குழாய்கள் & ஃபிட்டிங்ஸ்' : 'Plumbing & Pipes',
        'quantity': totalArea,
        'unit': 'sqft',
        'type': 'plumbing'
      },
    };

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Reset Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isTamil
                      ? 'பிராண்ட் தேர்வு & நேரலை விலை'
                      : 'Live Brand Customizer',
                  style: GoogleFonts.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTitle,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_customMaterialPrices.isNotEmpty)
                GestureDetector(
                  onTap: _resetCustomizations,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      isTamil ? 'மீட்டமை' : 'Reset Rates',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Custom Material Search Widget
          MaterialSearchWidget(onSelected: _onBrandSelected),
          const SizedBox(height: 14),

          // Material Brand Cards List
          ...activeMaterials.entries.map((e) {
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
                (availableBrands.isNotEmpty
                    ? availableBrands.first['name']
                    : '');

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _customMaterialPrices.containsKey(key)
                      ? AppColors.primary
                      : AppColors.borderLight,
                  width: _customMaterialPrices.containsKey(key) ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['name'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${qty.toInt()} ${m['unit']} · ₹${price.toInt()}/${m['unit']}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${_formatIndianCurrency(itemTotal.round())}',
                        style: GoogleFonts.syne(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ],
                  ),
                  if (availableBrands.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: availableBrands
                                  .any((b) => b['name'] == selectedBrandName)
                              ? selectedBrandName
                              : availableBrands.first['name'],
                          isDense: true,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: AppColors.textTitle,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTitle,
                          ),
                          items: availableBrands.map((b) {
                            return DropdownMenuItem<String>(
                              value: b['name'] as String,
                              child: Text(
                                '${b['name']} — ₹${(b['price'] as num).toInt()} / ${b['unit']}',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTitle,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
          }),

          // User Added Custom Materials
          if (_addedCustomMaterials.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              isTamil
                  ? 'கூடுதலாக சேர்க்கப்பட்ட பொருட்கள்'
                  : 'Added Custom Materials',
              style: GoogleFonts.syne(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 8),
            ..._addedCustomMaterials.map((item) {
              final double price =
                  _customMaterialPrices[item.type] ?? item.price;
              final double qty = _customMaterialQty[item.type] ?? 1.0;
              final double subtotal = price * qty;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.surfaceSecondary,
                      child:
                          Icon(item.icon, size: 14, color: AppColors.textTitle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${qty.toInt()} ${item.unit} · ₹${price.toInt()}/${item.unit}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${_formatIndianCurrency(subtotal.round())}',
                      style: GoogleFonts.syne(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTitle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.redAccent,
                      ),
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA & HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
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
      {
        'name': 'Polycab Wires + Modular Switches',
        'price': 155.0,
        'unit': 'sqft'
      },
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

  String _formatIndianCurrency(int value) {
    if (value < 0) value = 0;
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
