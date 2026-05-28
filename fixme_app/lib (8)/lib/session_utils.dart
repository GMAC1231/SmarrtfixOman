// lib/shared/session_utils.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixme_app/employee_registration.dart';
import 'package:fixme_app/splash_screen.dart';

class SessionUtils {
  static Future<void> logout(
    BuildContext context, {
    Future<void> Function()? beforeSignOut,
  }) async {
    try {
      if (beforeSignOut != null) {
        try { await beforeSignOut(); } catch (_) {}
      }

      // sign out providers
      try { await FirebaseAuth.instance.signOut(); } catch (_) {}
      try { final g = GoogleSignIn(); await g.signOut(); await g.disconnect(); } catch (_) {}
      try { final prefs = await SharedPreferences.getInstance(); await prefs.clear(); } catch (_) {}
    } finally {
      // Always use the ROOT navigator and hop to next frame
      final nav = Navigator.of(context, rootNavigator: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!nav.mounted) return;
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (_) => false,
        );
      });
    }
  }

  static Future<void> switchRole(
    BuildContext context, {
    required String targetRole,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = firestore.FirebaseFirestore.instance.collection('users').doc(user.uid);
    await ref.set(
      {'role': targetRole, 'roleUpdatedAt': firestore.FieldValue.serverTimestamp()},
      firestore.SetOptions(merge: true),
    );

    final data = (await ref.get()).data() ?? {};
    final nav = Navigator.of(context, rootNavigator: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!nav.mounted) return;
      if (targetRole == 'employee') {
        final profession = (data['profession'] as String?)?.trim() ?? '';
        if (profession.isEmpty) {
          nav.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => EmployeeRegistrationScreen(
                email: user.email ?? '',
                name: data['name'] ?? user.displayName ?? 'Employee',
                existingData: data,
              ),
            ),
            (_) => false,
          );
        } else {
          nav.pushNamedAndRemoveUntil('/employee_dashboard', (_) => false);
        }
      } else {
        nav.pushNamedAndRemoveUntil('/customer_dashboard', (_) => false);
      }
    });
  }
}

