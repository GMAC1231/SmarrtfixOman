import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'live_location_service.dart';

class LocationTrackingService {
  StreamSubscription<Position>? _positionSub;

  ////////////////////////////////////////////////////////////
  /// START LIVE TRACKING
  ////////////////////////////////////////////////////////////

  Future<void> startTracking({
    String role = 'employee',
    String? jobId,
  }) async {
    //////////////////////////////////////////////////////////
    /// CHECK LOGIN
    //////////////////////////////////////////////////////////

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    //////////////////////////////////////////////////////////
    /// LOCATION ENABLED
    //////////////////////////////////////////////////////////

    bool enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      return;
    }

    //////////////////////////////////////////////////////////
    /// PERMISSION
    //////////////////////////////////////////////////////////

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    //////////////////////////////////////////////////////////
    /// STOP OLD STREAM
    //////////////////////////////////////////////////////////

    await _positionSub?.cancel();

    //////////////////////////////////////////////////////////
    /// START STREAM
    //////////////////////////////////////////////////////////

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((position) async {
      try {
        await LiveLocationService.publish(
          lat: position.latitude,
          lng: position.longitude,
          heading: position.heading,
          speedKph: position.speed * 3.6,
          isOnline: true,
          jobId: jobId,
          role: role,
        );
      } catch (_) {}
    });
  }

  ////////////////////////////////////////////////////////////
  /// STOP TRACKING
  ////////////////////////////////////////////////////////////

  Future<void> stopTracking() async {
    await _positionSub?.cancel();

    _positionSub = null;
  }

  ////////////////////////////////////////////////////////////
  /// CURRENT POSITION
  ////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////
/// CURRENT POSITION
////////////////////////////////////////////////////////////

Future<Position?> getCurrentPosition() async {

  bool serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

  if (!serviceEnabled) {
    return null;
  }

  LocationPermission permission =
      await Geolocator.checkPermission();

  if (permission ==
      LocationPermission.denied) {

    permission =
        await Geolocator.requestPermission();
  }

  if (permission ==
      LocationPermission.denied ||
      permission ==
      LocationPermission.deniedForever) {

    return null;
  }

  return await Geolocator.getCurrentPosition(

    desiredAccuracy:
        LocationAccuracy.bestForNavigation,
  );
}

////////////////////////////////////////////////////////////
/// DISPOSE
////////////////////////////////////////////////////////////

void dispose() {

  _positionSub?.cancel();
}
}