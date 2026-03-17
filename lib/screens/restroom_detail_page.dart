import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import '../models/restroom.dart';
import '../utils/slide_route.dart';
import 'edit_restroom_page.dart';

class _DetailPhoto {
  final String path;
  final Uint8List? bytes;

  const _DetailPhoto({required this.path, this.bytes});
}

class RestroomDetailPage extends StatefulWidget {
  final Restroom restroom;
  final bool isSaved;
  final VoidCallback? onToggleSaved;
  final int flagCount;
  final void Function(String reason)? onSubmitFlag;
  final List<RestroomReview> initialReviews;
  final void Function(double rating, String comment)? onSubmitReview;
  final void Function(Restroom updatedRestroom)? onRestroomChanged;
  final VoidCallback? onGetDirections;

  const RestroomDetailPage({
    super.key,
    required this.restroom,
    this.isSaved = false,
    this.onToggleSaved,
    this.flagCount = 0,
    this.onSubmitFlag,
    this.initialReviews = const [],
    this.onSubmitReview,
    this.onRestroomChanged,
    this.onGetDirections,
  });

  @override
  State<RestroomDetailPage> createState() => _RestroomDetailPageState();
}

class _RestroomDetailPageState extends State<RestroomDetailPage> {
  static const Map<String, IconData> _amenityIcons = {
    'Soap': Icons.soap,
    'Tissue': Icons.receipt_long,
    'Spacious': Icons.zoom_out_map,
    'PWD': Icons.accessible,
    'PWD Friendly': Icons.accessible,
    'Bidet': Icons.water_drop,
    'Clean': Icons.cleaning_services,
    'Lock': Icons.lock,
    'Accessible': Icons.accessible,
    'No Fee': Icons.money_off,
    'Free': Icons.money_off,
  };

  final TextEditingController _reviewController = TextEditingController();
  final ScrollController _photoScrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  late bool _isSaved;
  late int _flagCount;
  late List<RestroomReview> _reviews;
  late Restroom _restroom;
  late List<_DetailPhoto> _photos;
  double _selectedRating = 0;
  bool _canScrollPhotosPrev = false;
  bool _canScrollPhotosNext = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
    _flagCount = widget.flagCount;
    _reviews = List<RestroomReview>.from(widget.initialReviews);
    if (_reviews.isNotEmpty) {
      _selectedRating = _reviews.first.rating;
      _reviewController.text = _reviews.first.comment;
    }
    _restroom = widget.restroom;
    _photos = List.generate(_restroom.photoPaths.length, (index) {
      final bytes = index < _restroom.photoBytesList.length
          ? _restroom.photoBytesList[index]
          : (index == 0 ? _restroom.imageBytes : null);
      return _DetailPhoto(path: _restroom.photoPaths[index], bytes: bytes);
    });
    _photoScrollController.addListener(_onPhotoScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshPhotoScrollState();
    });
  }

  void _applyPhotoChanges() {
    if (_photos.isEmpty) return;

    final first = _photos.first;
    final updated = Restroom(
      imageColor: _restroom.imageColor,
      imagePath: first.path,
      imageBytes: first.bytes,
      photoPaths: _photos.map((p) => p.path).toList(),
      photoBytesList: _photos
          .map((p) => p.bytes)
          .whereType<Uint8List>()
          .toList(),
      imageAlignment: _restroom.imageAlignment,
      name: _restroom.name,
      address: _restroom.address,
      latitude: _restroom.latitude,
      longitude: _restroom.longitude,
      distance: _restroom.distance,
      rating: _restroom.rating,
      reviewCount: _restroom.reviewCount,
      amenities: _restroom.amenities,
      cardColor: _restroom.cardColor,
      isOpen: _restroom.isOpen,
      openingTime: _restroom.openingTime,
      closingTime: _restroom.closingTime,
      isUserAdded: _restroom.isUserAdded,
    );

    setState(() {
      _restroom = updated;
    });
    widget.onRestroomChanged?.call(updated);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshPhotoScrollState();
    });
  }

  bool _canRemovePhoto(int index) {
    return !_photos[index].path.startsWith('assets/');
  }

  void _removePhoto(int index) {
    if (_photos.length <= 1) return;
    if (!_canRemovePhoto(index)) return;

    setState(() {
      _photos.removeAt(index);
    });
    _applyPhotoChanges();
  }

  Future<void> _addPhotoFromGallery() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _photos.add(_DetailPhoto(path: picked.path, bytes: bytes));
    });
    _applyPhotoChanges();
  }

  Future<void> _addPhotoFromCamera() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _photos.add(_DetailPhoto(path: picked.path, bytes: bytes));
    });
    _applyPhotoChanges();
  }

  Future<void> _showAddPhotoPicker() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    if (source == ImageSource.camera) {
      await _addPhotoFromCamera();
    } else {
      await _addPhotoFromGallery();
    }
  }

  ImageProvider _imageProviderFor(String path, Uint8List? bytes) {
    if (path.startsWith('assets/')) {
      return AssetImage(path);
    }

    if (bytes != null) {
      return MemoryImage(bytes);
    }

    if (kIsWeb) {
      return const AssetImage('assets/images/pottypal-logo.webp');
    }

    return FileImage(File(path));
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _photoScrollController.removeListener(_onPhotoScroll);
    _photoScrollController.dispose();
    super.dispose();
  }

  void _onPhotoScroll() {
    _refreshPhotoScrollState();
  }

  void _refreshPhotoScrollState() {
    bool canPrev = false;
    bool canNext = false;

    if (_photoScrollController.hasClients) {
      final pos = _photoScrollController.position;
      const epsilon = 0.5;
      canPrev = pos.pixels > epsilon;
      canNext = pos.pixels < (pos.maxScrollExtent - epsilon);
    }

    if (canPrev != _canScrollPhotosPrev || canNext != _canScrollPhotosNext) {
      setState(() {
        _canScrollPhotosPrev = canPrev;
        _canScrollPhotosNext = canNext;
      });
    }
  }

  Future<void> _scrollPhotos({required bool forward}) async {
    if (!_photoScrollController.hasClients) return;
    const step = 130.0;
    final pos = _photoScrollController.position;
    final target = forward
        ? (pos.pixels + step).clamp(0.0, pos.maxScrollExtent)
        : (pos.pixels - step).clamp(0.0, pos.maxScrollExtent);
    await _photoScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<String?> _showFlagReasonDialog(BuildContext context) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Flag For Removal'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter reason for flagging this restroom',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _submitReview() {
    final comment = _reviewController.text.trim();
    if (_selectedRating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a star rating.')),
      );
      return;
    }

    final review = RestroomReview(
      rating: _selectedRating,
      comment: comment,
      createdAt: DateTime.now(),
    );

    final isEditingExisting = _reviews.isNotEmpty;

    setState(() {
      if (isEditingExisting) {
        _reviews[0] = review;
      } else {
        _reviews.insert(0, review);
      }
    });

    widget.onSubmitReview?.call(review.rating, review.comment);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditingExisting ? 'Review updated.' : 'Review submitted.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restroom = _restroom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          restroom.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: restroom.isUserAdded ? 0 : 8),
            child: IconButton(
              onPressed: () {
                setState(() {
                  _isSaved = !_isSaved;
                });
                widget.onToggleSaved?.call();
              },
              icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: Colors.white,
              ),
              tooltip: _isSaved ? 'Remove bookmark' : 'Save restroom',
            ),
          ),
          if (restroom.isUserAdded)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () async {
                  final result = await Navigator.push<Object?>(
                    context,
                    slideRoute(
                      page: EditRestroomPage(restroom: restroom),
                      fromRight: true,
                    ),
                  );
                  if (!context.mounted) return;
                  if (result == 'deleted') {
                    Navigator.pop(context, 'deleted');
                  } else if (result is Restroom) {
                    Navigator.pop(context, result);
                  }
                },
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                tooltip: 'Edit Restroom',
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 240,
              width: double.infinity,
              child: Image(
                image: restroom.imageProvider,
                fit: BoxFit.cover,
                alignment: restroom.imageAlignment,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restroom.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (index) => Icon(
                          Icons.star,
                          color: index < restroom.rating.toInt()
                              ? Colors.amber
                              : Colors.grey.shade300,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${restroom.rating}  (${restroom.reviewCount})',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFF1565C0),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              restroom.address,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_flagCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.flag_rounded,
                            size: 16,
                            color: Colors.deepOrange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_flagCount flag${_flagCount == 1 ? '' : 's'} reported',
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final reason = await _showFlagReasonDialog(context);
                        if (!context.mounted) return;
                        if (reason == null || reason.isEmpty) return;

                        widget.onSubmitFlag?.call(reason);
                        setState(() {
                          _flagCount += 1;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Flag submitted.'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.flag_outlined,
                        color: Colors.deepOrange,
                      ),
                      label: const Text(
                        'Flag For Removal',
                        style: TextStyle(color: Colors.deepOrange),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.deepOrange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Amenities',
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
                      final circleSize = constraints.maxWidth < 330
                          ? 44.0
                          : 52.0;
                      final iconSize = constraints.maxWidth < 330 ? 18.0 : 20.0;

                      return Wrap(
                        alignment: WrapAlignment.start,
                        spacing: 12,
                        runSpacing: 12,
                        children:
                            [
                              'Soap',
                              'Tissue',
                              'Spacious',
                              'PWD',
                              'Bidet',
                              'Clean',
                              'Lock',
                              'Accessible',
                              'No Fee',
                            ].map((amenity) {
                              final isAvailable = restroom.amenities.any(
                                (a) => a.toLowerCase() == amenity.toLowerCase(),
                              );
                              return SizedBox(
                                width: itemWidth,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      width: circleSize,
                                      height: circleSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isAvailable
                                              ? const Color(0xFF1565C0)
                                              : Colors.grey.shade300,
                                          width: 2,
                                        ),
                                        color: isAvailable
                                            ? const Color(0xFF1565C0)
                                            : Colors.transparent,
                                      ),
                                      child: Icon(
                                        _amenityIcons[amenity] ??
                                            Icons.check_circle_outline,
                                        color: isAvailable
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
                                        color: isAvailable
                                            ? Colors.black87
                                            : Colors.grey.shade400,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Text(
                        'Photos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Add photo',
                        onPressed: _showAddPhotoPicker,
                        icon: const Icon(Icons.add_a_photo_outlined),
                      ),
                      IconButton(
                        tooltip: 'Previous photo',
                        onPressed: _canScrollPhotosPrev
                            ? () => _scrollPhotos(forward: false)
                            : null,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      IconButton(
                        tooltip: 'Next photo',
                        onPressed: _canScrollPhotosNext
                            ? () => _scrollPhotos(forward: true)
                            : null,
                        icon: const Icon(Icons.arrow_forward_ios_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      controller: _photoScrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final imageProvider = _imageProviderFor(
                          _photos[index].path,
                          _photos[index].bytes,
                        );
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _PhotoViewerPage(
                                  photos: _photos
                                      .map(
                                        (p) =>
                                            _imageProviderFor(p.path, p.bytes),
                                      )
                                      .toList(),
                                  initialIndex: index,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.grey.shade200,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image(
                                    image: imageProvider,
                                    fit: BoxFit.cover,
                                    alignment: restroom.imageAlignment,
                                  ),
                                  if (_canRemovePhoto(index))
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: InkWell(
                                        onTap: () => _removePhoto(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.65,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Your Rating',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      return IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedRating = value.toDouble();
                          });
                        },
                        icon: Icon(
                          value <= _selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: _reviewController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write your review here (optional)...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _reviews.isNotEmpty ? 'Update Review' : 'Submit Review',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Reviews',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_reviews.isEmpty)
                    const Text(
                      'No reviews yet. Be the first to review this restroom.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Column(
                      children: _reviews.map((review) {
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAFD),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE1E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ...List.generate(
                                    5,
                                    (index) => Icon(
                                      Icons.star,
                                      size: 14,
                                      color: index < review.rating.round()
                                          ? Colors.amber
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    review.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                review.comment.isEmpty
                                    ? 'No written review.'
                                    : review.comment,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onGetDirections,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Get Directions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoViewerPage extends StatefulWidget {
  final List<ImageProvider> photos;
  final int initialIndex;

  const _PhotoViewerPage({required this.photos, required this.initialIndex});

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;

  void _goToPrevious() {
    if (_currentIndex <= 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goToNext() {
    if (_currentIndex >= widget.photos.length - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Photo ${_currentIndex + 1} of ${widget.photos.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image(image: widget.photos[i], fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: Row(
              children: [
                IconButton(
                  onPressed: _currentIndex == 0 ? null : _goToPrevious,
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _currentIndex == widget.photos.length - 1
                      ? null
                      : _goToNext,
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
