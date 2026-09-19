// ============================================================
// models.dart
// Data models for the Flutter Map Navigation Feature
// ============================================================

import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────
// POI CATEGORY CONSTANTS
// ─────────────────────────────────────────────────────────────
class PoiCategory {
  static const String all      = 'all';
  static const String hospital = 'hospital';
  static const String police   = 'police';
  static const String fuel     = 'fuel';
  static const String bank     = 'bank';
  static const String park     = 'park';
  static const String cafe     = 'cafe';
  static const String unknown  = 'unknown';

  static const List<String> filters = [
    hospital, police, fuel, bank, park, cafe,
  ];

  /// ORS category_group_ids for each category
  static List<int> groupIds(String category) {
    switch (category) {
      case hospital: return [580];
      case police:   return [600];
      case fuel:     return [660];
      case bank:     return [620];
      case park:     return [640];
      case cafe:     return [560];
      default:       return allGroupIds; // 'all'
    }
  }

  static const List<int> allGroupIds = [580, 600, 660, 620, 640, 560];
}

// ─────────────────────────────────────────────────────────────
// PLACE MODEL
// Represents a single POI or search result
// ─────────────────────────────────────────────────────────────
class PlaceModel {
  final String  name;
  final LatLng  position;
  final String  category;
  final String? address;
  final String? osmId;

  const PlaceModel({
    required this.name,
    required this.position,
    required this.category,
    this.address,
    this.osmId,
  });

  factory PlaceModel.fromOrsFeature(Map<String, dynamic> json) {
    final props    = json['properties'] as Map<String, dynamic>? ?? {};
    final geometry = json['geometry']   as Map<String, dynamic>? ?? {};
    final coords   = geometry['coordinates'] as List<dynamic>? ?? [0.0, 0.0];
    final cat      = _resolveCategoryFromProps(props);

    return PlaceModel(
      name:     props['name'] as String? ?? _labelFromCategory(cat),
      position: LatLng(
        (coords[1] as num).toDouble(),
        (coords[0] as num).toDouble(),
      ),
      category: cat,
      address:  props['street'] as String?,
      osmId:    props['osm_id']?.toString(),
    );
  }

  static String _labelFromCategory(String cat) {
    const map = {
      PoiCategory.hospital: 'Hospital',
      PoiCategory.police:   'Police Station',
      PoiCategory.fuel:     'Fuel Station',
      PoiCategory.bank:     'Bank',
      PoiCategory.park:     'Park',
      PoiCategory.cafe:     'Café',
    };
    return map[cat] ?? 'Place';
  }

  static String _resolveCategoryFromProps(Map<String, dynamic> props) {
    final categoryIds = props['category_ids'];
    if (categoryIds is Map) {
      for (final key in categoryIds.keys) {
        final id       = int.tryParse(key.toString()) ?? 0;
        final resolved = _categoryFromOrsId(id);
        if (resolved != PoiCategory.unknown) return resolved;
      }
    }
    final groupIds = props['category_group_ids'];
    if (groupIds is List && groupIds.isNotEmpty) {
      return _categoryFromGroupId((groupIds.first as num).toInt());
    }
    return PoiCategory.unknown;
  }

  static String _categoryFromOrsId(int id) {
    if (id >= 580 && id <= 582) return PoiCategory.hospital;
    if (id >= 600 && id <= 603) return PoiCategory.police;
    if (id == 660)               return PoiCategory.fuel;
    if (id >= 620 && id <= 625) return PoiCategory.bank;
    if (id >= 640 && id <= 650) return PoiCategory.park;
    if (id >= 560 && id <= 570) return PoiCategory.cafe;
    return PoiCategory.unknown;
  }

  static String _categoryFromGroupId(int groupId) {
    const map = {
      580: PoiCategory.hospital,
      600: PoiCategory.police,
      660: PoiCategory.fuel,
      620: PoiCategory.bank,
      640: PoiCategory.park,
      560: PoiCategory.cafe,
    };
    return map[groupId] ?? PoiCategory.unknown;
  }
}

// ─────────────────────────────────────────────────────────────
// ROUTE STATS MODEL
// POI counts along a route corridor
// ─────────────────────────────────────────────────────────────
class RouteStats {
  final int hospitals;
  final int police;
  final int fuel;
  final int banks;
  final int parks;
  final int cafes;

  const RouteStats({
    this.hospitals = 0,
    this.police    = 0,
    this.fuel      = 0,
    this.banks     = 0,
    this.parks     = 0,
    this.cafes     = 0,
  });

  int get total => hospitals + police + fuel + banks + parks + cafes;

  @override
  String toString() =>
      'RouteStats(hospitals:$hospitals police:$police fuel:$fuel '
          'banks:$banks parks:$parks cafes:$cafes)';
}

// ─────────────────────────────────────────────────────────────
// ROUTE MODEL
// A single navigation route with geometry + analysis data
// ─────────────────────────────────────────────────────────────
class RouteModel {
  final int            index;
  final List<LatLng>   points;
  final double         distanceKm;
  final double         durationMin;
  final RouteStats     stats;
  final bool           isSelected;

  const RouteModel({
    required this.index,
    required this.points,
    required this.distanceKm,
    required this.durationMin,
    this.stats      = const RouteStats(),
    this.isSelected = false,
  });

  String get distanceLabel {
    if (distanceKm < 1) return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String get durationLabel {
    if (durationMin < 60) return '${durationMin.toStringAsFixed(0)} min';
    final h = (durationMin / 60).floor();
    final m = (durationMin % 60).round();
    return '${h}h ${m}m';
  }

  RouteModel copyWith({bool? isSelected, RouteStats? stats}) => RouteModel(
    index:       index,
    points:      points,
    distanceKm:  distanceKm,
    durationMin: durationMin,
    stats:       stats      ?? this.stats,
    isSelected:  isSelected ?? this.isSelected,
  );
}

// ─────────────────────────────────────────────────────────────
// GEOCODE RESULT
// A single result from a forward geocoding search
// ─────────────────────────────────────────────────────────────
class GeocodeResult {
  final String  label;
  final LatLng  position;
  final String? country;

  const GeocodeResult({
    required this.label,
    required this.position,
    this.country,
  });

  factory GeocodeResult.fromOrsFeature(Map<String, dynamic> json) {
    final props    = json['properties'] as Map<String, dynamic>? ?? {};
    final geometry = json['geometry']   as Map<String, dynamic>? ?? {};
    final coords   = geometry['coordinates'] as List<dynamic>? ?? [0.0, 0.0];

    return GeocodeResult(
      label:    props['label'] as String? ?? props['name'] as String? ?? 'Unknown',
      position: LatLng(
        (coords[1] as num).toDouble(),
        (coords[0] as num).toDouble(),
      ),
      country:  props['country'] as String?,
    );
  }
}
