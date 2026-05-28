import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class ProviderLiveLocationService {
  ProviderLiveLocationService._();

  static StreamSubscription<Position>? _positionSub;

  static Future<void> start() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final req = await Geolocator.requestPermission();
      if (req == LocationPermission.denied ||
          req == LocationPermission.deniedForever) {
        return;
      }
    }

    await _positionSub?.cancel();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      ),
    ).listen((pos) async {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'liveLocation': GeoPoint(pos.latitude, pos.longitude),
        'lat': pos.latitude,
        'lng': pos.longitude,
        'lastLocationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  static Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
  }
}