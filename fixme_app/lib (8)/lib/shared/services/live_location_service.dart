import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';

class LiveLocationService {
  static firestore.CollectionReference<Map<String, dynamic>> get _col =>
      firestore.FirebaseFirestore.instance.collection('liveLocations');

  /// One-time purge to remove legacy keys (e.g., `uid`) and write a clean doc.
  static Future<void> purgeAndPublish({
    required double lat,
    required double lng,
    double? heading,
    double? speedKph,
    bool? isOnline,
    String? jobId, // may be null
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    final ref = _col.doc(user.uid); // doc id == uid
    final payload = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'ts': firestore.FieldValue.serverTimestamp(),      // REQUIRED
      if (heading != null) 'heading': heading,           // number
      if (speedKph != null) 'speedKph': speedKph,        // number
      if (isOnline != null) 'isOnline': isOnline,        // bool
      'jobId': jobId,                                    // string or null
      'updatedAt': firestore.FieldValue.serverTimestamp()// timestamp
    };

    // IMPORTANT: replace doc to drop any old/extra keys
    await ref.set(payload, firestore.SetOptions(merge: false));
  }

  /// Regular updates after purge. Safe to call repeatedly (e.g., on a stream).
  static Future<void> publish({
    required double lat,
    required double lng,
    double? heading,
    double? speedKph,
    bool? isOnline,
    String? jobId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    final ref = _col.doc(user.uid);
    await ref.set({
      'lat': lat,
      'lng': lng,
      'ts': firestore.FieldValue.serverTimestamp(),
      if (heading != null) 'heading': heading,
      if (speedKph != null) 'speedKph': speedKph,
      if (isOnline != null) 'isOnline': isOnline,
      'jobId': jobId,
      'updatedAt': firestore.FieldValue.serverTimestamp(),
    }, firestore.SetOptions(merge: true));
  }
}
