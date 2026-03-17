import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'models/restroom.dart';
import 'screens/about_page.dart';
import 'screens/map_page.dart';
import 'screens/profile_page.dart';
import 'screens/restroom_detail_page.dart';
import 'utils/slide_route.dart';

void main() {
  runApp(const PottyPalApp());
}

class PottyPalApp extends StatelessWidget {
  const PottyPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PottyPal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const LatLng _hauDemoCenter = LatLng(15.1325230, 120.5901905);
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

  int _currentTab = 0;
  bool _openNowOnly = false;
  bool _topRatedOnly = false;
  double _searchRadiusKm = 0.5;
  Set<String> _selectedAmenities = <String>{};

  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();
  final Distance _distance = const Distance();
  final Connectivity _connectivity = Connectivity();

  Timer? _statusRefreshTimer;
  Timer? _internetProbeTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool? _isOffline;
  LatLng? _userLocation;
  Restroom? _mapDirectionsTarget;
  int _mapDirectionsRequestId = 0;
  late List<Restroom> _restrooms;
  final Map<String, List<RestroomReview>> _reviewsByRestroomKey =
      <String, List<RestroomReview>>{};
  final Set<String> _savedRestroomKeys = <String>{};
  final Map<String, List<String>> _flagReasonsByRestroomKey =
      <String, List<String>>{};

  String _restroomKey(Restroom restroom) {
    final lat = restroom.latitude?.toStringAsFixed(6) ?? 'na';
    final lng = restroom.longitude?.toStringAsFixed(6) ?? 'na';
    return '${restroom.name}|${restroom.address}|$lat|$lng';
  }

  bool _isSaved(Restroom restroom) {
    return _savedRestroomKeys.contains(_restroomKey(restroom));
  }

  void _toggleSaved(Restroom restroom) {
    final key = _restroomKey(restroom);
    setState(() {
      if (_savedRestroomKeys.contains(key)) {
        _savedRestroomKeys.remove(key);
      } else {
        _savedRestroomKeys.add(key);
      }
    });
  }

  void _migrateSavedKey(Restroom oldRestroom, Restroom updatedRestroom) {
    final oldKey = _restroomKey(oldRestroom);
    final newKey = _restroomKey(updatedRestroom);

    if (_savedRestroomKeys.remove(oldKey)) {
      _savedRestroomKeys.add(newKey);
    }
  }

  int _flagCountFor(Restroom restroom) {
    return _flagReasonsByRestroomKey[_restroomKey(restroom)]?.length ?? 0;
  }

  int get _totalFlagCount {
    return _flagReasonsByRestroomKey.values.fold<int>(
      0,
      (sum, reasons) => sum + reasons.length,
    );
  }

  int get _addedRestroomCount {
    return _restrooms.where((r) => r.isUserAdded).length;
  }

  List<RestroomReview> _reviewsFor(Restroom restroom) {
    final key = _restroomKey(restroom);
    return List<RestroomReview>.from(_reviewsByRestroomKey[key] ?? const []);
  }

  void _submitUserReview(Restroom restroom, double rating, String comment) {
    final key = _restroomKey(restroom);
    setState(() {
      _reviewsByRestroomKey[key] = [
        RestroomReview(
          rating: rating,
          comment: comment,
          createdAt: DateTime.now(),
        ),
      ];
    });
  }

  int get _userReviewCount {
    return _reviewsByRestroomKey.values.fold<int>(
      0,
      (sum, reviews) => sum + reviews.length,
    );
  }

  void _migrateReviewKey(Restroom oldRestroom, Restroom updatedRestroom) {
    final oldKey = _restroomKey(oldRestroom);
    final newKey = _restroomKey(updatedRestroom);
    final reviews = _reviewsByRestroomKey.remove(oldKey);
    if (reviews != null && reviews.isNotEmpty) {
      _reviewsByRestroomKey[newKey] = reviews;
    }
  }

  void _submitFlag(Restroom restroom, String reason) {
    final key = _restroomKey(restroom);
    setState(() {
      final existing = _flagReasonsByRestroomKey[key] ?? <String>[];
      _flagReasonsByRestroomKey[key] = [...existing, reason];
    });
  }

  void _migrateFlagKey(Restroom oldRestroom, Restroom updatedRestroom) {
    final oldKey = _restroomKey(oldRestroom);
    final newKey = _restroomKey(updatedRestroom);

    final reasons = _flagReasonsByRestroomKey.remove(oldKey);
    if (reasons != null && reasons.isNotEmpty) {
      _flagReasonsByRestroomKey[newKey] = reasons;
    }
  }

  void _requestDirectionsTo(Restroom restroom) {
    if (restroom.latitude == null || restroom.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Directions unavailable for ${restroom.name} because location is missing.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _mapDirectionsTarget = restroom;
      _mapDirectionsRequestId++;
      _currentTab = 1;
    });
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _setSharedSearchQuery(String query) {
    if (_searchController.text == query) return;
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
  }

  @override
  void initState() {
    super.initState();
    _restrooms = [
      Restroom(
        imageColor: const Color(0xFF0D47A1),
        imagePath: 'assets/images/angeles-city-library.webp',
        name: 'Angeles City Library',
        address: 'Sto. Rosario St, Angeles City',
        latitude: 15.135187141550155,
        longitude: 120.59081857762324,
        distance: '55 m away',
        rating: 4.1,
        reviewCount: 28,
        amenities: ['Soap', 'Tissue', 'Lock', 'PWD'],
        cardColor: const Color(0xFFE3F2FD),
        isOpen: true,
        openingTime: const TimeOfDay(hour: 9, minute: 0),
        closingTime: const TimeOfDay(hour: 17, minute: 0),
      ),
      Restroom(
        imageColor: const Color(0xFF1976D2),
        imagePath: 'assets/images/singku.webp',
        imageAlignment: const Alignment(0, -0.7),
        name: 'Singku Cafe',
        address: 'MacArthur Hwy, Angeles City',
        latitude: 15.134836407789782,
        longitude: 120.5913449849172,
        distance: '120 m away',
        rating: 3.8,
        reviewCount: 14,
        amenities: ['Bidet', 'Soap', 'Lock'],
        cardColor: const Color(0xFFE3F2FD),
        isOpen: true,
        openingTime: const TimeOfDay(hour: 10, minute: 0),
        closingTime: const TimeOfDay(hour: 0, minute: 0),
      ),
      Restroom(
        imageColor: const Color(0xFF42A5F5),
        imagePath: 'assets/images/sm-city-clark.webp',
        name: 'SM City Clark',
        address: 'Jose Abad Santos Ave, Clark',
        latitude: 15.1679038,
        longitude: 120.5817230,
        distance: '340 m away',
        rating: 4.6,
        reviewCount: 87,
        amenities: ['Bidet', 'Soap', 'Tissue', 'Lock', 'PWD'],
        cardColor: const Color(0xFFE3F2FD),
        isOpen: true,
        openingTime: const TimeOfDay(hour: 10, minute: 0),
        closingTime: const TimeOfDay(hour: 21, minute: 0),
      ),
    ];

    _statusRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });

    _loadCurrentLocation();
    _startConnectivityMonitoring();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _internetProbeTimer?.cancel();
    _statusRefreshTimer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _isDisconnected(List<ConnectivityResult> results) {
    if (results.isEmpty) return true;
    return results.every((result) => result == ConnectivityResult.none);
  }

  void _showConnectivitySnackBar({required bool offline}) {
    if (!mounted) return;

    final message = offline
        ? 'You are offline. Some features may not work.'
        : 'Back online.';
    final backgroundColor = offline
        ? Colors.red.shade700
        : Colors.green.shade700;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: backgroundColor,
          duration: offline
              ? const Duration(days: 1)
              : const Duration(seconds: 3),
        ),
      );
    });
  }

  Future<bool> _hasInternetAccess() async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/nearest/v1/driving/120.5901905,15.1325230?number=1',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshConnectivityStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasSignal = !_isDisconnected(results);
      final hasInternet = hasSignal && await _hasInternetAccess();
      final offline = !hasInternet;

      final previous = _isOffline;
      _isOffline = offline;

      if (previous != null && previous != offline) {
        _showConnectivitySnackBar(offline: offline);
      }
    } catch (_) {
      // Ignore probe failures and keep last known status.
    }
  }

  Future<void> _startConnectivityMonitoring() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      final hasSignal = !_isDisconnected(initial);
      final hasInternet = hasSignal && await _hasInternetAccess();
      _isOffline = !hasInternet;

      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        _,
      ) {
        _refreshConnectivityStatus();
      });

      _internetProbeTimer = Timer.periodic(
        const Duration(seconds: 7),
        (_) => _refreshConnectivityStatus(),
      );
    } catch (_) {
      // If connectivity monitoring is unavailable, keep app behavior unchanged.
    }
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _userLocation = _hauDemoCenter);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _userLocation = _hauDemoCenter);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userLocation = _hauDemoCenter;
      });
    }
  }

  Future<void> _openAmenityPicker() async {
    final tempSelected = _selectedAmenities.toSet();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: _amenityOptions.length,
                        itemBuilder: (context, index) {
                          final amenity = _amenityOptions[index];
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

  String _distanceLabelFor(Restroom restroom, LatLng anchor) {
    if (restroom.latitude == null || restroom.longitude == null) {
      return restroom.distance;
    }

    final restroomPoint = LatLng(restroom.latitude!, restroom.longitude!);
    final meters = _distance.as(LengthUnit.Meter, anchor, restroomPoint);

    if (meters < 1000) {
      return '${meters.round()} m away';
    }

    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase().trim();
    final anchor = _userLocation ?? _hauDemoCenter;

    final filtered = _restrooms.where((r) {
      final matchesSearch =
          query.isEmpty ||
          r.name.toLowerCase().contains(query) ||
          r.address.toLowerCase().contains(query) ||
          r.amenities.any((a) => a.toLowerCase().contains(query));
      final matchesOpen = !_openNowOnly || r.isOpen;
      final matchesTopRated = !_topRatedOnly || r.rating >= 3.0;
      final matchesAmenities =
          _selectedAmenities.isEmpty ||
          _selectedAmenities.every(r.amenities.contains);

      final hasCoords = r.latitude != null && r.longitude != null;
      final matchesRadius =
          !hasCoords ||
          _distance.as(
                LengthUnit.Kilometer,
                anchor,
                LatLng(r.latitude!, r.longitude!),
              ) <=
              _searchRadiusKm;

      return matchesSearch &&
          matchesOpen &&
          matchesTopRated &&
          matchesAmenities &&
          matchesRadius;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        toolbarHeight: 64,
        titleSpacing: 8,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/pottypal-logo.webp', height: 70),
            const SizedBox(width: 5),
            const Text(
              'PottyPal',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 34,
              ),
            ),
          ],
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Open Now'),
                          selected: _openNowOnly,
                          showCheckmark: false,
                          onSelected: (v) => setState(() => _openNowOnly = v),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Top Rated'),
                          selected: _topRatedOnly,
                          showCheckmark: false,
                          onSelected: (v) => setState(() => _topRatedOnly = v),
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
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Results (${filtered.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No results match your search/filters.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final restroom = filtered[index];
                          final distanceLabel = _distanceLabelFor(
                            restroom,
                            anchor,
                          );
                          final restroomIndex = _restrooms.indexWhere(
                            (r) => identical(r, restroom),
                          );
                          return RestroomCard(
                            restroom: restroom,
                            distanceLabel: distanceLabel,
                            flagCount: _flagCountFor(restroom),
                            isSaved: _isSaved(restroom),
                            onToggleSaved: () => _toggleSaved(restroom),
                            onDirections: () => _requestDirectionsTo(restroom),
                            onTap: () async {
                              final result = await Navigator.push<Object?>(
                                context,
                                slideRoute(
                                  page: RestroomDetailPage(
                                    restroom: restroom,
                                    onGetDirections: () {
                                      Navigator.pop(context);
                                      _requestDirectionsTo(restroom);
                                    },
                                    isSaved: _isSaved(restroom),
                                    onToggleSaved: () => _toggleSaved(restroom),
                                    flagCount: _flagCountFor(restroom),
                                    initialReviews: _reviewsFor(restroom),
                                    onSubmitReview: (rating, comment) =>
                                        _submitUserReview(
                                          restroom,
                                          rating,
                                          comment,
                                        ),
                                    onSubmitFlag: (reason) =>
                                        _submitFlag(restroom, reason),
                                    onRestroomChanged: (updatedRestroom) {
                                      setState(() {
                                        if (restroomIndex != -1) {
                                          _restrooms[restroomIndex] =
                                              updatedRestroom;
                                        }
                                        _migrateSavedKey(
                                          restroom,
                                          updatedRestroom,
                                        );
                                        _migrateFlagKey(
                                          restroom,
                                          updatedRestroom,
                                        );
                                        _migrateReviewKey(
                                          restroom,
                                          updatedRestroom,
                                        );
                                      });
                                    },
                                  ),
                                  fromRight: true,
                                ),
                              );
                              if (!context.mounted) return;
                              if (result == 'deleted') {
                                setState(() {
                                  if (restroomIndex != -1) {
                                    _restrooms.removeAt(restroomIndex);
                                  }
                                  _savedRestroomKeys.remove(
                                    _restroomKey(restroom),
                                  );
                                  _flagReasonsByRestroomKey.remove(
                                    _restroomKey(restroom),
                                  );
                                  _reviewsByRestroomKey.remove(
                                    _restroomKey(restroom),
                                  );
                                });
                              } else if (result is Restroom) {
                                setState(() {
                                  if (restroomIndex != -1) {
                                    _restrooms[restroomIndex] = result;
                                  }
                                  _migrateSavedKey(restroom, result);
                                  _migrateFlagKey(restroom, result);
                                  _migrateReviewKey(restroom, result);
                                });
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
          MapPage(
            restrooms: _restrooms,
            directionsTarget: _mapDirectionsTarget,
            directionsRequestId: _mapDirectionsRequestId,
            searchQuery: _searchController.text,
            openNowOnly: _openNowOnly,
            topRatedOnly: _topRatedOnly,
            searchRadiusKm: _searchRadiusKm,
            selectedAmenities: _selectedAmenities,
            onSearchQueryChanged: _setSharedSearchQuery,
            onOpenNowOnlyChanged: (value) {
              if (_openNowOnly == value) return;
              setState(() => _openNowOnly = value);
            },
            onTopRatedOnlyChanged: (value) {
              if (_topRatedOnly == value) return;
              setState(() => _topRatedOnly = value);
            },
            onSearchRadiusKmChanged: (value) {
              if (_searchRadiusKm == value) return;
              setState(() => _searchRadiusKm = value);
            },
            onSelectedAmenitiesChanged: (value) {
              if (_selectedAmenities.length == value.length &&
                  _selectedAmenities.containsAll(value)) {
                return;
              }
              setState(() => _selectedAmenities = value);
            },
            onRestroomAdded: (restroom) {
              setState(() {
                _restrooms.add(restroom);
              });
            },
            onRestroomUpdated: (oldRestroom, updatedRestroom) {
              setState(() {
                final index = _restrooms.indexWhere(
                  (r) => identical(r, oldRestroom),
                );
                if (index != -1) {
                  _restrooms[index] = updatedRestroom;
                }
                _migrateSavedKey(oldRestroom, updatedRestroom);
                _migrateFlagKey(oldRestroom, updatedRestroom);
                _migrateReviewKey(oldRestroom, updatedRestroom);
              });
            },
            onRestroomDeleted: (restroom) {
              setState(() {
                _restrooms.removeWhere((r) => identical(r, restroom));
                _savedRestroomKeys.remove(_restroomKey(restroom));
                _flagReasonsByRestroomKey.remove(_restroomKey(restroom));
                _reviewsByRestroomKey.remove(_restroomKey(restroom));
              });
            },
            isRestroomSaved: _isSaved,
            onToggleRestroomSaved: _toggleSaved,
            restroomFlagCount: _flagCountFor,
            onSubmitRestroomFlag: _submitFlag,
            restroomReviews: _reviewsFor,
            onSubmitRestroomReview: _submitUserReview,
          ),
          ProfilePage(
            addedCount: _addedRestroomCount,
            reviewsCount: _userReviewCount,
            savedCount: _savedRestroomKeys.length,
            flagCount: _totalFlagCount,
          ),
          const AboutPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) {
          setState(() => _currentTab = i);
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
          );
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1565C0),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Restrooms',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: 'About',
          ),
        ],
      ),
    );
  }
}

class RestroomCard extends StatelessWidget {
  final Restroom restroom;
  final String? distanceLabel;
  final int flagCount;
  final VoidCallback? onTap;
  final VoidCallback? onDirections;
  final bool isSaved;
  final VoidCallback? onToggleSaved;

  const RestroomCard({
    super.key,
    required this.restroom,
    this.distanceLabel,
    this.flagCount = 0,
    this.onTap,
    this.onDirections,
    this.isSaved = false,
    this.onToggleSaved,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: restroom.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: Image(
                    image: restroom.imageProvider,
                    fit: BoxFit.cover,
                    alignment: restroom.imageAlignment,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.near_me,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distanceLabel ?? restroom.distance,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: restroom.isOpen ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          restroom.isOpen
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          restroom.isOpen ? 'Open' : 'Closed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 10,
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        '${restroom.rating}  (${restroom.reviewCount})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          restroom.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (flagCount > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.deepOrange),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.flag_rounded,
                                size: 12,
                                color: Colors.deepOrange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$flagCount',
                                style: const TextStyle(
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved
                              ? const Color(0xFF1565C0)
                              : Colors.blueGrey,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onToggleSaved,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Color(0xFF1565C0),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restroom.address,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 14,
                        color: Color(0xFF1565C0),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restroom.availabilityStatusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: restroom.isOpen
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          'Hours: ${restroom.operatingHoursLabel} (PHT)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: restroom.amenities
                        .map((a) => _AmenityChip(label: a))
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          onPressed: onDirections,
                          icon: const Icon(Icons.directions, size: 16),
                          label: const Text('Directions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: onTap,
                          icon: const Icon(Icons.info_outline, size: 16),
                          label: const Text('Details'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1565C0),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            side: const BorderSide(color: Color(0xFF1565C0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmenityChip extends StatelessWidget {
  final String label;

  const _AmenityChip({required this.label});

  static const Map<String, IconData> _icons = {
    'Bidet': Icons.water_drop,
    'Soap': Icons.soap,
    'Tissue': Icons.receipt_long,
    'Spacious': Icons.zoom_out_map,
    'PWD': Icons.accessible,
    'Clean': Icons.cleaning_services,
    'Lock': Icons.lock,
    'Accessible': Icons.accessible,
    'No Fee': Icons.money_off,
    'Free': Icons.money_off,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[label] ?? Icons.check_circle_outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1565C0), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1565C0)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
