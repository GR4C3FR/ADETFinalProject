import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

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

class Restroom {
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
  final bool manualIsOpen;
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

  List<ImageProvider> get photoProviders {
    if (photoPaths.isEmpty) return [imageProvider];

    return List.generate(photoPaths.length, (index) {
      final bytes = index < photoBytesList.length
          ? photoBytesList[index]
          : null;
      return _providerFor(photoPaths[index], bytes);
    });
  }

  static DateTime nowInPhilippines([DateTime? now]) {
    final utcNow = now?.toUtc() ?? DateTime.now().toUtc();
    return utcNow.add(const Duration(hours: 8));
  }

  bool get hasSchedule => openingTime != null && closingTime != null;

  int _minutesFromTimeOfDay(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  String _formatTime(TimeOfDay time) {
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  String get operatingHoursLabel {
    if (!hasSchedule) return 'Hours not set';
    return '${_formatTime(openingTime!)} - ${_formatTime(closingTime!)}';
  }

  String get availabilityStatusText {
    if (!hasSchedule) {
      return isOpen ? 'Open now' : 'Currently closed';
    }

    final openMinutes = _minutesFromTimeOfDay(openingTime!);
    final closeMinutes = _minutesFromTimeOfDay(closingTime!);

    if (openMinutes == closeMinutes) {
      return 'Open 24 hours';
    }

    return isOpen
        ? 'Open until ${_formatTime(closingTime!)}'
        : 'Opens at ${_formatTime(openingTime!)}';
  }

  bool get isOpen {
    if (!hasSchedule) return manualIsOpen;

    final now = nowInPhilippines();
    final nowMinutes = now.hour * 60 + now.minute;
    final openMinutes = _minutesFromTimeOfDay(openingTime!);
    final closeMinutes = _minutesFromTimeOfDay(closingTime!);

    if (openMinutes == closeMinutes) return true;

    if (closeMinutes > openMinutes) {
      return nowMinutes >= openMinutes && nowMinutes < closeMinutes;
    }

    return nowMinutes >= openMinutes || nowMinutes < closeMinutes;
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
  }) : manualIsOpen = isOpen,
       photoPaths = List.unmodifiable(photoPaths ?? [imagePath]),
       photoBytesList = List.unmodifiable(
         photoBytesList ?? (imageBytes != null ? [imageBytes] : const []),
       );
}
