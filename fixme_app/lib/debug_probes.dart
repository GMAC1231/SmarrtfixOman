// lib/debug_probes.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> logMyProfession() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    print('❌ No user signed in');
    return;
  }
  final doc = FirebaseFirestore.instance
    .collection('users')
    .doc(FirebaseAuth.instance.currentUser!.uid)
    .snapshots().doc(uid).get();
  print('👷 myProf=${doc.data()?['profession']}');
}
