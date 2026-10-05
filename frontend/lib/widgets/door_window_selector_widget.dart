import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DoorStyleOption {
  final String id;
  final String name;
  final String description;
  final String assetPath;
  final String badge;

  const DoorStyleOption({
    required this.id,
    required this.name,
    required this.description,
    required this.assetPath,
    required this.badge,
  });
}

class WindowStyleOption {
  final String id;
  final String name;
  final String description;
  final String assetPath;
  final String badge;

  const WindowStyleOption({
    required this.id,
    required this.name,
    required this.description,
    required this.assetPath,
    required this.badge,
  });
}

const List<DoorStyleOption> doorStyleOptions = [
  DoorStyleOption(
    id: 'glass',
    name: 'Door Option 3: Glass Insert Mahogany',
    description: 'Dark mahogany wood door with frosted glass insert & long black handle.',
    assetPath: 'assets/images/door_glass.jpg',
    badge: 'SELECTED (OPTION 3)',
  ),
  DoorStyleOption(
    id: 'teak',
    name: 'Door Option 1: Modern Teak Wood',
    description: 'Sleek vertical teak wood grain with long stainless steel handle.',
    assetPath: 'assets/images/door_teak.jpg',
    badge: 'OPTION 1',
  ),
  DoorStyleOption(
    id: 'panel',
    name: 'Door Option 2: Classic Mahogany Panel',
    description: 'Rich mahogany door with 4 raised rectangular panels & brass handle.',
    assetPath: 'assets/images/door_panel.jpg',
    badge: 'OPTION 2',
  ),
];

const List<WindowStyleOption> windowStyleOptions = [
  WindowStyleOption(
    id: 'wood',
    name: 'Window Option 2: Teak Wooden Frame',
    description: 'Traditional solid teak wood frame window with glass shutters.',
    assetPath: 'assets/images/window_wood.jpg',
    badge: 'SELECTED (OPTION 2)',
  ),
  WindowStyleOption(
    id: 'upvc',
    name: 'Window Option 1: UPVC Sliding Window',
    description: 'White 3-track UPVC sliding window with clear glass & mosquito mesh.',
    assetPath: 'assets/images/window_upvc.jpg',
    badge: 'OPTION 1',
  ),
  WindowStyleOption(
    id: 'black',
    name: 'Window Option 3: Black Aluminum Window',
    description: 'Modern black anodized aluminum frame with double glazing.',
    assetPath: 'assets/images/window_black.jpg',
    badge: 'OPTION 3',
  ),
];

class DoorWindowSelectorWidget extends StatefulWidget {
  final String currentDoorStyle;
  final String currentWindowStyle;
  final Function(String doorStyle) onDoorStyleChanged;
  final Function(String windowStyle) onWindowStyleChanged;
  final Function(XFile customImage, String type)? onCustomImageUploaded;

  const DoorWindowSelectorWidget({
    super.key,
    this.currentDoorStyle = 'glass',
    this.currentWindowStyle = 'wood',
    required this.onDoorStyleChanged,
    required this.onWindowStyleChanged,
    this.onCustomImageUploaded,
  });

  @override
  State<DoorWindowSelectorWidget> createState() =>
      _DoorWindowSelectorWidgetState();
}

class _DoorWindowSelectorWidgetState extends State<DoorWindowSelectorWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedDoor;
  late String _selectedWindow;
  XFile? _customDoorImage;
  XFile? _customWindowImage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDoor = widget.currentDoorStyle;
    _selectedWindow = widget.currentWindowStyle;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomImage(String category) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (category == 'door') {
          _customDoorImage = image;
          _selectedDoor = 'custom';
          widget.onDoorStyleChanged('custom');
        } else {
          _customWindowImage = image;
          _selectedWindow = 'custom';
          widget.onWindowStyleChanged('custom');
        }
      });
      widget.onCustomImageUploaded?.call(image, category);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ Custom $category image uploaded successfully!'),
          backgroundColor: const Color(0xFF2979FF),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 720,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2979FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.door_sliding_outlined,
                        color: Color(0xFF2979FF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Realistic Door & Window Selection',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Selected Door Option 3 & Window Option 2 for 3D Model',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFF2979FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: '🚪 Door Designs'),
                  Tab(text: '🪟 Window Designs'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab View Body
            SizedBox(
              height: 400,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDoorTab(),
                  _buildWindowTab(),
                ],
              ),
            ),

            const SizedBox(height: 16),
            // Footer Action
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2979FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Apply Selection to 3D Model',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoorTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: doorStyleOptions.map((opt) {
              final isSelected = _selectedDoor == opt.id;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedDoor = opt.id);
                    widget.onDoorStyleChanged(opt.id);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2979FF)
                            : const Color(0xFFE2E8F0),
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2979FF).withValues(alpha: 0.15),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                opt.assetPath,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF2979FF) : Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  opt.badge,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (isSelected)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2979FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          opt.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          opt.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Upload custom door option
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            onPressed: () => _pickCustomImage('door'),
            icon: const Icon(Icons.add_photo_alternate_outlined,
                color: Color(0xFF2979FF)),
            label: Text(
              _customDoorImage != null
                  ? 'Custom Door Uploaded: ${_customDoorImage!.name}'
                  : 'Upload Custom Door Image',
              style: const TextStyle(
                color: Color(0xFF2979FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: windowStyleOptions.map((opt) {
              final isSelected = _selectedWindow == opt.id;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedWindow = opt.id);
                    widget.onWindowStyleChanged(opt.id);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2979FF)
                            : const Color(0xFFE2E8F0),
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2979FF).withValues(alpha: 0.15),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                opt.assetPath,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF2979FF) : Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  opt.badge,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (isSelected)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2979FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          opt.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          opt.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Upload custom window option
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            onPressed: () => _pickCustomImage('window'),
            icon: const Icon(Icons.add_photo_alternate_outlined,
                color: Color(0xFF2979FF)),
            label: Text(
              _customWindowImage != null
                  ? 'Custom Window Uploaded: ${_customWindowImage!.name}'
                  : 'Upload Custom Window Image',
              style: const TextStyle(
                color: Color(0xFF2979FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
