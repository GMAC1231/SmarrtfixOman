// lib/map_tab.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:geolocator/geolocator.dart';

import 'shared/services/request_service.dart';

class MapTab extends StatefulWidget {
  final String? requestId;

  const MapTab({
    super.key,
    this.requestId,
  });

  @override
  MapTabState createState() => MapTabState();
}

class MapTabState extends State<MapTab> {
  final osm.MapController _mapController = osm.MapController(
    initMapWithUserPosition: const osm.UserTrackingOption(),
  );

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<firestore.DocumentSnapshot<Map<String, dynamic>>>?
      _requestSub;
  StreamSubscription<firestore.DocumentSnapshot<Map<String, dynamic>>>?
      _providerLiveSub;

  osm.GeoPoint? _myPoint;
  osm.GeoPoint? _customerPoint;
  osm.GeoPoint? _providerPoint;

  osm.GeoPoint? _myMarkerPoint;
  osm.GeoPoint? _customerMarkerPoint;
  osm.GeoPoint? _providerMarkerPoint;

  bool _mapReady = false;
  bool _isAnimatingProvider = false;

  double? _distanceKm;
  int? _etaMinutes;

  String? _acceptedProviderId;
  String? _acceptedProviderName;
  String? _acceptedProviderCar;
  double? _acceptedProviderRating;

  @override
  void initState() {
    super.initState();
    _startOwnLocationTracking();
    _listenToRequestIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestId != widget.requestId) {
      _cancelRequestListeners();
      _acceptedProviderId = null;
      _acceptedProviderName = null;
      _acceptedProviderCar = null;
      _acceptedProviderRating = null;
      _customerPoint = null;
      _providerPoint = null;
      _customerMarkerPoint = null;
      _providerMarkerPoint = null;
      _distanceKm = null;
      _etaMinutes = null;
      _listenToRequestIfNeeded();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _cancelRequestListeners();
    _mapController.dispose();
    super.dispose();
  }

  void _cancelRequestListeners() {
    _requestSub?.cancel();
    _providerLiveSub?.cancel();
  }

  void _startOwnLocationTracking() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((pos) async {
      final point = osm.GeoPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      _myPoint = point;
      await RequestService.publishLiveLocation(
        lat: point.latitude,
        lng: point.longitude,
      );
      await _refreshMyMarker();

      if (_customerPoint == null && widget.requestId == null) {
        await _goToPointIfReady(point);
      }

      await _drawRouteIfPossible();
    });
  }

  void _listenToRequestIfNeeded() {
    final requestId = widget.requestId;
    if (requestId == null || requestId.isEmpty) return;

    final requestRef = firestore.FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(requestId);

    _requestSub = requestRef.snapshots().listen((doc) async {
      final data = doc.data();
      if (data == null) return;

      final customerPoint = _extractPointFromRequest(data);
      if (customerPoint != null) {
        _customerPoint = customerPoint;
        await _refreshCustomerMarker();
      }

      final status = (data['status'] ?? '').toString();
      final providerId =
          (data['providerId'] ?? data['employeeId'] ?? '').toString();

      if ((status == 'accepted' ||
              status == 'ongoing' ||
              status == 'arrived' ||
              status == 'completed') &&
          providerId.isNotEmpty) {
        _acceptedProviderId = providerId;
        _acceptedProviderName =
            (data['providerName'] ?? data['employeeName'] ?? 'Driver')
                .toString();
        _acceptedProviderCar =
            (data['car'] ?? data['vehicleName'] ?? data['vehicleModel'] ?? 'N/A')
                .toString();

        final rawRating = data['rating'];
        _acceptedProviderRating =
            rawRating is num ? rawRating.toDouble() : null;

        _listenToAcceptedProvider(providerId);
      } else {
        _acceptedProviderId = null;
        _acceptedProviderName = null;
        _acceptedProviderCar = null;
        _acceptedProviderRating = null;
        _providerPoint = null;
        _providerLiveSub?.cancel();
        _providerLiveSub = null;

        if (mounted) {
          setState(() {
            _distanceKm = null;
            _etaMinutes = null;
          });
        }
      }

      await _fitImportantPoints();
      await _drawRouteIfPossible();

      if (mounted) setState(() {});
    });
  }

  osm.GeoPoint? _extractPointFromRequest(Map<String, dynamic> data) {
    final customerLat = data['customerLat'];
    final customerLng = data['customerLng'];
    if (customerLat is num && customerLng is num) {
      return osm.GeoPoint(
        latitude: customerLat.toDouble(),
        longitude: customerLng.toDouble(),
      );
    }

    final customerLocation = data['customerLocation'];
    if (customerLocation is firestore.GeoPoint) {
      return osm.GeoPoint(
        latitude: customerLocation.latitude,
        longitude: customerLocation.longitude,
      );
    }

    return null;
  }

  void _listenToAcceptedProvider(String providerId) {
    _providerLiveSub?.cancel();
    _providerLiveSub = firestore.FirebaseFirestore.instance
        .collection('liveLocations')
        .doc(providerId)
        .snapshots()
        .listen((doc) async {
      final data = doc.data();
      if (data == null) return;

      final lat = data['lat'];
      final lng = data['lng'];
      if (lat is num && lng is num) {
        await _animateProviderTo(
          osm.GeoPoint(
            latitude: lat.toDouble(),
            longitude: lng.toDouble(),
          ),
        );
      }
    });
  }

  Future<void> _refreshMyMarker() async {
    if (!_mapReady || _myPoint == null) return;

    try {
      if (_myMarkerPoint != null) {
        await _mapController.removeMarker(_myMarkerPoint!);
      }
    } catch (_) {}

    try {
      await _mapController.addMarker(
        _myPoint!,
        markerIcon: const osm.MarkerIcon(
          icon: Icon(Icons.my_location, color: Colors.red, size: 40),
        ),
      );
      _myMarkerPoint = _myPoint;
    } catch (_) {}
  }

  Future<void> _refreshCustomerMarker() async {
    if (!_mapReady || _customerPoint == null) return;

    try {
      if (_customerMarkerPoint != null) {
        await _mapController.removeMarker(_customerMarkerPoint!);
      }
    } catch (_) {}

    try {
      await _mapController.addMarker(
        _customerPoint!,
        markerIcon: const osm.MarkerIcon(
          icon: Icon(Icons.location_on, color: Colors.green, size: 44),
        ),
      );
      _customerMarkerPoint = _customerPoint;
    } catch (_) {}
  }

  Future<void> _refreshProviderMarker() async {
    if (!_mapReady || _providerPoint == null) return;

    try {
      if (_providerMarkerPoint != null) {
        await _mapController.removeMarker(_providerMarkerPoint!);
      }
    } catch (_) {}

    try {
      await _mapController.addMarker(
        _providerPoint!,
        markerIcon: const osm.MarkerIcon(
          icon: Icon(Icons.local_taxi, color: Colors.blue, size: 42),
        ),
      );
      _providerMarkerPoint = _providerPoint;
    } catch (_) {}
  }

  Future<void> _animateProviderTo(osm.GeoPoint newPoint) async {
    if (_isAnimatingProvider) return;

    if (_providerPoint == null) {
      _providerPoint = newPoint;
      await _refreshProviderMarker();
      await _fitImportantPoints();
      await _drawRouteIfPossible();
      return;
    }

    _isAnimatingProvider = true;
    final start = _providerPoint!;
    const steps = 10;

    for (int i = 1; i <= steps; i++) {
      final lat =
          start.latitude + (newPoint.latitude - start.latitude) * (i / steps);
      final lng =
          start.longitude + (newPoint.longitude - start.longitude) * (i / steps);

      _providerPoint = osm.GeoPoint(latitude: lat, longitude: lng);
      await _refreshProviderMarker();

      if (i == steps || i % 3 == 0) {
        await _drawRouteIfPossible();
      }

      await Future.delayed(const Duration(milliseconds: 80));
    }

    _providerPoint = newPoint;
    await _refreshProviderMarker();
    await _fitImportantPoints();
    await _drawRouteIfPossible();
    _isAnimatingProvider = false;
  }

  Future<void> _drawRouteIfPossible() async {
    if (!_mapReady) return;
    if (_acceptedProviderId == null) return;
    if (_providerPoint == null || _customerPoint == null) return;

    try {
      await _mapController.clearAllRoads();
    } catch (_) {}

    try {
      final roadInfo = await _mapController.drawRoad(
        _providerPoint!,
        _customerPoint!,
        roadOption: const osm.RoadOption(
          roadColor: Colors.green,
          roadWidth: 7,
        ),
      );

      double? km;
      int? minutes;

      if (roadInfo.distance is num) {
        km = (roadInfo.distance as num).toDouble();
      }

      if (roadInfo.duration is num) {
        minutes = (roadInfo.duration as num).toDouble().ceil();
      }

      if (!mounted) return;
      setState(() {
        _distanceKm = km;
        _etaMinutes = minutes;
      });
    } catch (_) {
      final meters = Geolocator.distanceBetween(
        _providerPoint!.latitude,
        _providerPoint!.longitude,
        _customerPoint!.latitude,
        _customerPoint!.longitude,
      );

      if (!mounted) return;
      setState(() {
        _distanceKm = meters / 1000.0;
        _etaMinutes = ((_distanceKm! / 25.0) * 60.0).ceil();
      });
    }
  }

  Future<void> _goToPointIfReady(osm.GeoPoint point) async {
    if (!_mapReady) return;
    try {
      await _mapController.goToLocation(point);
      await _mapController.setZoom(zoomLevel: 16);
    } catch (_) {}
  }

  Future<void> _fitImportantPoints() async {
    if (!_mapReady) return;

    final points = <osm.GeoPoint>[];
    if (_customerPoint != null) points.add(_customerPoint!);
    if (_providerPoint != null) points.add(_providerPoint!);
    if (_providerPoint == null && _myPoint != null) points.add(_myPoint!);

    if (points.isEmpty) return;

    if (points.length == 1) {
      await _goToPointIfReady(points.first);
      return;
    }

    try {
      await _mapController.zoomToBoundingBox(
        osm.BoundingBox.fromGeoPoints(points),
        paddinInPixel: 70,
      );
    } catch (_) {}
  }

  Future<void> centerToEmployee() async {
    if (_myPoint == null) return;
    await _goToPointIfReady(_myPoint!);
  }

  Future<void> centerToProvider() async {
    if (_providerPoint == null) return;
    await _goToPointIfReady(_providerPoint!);
  }

  Future<void> setCustomerLocation(osm.GeoPoint point) async {
    _customerPoint = point;
    await _refreshCustomerMarker();
    await _fitImportantPoints();
  }

  Widget _buildTopInfoCard() {
    if (_acceptedProviderId == null) return const SizedBox.shrink();
    if (_distanceKm == null && _etaMinutes == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.black87,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'ETA: ${_etaMinutes ?? '-'} min   •   Distance: ${_distanceKm?.toStringAsFixed(1) ?? '-'} km',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptedDriverCard() {
    if (_acceptedProviderId == null) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  radius: 24,
                  child: Icon(Icons.person),
                ),
                title: Text(_acceptedProviderName ?? 'Driver'),
                subtitle: Text(
                  '${_acceptedProviderCar ?? 'N/A'} • ⭐ ${(_acceptedProviderRating ?? 0).toStringAsFixed(1)}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_etaMinutes ?? '-'} min',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('ETA'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: centerToEmployee,
                      icon: const Icon(Icons.my_location),
                      label: const Text('My location'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: centerToProvider,
                      icon: const Icon(Icons.local_taxi),
                      label: const Text('Driver'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        osm.OSMFlutter(
          controller: _mapController,
          osmOption: osm.OSMOption(
            zoomOption: const osm.ZoomOption(
              initZoom: 15,
              minZoomLevel: 3,
              maxZoomLevel: 18,
            ),
            userTrackingOption:
                const osm.UserTrackingOption(enableTracking: false),
            showZoomController: true,
          ),
          onMapIsReady: (ready) async {
            if (!mounted || !ready) return;
            setState(() => _mapReady = true);
            await _refreshMyMarker();
            await _refreshCustomerMarker();
            await _refreshProviderMarker();
            await _fitImportantPoints();
            await _drawRouteIfPossible();
          },
        ),
        _buildTopInfoCard(),
        _buildAcceptedDriverCard(),
      ],
    );
  }
}