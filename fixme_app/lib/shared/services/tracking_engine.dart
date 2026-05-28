import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class TrackingSnapshot {
  final List<LatLng> routePoints;
  final double? distanceKm;
  final int? etaMin;

  const TrackingSnapshot({
    required this.routePoints,
    required this.distanceKm,
    required this.etaMin,
  });
}

class TrackingEngine {
  final Distance distance;
  final String osrmBaseUrl;

  const TrackingEngine({
    this.distance = const Distance(),
    this.osrmBaseUrl = 'https://router.project-osrm.org',
  });

  Future<TrackingSnapshot> fetchRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    try {
      final uri = Uri.parse(
        '$osrmBaseUrl/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        return fallbackStraightLine(from: from, to: to);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = json['routes'] as List<dynamic>?;

      if (routes == null || routes.isEmpty) {
        return fallbackStraightLine(from: from, to: to);
      }

      final route0 = routes.first as Map<String, dynamic>;
      final geometry = route0['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;

      final points = coords.map((dynamic point) {
        final p = point as List<dynamic>;
        return LatLng(
          (p[1] as num).toDouble(),
          (p[0] as num).toDouble(),
        );
      }).toList();

final distanceMeters = (route0['distance'] as num?)?.toDouble();
final durationSeconds = (route0['duration'] as num?)?.toDouble();

      return TrackingSnapshot(
        routePoints: points,
        distanceKm: distanceMeters == null ? null : distanceMeters / 1000.0,
        etaMin: durationSeconds == null
            ? null
            : math.max(1, (durationSeconds / 60).round()),
      );
    } catch (_) {
      return fallbackStraightLine(from: from, to: to);
    }
  }

  TrackingSnapshot fallbackStraightLine({
    required LatLng from,
    required LatLng to,
  }) {
    final meters = distance.as(LengthUnit.Meter, from, to);
    final km = meters / 1000.0;
    final eta = math.max(1, ((km / 35.0) * 60.0).round());

    return TrackingSnapshot(
      routePoints: [from, to],
      distanceKm: km,
      etaMin: eta,
    );
  }

  double metersBetween(LatLng a, LatLng b) {
    return distance.as(LengthUnit.Meter, a, b);
  }

  LatLng interpolate({
    required LatLng from,
    required LatLng to,
    required double t,
  }) {
    final clamped = t.clamp(0.0, 1.0);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * clamped,
      from.longitude + (to.longitude - from.longitude) * clamped,
    );
  }

  double? readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }

  double? readLat(Map<String, dynamic> data) {
    final liveLocation = data['liveLocation'];

    if (liveLocation is GeoPoint) {
      return liveLocation.latitude;
    }

    if (liveLocation is Map<String, dynamic>) {
      final lat = liveLocation['lat'] ?? liveLocation['latitude'];
      if (lat is num) return lat.toDouble();
    }

    final lat = data['lat'] ?? data['latitude'];
    if (lat is num) return lat.toDouble();

    return null;
  }

  double? readLng(Map<String, dynamic> data) {
    final liveLocation = data['liveLocation'];

    if (liveLocation is GeoPoint) {
      return liveLocation.longitude;
    }

    if (liveLocation is Map<String, dynamic>) {
      final lng = liveLocation['lng'] ?? liveLocation['longitude'];
      if (lng is num) return lng.toDouble();
    }

    final lng = data['lng'] ?? data['longitude'];
    if (lng is num) return lng.toDouble();

    return null;
  }
}