import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BootResult {
  final String role;
  final bool showCompleteProfile;

  const BootResult({
    required this.role,
    required this.showCompleteProfile,
  });
}

class ProfileBootstrap {
  static const String adminEmail = 'pakistanfixme.service1@gmail.com';

  static Future<BootResult> ensureProfile() async {
    final auth = FirebaseAuth.instance;
    final u = auth.currentUser;

    if (u == null) {
      return const BootResult(
        role: '',
        showCompleteProfile: false,
      );
    }

    final normalizedEmail = (u.email ?? '').trim().toLowerCase();
    if (normalizedEmail == adminEmail) {
      return const BootResult(
        role: 'admin',
        showCompleteProfile: false,
      );
    }

    final uid = u.uid;
    final usersDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    final pubsDoc = FirebaseFirestore.instance.collection('publicUsers').doc(uid);

    final userSnap = await usersDoc.get();
    final data = (userSnap.data() ?? {}) as Map<String, dynamic>;

    final name = (u.displayName ?? '').trim();
    final email = (u.email ?? '').trim();
    final photo = u.photoURL;

    final currentRole = (data['role'] as String?)?.toLowerCase();
    final role = (currentRole == 'employee' || currentRole == 'customer')
        ? currentRole!
        : '';

    final profileComplete = data['profileComplete'] == true;

    final now = FieldValue.serverTimestamp();

    final usersMerge = <String, dynamic>{
      if (!userSnap.exists) 'createdAt': now,
      'updatedAt': now,
      'uid': uid,
      if (email.isNotEmpty) 'email': email,
      if (name.isNotEmpty) 'name': name,
      if (photo != null && photo.isNotEmpty) 'photoUrl': photo,
      'lastLogin': now,
      if (!data.containsKey('profileComplete')) 'profileComplete': false,
    };

    await usersDoc.set(usersMerge, SetOptions(merge: true));

    final fresh = (await usersDoc.get()).data() ?? {};
    final freshRole = (fresh['role'] ?? '').toString();

    final pubsMerge = <String, dynamic>{
      'name': (fresh['name'] ?? name).toString().isNotEmpty
          ? (fresh['name'] ?? name)
          : 'User',
      if ((fresh['profession'] ?? '').toString().isNotEmpty)
        'profession': fresh['profession'],
      if ((fresh['professionEmoji'] ?? '').toString().isNotEmpty)
        'professionEmoji': fresh['professionEmoji'],
      if (fresh['fare'] != null) 'fare': fresh['fare'],
      if ((fresh['photoUrl'] ?? '').toString().isNotEmpty)
        'photoUrl': fresh['photoUrl'],
      if (freshRole.isNotEmpty) 'role': freshRole,
      if ((fresh['city'] ?? '').toString().isNotEmpty) 'city': fresh['city'],
    };

    await pubsDoc.set(pubsMerge, SetOptions(merge: true));

    return BootResult(
      role: freshRole,
      showCompleteProfile: !profileComplete,
    );
  }
}