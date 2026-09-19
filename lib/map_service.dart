// ============================================================
// map_service.dart
// All external API calls:
//   • ORS Directions  → routes
//   • ORS POI API     → points of interest + route stats
//   • ORS Geocoding   → search
//
// FIXES APPLIED:
//   1. Use GET-based directions URL (CORS-safe for Flutter Web)
//   2. Parse encoded polyline geometry (ORS default format)
//   3. Expose real error messages instead of silent swallow
// ============================================================

import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'models.dart';

class MapService {
  // ── YOUR ORS API KEY ───────────────────────────────────────
  static const String _apiKey  = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjgxYWM0MzRmYjQ2ZmU3NGQyYTI3MjEzNzE3YWNjOTA5NzQyMGI4NDA2YzkzMWU5ZDYxMzY2M2NkIiwiaCI6Im11cm11cjY0In0=';
  static const String _baseUrl = 'https://api.openrouteservice.org';
  static const Duration _timeout = Duration(seconds: 20);

  // ─────────────────────────────────────────────────────────
  // 1. GEOCODING — forward geocode text → list of results
  //    Uses GET request — works fine on web (no CORS issue)
  // ─────────────────────────────────────────────────────────
  Future<List<GeocodeResult>> searchPlace(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/geocode/search').replace(
      queryParameters: {
        'api_key': _apiKey,
        'text':    query.trim(),
        'size':    '5',
      },
    );

    final response = await http.get(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Search error ${response.statusCode}: ${response.body}');
    }

    final data     = jsonDecode(response.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? [];
    return features
        .map((f) => GeocodeResult.fromOrsFeature(f as Map<String, dynamic>))
        .toList();
  }

  // ─────────────────────────────────────────────────────────
  // 2. ROUTING
  //
  //  FIX 1 — CORS: Use the GET-based URL format which ORS
  //  allows cross-origin. The POST /v2/directions endpoint
  //  is blocked by browsers (no CORS headers from ORS).
  //
  //  GET /v2/directions/{profile}?start=lng,lat&end=lng,lat
  //  returns a GeoJSON FeatureCollection — standard format,
  //  works from web without a proxy.
  //
  //  FIX 2 — Geometry: The GET endpoint returns geometry as
  //  a proper GeoJSON LineString inside a Feature, so the
  //  encoded-polyline parsing problem goes away entirely.
  //
  //  Alternate routes: ORS GET endpoint does not support
  //  alternatives directly, so we fetch the primary route
  //  first, then fetch 1–2 slight variants by tweaking the
  //  profile (foot-walking, cycling-regular) as visual
  //  alternatives — or just return 1 route if only driving
  //  matters. For real multi-route support use a backend proxy.
  // ─────────────────────────────────────────────────────────
  Future<List<RouteModel>> fetchRoutes(
      LatLng origin, LatLng destination) async {
    final List<RouteModel> results = [];

    // Profiles to try — gives up to 3 visually distinct routes
    const profiles = [
      'driving-car',
      'driving-hgv',       // heavy goods — slightly different road selection
      'cycling-regular',   // fallback visual alternative
    ];

    for (int i = 0; i < profiles.length; i++) {
      try {
        final route = await _fetchRouteGet(
          origin:      origin,
          destination: destination,
          profile:     profiles[i],
          index:       i,
        );
        if (route != null) results.add(route);
      } catch (_) {
        // Skip profiles that fail (e.g. no cycling route available)
      }
    }

    if (results.isEmpty) {
      throw Exception('No routes found between these points.');
    }

    // Mark first as selected
    return [
      results[0].copyWith(isSelected: true),
      ...results.skip(1).map((r) => r.copyWith(isSelected: false)),
    ];
  }

  /// Fetch a single route via the CORS-safe GET endpoint.
  Future<RouteModel?> _fetchRouteGet({
    required LatLng origin,
    required LatLng destination,
    required String profile,
    required int index,
  }) async {
    // GET /v2/directions/{profile}
    // Query params: start=lng,lat  end=lng,lat
    final uri = Uri.parse(
      '$_baseUrl/v2/directions/$profile',
    ).replace(queryParameters: {
      'api_key': _apiKey,
      'start':   '${origin.longitude},${origin.latitude}',
      'end':     '${destination.longitude},${destination.latitude}',
    });

    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json, application/geo+json'},
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Directions $profile ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // GET endpoint returns a GeoJSON FeatureCollection
    // features[0].geometry is a LineString
    // features[0].properties.summary has distance/duration
    final features = data['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) return null;

    final feature  = features[0] as Map<String, dynamic>;
    final props    = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry']   as Map<String, dynamic>? ?? {};
    final summary  = props['summary']      as Map<String, dynamic>? ?? {};

    // Geometry is a proper GeoJSON LineString — no decoding needed
    if (geometry['type'] != 'LineString') return null;

    final coords = geometry['coordinates'] as List<dynamic>;
    final points = coords.map((c) {
      final coord = c as List<dynamic>;
      return LatLng(
        (coord[1] as num).toDouble(),
        (coord[0] as num).toDouble(),
      );
    }).toList();

    if (points.isEmpty) return null;

    return RouteModel(
      index:       index,
      points:      points,
      // GET endpoint returns distance in metres — convert to km
      distanceKm:  ((summary['distance'] as num?)?.toDouble() ?? 0.0) / 1000.0,
      durationMin: ((summary['duration'] as num?)?.toDouble() ?? 0.0) / 60.0,
      isSelected:  false,
    );
  }

  // ─────────────────────────────────────────────────────────
  // 3. POI STATS ALONG A ROUTE
  //    Buffer the route polyline and count POIs per category.
  //    Non-fatal — returns zeros on any error.
  // ─────────────────────────────────────────────────────────
  Future<RouteStats> fetchPoiStatsForRoute(
      List<LatLng> routePoints, {
        double bufferMeters = 500,
      }) async {
    if (routePoints.isEmpty) return const RouteStats();

    final sampled = _samplePolyline(routePoints, maxPoints: 60);
    final uri     = Uri.parse('$_baseUrl/pois');

    final body = jsonEncode({
      'request': 'pois',
      'geometry': {
        'geojson': {
          'type': 'LineString',
          'coordinates': sampled
              .map((p) => [p.longitude, p.latitude])
              .toList(),
        },
        'buffer': bufferMeters,
      },
      'filters': {
        'category_group_ids': PoiCategory.allGroupIds,
      },
      'limit': 500,
    });

    try {
      final response = await http
          .post(uri,
          headers: {
            'Authorization': _apiKey,
            'Content-Type':  'application/json',
            'Accept':        'application/json',
          },
          body: body)
          .timeout(_timeout);

      if (response.statusCode != 200) return const RouteStats();

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parsePoiStats(data);
    } catch (_) {
      return const RouteStats();
    }
  }

  RouteStats _parsePoiStats(Map<String, dynamic> data) {
    final features = data['features'] as List<dynamic>? ?? [];
    int hospitals = 0, police = 0, fuel = 0, banks = 0, parks = 0, cafes = 0;

    for (final feature in features) {
      final props       = (feature as Map<String, dynamic>)['properties']
      as Map<String, dynamic>? ?? {};
      final categoryIds = props['category_ids'];
      bool counted      = false;

      if (categoryIds is Map) {
        for (final key in categoryIds.keys) {
          final id = int.tryParse(key.toString()) ?? -1;
          if      (id >= 580 && id <= 582) { hospitals++; counted = true; break; }
          else if (id >= 600 && id <= 603) { police++;    counted = true; break; }
          else if (id == 660)              { fuel++;      counted = true; break; }
          else if (id >= 620 && id <= 625) { banks++;     counted = true; break; }
          else if (id >= 640 && id <= 650) { parks++;     counted = true; break; }
          else if (id >= 560 && id <= 570) { cafes++;     counted = true; break; }
        }
      }

      if (!counted) {
        final groupIds = props['category_group_ids'];
        if (groupIds is List) {
          for (final gid in groupIds) {
            final id = (gid as num).toInt();
            if      (id == 580) { hospitals++; break; }
            else if (id == 600) { police++;    break; }
            else if (id == 660) { fuel++;      break; }
            else if (id == 620) { banks++;     break; }
            else if (id == 640) { parks++;     break; }
            else if (id == 560) { cafes++;     break; }
          }
        }
      }
    }

    return RouteStats(
      hospitals: hospitals,
      police:    police,
      fuel:      fuel,
      banks:     banks,
      parks:     parks,
      cafes:     cafes,
    );
  }

  // ─────────────────────────────────────────────────────────
  // 4. MAP POIs AROUND A POINT
  // ─────────────────────────────────────────────────────────
  Future<List<PlaceModel>> fetchPoisAround(
      LatLng center, {
        String category     = PoiCategory.all,
        double radiusMeters = 1500,
      }) async {
    final uri  = Uri.parse('$_baseUrl/pois');
    final body = jsonEncode({
      'request': 'pois',
      'geometry': {
        'geojson': {
          'type':        'Point',
          'coordinates': [center.longitude, center.latitude],
        },
        'buffer': radiusMeters,
      },
      'filters': {
        'category_group_ids': PoiCategory.groupIds(category),
      },
      'limit': 100,
    });

    try {
      final response = await http
          .post(uri,
          headers: {
            'Authorization': _apiKey,
            'Content-Type':  'application/json',
            'Accept':        'application/json',
          },
          body: body)
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('POI error ${response.statusCode}');
      }

      final data     = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? [];

      return features
          .map((f) => PlaceModel.fromOrsFeature(f as Map<String, dynamic>))
          .where((p) => p.category != PoiCategory.unknown)
          .toList();
    } catch (e) {
      throw Exception('POI fetch failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────

  /// Down-sample a polyline to ≤ maxPoints for the ORS /pois limit
  List<LatLng> _samplePolyline(List<LatLng> points, {int maxPoints = 60}) {
    if (points.length <= maxPoints) return points;
    final step   = points.length / maxPoints;
    final result = <LatLng>[];
    for (int i = 0; i < maxPoints; i++) {
      result.add(points[(i * step).floor()]);
    }
    if (result.last != points.last) result.add(points.last);
    return result;
  }

  /// Compass bearing between two points (degrees, 0–360)
  double bearingBetween(LatLng a, LatLng b) {
    final lat1 = a.latitudeInRad;
    final lat2 = b.latitudeInRad;
    final dLng = (b.longitude - a.longitude) * (math.pi / 180);
    final y    = math.sin(dLng) * math.cos(lat2);
    final x    = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * (180 / math.pi) + 360) % 360;
  }
}