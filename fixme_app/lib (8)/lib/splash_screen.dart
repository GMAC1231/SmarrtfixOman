import 'package:fixme_app/shared/services/profile_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fixme_app/admin_dashboard.dart';
import 'package:fixme_app/home_page.dart';
import 'package:fixme_app/customer_dashboard.dart';
import 'package:fixme_app/employee_dashboard.dart';
import 'package:fixme_app/complete_profile_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const String adminEmail = 'pakistanfixme.service1@gmail.com';
  Widget? _next;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() => _next = const HomePage());
        return;
      }

      final email = (user.email ?? '').trim().toLowerCase();

      if (email == adminEmail) {
        if (!mounted) return;
        setState(() => _next = const AdminDashboardScreen());
        return;
      }

      final boot = await ProfileBootstrap.ensureProfile();

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snap = await userRef.get();
      final data = snap.data() ?? <String, dynamic>{};

      final role = (data['role'] as String?)?.toLowerCase() ?? '';
      final profileComplete = data['profileComplete'] == true;

      if (!profileComplete || role.isEmpty || boot.showCompleteProfile) {
        if (!mounted) return;
        setState(() {
          _next = CompleteProfileScreen(
            email: (data['email'] as String?) ?? user.email ?? '',
            name: (data['name'] as String?) ?? user.displayName ?? 'User',
            role: role.isEmpty ? 'customer' : role,
          );
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _next = role == 'employee'
            ? const EmployeeDashboardScreen()
            : const CustomerDashboardScreen();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _next = const HomePage());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_next != null) return _next!;

    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF01411C),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BounceInDown(
                  duration: const Duration(milliseconds: 900),
                  child: Image.asset(
                    'assets/icons/google2.png',
                    height: h * 0.18,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                FadeIn(
                  duration: const Duration(milliseconds: 600),
                  child: const Text(
                    'SmartFixOman',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeIn(
                  delay: const Duration(milliseconds: 150),
                  duration: const Duration(milliseconds: 600),
                  child: const Text(
                    'Household Service Management System.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 500),
                  child: const CircularProgressIndicator(
                    color: Color(0xFFCDE7D1),
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}