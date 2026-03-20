import 'package:flutter/material.dart';

import '../models/restroom.dart';

enum DashboardSection { added, reviews, saved, flags }

class ProfilePage extends StatefulWidget {
  final int addedCount;
  final int reviewsCount;
  final int savedCount;
  final int flagCount;
  final List<Restroom> addedRestrooms;
  final List<Restroom> reviewedRestrooms;
  final List<Restroom> savedRestrooms;
  final List<Restroom> flaggedRestrooms;
  final void Function(Restroom)? onRestroomTap;

  const ProfilePage({
    super.key,
    this.addedCount = 0,
    this.reviewsCount = 0,
    this.savedCount = 0,
    this.flagCount = 0,
    this.addedRestrooms = const [],
    this.reviewedRestrooms = const [],
    this.savedRestrooms = const [],
    this.flaggedRestrooms = const [],
    this.onRestroomTap,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late DashboardSection _selectedSection;
  final TextEditingController _searchController = TextEditingController();
  bool _slideFromRight = true;
  String _sortOption = 'latest';
  bool _openNowOnly = false;
  bool _topRatedOnly = false;

  @override
  void initState() {
    super.initState();
    _selectedSection = DashboardSection.added;
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setSection(DashboardSection next) {
    if (_selectedSection == next) return;
    setState(() {
      _slideFromRight = next.index > _selectedSection.index;
      _selectedSection = next;
    });
  }

  List<Restroom> get _currentSectionData {
    switch (_selectedSection) {
      case DashboardSection.added:
        return widget.addedRestrooms;
      case DashboardSection.reviews:
        return widget.reviewedRestrooms;
      case DashboardSection.saved:
        return widget.savedRestrooms;
      case DashboardSection.flags:
        return widget.flaggedRestrooms;
    }
  }

  List<Restroom> get _filteredAndSortedData {
    List<Restroom> data = List.from(_currentSectionData);
    final query = _searchController.text.toLowerCase().trim();

    if (_topRatedOnly) {
      data = data.where((r) => r.rating >= 4.0).toList();
    }

    if (_openNowOnly) {
      data = data.where((r) => r.isOpen).toList();
    }

    if (query.isNotEmpty) {
      data = data.where((r) {
        return r.name.toLowerCase().contains(query) ||
            r.address.toLowerCase().contains(query) ||
            r.amenities.any((a) => a.toLowerCase().contains(query));
      }).toList();
    }

    if (_sortOption == 'latest') {
      data.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_sortOption == 'oldest') {
      data.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return data;
  }

  String get _emptyMessage {
    switch (_selectedSection) {
      case DashboardSection.added:
        return 'No added restroom';
      case DashboardSection.reviews:
        return 'No reviewed restroom';
      case DashboardSection.saved:
        return 'No saved restroom';
      case DashboardSection.flags:
        return 'No flagged restroom';
    }
  }

  @override
  Widget build(BuildContext context) {
    const appBlue = Color(0xFF1565C0);
    final filteredData = _filteredAndSortedData;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  color: appBlue,
                ),
                child: const Icon(Icons.person, size: 52, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'Guest User',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'PottyPal Member',
                style: TextStyle(color: Colors.blueGrey, fontSize: 13),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _DashboardStatTile(
                  icon: Icons.wc,
                  value: '${widget.addedCount}',
                  label: 'Added',
                  color: Colors.green,
                  isActive: _selectedSection == DashboardSection.added,
                  onTap: () => _setSection(DashboardSection.added),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardStatTile(
                  icon: Icons.star,
                  value: '${widget.reviewsCount}',
                  label: 'Reviews',
                  color: Colors.amber[700]!,
                  isActive: _selectedSection == DashboardSection.reviews,
                  onTap: () => _setSection(DashboardSection.reviews),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardStatTile(
                  icon: Icons.bookmark,
                  value: '${widget.savedCount}',
                  label: 'Saved',
                  color: const Color(0xFF1565C0),
                  isActive: _selectedSection == DashboardSection.saved,
                  onTap: () => _setSection(DashboardSection.saved),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardStatTile(
                  icon: Icons.flag_rounded,
                  value: '${widget.flagCount}',
                  label: 'Flags',
                  color: Colors.deepOrange,
                  isActive: _selectedSection == DashboardSection.flags,
                  onTap: () => _setSection(DashboardSection.flags),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search your stats...',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Icon(Icons.search, color: Colors.blueGrey),
                ),
                suffixIcon: _searchController.text.trim().isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        onPressed: _searchController.clear,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.blueGrey,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Align(
            alignment: Alignment.center,
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Open Now'),
                  selected: _openNowOnly,
                  showCheckmark: false,
                  onSelected: (v) => setState(() => _openNowOnly = v),
                ),
                FilterChip(
                  label: const Text('Top Rated'),
                  selected: _topRatedOnly,
                  showCheckmark: false,
                  onSelected: (v) => setState(() => _topRatedOnly = v),
                ),
                FilterChip(
                  label: Text(
                    _sortOption == 'latest' ? 'Sort: Latest' : 'Sort: Oldest',
                  ),
                  selected: true,
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() {
                      _sortOption = _sortOption == 'latest'
                          ? 'oldest'
                          : 'latest';
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) {
              final offsetTween = Tween<Offset>(
                begin: Offset(_slideFromRight ? 0.12 : -0.12, 0),
                end: Offset.zero,
              );
              return ClipRect(
                child: FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: animation.drive(offsetTween),
                    child: child,
                  ),
                ),
              );
            },
            child: filteredData.isEmpty
                ? Center(
                    key: ValueKey('empty_${_selectedSection.name}'),
                    child: Text(
                      _emptyMessage,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    key: ValueKey('list_${_selectedSection.name}'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filteredData.length,
                    itemBuilder: (context, index) {
                      final restroom = filteredData[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == filteredData.length - 1 ? 0 : 12,
                        ),
                        child: InkWell(
                          onTap: () => widget.onRestroomTap?.call(restroom),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: restroom.cardColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: restroom.imageProvider,
                                          fit: BoxFit.cover,
                                          alignment: restroom.imageAlignment,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            restroom.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            restroom.address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.blueGrey,
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
                                                '${restroom.rating.toStringAsFixed(1)}  (${restroom.reviewCount})',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            restroom.distance,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.blueGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (restroom.amenities.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: restroom.amenities
                                            .take(3)
                                            .map(
                                              (a) => Container(
                                                margin: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFBBDEFB,
                                                    ),
                                                  ),
                                                ),
                                                child: Text(
                                                  a,
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
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
        ),
      ],
    );
  }
}

class _DashboardStatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _DashboardStatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: color, width: 2)
              : Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? color : color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? color : Colors.grey,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
