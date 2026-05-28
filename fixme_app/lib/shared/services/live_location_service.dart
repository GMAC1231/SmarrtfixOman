import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/firestore_keys.dart';

class LiveLocationService {
  LiveLocationService._();

  static firestore.CollectionReference<Map<String, dynamic>> get _col =>
      firestore.FirebaseFirestore.instance
          .collection(FirestoreCollections.liveLocations);

  static Future<void> purgeAndPublish({
    required double lat,
    required double lng,
    double? heading,
    double? speedKph,
    bool? isOnline,
    String? jobId,
    String role = 'employee',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    final payload = _payload(
      uid: user.uid,
      lat: lat,
      lng: lng,
      heading: heading,
      speedKph: speedKph,
      isOnline: isOnline,
      jobId: jobId,
      role: role,
    );

    await _col.doc(user.uid).set(payload, firestore.SetOptions(merge: false));
  }

  static Future<void> publish({
    required double lat,
    required double lng,
    double? heading,
    double? speedKph,
    bool? isOnline,
    String? jobId,
    String role = 'employee',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    await _col.doc(user.uid).set(
      _payload(
        uid: user.uid,
        lat: lat,
        lng: lng,
        heading: heading,
        speedKph: speedKph,
        isOnline: isOnline,
        jobId: jobId,
        role: role,
      ),
      firestore.SetOptions(merge: true),
    );
  }

  static Map<String, dynamic> _payload({
    required String uid,
    required double lat,
    required double lng,
    double? heading,
    double? speedKph,
    bool? isOnline,
    String? jobId,
    required String role,
  }) {
    return <String, dynamic>{
      'uid': uid,
      'lat': lat,
      'lng': lng,
      'liveLocation': firestore.GeoPoint(lat, lng),
      'role': role,
      if (heading != null) 'heading': heading,
      if (speedKph != null) 'speedKph': speedKph,
      if (isOnline != null) 'isOnline': isOnline,
      'jobId': jobId,
      'ts': firestore.FieldValue.serverTimestamp(),
      'updatedAt': firestore.FieldValue.serverTimestamp(),
    };
  }
}
