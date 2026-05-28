import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

const Color kBrand = Color(0xFF01411C);

class MapScreen extends StatefulWidget {
  final String? requestId;
  final String? providerId;
  final double? customerLat;
  final double? customerLng;

  const MapScreen({
    super.key,
    this.requestId,
    this.providerId,
    this.customerLat,
    this.customerLng,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _providerSub;
  Timer? _routeRefreshTimer;

  LatLng? _providerPosition;
  LatLng? _customerPosition;
  LatLng? _animatedProviderPosition;

  List<LatLng> _routePoints = [];
  bool _loadingRoute = false;
  bool _didInitialFit = false;

  double? _distanceKm;
  int? _etaMinutes;
  String? _providerName;
  String _status = 'tracking';

  @override
  void initState() {
    super.initState();

    if (widget.customerLat != null && widget.customerLng != null) {
      _customerPosition = LatLng(widget.customerLat!, widget.customerLng!);
    }

    _listenProvider();
    _startRouteRefreshLoop();
  }

  @override
  void dispose() {
    _providerSub?.cancel();
    _routeRefreshTimer?.cancel();
    super.dispose();
  }

  void _listenProvider() {
    final providerId = widget.providerId;
    if (providerId == null || providerId.isEmpty) return;

    _providerSub = FirebaseFirestore.instance
        .collection('users')
        .doc(providerId)
        .snapshots()
        .listen((doc) async {
      if (!doc.exists) return;

      final data = doc.data() ?? <String, dynamic>{};

      final providerLat = _readLat(data);
      final providerLng = _readLng(data);

      if (providerLat == null || providerLng == null) return;

      final nextPosition = LatLng(providerLat, providerLng);

      _providerName = (data['name'] ??
              data['fullName'] ??
              data['displayName'] ??
              data['username'] ??
              'Provider')
          .toString();

      _status = (data['jobStatus'] ?? _status).toString();

      if (_animatedProviderPosition == null) {
        _animatedProviderPosition = nextPosition;
      } else {
        _animateProvider(from: _animatedProviderPosition!, to: nextPosition);
      }

      _providerPosition = nextPosition;

      if (_customerPosition != null) {
        await _fetchRoute();
      }

      if (mounted) {
        setState(() {});
        _fitOnceOrKeepVisible();
      }
    });
  }

  void _startRouteRefreshLoop() {
    _routeRefreshTimer?.cancel();
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (_providerPosition != null && _customerPosition != null) {
        await _fetchRoute();
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (_providerPosition == null || _customerPosition == null) return;
    if (_loadingRoute) return;

    _loadingRoute = true;

    try {
      final from = _providerPosition!;
      final to = _customerPosition!;

      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );

      final res = await http.get(uri);

      if (res.statusCode != 200) return;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = json['routes'] as List<dynamic>?;

      if (routes == null || routes.isEmpty) return;

      final route0 = routes.first as Map<String, dynamic>;
      final geometry = route0['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;

      final distanceMeters = (route0['distance'] as num?)?.toDouble();
      final durationSeconds = (route0['duration'] as num?)?.toDouble();

      final parsed = coords.map((point) {
        final p = point as List<dynamic>;
        return LatLng(
          (p[1] as num).toDouble(),
          (p[0] as num).toDouble(),
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _routePoints = parsed;
        _distanceKm =
            distanceMeters == null ? null : distanceMeters / 1000.0;
        _etaMinutes = durationSeconds == null
            ? null
            : math.max(1, (durationSeconds / 60).round());
      });
    } catch (_) {
      // keep silent in production UI; map still works without route
    } finally {
      _loadingRoute = false;
    }
  }

  double? _readLat(Map<String, dynamic> data) {
    final liveLocation = data['liveLocation'];

    if (liveLocation is GeoPoint) return liveLocation.latitude;

    if (liveLocation is Map<String, dynamic>) {
      final lat = liveLocation['lat'] ?? liveLocation['latitude'];
      if (lat is num) return lat.toDouble();
    }

    final lat = data['lat'] ?? data['latitude'];
    if (lat is num) return lat.toDouble();

    return null;
  }

  double? _readLng(Map<String, dynamic> data) {
    final liveLocation = data['liveLocation'];

    if (liveLocation is GeoPoint) return liveLocation.longitude;

    if (liveLocation is Map<String, dynamic>) {
      final lng = liveLocation['lng'] ?? liveLocation['longitude'];
      if (lng is num) return lng.toDouble();
    }

    final lng = data['lng'] ?? data['longitude'];
    if (lng is num) return lng.toDouble();

    return null;
  }

  void _animateProvider({
    required LatLng from,
    required LatLng to,
  }) {
    const steps = 12;
    const stepDuration = Duration(milliseconds: 150);

    int current = 0;
    Timer.periodic(stepDuration, (timer) {
      current++;
      final t = current / steps;

      final lat = from.latitude + (to.latitude - from.latitude) * t;
      final lng = from.longitude + (to.longitude - from.longitude) * t;

      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _animatedProviderPosition = LatLng(lat, lng);
      });

      if (current >= steps) {
        timer.cancel();
      }
    });
  }

  void _fitOnceOrKeepVisible() {
    final provider = _animatedProviderPosition ?? _providerPosition;
    final customer = _customerPosition;
    if (provider == null && customer == null) return;

    if (!_didInitialFit && provider != null && customer != null) {
      _didInitialFit = true;

      final bounds = LatLngBounds.fromPoints([provider, customer]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(70),
        ),
      );
    }
  }

  void _centerOnTrip() {
    final provider = _animatedProviderPosition ?? _providerPosition;
    final customer = _customerPosition;

    if (provider != null && customer != null) {
      final bounds = LatLngBounds.fromPoints([provider, customer]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(70),
        ),
      );
      return;
    }

    final fallback = provider ?? customer;
    if (fallback != null) {
      _mapController.move(fallback, 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _customerPosition ??
        _providerPosition ??
        const LatLng(23.5880, 58.3829);

    final providerMarker = _animatedProviderPosition ?? _providerPosition;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Live Tracking'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _centerOnTrip,
            icon: const Icon(Icons.my_location_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fixme.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 6,
                      color: kBrand,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_customerPosition != null)
                    Marker(
                      point: _customerPosition!,
                      width: 64,
                      height: 64,
                      child: const _PinMarker(
                        icon: Icons.location_pin,
                        bg: Colors.red,
                        fg: Colors.white,
                        label: 'You',
                      ),
                    ),
                  if (providerMarker != null)
                    Marker(
                      point: providerMarker,
                      width: 64,
                      height: 64,
                      child: const _CarMarker(),
                    ),
                ],
              ),
            ],
          ),

          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: _TopTripCard(
              providerName: _providerName ?? 'Provider',
              status: _status,
              etaMinutes: _etaMinutes,
              distanceKm: _distanceKm,
              loadingRoute: _loadingRoute,
            ),
          ),
        ],
      ),
      bottomSheet: _BottomTripSheet(
        providerName: _providerName ?? 'Provider',
        etaMinutes: _etaMinutes,
        distanceKm: _distanceKm,
        requestId: widget.requestId,
        providerId: widget.providerId,
      ),
    );
  }
}

class _TopTripCard extends StatelessWidget {
  final String providerName;
  final String status;
  final int? etaMinutes;
  final double? distanceKm;
  final bool loadingRoute;

  const _TopTripCard({
    required this.providerName,
    required this.status,
    required this.etaMinutes,
    required this.distanceKm,
    required this.loadingRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0x1401411C),
              child: Icon(Icons.person, color: kBrand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    providerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loadingRoute
                        ? 'Refreshing route...'
                        : _buildSubtitle(status, etaMinutes, distanceKm),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kBrand.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                etaMinutes == null ? '-- min' : '$etaMinutes min',
                style: const TextStyle(
                  color: kBrand,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle(String status, int? eta, double? km) {
    final s = status.isEmpty ? 'arriving' : status;
    final d = km == null ? null : '${km.toStringAsFixed(2)} km';
    final e = eta == null ? null : '$eta min';

    final parts = <String>[
      s.toUpperCase(),
      if (e != null) e,
      if (d != null) d,
    ];

    return parts.join(' • ');
  }
}

class _BottomTripSheet extends StatelessWidget {
  final String providerName;
  final int? etaMinutes;
  final double? distanceKm;
  final String? requestId;
  final String? providerId;

  const _BottomTripSheet({
    required this.providerName,
    required this.etaMinutes,
    required this.distanceKm,
    required this.requestId,
    required this.providerId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Color(0x1401411C),
                child: Icon(Icons.directions_car, color: kBrand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${etaMinutes ?? '--'} min away • '
                      '${distanceKm == null ? '--' : distanceKm!.toStringAsFixed(2)} km',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (requestId == null || providerId == null)
                      ? null
                      : () {
                          // hook your chat screen here
                        },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrand,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Close'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinMarker extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final String label;

  const _PinMarker({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: fg, size: 28),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CarMarker extends StatelessWidget {
  const _CarMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kBrand,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: const Icon(
        Icons.directions_car_filled,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}