class ApiRestroomPlace {
  final String name;
  final String fullAddress;
  final double latitude;
  final double longitude;

  const ApiRestroomPlace({
    required this.name,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
  });

  factory ApiRestroomPlace.fromJson(Map<String, dynamic> json) {
    final displayName = (json['display_name'] as String? ?? '').trim();
    final derivedName = displayName.isEmpty
        ? 'Public Restroom'
        : displayName.split(',').first.trim();

    final latValue = double.tryParse(json['lat']?.toString() ?? '0') ?? 0;
    final lonValue = double.tryParse(json['lon']?.toString() ?? '0') ?? 0;

    return ApiRestroomPlace(
      name: derivedName,
      fullAddress: displayName,
      latitude: latValue,
      longitude: lonValue,
    );
  }
}
