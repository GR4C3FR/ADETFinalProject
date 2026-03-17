import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/restroom.dart';
import 'add_restroom_page.dart';
import 'restroom_detail_page.dart';

class MapPage extends StatefulWidget {
  final List<Restroom> restrooms;
  final void Function(Restroom oldRestroom, Restroom updatedRestroom)
  onRestroomUpdated;
  final void Function(Restroom restroom) onRestroomDeleted;
  final void Function(Restroom restroom) onRestroomAdded;
  final bool Function(Restroom restroom)? isRestroomSaved;
  final void Function(Restroom restroom)? onToggleRestroomSaved;
  final int Function(Restroom restroom)? restroomFlagCount;
  final void Function(Restroom restroom, String reason)? onSubmitRestroomFlag;
  final List<RestroomReview> Function(Restroom restroom)? restroomReviews;
  final void Function(Restroom restroom, double rating, String comment)?
  onSubmitRestroomReview;
  final Restroom? directionsTarget;
  final int directionsRequestId;
  final String searchQuery;
  final bool openNowOnly;
  final bool topRatedOnly;
  final double searchRadiusKm;
  final Set<String> selectedAmenities;
  final ValueChanged<String>? onSearchQueryChanged;
  final ValueChanged<bool>? onOpenNowOnlyChanged;
  final ValueChanged<bool>? onTopRatedOnlyChanged;
  final ValueChanged<double>? onSearchRadiusKmChanged;
  final ValueChanged<Set<String>>? onSelectedAmenitiesChanged;

  const MapPage({
    super.key,
    required this.restrooms,
    required this.onRestroomUpdated,
    required this.onRestroomDeleted,
    required this.onRestroomAdded,
    this.isRestroomSaved,
    this.onToggleRestroomSaved,
    this.restroomFlagCount,
    this.onSubmitRestroomFlag,
    this.restroomReviews,
    this.onSubmitRestroomReview,
    this.directionsTarget,
    this.directionsRequestId = 0,
    this.searchQuery = '',
    this.openNowOnly = false,
    this.topRatedOnly = false,
    this.searchRadiusKm = 0.5,
    this.selectedAmenities = const <String>{},
    this.onSearchQueryChanged,
    this.onOpenNowOnlyChanged,
    this.onTopRatedOnlyChanged,
    this.onSearchRadiusKmChanged,
    this.onSelectedAmenitiesChanged,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage>
    with AutomaticKeepAliveClientMixin<MapPage> {
  static const LatLng _defaultCenter = LatLng(14.5995, 120.9842);
  static const LatLng _hauDemoCenter = LatLng(15.1325230, 120.5901905);
  static const double _returnButtonDistanceMeters = 1200;
  static const double _movementThresholdMeters = 4;
  static const List<String> _amenityOptions = [
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

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _resultsScrollController = ScrollController();
  final GlobalKey _resultsPanelKey = GlobalKey();
  final GlobalKey _routeCardKey = GlobalKey();
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();
  StreamSubscription<Position>? _positionSubscription;

  bool _isLoading = false;
  bool _openNowOnly = false;
  bool _topRatedOnly = false;
  double _searchRadiusKm = 0.5;
  bool _showReturnToUserButton = false;
  bool _isRouting = false;
  bool _isUserMoving = false;
  bool _isResultsExpanded = true;
  bool _canScrollPrevious = false;
  bool _canScrollNext = false;
  double _resultsPanelHeight = 118;
  double _routeCardHeight = 76;
  List<_MapRestroomPoint> _allRestrooms = const [];
  List<LatLng> _routePoints = const [];
  Set<String> _selectedAmenities = <String>{};
  double? _routeDistanceKm;
  double? _routeDurationMinutes;
  String? _routeTargetName;
  String? _routeError;

  LatLng? _userLocation;
  LatLng? _activeMapCenter;
  bool _isSyncingSearchText = false;
  int _lastHandledDirectionsRequestId = -1;

  bool get _hasRouteCard => _routeTargetName != null;

  double get _routeCardBottom => 10 + _resultsPanelHeight + 10;

  double get _returnButtonBottom {
    final extra = _hasRouteCard ? (_routeCardHeight + 10) : 0.0;
    return 10 + _resultsPanelHeight + 10 + extra;
  }

  @override
  void initState() {
    super.initState();
    _openNowOnly = widget.openNowOnly;
    _topRatedOnly = widget.topRatedOnly;
    _searchRadiusKm = widget.searchRadiusKm;
    _selectedAmenities = Set<String>.from(widget.selectedAmenities);
    _searchController.text = widget.searchQuery;
    _syncRestroomsFromWidget();
    _loadCurrentLocation();
    _startLocationTracking();
    _resultsScrollController.addListener(_onResultsScroll);
    _searchController.addListener(_onSearchChanged);
    _maybeHandleDirectionsRequest();
  }

  @override
  void didUpdateWidget(covariant MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRestroomsFromWidget();
    _syncFiltersFromWidget(oldWidget);
    _maybeHandleDirectionsRequest();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _searchController.dispose();
    _resultsScrollController.removeListener(_onResultsScroll);
    _resultsScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!_isSyncingSearchText) {
      widget.onSearchQueryChanged?.call(_searchController.text);
    }
    setState(() {});
  }

  void _syncFiltersFromWidget(MapPage oldWidget) {
    if (widget.searchQuery != _searchController.text) {
      _isSyncingSearchText = true;
      _searchController.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
      _isSyncingSearchText = false;
    }

    if (_openNowOnly != widget.openNowOnly ||
        _topRatedOnly != widget.topRatedOnly ||
        _searchRadiusKm != widget.searchRadiusKm ||
        !setEquals(_selectedAmenities, widget.selectedAmenities)) {
      setState(() {
        _openNowOnly = widget.openNowOnly;
        _topRatedOnly = widget.topRatedOnly;
        _searchRadiusKm = widget.searchRadiusKm;
        _selectedAmenities = Set<String>.from(widget.selectedAmenities);
      });
    }
  }

  void _maybeHandleDirectionsRequest() {
    if (widget.directionsTarget == null) return;
    if (widget.directionsRequestId == _lastHandledDirectionsRequestId) return;

    _lastHandledDirectionsRequestId = widget.directionsRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.directionsTarget == null) return;
      _showDirectionsTo(widget.directionsTarget!);
    });
  }

  Future<void> _startLocationTracking() async {
    final hasPermission = await _hasLocationPermission();
    if (!hasPermission) {
      return;
    }

    try {
      final stream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        ),
      );

      _positionSubscription = stream.listen(
        (position) {
          if (!mounted) return;

          final next = LatLng(position.latitude, position.longitude);
          final previous = _userLocation;
          final movedMeters = previous == null
              ? 0.0
              : _distance.as(LengthUnit.Meter, previous, next);
          final moving =
              (position.speed > 0.8) ||
              (movedMeters >= _movementThresholdMeters);

          if (previous == null ||
              movedMeters >= 1.5 ||
              moving != _isUserMoving) {
            setState(() {
              _userLocation = next;
              _isUserMoving = moving;
            });
          }
        },
        onError: (_) {
          // Ignore location stream errors (e.g., permission denied) and keep map usable.
        },
      );
    } catch (_) {
      // Keep existing behavior if live stream cannot start.
    }
  }

  Future<bool> _hasLocationPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get wantKeepAlive => true;

  void _syncRestroomsFromWidget() {
    setState(() {
      _allRestrooms = widget.restrooms
          .map(_MapRestroomPoint.fromRestroom)
          .toList();
    });
  }

  List<String> get _availableAmenities => _amenityOptions;

  List<_MapRestroomPoint> get _filteredRestrooms {
    final query = _searchController.text.toLowerCase().trim();
    final anchor = _userLocation ?? _activeMapCenter ?? _hauDemoCenter;

    final results = _allRestrooms.where((restroom) {
      final point = _pinPositionFor(restroom, _allRestrooms.indexOf(restroom));
      final distanceKm = _distance.as(LengthUnit.Kilometer, anchor, point);

      final matchesSearch =
          query.isEmpty ||
          restroom.name.toLowerCase().contains(query) ||
          restroom.fullAddress.toLowerCase().contains(query) ||
          restroom.amenities.any((a) => a.toLowerCase().contains(query));
      final matchesOpen = !_openNowOnly || restroom.isOpen;
      final matchesAmenities =
          _selectedAmenities.isEmpty ||
          _selectedAmenities.every(restroom.amenities.contains);
      final matchesTopRated = !_topRatedOnly || restroom.rating >= 3.0;
      final matchesRadius = distanceKm <= _searchRadiusKm;

      return matchesSearch &&
          matchesOpen &&
          matchesAmenities &&
          matchesTopRated &&
          matchesRadius;
    }).toList()..sort((a, b) => b.rating.compareTo(a.rating));

    return results;
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      LatLng center;
      try {
        final position = await _determinePosition();
        center = LatLng(position.latitude, position.longitude);
      } catch (_) {
        center = _hauDemoCenter;
      }

      if (!mounted) return;
      setState(() {
        _userLocation = center;
        _activeMapCenter = center;
        _isLoading = false;
        _showReturnToUserButton = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _userLocation = null;
        _activeMapCenter = _hauDemoCenter;
        _showReturnToUserButton = false;
      });
    }
  }

  Future<Position> _determinePosition() async {
    if (!kIsWeb) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on TimeoutException {
      final fallback = await Geolocator.getLastKnownPosition();
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  void _updateReturnToUserButtonVisibility(LatLng mapCenter) {
    final user = _userLocation;
    if (user == null) {
      if (_showReturnToUserButton) {
        setState(() => _showReturnToUserButton = false);
      }
      return;
    }

    final meters = _distance.as(LengthUnit.Meter, user, mapCenter);
    final shouldShow = meters >= _returnButtonDistanceMeters;
    if (shouldShow != _showReturnToUserButton) {
      setState(() => _showReturnToUserButton = shouldShow);
    }
  }

  void _returnToUserLocation() {
    final user = _userLocation;
    if (user == null) return;
    _mapController.move(user, 15);
    _updateReturnToUserButtonVisibility(user);
  }

  Future<void> _handleMapTapAddRestroom(LatLng tappedPoint) async {
    final result = await Navigator.push<Restroom>(
      context,
      MaterialPageRoute(
        builder: (_) => AddRestroomPage(
          initialLatitude: tappedPoint.latitude,
          initialLongitude: tappedPoint.longitude,
        ),
      ),
    );

    if (!mounted || result == null) return;
    widget.onRestroomAdded(result);
  }

  Future<void> _showDirectionsTo(Restroom restroom) async {
    LatLng? start = _userLocation;
    try {
      final current = await _determinePosition();
      start = LatLng(current.latitude, current.longitude);
      if (mounted) {
        setState(() {
          _userLocation = start;
        });
      }
    } catch (_) {
      // Keep last known location if a fresh reading is unavailable.
    }

    final endLat = restroom.latitude;
    final endLng = restroom.longitude;
    if (start == null || endLat == null || endLng == null) {
      if (!mounted) return;
      setState(() {
        _routeError = 'Unable to generate route for this restroom.';
        _routeTargetName = restroom.name;
        _routePoints = const [];
        _routeDistanceKm = null;
        _routeDurationMinutes = null;
      });
      return;
    }

    final destination = LatLng(endLat, endLng);
    if (mounted) {
      setState(() {
        _isRouting = true;
        _routeError = null;
        _routeTargetName = restroom.name;
      });
    }

    final routeResult = await _fetchFastestRoute(start, destination);

    if (!mounted) return;
    setState(() {
      _isRouting = false;
      _routePoints = routeResult.points;
      _routeDistanceKm = routeResult.distanceKm;
      _routeDurationMinutes = routeResult.durationMinutes;
      _routeError = routeResult.error;
      _activeMapCenter = destination;
    });

    _mapController.move(destination, 15);
  }

  Future<_RouteResult> _fetchFastestRoute(LatLng start, LatLng end) async {
    try {
      final snappedStart = await _snapToNearestRoad(start) ?? start;
      final snappedEnd = await _snapToNearestRoad(end) ?? end;

      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${snappedStart.longitude},${snappedStart.latitude};'
        '${snappedEnd.longitude},${snappedEnd.latitude}'
        '?overview=full&geometries=geojson&alternatives=false&steps=false',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return _fallbackRoute(
          snappedStart,
          snappedEnd,
          'Route service unavailable.',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final apiRoute = _RouteApiResponse.fromJson(data);

      return _RouteResult(
        points: apiRoute.points,
        distanceKm: apiRoute.distanceMeters / 1000,
        durationMinutes: apiRoute.durationSeconds / 60,
      );
    } catch (_) {
      return _fallbackRoute(
        start,
        end,
        'Using direct path (route service timeout).',
      );
    }
  }

  Future<LatLng?> _snapToNearestRoad(LatLng point) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/nearest/v1/driving/'
        '${point.longitude},${point.latitude}?number=1',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final waypoints = data['waypoints'] as List<dynamic>?;
      if (waypoints == null || waypoints.isEmpty) return null;

      final waypoint = waypoints.first as Map<String, dynamic>;
      final location = waypoint['location'] as List<dynamic>?;
      if (location == null || location.length < 2) return null;

      return LatLng(
        (location[1] as num).toDouble(),
        (location[0] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  _RouteResult _fallbackRoute(LatLng start, LatLng end, String error) {
    final meters = _distance.as(LengthUnit.Meter, start, end);
    final estimatedMinutes = (meters / 1000) * 2;
    return _RouteResult(
      points: [start, end],
      distanceKm: meters / 1000,
      durationMinutes: estimatedMinutes,
      error: error,
    );
  }

  LatLng _pinPositionFor(_MapRestroomPoint point, int index) {
    if (point.latitude != 0 || point.longitude != 0) {
      return LatLng(point.latitude, point.longitude);
    }

    final anchor = _userLocation ?? _activeMapCenter ?? _hauDemoCenter;
    final seed = '${point.name}|${point.fullAddress}|$index'.codeUnits
        .fold<int>(0, (acc, n) => acc + n);
    final angle = (seed % 360) * (math.pi / 180);
    final distanceMeters = 140.0 + (seed % 6) * 55.0;

    final latOffset = (distanceMeters / 111320) * math.sin(angle);
    final lonScale = (111320 * math.cos(anchor.latitude * math.pi / 180)).abs();
    final safeLonScale = lonScale < 20000 ? 20000 : lonScale;
    final lonOffset = (distanceMeters / safeLonScale) * math.cos(angle);

    return LatLng(anchor.latitude + latOffset, anchor.longitude + lonOffset);
  }

  Future<void> _scrollResultsBy({required bool forward}) async {
    if (!_resultsScrollController.hasClients) return;

    const itemStep = 228.0;
    final position = _resultsScrollController.position;
    final target = forward
        ? (position.pixels + itemStep).clamp(0.0, position.maxScrollExtent)
        : (position.pixels - itemStep).clamp(0.0, position.maxScrollExtent);

    await _resultsScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _onResultsScroll() {
    _refreshResultsScrollState(filteredCount: _filteredRestrooms.length);
  }

  void _refreshResultsScrollState({required int filteredCount}) {
    bool canScrollPrevious = false;
    bool canScrollNext = false;

    if (filteredCount > 1) {
      if (_resultsScrollController.hasClients) {
        final position = _resultsScrollController.position;
        const epsilon = 0.5;
        canScrollPrevious = position.pixels > epsilon;
        canScrollNext = position.pixels < (position.maxScrollExtent - epsilon);
      } else {
        canScrollNext = true;
      }
    }

    if (canScrollPrevious != _canScrollPrevious ||
        canScrollNext != _canScrollNext) {
      setState(() {
        _canScrollPrevious = canScrollPrevious;
        _canScrollNext = canScrollNext;
      });
    }
  }

  void _updateResultsPanelHeight() {
    final context = _resultsPanelKey.currentContext;
    if (context == null) return;
    final size = context.size;
    if (size == null) return;

    if ((_resultsPanelHeight - size.height).abs() > 1) {
      setState(() {
        _resultsPanelHeight = size.height;
      });
    }
  }

  void _updateRouteCardHeight() {
    final context = _routeCardKey.currentContext;
    if (context == null) return;
    final size = context.size;
    if (size == null) return;

    if ((_routeCardHeight - size.height).abs() > 1) {
      setState(() {
        _routeCardHeight = size.height;
      });
    }
  }

  void _clearRouteCard() {
    setState(() {
      _routePoints = const [];
      _routeDistanceKm = null;
      _routeDurationMinutes = null;
      _routeTargetName = null;
      _routeError = null;
      _isRouting = false;
    });
  }

  Future<void> _openAmenityPicker() async {
    final tempSelected = _selectedAmenities.toSet();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final options = _availableAmenities;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amenities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: options.isEmpty
                          ? const Center(
                              child: Text('No amenities available yet.'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 8),
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final amenity = options[index];
                                return CheckboxListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  value: tempSelected.contains(amenity),
                                  title: Text(amenity),
                                  onChanged: (checked) {
                                    setModalState(() {
                                      if (checked ?? false) {
                                        tempSelected.add(amenity);
                                      } else {
                                        tempSelected.remove(amenity);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => setModalState(tempSelected.clear),
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedAmenities = tempSelected;
                            });
                            widget.onSelectedAmenitiesChanged?.call(
                              Set<String>.from(tempSelected),
                            );
                            Navigator.pop(context);
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openRadiusPicker() async {
    double tempRadius = _searchRadiusKm;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search Radius',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${tempRadius.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Slider(
                      value: tempRadius,
                      min: 0.5,
                      max: 20,
                      divisions: 39,
                      label: '${tempRadius.toStringAsFixed(1)} km',
                      onChanged: (value) =>
                          setModalState(() => tempRadius = value),
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () =>
                              setModalState(() => tempRadius = 0.5),
                          child: const Text('Reset'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _searchRadiusKm = tempRadius;
                            });
                            widget.onSearchRadiusKmChanged?.call(tempRadius);
                            Navigator.pop(context);
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final center =
        _activeMapCenter ??
        _userLocation ??
        (_allRestrooms.isNotEmpty
            ? LatLng(
                _allRestrooms.first.latitude,
                _allRestrooms.first.longitude,
              )
            : _defaultCenter);

    final filtered = _filteredRestrooms;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshResultsScrollState(filteredCount: filtered.length);
      _updateResultsPanelHeight();
      _updateRouteCardHeight();
    });

    return Container(
      color: const Color(0xFFF0F4F8),
      child: Stack(
        children: [
          Positioned.fill(child: _buildMapBody(center, filtered)),
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search restrooms...',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Icon(Icons.search, color: Colors.blueGrey),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Open Now'),
                        selected: _openNowOnly,
                        showCheckmark: false,
                        onSelected: (v) {
                          setState(() => _openNowOnly = v);
                          widget.onOpenNowOnlyChanged?.call(v);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Top Rated'),
                        selected: _topRatedOnly,
                        showCheckmark: false,
                        onSelected: (v) {
                          setState(() => _topRatedOnly = v);
                          widget.onTopRatedOnlyChanged?.call(v);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(
                          'Radius (${_searchRadiusKm.toStringAsFixed(1)} km)',
                        ),
                        selected: true,
                        showCheckmark: false,
                        onSelected: (_) => _openRadiusPicker(),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(
                          _selectedAmenities.isEmpty
                              ? 'Amenities'
                              : 'Amenities (${_selectedAmenities.length})',
                        ),
                        selected: _selectedAmenities.isNotEmpty,
                        showCheckmark: false,
                        onSelected: (_) => _openAmenityPicker(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            right: 12,
            bottom: _returnButtonBottom,
            child: IgnorePointer(
              ignoring: !_showReturnToUserButton,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                opacity: _showReturnToUserButton ? 1 : 0,
                child: FloatingActionButton.small(
                  heroTag: 'returnToUserLocation',
                  onPressed: _returnToUserLocation,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1565C0),
                  child: const Icon(Icons.my_location),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            left: 12,
            right: 12,
            bottom: _routeCardBottom,
            child: IgnorePointer(
              ignoring: !_hasRouteCard,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                opacity: _hasRouteCard ? 1 : 0,
                child: Container(
                  key: _routeCardKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Fastest route to ${_routeTargetName ?? ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close route card',
                            onPressed: _clearRouteCard,
                            icon: const Icon(Icons.close_rounded, size: 20),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _isRouting
                            ? const Row(
                                key: ValueKey('routing_progress'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Calculating route...'),
                                ],
                              )
                            : Text(
                                '${_routeDistanceKm?.toStringAsFixed(1) ?? '--'} km • '
                                '${_routeDurationMinutes?.round() ?? '--'} min',
                                key: const ValueKey('routing_stats'),
                                style: const TextStyle(color: Colors.blueGrey),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _isUserMoving
                              ? 'Live location: moving'
                              : 'Live location: stationary',
                          style: TextStyle(
                            fontSize: 11,
                            color: _isUserMoving
                                ? Colors.green[700]
                                : Colors.blueGrey,
                          ),
                        ),
                      ),
                      if (_routeError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _routeError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Container(
              key: _resultsPanelKey,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Results (${filtered.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: _isResultsExpanded
                            ? 'Collapse results'
                            : 'Expand results',
                        onPressed: () {
                          setState(() {
                            _isResultsExpanded = !_isResultsExpanded;
                          });
                        },
                        icon: Icon(
                          _isResultsExpanded
                              ? Icons.expand_more_rounded
                              : Icons.expand_less_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Previous',
                        onPressed: _isResultsExpanded && _canScrollPrevious
                            ? () => _scrollResultsBy(forward: false)
                            : null,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      IconButton(
                        tooltip: 'Next',
                        onPressed: _isResultsExpanded && _canScrollNext
                            ? () => _scrollResultsBy(forward: true)
                            : null,
                        icon: const Icon(Icons.arrow_forward_ios_rounded),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    child: _isResultsExpanded
                        ? (filtered.isEmpty
                              ? const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'No results match your search/filters.',
                                  ),
                                )
                              : SizedBox(
                                  height: 114,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragUpdate: (_) {},
                                    child: ListView.separated(
                                      controller: _resultsScrollController,
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(width: 8),
                                      itemBuilder: (context, index) {
                                        final item = filtered[index];
                                        return InkWell(
                                          onTap: () async {
                                            final result = await Navigator.push<Object?>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => RestroomDetailPage(
                                                  restroom: item.restroom,
                                                  onGetDirections: () {
                                                    Navigator.pop(context);
                                                    _showDirectionsTo(
                                                      item.restroom,
                                                    );
                                                  },
                                                  isSaved:
                                                      widget.isRestroomSaved
                                                          ?.call(
                                                            item.restroom,
                                                          ) ??
                                                      false,
                                                  flagCount:
                                                      widget.restroomFlagCount
                                                          ?.call(
                                                            item.restroom,
                                                          ) ??
                                                      0,
                                                  onToggleSaved:
                                                      widget.onToggleRestroomSaved ==
                                                          null
                                                      ? null
                                                      : () =>
                                                            widget
                                                                .onToggleRestroomSaved!(
                                                              item.restroom,
                                                            ),
                                                  onSubmitFlag:
                                                      widget.onSubmitRestroomFlag ==
                                                          null
                                                      ? null
                                                      : (reason) =>
                                                            widget
                                                                .onSubmitRestroomFlag!(
                                                              item.restroom,
                                                              reason,
                                                            ),
                                                  initialReviews:
                                                      widget.restroomReviews
                                                          ?.call(
                                                            item.restroom,
                                                          ) ??
                                                      const [],
                                                  onSubmitReview:
                                                      widget.onSubmitRestroomReview ==
                                                          null
                                                      ? null
                                                      : (rating, comment) =>
                                                            widget
                                                                .onSubmitRestroomReview!(
                                                              item.restroom,
                                                              rating,
                                                              comment,
                                                            ),
                                                  onRestroomChanged:
                                                      (updatedRestroom) {
                                                        widget
                                                            .onRestroomUpdated(
                                                              item.restroom,
                                                              updatedRestroom,
                                                            );
                                                      },
                                                ),
                                              ),
                                            );

                                            if (!mounted) return;
                                            if (result == 'deleted') {
                                              widget.onRestroomDeleted(
                                                item.restroom,
                                              );
                                            } else if (result is Restroom) {
                                              widget.onRestroomUpdated(
                                                item.restroom,
                                                result,
                                              );
                                            }
                                          },
                                          onLongPress: () {
                                            setState(() {
                                              _activeMapCenter =
                                                  _pinPositionFor(item, index);
                                            });
                                          },
                                          child: Container(
                                            width: 220,
                                            padding: const EdgeInsets.fromLTRB(
                                              10,
                                              8,
                                              10,
                                              8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE3F2FD),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.star,
                                                      color: Colors.amber,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${item.rating.toStringAsFixed(1)}  (${item.reviewCount})',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  item
                                                      .restroom
                                                      .availabilityStatusText,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: item.isOpen
                                                        ? Colors.green[700]
                                                        : Colors.red[700],
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                Text(
                                                  '${item.restroom.operatingHoursLabel} (PHT)',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.blueGrey,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: Row(
                                                    children: item.amenities
                                                        .take(3)
                                                        .map(
                                                          (a) => Container(
                                                            margin:
                                                                const EdgeInsets.only(
                                                                  right: 4,
                                                                ),
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  Colors.white,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                              border: Border.all(
                                                                color:
                                                                    const Color(
                                                                      0xFF1565C0,
                                                                    ),
                                                                width: 0.7,
                                                              ),
                                                            ),
                                                            child: Text(
                                                              a,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                  ),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ))
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          if (_isRouting)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.08),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                        SizedBox(width: 10),
                        Text('Loading directions...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildMapBody(LatLng center, List<_MapRestroomPoint> filtered) {
    final radiusCenter = _userLocation ?? _activeMapCenter ?? _hauDemoCenter;

    return FlutterMap(
      mapController: _mapController,
      key: ValueKey(
        '${center.latitude}_${center.longitude}_${_allRestrooms.length}',
      ),
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        onTap: (_, point) => _handleMapTapAddRestroom(point),
        onPositionChanged: (position, _) {
          final mapCenter = position.center;
          _activeMapCenter = mapCenter;
          _updateReturnToUserButtonVisibility(mapCenter);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.pottypal',
        ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: radiusCenter,
              radius: _searchRadiusKm * 1000,
              useRadiusInMeter: true,
              color: const Color(0x331565C0),
              borderStrokeWidth: 1.5,
              borderColor: const Color(0xAA1565C0),
            ),
          ],
        ),
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 18,
                height: 18,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isUserMoving
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF1565C0),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ],
          ),
        PolylineLayer(
          polylines: _routePoints.length >= 2
              ? <Polyline<Object>>[
                  Polyline<Object>(
                    points: _routePoints,
                    strokeWidth: 5,
                    color: const Color(0xFF1565C0),
                  ),
                ]
              : const <Polyline<Object>>[],
        ),
        MarkerLayer(
          markers: List.generate(filtered.length, (index) {
            final point = filtered[index];
            final latLng = _pinPositionFor(point, index);
            return Marker(
              point: latLng,
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<Object?>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RestroomDetailPage(
                        restroom: point.restroom,
                        onGetDirections: () {
                          Navigator.pop(context);
                          _showDirectionsTo(point.restroom);
                        },
                        isSaved:
                            widget.isRestroomSaved?.call(point.restroom) ??
                            false,
                        flagCount:
                            widget.restroomFlagCount?.call(point.restroom) ?? 0,
                        onToggleSaved: widget.onToggleRestroomSaved == null
                            ? null
                            : () =>
                                  widget.onToggleRestroomSaved!(point.restroom),
                        onSubmitFlag: widget.onSubmitRestroomFlag == null
                            ? null
                            : (reason) => widget.onSubmitRestroomFlag!(
                                point.restroom,
                                reason,
                              ),
                        initialReviews:
                            widget.restroomReviews?.call(point.restroom) ??
                            const [],
                        onSubmitReview: widget.onSubmitRestroomReview == null
                            ? null
                            : (rating, comment) =>
                                  widget.onSubmitRestroomReview!(
                                    point.restroom,
                                    rating,
                                    comment,
                                  ),
                        onRestroomChanged: (updatedRestroom) {
                          widget.onRestroomUpdated(
                            point.restroom,
                            updatedRestroom,
                          );
                        },
                      ),
                    ),
                  );

                  if (!mounted) return;
                  if (result == 'deleted') {
                    widget.onRestroomDeleted(point.restroom);
                  } else if (result is Restroom) {
                    widget.onRestroomUpdated(point.restroom, result);
                  }
                },
                child: const Icon(
                  Icons.location_pin,
                  color: Color(0xFFD32F2F),
                  size: 36,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes;
  final String? error;

  const _RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    this.error,
  });
}

class _RouteApiResponse {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const _RouteApiResponse({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  factory _RouteApiResponse.fromJson(Map<String, dynamic> json) {
    final routes = json['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw const FormatException('No route found.');
    }

    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;
    if (coordinates == null || coordinates.isEmpty) {
      throw const FormatException('No route geometry available.');
    }

    final points = coordinates
        .map((coord) {
          final pair = coord as List<dynamic>;
          return LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          );
        })
        .toList(growable: false);

    final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0;
    final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0;

    return _RouteApiResponse(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }
}

class _MapRestroomPoint {
  final Restroom restroom;
  final String name;
  final String fullAddress;
  final double latitude;
  final double longitude;
  final bool isOpen;
  final double rating;
  final int reviewCount;
  final List<String> amenities;

  const _MapRestroomPoint({
    required this.restroom,
    required this.name,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    required this.isOpen,
    required this.rating,
    required this.reviewCount,
    required this.amenities,
  });

  factory _MapRestroomPoint.fromRestroom(Restroom restroom) {
    return _MapRestroomPoint(
      restroom: restroom,
      name: restroom.name,
      fullAddress: restroom.address,
      latitude: restroom.latitude ?? 0,
      longitude: restroom.longitude ?? 0,
      isOpen: restroom.isOpen,
      rating: restroom.rating,
      reviewCount: restroom.reviewCount,
      amenities: restroom.amenities,
    );
  }
}
