import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/restroom.dart';

enum _PhotoSource { camera, gallery }

class _EditablePhoto {
  final String path;
  final Uint8List? bytes;

  const _EditablePhoto({required this.path, this.bytes});
}

class EditRestroomPage extends StatefulWidget {
  final Restroom restroom;
  const EditRestroomPage({super.key, required this.restroom});

  @override
  State<EditRestroomPage> createState() => _EditRestroomPageState();
}

class _EditRestroomPageState extends State<EditRestroomPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final Set<String> _selectedAmenities;
  late final List<_EditablePhoto> _editablePhotos;
  late bool _isOpen;
  final ImagePicker _imagePicker = ImagePicker();

  String? _nameError;
  String? _addressError;
  String? _photosError;

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
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.restroom.name);
    _addressController = TextEditingController(text: widget.restroom.address);
    _selectedAmenities = Set<String>.from(widget.restroom.amenities);
    final initialPaths = widget.restroom.photoPaths.isNotEmpty
        ? widget.restroom.photoPaths
        : [widget.restroom.imagePath];
    _editablePhotos = List.generate(initialPaths.length, (index) {
      final bytes = index < widget.restroom.photoBytesList.length
          ? widget.restroom.photoBytesList[index]
          : (index == 0 ? widget.restroom.imageBytes : null);
      return _EditablePhoto(path: initialPaths[index], bytes: bytes);
    });
    _isOpen = widget.restroom.isOpen;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  ImageProvider _photoProvider(_EditablePhoto photo) {
    if (photo.path.startsWith('assets/')) {
      return AssetImage(photo.path);
    }
    if (photo.bytes != null) {
      return MemoryImage(photo.bytes!);
    }
    if (kIsWeb) {
      return const AssetImage('assets/images/pottypal-logo.webp');
    }
    return FileImage(File(photo.path));
  }

  Future<void> _pickFromCamera() async {
    if (_editablePhotos.length >= 4) {
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
          _editablePhotos.add(
            _EditablePhoto(path: pickedFile.path, bytes: bytes),
          );
          _photosError = null;
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
    if (_editablePhotos.length >= 4) {
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

    final remainingSlots = 4 - _editablePhotos.length;

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
        _editablePhotos.addAll(
          List.generate(
            limitedFiles.length,
            (index) => _EditablePhoto(
              path: limitedFiles[index].path,
              bytes: bytesList[index],
            ),
          ),
        );
        _photosError = null;
      });
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
    if (_editablePhotos.length >= 4) {
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

  void _removePhoto(int index) {
    if (_editablePhotos.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least 1 photo is required.'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      _editablePhotos.removeAt(index);
      _photosError = null;
    });
  }

  void _validateAndSave() {
    setState(() {
      _nameError = _nameController.text.trim().isEmpty
          ? 'Restroom name is required'
          : null;
      _addressError = _addressController.text.trim().isEmpty
          ? 'Address is required'
          : null;
      _photosError = _editablePhotos.isEmpty ? 'Add at least 1 photo' : null;
    });

    if (_nameError != null || _addressError != null || _photosError != null) {
      return;
    }

    final firstPhoto = _editablePhotos.first;

    final updated = Restroom(
      imageColor: widget.restroom.imageColor,
      imagePath: firstPhoto.path,
      imageBytes: firstPhoto.bytes,
      photoPaths: _editablePhotos.map((p) => p.path).toList(),
      photoBytesList: _editablePhotos
          .where((p) => p.bytes != null)
          .map((p) => p.bytes!)
          .toList(),
      imageAlignment: widget.restroom.imageAlignment,
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      distance: widget.restroom.distance,
      rating: widget.restroom.rating,
      reviewCount: widget.restroom.reviewCount,
      amenities: _selectedAmenities.toList(),
      cardColor: widget.restroom.cardColor,
      isOpen: _isOpen,
      isUserAdded: widget.restroom.isUserAdded,
    );

    Navigator.pop(context, updated);
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Restroom?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.restroom.name}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, 'deleted');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Edit Restroom',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Delete Restroom',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: widget.restroom.imageProvider,
                      fit: BoxFit.cover,
                      alignment: widget.restroom.imageAlignment,
                    ),
                    Container(color: Colors.black.withValues(alpha: 0.25)),
                    const Center(
                      child: Icon(Icons.image, color: Colors.white54, size: 48),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 12,
                      child: Text(
                        'Editing: ${widget.restroom.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const _SectionLabel(text: 'Restroom Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: _inputDecoration(
                hint: 'e.g. SM City Clark Comfort Room',
                errorText: _nameError,
              ),
            ),

            const SizedBox(height: 16),
            const _SectionLabel(text: 'Address'),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              onChanged: (_) {
                if (_addressError != null) setState(() => _addressError = null);
              },
              decoration: _inputDecoration(
                hint: 'e.g. Jose Abad Santos Ave, Clark',
                errorText: _addressError,
              ),
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionLabel(text: 'Photos'),
                Text(
                  '${_editablePhotos.length}/4',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_photosError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _photosError!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(
                _editablePhotos.length,
                (index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image(
                        image: _photoProvider(_editablePhotos[index]),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removePhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.6),
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
            if (_editablePhotos.length < 4)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: _showPhotoSourcePicker,
                  child: Container(
                    width: double.infinity,
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
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
                          Icons.add_photo_alternate_outlined,
                          size: 30,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add More Photos',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                value: _isOpen,
                onChanged: (v) => setState(() => _isOpen = v),
                activeThumbColor: const Color(0xFF1565C0),
                title: const Text(
                  'Currently Open',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  _isOpen
                      ? 'Restroom is open to the public'
                      : 'Restroom is currently closed',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isOpen ? Colors.green[700] : Colors.red[400],
                  ),
                ),
                secondary: Icon(
                  _isOpen ? Icons.lock_open : Icons.lock,
                  color: _isOpen ? Colors.green[700] : Colors.red[400],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const _SectionLabel(text: 'Amenities'),
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

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _validateAndSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text(
                  'Delete Restroom',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, String? errorText}) {
    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(14),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }
}
