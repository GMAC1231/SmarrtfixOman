import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'shared/services/tracking_engine.dart';

const Color kBrand = Color(0xFF01411C);

class MapTab extends StatefulWidget {
  final String? requestId;
  final String? providerId;
  final double? customerLat;
  final double? customerLng;
  final bool trackLiveDriver;
  final bool listenToAssignedRequest;
  final bool showInternalTopCard;
  final bool showInternalBottomCard;

  const MapTab({
    super.key,
    this.requestId,
    this.providerId,
    this.customerLat,
    this.customerLng,
    this.trackLiveDriver = true,
    this.listenToAssignedRequest = true,
    this.showInternalTopCard = true,
    this.showInternalBottomCard = true,
  });

  @override
  State<MapTab> createState() => MapTabState();
}

class MapTabState extends State<MapTab> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final TrackingEngine _engine = const TrackingEngine();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _requestSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _providerSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _nearbyProvidersSub;

  Timer? _routeTimer;
  Timer? _animationTimer;

  LatLng? _customer;
  LatLng? _provider;
  LatLng? _animatedProvider;

  List<LatLng> _route = <LatLng>[];

  double? _distanceKm;
  int? _etaMin;
  double? _heading;
  double? _speedKph;

  bool _mapReady = false;
  bool _followMode = true;
  bool _initialFitDone = false;
  bool _loadingRoute = false;
  bool _arrivalDetected = false;
  bool _arrivalNotificationSent = false;

  String? _selectedProviderId;
  String? _selectedProviderName;

  static const double _arrivalThresholdMeters = 50.0;

  final List<_ProviderPreview> _nearbyProviders = [];

  @override
  void initState() {
    super.initState();

    if (widget.customerLat != null && widget.customerLng != null) {
      _customer = LatLng(widget.customerLat!, widget.customerLng!);
    }

    _initNotifications();

    if (widget.listenToAssignedRequest &&
        widget.requestId != null &&
        widget.requestId!.trim().isNotEmpty) {
      _listenToAssignedRequest();
    }

    if (widget.providerId != null && widget.providerId!.trim().isNotEmpty) {
      _selectedProviderId = widget.providerId!.trim();
      _listenSingleProvider(_selectedProviderId!);
    } else {
      _listenNearbyProviders();
    }

    _startRouteLoop();
  }

  @override
  void dispose() {
    _requestSub?.cancel();
    _providerSub?.cancel();
    _nearbyProvidersSub?.cancel();
    _routeTimer?.cancel();
    _animationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);
  }

  void _listenToAssignedRequest() {
    _requestSub = FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(widget.requestId)
        .snapshots()
        .listen((doc) async {
      final data = doc.data();
      if (data == null) return;

      final customerLat = _readDouble(data['customerLat']);
      final customerLng = _readDouble(data['customerLng']);

      if (customerLat != null && customerLng != null) {
        _customer = LatLng(customerLat, customerLng);
      }

      final assignedProviderId = (data['employeeId'] ?? '').toString().trim();

      if (assignedProviderId.isNotEmpty &&
          (_selectedProviderId == null || _selectedProviderId!.isEmpty)) {
        _selectedProviderId = assignedProviderId;
        _listenSingleProvider(assignedProviderId);
      }

      if (_provider != null && _customer != null) {
        await _refreshRouteAndArrival();
      }

      if (mounted) setState(() {});
    });
  }

  void _listenSingleProvider(String providerId) {
    _providerSub?.cancel();

    _providerSub = FirebaseFirestore.instance
        .collection('liveLocations')
        .doc(providerId)
        .snapshots()
        .listen(_handleProviderSnapshot);
  }

  void _listenNearbyProviders() {
    _nearbyProvidersSub?.cancel();

    _nearbyProvidersSub = FirebaseFirestore.instance
        .collection('liveLocations')
        .snapshots()
        .listen((snapshot) async {
      if (_customer == null) return;

      final items = <_ProviderPreview>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final lat = _readLat(data);
        final lng = _readLng(data);
        if (lat == null || lng == null) continue;

        final isOnline = data['isOnline'] == true ||
            data['online'] == true ||
            data['available'] == true;

        if (!isOnline) continue;

        final point = LatLng(lat, lng);
        final meters = _engine.metersBetween(_customer!, point);

        items.add(
          _ProviderPreview(
            id: doc.id,
            name: (data['name'] ?? data['providerName'] ?? 'Driver').toString(),
            role: (data['role'] ?? data['serviceType'] ?? 'Provider').toString(),
            latLng: point,
            heading: _readDouble(data['heading']) ?? 0,
            speedKph: _readDouble(data['speedKph']),
            distanceKm: meters / 1000.0,
            etaMin: math.max(1, (((meters / 1000.0) / 35.0) * 60.0).round()),
          ),
        );
      }

      items.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      if (!mounted) return;

      setState(() {
        _nearbyProviders
          ..clear()
          ..addAll(items.take(8));
      });

      if (_selectedProviderId == null && _nearbyProviders.isNotEmpty) {
        final first = _nearbyProviders.first;
        _selectProvider(first);
      }
    });
  }

  Future<void> _handleProviderSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (!doc.exists) return;

    final data = doc.data() ?? <String, dynamic>{};

    final lat = _readLat(data);
    final lng = _readLng(data);
    if (lat == null || lng == null) return;

    final nextPos = LatLng(lat, lng);

    _selectedProviderName =
        (data['name'] ?? data['providerName'] ?? 'Driver').toString();

    _heading = _readDouble(data['heading']) ?? _heading;
    _speedKph = _readDouble(data['speedKph']) ?? _speedKph;

    if (_animatedProvider == null) {
      _animatedProvider = nextPos;
    } else {
      _animateMove(from: _animatedProvider!, to: nextPos);
    }

    _provider = nextPos;

    if (_customer != null) {
      await _refreshRouteAndArrival();
    }

    if (!mounted) return;
    setState(() {});
    _autoFollow();
  }

  void _selectProvider(_ProviderPreview provider) {
    _selectedProviderId = provider.id;
    _selectedProviderName = provider.name;
    _provider = provider.latLng;
    _animatedProvider = provider.latLng;
    _heading = provider.heading;
    _speedKph = provider.speedKph;

    _listenSingleProvider(provider.id);
    _refreshRouteAndArrival();
    _fitDriverAndCustomer();

    if (mounted) setState(() {});
  }

  void _startRouteLoop() {
    _routeTimer?.cancel();
    _routeTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_provider != null && _customer != null) {
        await _refreshRouteAndArrival();
      }
    });
  }

  Future<void> _refreshRouteAndArrival() async {
    await _fetchRoute();
    await _checkArrival();
  }

  Future<void> _fetchRoute() async {
    if (_provider == null || _customer == null || _loadingRoute) return;

    _loadingRoute = true;
    try {
      final result = await _engine.fetchRoute(
        from: _provider!,
        to: _customer!,
      );

      if (!mounted) return;
      setState(() {
        _route = result.routePoints;
        _distanceKm = result.distanceKm;
        _etaMin = result.etaMin;
      });
    } finally {
      _loadingRoute = false;
    }
  }

  Future<void> _checkArrival() async {
    final provider = _animatedProvider ?? _provider;
    final customer = _customer;
    if (provider == null || customer == null) return;

    final meters = _engine.metersBetween(provider, customer);
    final arrived = meters <= _arrivalThresholdMeters;

    if (arrived && !_arrivalDetected) {
      _arrivalDetected = true;

      if (!_arrivalNotificationSent) {
        _arrivalNotificationSent = true;
        await _showArrivalNotification();
      }

      if (widget.requestId != null && widget.requestId!.trim().isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('serviceRequests')
            .doc(widget.requestId)
            .set({
          'providerArrived': true,
          'arrivalDistanceMeters': meters,
          'arrivalDetectedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) setState(() {});
      return;
    }

    if (!arrived && _arrivalDetected) {
      _arrivalDetected = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _showArrivalNotification() async {
    const android = AndroidNotificationDetails(
      'arrival_channel',
      'Arrival Notifications',
      channelDescription: 'Provider arrival alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: android);

    await _notifications.show(
      1001,
      'Driver is close',
      'Your selected provider is very close.',
      details,
    );
  }

  void _animateMove({
    required LatLng from,
    required LatLng to,
  }) {
    _animationTimer?.cancel();

    const totalFrames = 40;
    const frameDuration = Duration(milliseconds: 20);

    int frame = 0;

    _animationTimer = Timer.periodic(frameDuration, (timer) {
      frame++;

      final t = Curves.easeInOutCubic.transform(frame / totalFrames);
      final lat = from.latitude + (to.latitude - from.latitude) * t;
      final lng = from.longitude + (to.longitude - from.longitude) * t;

      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _animatedProvider = LatLng(lat, lng);
      });

      if (_followMode) {
        _smoothFollowCamera();
      }

      if (frame >= totalFrames) {
        timer.cancel();
      }
    });
  }

  void _autoFollow() {
    final provider = _animatedProvider ?? _provider;
    if (provider == null || !_followMode || !_mapReady) return;

    if (!_initialFitDone && _customer != null) {
      _initialFitDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapReady || _customer == null) return;
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([provider, _customer!]),
            padding: const EdgeInsets.all(90),
          ),
        );
      });
      return;
    }

    _smoothFollowCamera();
  }

  void _smoothFollowCamera() {
    final provider = _animatedProvider ?? _provider;
    if (provider == null || !_mapReady) return;

    final zoom = math.max(_mapController.camera.zoom, 16);

    _mapController.move(
      LatLng(provider.latitude - 0.0005, provider.longitude),
      zoom.toDouble(),
    );
  }

  Future<void> setCustomerLocation(LatLng point) async {
    _customer = point;
    _arrivalDetected = false;
    _arrivalNotificationSent = false;

    if (_selectedProviderId == null && _nearbyProviders.isNotEmpty) {
      _selectProvider(_nearbyProviders.first);
    }

    if (mounted) setState(() {});
    await _refreshRouteAndArrival();
    _fitDriverAndCustomer();
  }

  void centerToEmployee() {
    final provider = _animatedProvider ?? _provider;
    if (provider == null || !_mapReady) return;

    _mapController.move(
      provider,
      math.max(_mapController.camera.zoom, 16),
    );
  }

  void _fitDriverAndCustomer() {
    final provider = _animatedProvider ?? _provider;
    final customer = _customer;

    if (!_mapReady || provider == null || customer == null) return;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([provider, customer]),
        padding: const EdgeInsets.all(90),
      ),
    );
  }

  String get _statusText {
    if (_arrivalDetected) return 'Driver has arrived';
    if (_etaMin == null) return 'Calculating route...';
    if (_etaMin! <= 2) return 'Driver is very close';
    return 'Arriving in about $_etaMin min';
  }

  double? _readLat(Map<String, dynamic> data) => _engine.readLat(data);
  double? _readLng(Map<String, dynamic> data) => _engine.readLng(data);

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _animatedProvider ?? _provider;
    final center = provider ?? _customer ?? const LatLng(23.5880, 58.3829);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14,
            onMapReady: () {
              _mapReady = true;
              _autoFollow();
            },
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture && _followMode) {
                setState(() {
                  _followMode = false;
                });
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.fixme_app',
            ),

            if (_route.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _route,
                    strokeWidth: 12,
                    color: Colors.greenAccent.withOpacity(0.18),
                  ),
                  Polyline(
                    points: _route,
                    strokeWidth: 5,
                    color: Colors.greenAccent,
                  ),
                ],
              ),

            MarkerLayer(
              markers: [
                if (_customer != null)
                  Marker(
                    point: _customer!,
                    width: 70,
                    height: 70,
                    child: const _PulseCustomerMarker(),
                  ),
                ..._nearbyProviders
                    .where((e) => e.id != _selectedProviderId)
                    .map(
                      (e) => Marker(
                        point: e.latLng,
                        width: 54,
                        height: 54,
                        child: _MiniProviderMarker(
                          onTap: () => _selectProvider(e),
                        ),
                      ),
                    ),
                if (provider != null)
                  Marker(
                    point: provider,
                    width: 76,
                    height: 76,
                    child: Transform.rotate(
                      angle: ((_heading ?? 0) * math.pi) / 180.0,
                      child: const _SelectedProviderMarker(),
                    ),
                  ),
              ],
            ),
          ],
        ),

        if (widget.showInternalTopCard)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedProviderName == null
                          ? 'Nearby Providers'
                          : 'Tracking $_selectedProviderName',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (_distanceKm != null)
                          Text('Distance: ${_distanceKm!.toStringAsFixed(1)} km'),
                        if (_etaMin != null) Text('ETA: $_etaMin min'),
                        if (_speedKph != null)
                          Text('Speed: ${_speedKph!.toStringAsFixed(0)} km/h'),
                        Text(_arrivalDetected ? 'Status: Arrived' : 'Status: On the way'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        Positioned(
          right: 16,
          bottom: widget.showInternalBottomCard ? 210 : 100,
          child: FloatingActionButton(
            heroTag: 'follow_btn',
            backgroundColor: kBrand,
            onPressed: () {
              setState(() {
                _followMode = !_followMode;
              });
              if (_followMode) {
                _autoFollow();
              }
            },
            child: Icon(
              _followMode ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: Colors.white,
            ),
          ),
        ),

        Positioned(
          right: 16,
          bottom: widget.showInternalBottomCard ? 144 : 24,
          child: FloatingActionButton(
            heroTag: 'center_btn',
            backgroundColor: Colors.black87,
            onPressed: centerToEmployee,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ),

        if (_nearbyProviders.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.showInternalBottomCard ? 95 : 16,
            child: SizedBox(
              height: 96,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _nearbyProviders.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = _nearbyProviders[index];
                  final selected = item.id == _selectedProviderId;

                  return GestureDetector(
                    onTap: () => _selectProvider(item),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 230,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected ? kBrand : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.14),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: selected
                                    ? Colors.white.withOpacity(0.16)
                                    : kBrand.withOpacity(0.10),
                                child: Icon(
                                  Icons.directions_car,
                                  color: selected ? Colors.white : kBrand,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            item.role,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white70
                                  : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${item.distanceKm.toStringAsFixed(1)} km • ${item.etaMin} min',
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        if (widget.showInternalBottomCard)
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _arrivalDetected ? Colors.orange.shade700 : kBrand,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    color: Colors.black.withOpacity(0.22),
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _arrivalDetected
                        ? Icons.notifications_active
                        : Icons.directions_car,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _arrivalDetected
                              ? 'The provider is within ${_arrivalThresholdMeters.toInt()} meters'
                              : (_distanceKm == null
                                  ? 'Select a provider to begin tracking'
                                  : '${_distanceKm!.toStringAsFixed(1)} km remaining'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await _refreshRouteAndArrival();
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ProviderPreview {
  final String id;
  final String name;
  final String role;
  final LatLng latLng;
  final double heading;
  final double? speedKph;
  final double distanceKm;
  final int etaMin;

  const _ProviderPreview({
    required this.id,
    required this.name,
    required this.role,
    required this.latLng,
    required this.heading,
    required this.speedKph,
    required this.distanceKm,
    required this.etaMin,
  });
}

class _SelectedProviderMarker extends StatelessWidget {
  const _SelectedProviderMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: kBrand,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: kBrand.withOpacity(0.55),
            ),
          ],
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: const Icon(
          Icons.directions_car,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

class _MiniProviderMarker extends StatelessWidget {
  final VoidCallback onTap;

  const _MiniProviderMarker({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black87,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.directions_car,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _PulseCustomerMarker extends StatefulWidget {
  const _PulseCustomerMarker();

  @override
  State<_PulseCustomerMarker> createState() => _PulseCustomerMarkerState();
}

class _PulseCustomerMarkerState extends State<_PulseCustomerMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.22).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: const Icon(
        Icons.location_on,
        size: 46,
        color: Colors.red,
      ),
    );
  }
}