import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class Restroom {
  static const double _referenceLat = 15.1460;
  static const double _referenceLon = 120.5930;

  static const List<String> _defaultImagePaths = [
    'assets/images/angeles-city-library.webp',
    'assets/images/singku.webp',
    'assets/images/sm-city-clark.webp',
  ];

  static const List<Color> _defaultImageColors = [
    Color(0xFF0D47A1),
    Color(0xFF1976D2),
    Color(0xFF42A5F5),
  ];

  static const List<List<String>> _defaultAmenities = [
    ['Soap', 'Tissue', 'Lock', 'PWD'],
    ['Bidet', 'Soap', 'Lock'],
    ['Bidet', 'Soap', 'Tissue', 'Lock', 'Accessible'],
  ];

  final Color imageColor;
  final String imagePath;
  final Uint8List? imageBytes;
  final List<String> photoPaths;
  final List<Uint8List> photoBytesList;
  final Alignment imageAlignment;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String distance;
  final double rating;
  final int reviewCount;
  final List<String> amenities;
  final Color cardColor;
  final bool _isOpenFlag;
  final TimeOfDay? openingTime;
  final TimeOfDay? closingTime;
  final bool isUserAdded;

  ImageProvider _providerFor(String path, Uint8List? bytes) {
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

  ImageProvider get imageProvider {
    if (photoPaths.isNotEmpty) {
      final firstBytes = photoBytesList.isNotEmpty
          ? photoBytesList.first
          : imageBytes;
      return _providerFor(photoPaths.first, firstBytes);
    }

    return _providerFor(imagePath, imageBytes);
  }

  String get availabilityStatusText {
    if (!_isOpenFlag && openingTime == null && closingTime == null) {
      return 'Closed now';
    }

    if (openingTime == null || closingTime == null) {
      return _isOpenFlag ? 'Open now' : 'Closed now';
    }

    if (!isOpen) return 'Closed now';
    if (_isTwentyFourHours()) return 'Open 24 hours';
    return 'Open now';
  }

  bool get isOpen {
    if (!_isOpenFlag) return false;
    if (openingTime == null || closingTime == null) return _isOpenFlag;
    if (_isTwentyFourHours()) return true;

    final now = TimeOfDay.now();
    final nowMinutes = _toMinutes(now);
    final openMinutes = _toMinutes(openingTime!);
    final closeMinutes = _toMinutes(closingTime!);

    if (openMinutes < closeMinutes) {
      return nowMinutes >= openMinutes && nowMinutes < closeMinutes;
    }

    return nowMinutes >= openMinutes || nowMinutes < closeMinutes;
  }

  String get operatingHoursLabel {
    if (openingTime == null || closingTime == null) {
      return 'Hours not available';
    }
    if (_isTwentyFourHours()) return '24 hours';
    return '${_formatTime(openingTime!)} - ${_formatTime(closingTime!)}';
  }

  List<ImageProvider> get photoProviders {
    if (photoPaths.isEmpty) return [imageProvider];

    return List.generate(photoPaths.length, (index) {
      final bytes = index < photoBytesList.length
          ? photoBytesList[index]
          : null;
      return _providerFor(photoPaths[index], bytes);
    });
  }

  Restroom({
    required this.imageColor,
    required this.imagePath,
    this.imageBytes,
    List<String>? photoPaths,
    List<Uint8List>? photoBytesList,
    this.imageAlignment = Alignment.center,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    required this.distance,
    required this.rating,
    required this.reviewCount,
    required this.amenities,
    required this.cardColor,
    required bool isOpen,
    this.openingTime,
    this.closingTime,
    this.isUserAdded = false,
  }) : _isOpenFlag = isOpen,
       photoPaths = List.unmodifiable(photoPaths ?? [imagePath]),
       photoBytesList = List.unmodifiable(
         photoBytesList ?? (imageBytes != null ? [imageBytes] : const []),
       );

  factory Restroom.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final imageIndex = _safeIndex(id, _defaultImagePaths.length);
    final tags = _mapFrom(json['tags']);
    final center = _mapFrom(json['center']);
    final lat =
        _asDouble(json['lat']) ?? _asDouble(center['lat']) ?? _referenceLat;
    final lon =
        _asDouble(json['lon']) ?? _asDouble(center['lon']) ?? _referenceLon;

    return Restroom(
      imageColor: _defaultImageColors[imageIndex],
      imagePath: _defaultImagePaths[imageIndex],
      imageAlignment: imageIndex == 1
          ? const Alignment(0, -0.7)
          : Alignment.center,
      name: _nameFrom(tags, id),
      address: _addressFrom(tags),
      latitude: lat,
      longitude: lon,
      distance: _distanceLabel(lat, lon),
      rating: _ratingFromId(id),
      reviewCount: 12 + (id * 5),
      amenities: _amenitiesFromTags(tags, id),
      cardColor: const Color(0xFFE3F2FD),
      isOpen: _isOpenFromTags(tags),
    );
  }

  static Map<String, dynamic> _mapFrom(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static int _safeIndex(int seed, int length) {
    if (length == 0) return 0;
    return seed.abs() % length;
  }

  static String _addressFrom(Map<String, dynamic> tags) {
    final parts =
        [
              tags['addr:housenumber'],
              tags['addr:street'],
              tags['addr:suburb'],
              tags['addr:city'],
            ]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty);

    final joined = parts.join(', ');
    return joined.isEmpty ? 'Clark area, Angeles City' : joined;
  }

  static String _nameFrom(Map<String, dynamic> tags, int id) {
    final rawName = (tags['name'] as String?)?.trim();
    if (rawName != null && rawName.isNotEmpty) {
      return rawName;
    }

    final operator = (tags['operator'] as String?)?.trim();
    if (operator != null && operator.isNotEmpty) {
      return '$operator Restroom';
    }

    return 'Public Restroom ${_safeIndex(id, 99) + 1}';
  }

  static List<String> _amenitiesFromTags(Map<String, dynamic> tags, int id) {
    final amenities = <String>{};

    final wheelchair =
        '${tags['wheelchair'] ?? tags['toilets:wheelchair'] ?? ''}'
            .toLowerCase();
    if (wheelchair == 'yes') {
      amenities.add('PWD');
      amenities.add('Accessible');
    }

    if ('${tags['fee'] ?? ''}'.toLowerCase() == 'no') {
      amenities.add('No Fee');
    }

    for (final fallback
        in _defaultAmenities[_safeIndex(id, _defaultAmenities.length)]) {
      if (amenities.length >= 4) break;
      amenities.add(fallback);
    }

    return List.unmodifiable(amenities);
  }

  static bool _isOpenFromTags(Map<String, dynamic> tags) {
    final access = '${tags['access'] ?? ''}'.toLowerCase();
    if (access == 'private' || access == 'customers') {
      return false;
    }

    return true;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static String _distanceLabel(double lat, double lon) {
    final distanceInMeters = _haversineDistance(
      _referenceLat,
      _referenceLon,
      lat,
      lon,
    );

    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m away';
    }

    return '${(distanceInMeters / 1000).toStringAsFixed(1)} km away';
  }

  static double _haversineDistance(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) {
    const earthRadiusMeters = 6371000.0;
    final latDelta = _degreesToRadians(endLat - startLat);
    final lonDelta = _degreesToRadians(endLon - startLon);
    final startLatRadians = _degreesToRadians(startLat);
    final endLatRadians = _degreesToRadians(endLat);

    final a =
        math.pow(math.sin(latDelta / 2), 2) +
        math.cos(startLatRadians) *
            math.cos(endLatRadians) *
            math.pow(math.sin(lonDelta / 2), 2);

    final c =
        2 * math.atan2(math.sqrt(a.toDouble()), math.sqrt(1 - a.toDouble()));
    return earthRadiusMeters * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  static double _ratingFromId(int id) {
    final rating = 3.6 + (_safeIndex(id, 5) * 0.25);
    return double.parse(rating.toStringAsFixed(1));
  }

  bool _isTwentyFourHours() {
    if (openingTime == null || closingTime == null) return false;
    return openingTime!.hour == closingTime!.hour &&
        openingTime!.minute == closingTime!.minute;
  }

  static String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  static int _toMinutes(TimeOfDay time) {
    return (time.hour * 60) + time.minute;
  }
}

class RestroomReview {
  final double rating;
  final String comment;
  final DateTime createdAt;

  const RestroomReview({
    required this.rating,
    required this.comment,
    required this.createdAt,
  });
}
