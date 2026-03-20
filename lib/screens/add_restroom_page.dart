import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../models/restroom.dart';

enum _PhotoSource { camera, gallery }

class _SelectedImage {
  final String path;
  final Uint8List bytes;

  const _SelectedImage({required this.path, required this.bytes});
}

class AddRestroomPage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const AddRestroomPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<AddRestroomPage> createState() => _AddRestroomPageState();
}

class _AddRestroomPageState extends State<AddRestroomPage> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final Set<String> _selectedAmenities = {};
  final List<_SelectedImage> _selectedImages = [];
  TimeOfDay _openingTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 17, minute: 0);
  bool _open24Hours = false;
  String? _nameError;
  String? _addressError;
  String? _imagesError;
  final ImagePicker _imagePicker = ImagePicker();

  final List<String> _amenityOptions = [
    'Soap',
    'Tissue',
    'Spacious',
    'PWD',
    'Bidet',
    'Clean',
    'Lock',
    'Accessible',
    'No Fee',
  ];

  static const Map<String, IconData> _amenityIcons = {
    'Soap': Icons.soap,
    'Tissue': Icons.receipt_long,
    'Spacious': Icons.zoom_out_map,
    'PWD': Icons.accessible,
    'Bidet': Icons.water_drop,
    'Clean': Icons.cleaning_services,
    'Lock': Icons.lock,
    'Accessible': Icons.accessible,
    'No Fee': Icons.money_off,
    'Free': Icons.money_off,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    if (_selectedImages.length >= 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 4 photos allowed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (pickedFile != null && mounted) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImages.add(
            _SelectedImage(path: pickedFile.path, bytes: bytes),
          );
          _imagesError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_selectedImages.length >= 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 4 photos allowed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    final remainingSlots = 4 - _selectedImages.length;

    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 80,
      );

      if (pickedFiles.isEmpty || !mounted) return;

      final limitedFiles = pickedFiles.take(remainingSlots).toList();
      final bytesList = await Future.wait(
        limitedFiles.map((file) => file.readAsBytes()),
      );

      setState(() {
        _selectedImages.addAll(
          List.generate(
            limitedFiles.length,
            (index) => _SelectedImage(
              path: limitedFiles[index].path,
              bytes: bytesList[index],
            ),
          ),
        );
        _imagesError = null;
      });

      if (pickedFiles.length > remainingSlots && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only $remainingSlots photo${remainingSlots == 1 ? '' : 's'} were added (max 4).',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _showPhotoSourcePicker() async {
    if (_selectedImages.length >= 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 4 photos allowed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    final source = await showModalBottomSheet<_PhotoSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, _PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, _PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (!mounted || source == null) return;

    if (source == _PhotoSource.camera) {
      await _pickFromCamera();
    } else {
      await _pickFromGallery();
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _pickOpeningTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _openingTime,
      helpText: 'Select opening time',
    );
    if (picked != null) {
      setState(() {
        _openingTime = picked;
      });
    }
  }

  Future<void> _pickClosingTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _closingTime,
      helpText: 'Select closing time',
    );
    if (picked != null) {
      setState(() {
        _closingTime = picked;
      });
    }
  }

  void _validateAndSubmit() {
    setState(() {
      _nameError = _nameController.text.isEmpty
          ? 'Restroom name is required'
          : null;
      _addressError = _addressController.text.isEmpty
          ? 'Address is required'
          : null;
      _imagesError = _selectedImages.isEmpty ? 'Add at least 1 photo' : null;
    });

    if (_nameError == null && _addressError == null && _imagesError == null) {
      final openingTime = _open24Hours
          ? const TimeOfDay(hour: 0, minute: 0)
          : _openingTime;
      final closingTime = _open24Hours
          ? const TimeOfDay(hour: 0, minute: 0)
          : _closingTime;

      final newRestroom = Restroom(
        imageColor: const Color(0xFF1976D2),
        imagePath: _selectedImages.first.path,
        imageBytes: _selectedImages.first.bytes,
        photoPaths: _selectedImages.map((img) => img.path).toList(),
        photoBytesList: _selectedImages.map((img) => img.bytes).toList(),
        name: _nameController.text,
        address: _addressController.text,
        latitude: widget.initialLatitude,
        longitude: widget.initialLongitude,
        distance: '0 m away',
        rating: 0.0,
        reviewCount: 0,
        amenities: _selectedAmenities.toList(),
        cardColor: const Color(0xFFE3F2FD),
        isOpen: true,
        openingTime: openingTime,
        closingTime: closingTime,
        isUserAdded: true,
        createdAt: DateTime.now(),
      );

      Navigator.pop(context, newRestroom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Add New Restroom',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Photos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '${_selectedImages.length}/4',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_imagesError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _imagesError!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              _selectedImages.isEmpty
                  ? GestureDetector(
                      onTap: _showPhotoSourcePicker,
                      child: Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                          color: Colors.grey.shade100,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add Photos',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: List.generate(
                            _selectedImages.length,
                            (index) => Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    _selectedImages[index].bytes,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_selectedImages.length < 4)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: GestureDetector(
                              onTap: _showPhotoSourcePicker,
                              child: Container(
                                width: double.infinity,
                                height: _selectedImages.length == 1 ? 120 : 128,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1.5,
                                    style: BorderStyle.solid,
                                  ),
                                  color: Colors.grey.shade100,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 32,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Add More',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Restroom Name',
                  errorText: _nameError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1565C0),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1565C0),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  hintText: 'Address',
                  errorText: _addressError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1565C0),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1565C0),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1565C0), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Operating Hours (Philippines Time)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _open24Hours,
                      onChanged: (value) {
                        setState(() {
                          _open24Hours = value;
                        });
                      },
                      title: const Text(
                        'Open 24 Hours',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!_open24Hours)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickOpeningTime,
                              icon: const Icon(Icons.schedule),
                              label: Text(
                                'Open: ${_openingTime.format(context)}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickClosingTime,
                              icon: const Icon(Icons.schedule_outlined),
                              label: Text(
                                'Close: ${_closingTime.format(context)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_open24Hours)
                      const Text(
                        'Open and close times will both be set to 12:00 AM.',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Choose Present Amenities',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth < 330
                      ? 52.0
                      : constraints.maxWidth < 420
                      ? 60.0
                      : 64.0;
                  final circleSize = constraints.maxWidth < 330 ? 44.0 : 52.0;
                  final iconSize = constraints.maxWidth < 330 ? 18.0 : 20.0;

                  return Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 12,
                    runSpacing: 12,
                    children: _amenityOptions.map((amenity) {
                      final isSelected = _selectedAmenities.contains(amenity);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedAmenities.remove(amenity);
                            } else {
                              _selectedAmenities.add(amenity);
                            }
                          });
                        },
                        child: SizedBox(
                          width: itemWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: circleSize,
                                height: circleSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF1565C0)
                                        : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                  color: isSelected
                                      ? const Color(0xFF1565C0)
                                      : Colors.transparent,
                                ),
                                child: Icon(
                                  _amenityIcons[amenity] ??
                                      Icons.check_circle_outline,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade400,
                                  size: iconSize,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                amenity,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.black87
                                      : Colors.grey.shade400,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _validateAndSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Create Restroom Location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
