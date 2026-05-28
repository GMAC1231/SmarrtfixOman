import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_constants.dart';
import '../constants/firestore_keys.dart';

class BootResult {
  final String role;
  final bool showCompleteProfile;

  const BootResult({
    required this.role,
    required this.showCompleteProfile,
  });
}

class ProfileBootstrap {
  ProfileBootstrap._();

  static Future<BootResult> ensureProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const BootResult(role: '', showCompleteProfile: false);
    }

    final email = (user.email ?? '').trim();
    final normalizedEmail = email.toLowerCase();
    if (normalizedEmail == AppConstants.adminEmail) {
      return const BootResult(role: 'admin', showCompleteProfile: false);
    }

    final db = FirebaseFirestore.instance;
    final usersDoc = db.collection(FirestoreCollections.users).doc(user.uid);
    final publicDoc = db.collection(FirestoreCollections.publicUsers).doc(user.uid);

    final currentSnap = await usersDoc.get();
    final current = Map<String, dynamic>.from(currentSnap.data() ?? const <String, dynamic>{});

    final role = _normalizedRole(current['role']);
    final profileComplete = current['profileComplete'] == true;
    final displayName = (user.displayName ?? '').trim();
    final photoUrl = (user.photoURL ?? '').trim();

    await usersDoc.set(<String, dynamic>{
      'uid': user.uid,
      'email': email,
      if (displayName.isNotEmpty) 'name': displayName,
      if (photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      'lastLogin': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!currentSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!current.containsKey('profileComplete')) 'profileComplete': false,
    }, SetOptions(merge: true));

    final freshSnap = await usersDoc.get();
    final fresh = Map<String, dynamic>.from(freshSnap.data() ?? const <String, dynamic>{});
    final freshRole = _normalizedRole(fresh['role']);

    await publicDoc.set(<String, dynamic>{
      'uid': user.uid,
      'name': _nonEmpty(
        fresh['name'],
        fallback: displayName.isNotEmpty ? displayName : 'User',
      ),
      'role': freshRole,
      if (_hasValue(fresh['profession'])) 'profession': fresh['profession'],
      if (_hasValue(fresh['professionEmoji'])) 'professionEmoji': fresh['professionEmoji'],
      if (fresh['fare'] != null) 'fare': fresh['fare'],
      if (_hasValue(fresh['photoUrl'])) 'photoUrl': fresh['photoUrl'],
      if (_hasValue(fresh['city'])) 'city': fresh['city'],
      'updatedAt': FieldValue.serverTimestamp(),
      if (!(await publicDoc.get()).exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return BootResult(
      role: freshRole,
      showCompleteProfile: !profileComplete,
    );
  }

  static String _normalizedRole(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    if (value == 'employee' || value == 'customer') return value;
    return '';
  }

  static bool _hasValue(dynamic raw) => raw != null && raw.toString().trim().isNotEmpty;

  static String _nonEmpty(dynamic raw, {required String fallback}) {
    final value = (raw ?? '').toString().trim();
    return value.isEmpty ? fallback : value;
  }
}
