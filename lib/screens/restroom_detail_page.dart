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
  final List<RestroomFlag> initialFlags;
  final void Function(List<RestroomReview> reviews)? onReviewsChanged;
  final void Function(List<RestroomFlag> flags)? onFlagsChanged;
  final void Function(Restroom updatedRestroom)? onRestroomChanged;
  final VoidCallback? onGetDirections;
  final String restroomActivityLabel;

  const RestroomDetailPage({
    super.key,
    required this.restroom,
    this.isSaved = false,
    this.onToggleSaved,
    this.flagCount = 0,
    this.onSubmitFlag,
    this.initialReviews = const [],
    this.initialFlags = const [],
    this.onReviewsChanged,
    this.onFlagsChanged,
    this.onRestroomChanged,
    this.onGetDirections,
    required this.restroomActivityLabel,
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
  late List<RestroomReview> _reviews;
  late List<RestroomFlag> _flags;
  late Restroom _restroom;
  late List<_DetailPhoto> _photos;
  double _selectedRating = 0;
  bool _canScrollPhotosPrev = false;
  bool _canScrollPhotosNext = false;
  late String _restroomActivityLabel;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
    _reviews = List<RestroomReview>.from(widget.initialReviews);
    _flags = List<RestroomFlag>.from(widget.initialFlags);
    if (_reviews.isNotEmpty) {
      _selectedRating = _reviews.first.rating;
      _reviewController.text = _reviews.first.comment;
    }
    _restroom = widget.restroom;
    _restroomActivityLabel = widget.restroomActivityLabel;
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
      photoBytesList: _photos.map((p) => p.bytes).toList(),
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
      createdAt: _restroom.createdAt,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _restroom = updated;
      _restroomActivityLabel = _buildActivityLabel(updated.createdAt);
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

    final isEditingExisting = _reviews.isNotEmpty;
    final previous = isEditingExisting ? _reviews.first : null;
    final review = RestroomReview(
      rating: _selectedRating,
      comment: comment,
      createdAt: previous?.createdAt ?? DateTime.now(),
      updatedAt: previous == null ? null : DateTime.now(),
    );

    setState(() {
      if (isEditingExisting) {
        _reviews[0] = review;
      } else {
        _reviews.insert(0, review);
      }
    });

    widget.onReviewsChanged?.call(List<RestroomReview>.from(_reviews));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditingExisting ? 'Review updated.' : 'Review submitted.',
        ),
      ),
    );
  }

  String _timeAgo(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inDays >= 30) {
      return _formatDate(value);
    }
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds <= 1 ? 1 : diff.inSeconds} sec ago';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hr ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    }
    final months = (diff.inDays / 30).floor();
    return '$months mo${months == 1 ? '' : 's'} ago';
  }

  String _formatDate(DateTime value) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[value.month - 1];
    final day = value.day.toString().padLeft(2, '0');
    return '$month $day, ${value.year}';
  }

  String _buildActivityLabel(DateTime value) {
    return _timeAgo(value);
  }

  String get _latestReviewLabel {
    if (_reviews.isEmpty) {
      return _buildActivityLabel(_restroom.createdAt);
    }
    DateTime latest = _reviews.first.latestChangeAt;
    for (final review in _reviews.skip(1)) {
      if (review.latestChangeAt.isAfter(latest)) {
        latest = review.latestChangeAt;
      }
    }
    return _buildActivityLabel(latest);
  }

  String get _latestFlagLabel {
    if (_flags.isEmpty) {
      return _buildActivityLabel(_restroom.createdAt);
    }
    DateTime latest = _flags.first.latestChangeAt;
    for (final flag in _flags.skip(1)) {
      if (flag.latestChangeAt.isAfter(latest)) {
        latest = flag.latestChangeAt;
      }
    }
    return _buildActivityLabel(latest);
  }

  int get _displayReviewCount => _restroom.reviewCount + _reviews.length;

  double get _displayRating {
    final baseTotal = _restroom.rating * _restroom.reviewCount;
    final userTotal = _reviews.fold<double>(
      0,
      (sum, review) => sum + review.rating,
    );
    final totalCount = _displayReviewCount;
    if (totalCount <= 0) return 0;
    return double.parse(
      ((baseTotal + userTotal) / totalCount).toStringAsFixed(1),
    );
  }

  void _deleteReview(int index) {
    if (index < 0 || index >= _reviews.length) return;

    setState(() {
      _reviews.removeAt(index);
      if (_reviews.isEmpty) {
        _selectedRating = 0;
        _reviewController.clear();
      } else {
        final newest = _reviews.first;
        _selectedRating = newest.rating;
        _reviewController.text = newest.comment;
      }
    });

    widget.onReviewsChanged?.call(List<RestroomReview>.from(_reviews));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Review deleted.')));
  }

  void _addFlag(String reason) {
    setState(() {
      _flags = [
        ..._flags,
        RestroomFlag(reason: reason, createdAt: DateTime.now()),
      ];
    });

    widget.onFlagsChanged?.call(List<RestroomFlag>.from(_flags));
  }

  void _deleteFlag(int index) {
    if (index < 0 || index >= _flags.length) return;
    setState(() {
      _flags.removeAt(index);
    });
    widget.onFlagsChanged?.call(List<RestroomFlag>.from(_flags));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Flag removed.')));
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
                  const SizedBox(height: 4),
                  Text(
                    _restroomActivityLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (index) => Icon(
                          Icons.star,
                          color: index < _displayRating.toInt()
                              ? Colors.amber
                              : Colors.grey.shade300,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_displayRating.toStringAsFixed(1)}  ($_displayReviewCount)',
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
                      child: Column(
                        children: [
                          Row(
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
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                color: Color(0xFF1565C0),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Hours: ${restroom.operatingHoursLabel} (PHT)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueGrey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_flags.isNotEmpty)
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
                            '${_flags.length} flag${_flags.length == 1 ? '' : 's'} reported',
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
                        _addFlag(reason);

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
                      children: _reviews.asMap().entries.map((entry) {
                        final reviewIndex = entry.key;
                        final review = entry.value;
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
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _latestReviewLabel,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.blueGrey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete review',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    color: Colors.red[400],
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _deleteReview(reviewIndex),
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
                  const SizedBox(height: 20),
                  const Text(
                    'Flags',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_flags.isEmpty)
                    const Text(
                      'No flags submitted for this restroom.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    SizedBox(
                      height: _flags.length > 3 ? 210 : (_flags.length * 80.0),
                      child: ListView.builder(
                        itemCount: _flags.length,
                        itemBuilder: (context, index) {
                          final flag = _flags[index];
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFFD7C4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _latestFlagLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(child: Text(flag.reason)),
                                    IconButton(
                                      tooltip: 'Remove flag',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      color: Colors.red[400],
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _deleteFlag(index),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  IgnorePointer(
                    ignoring: _currentIndex == 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _currentIndex == 0 ? 0.35 : 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _goToPrevious,
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IgnorePointer(
                    ignoring: _currentIndex == widget.photos.length - 1,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _currentIndex == widget.photos.length - 1
                          ? 0.35
                          : 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _goToNext,
                          icon: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
