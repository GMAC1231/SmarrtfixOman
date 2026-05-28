// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_dashboard.dart';
import 'complete_profile_screen.dart';
import 'customer_dashboard.dart';
import 'employee_dashboard.dart';

class Config {
  static const String apiBaseUrl = "http://192.168.100.15:5000";
}

class ServiceCategory {
  final String name;
  final IconData icon;
  final Color color;

  const ServiceCategory(this.name, this.icon, this.color);
}

const kCategories = [
  ServiceCategory("Plumber", Icons.plumbing, Colors.blue),
  ServiceCategory("Electrician", Icons.electrical_services, Colors.amber),
  ServiceCategory("Technician", Icons.computer, Colors.red),
  ServiceCategory("Painter", Icons.brush, Colors.teal),
  ServiceCategory("Carpenter", Icons.construction, Colors.brown),
  ServiceCategory("Cleaner", Icons.cleaning_services, Colors.purple),
  ServiceCategory("Handyman", Icons.handyman, Colors.orange),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isUrdu = false;

  static const Color pakistanGreen = Color(0xFF01411C);
  static const String adminEmail = 'pakistanfixme.service1@gmail.com';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  Future<void> signInWithGoogle() async {
    try {
      // Force account chooser so you can switch between admin/customer/employee
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _snack(isUrdu ? "سائن ان منسوخ" : "Sign-in cancelled");
        return;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;

      if (user == null) {
        _snack("Login failed: user not found");
        return;
      }

      final uid = user.uid;
      final email = (user.email ?? '').trim().toLowerCase();

      debugPrint('UID: $uid');
      debugPrint('EMAIL: $email');

      // Admin login
      if (email == adminEmail) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userRef = _firestore.collection("users").doc(uid);
      final publicUserRef = _firestore.collection("publicUsers").doc(uid);
      final snap = await userRef.get();

      // New user
      if (!snap.exists) {
        final roleData = await _chooseRoleDialog();

        if (roleData == null || roleData["role"] == null) {
          await FirebaseAuth.instance.signOut();
          await _googleSignIn.signOut();
          _snack("Role selection required!");
          return;
        }

        final role = roleData["role"]!;

        await userRef.set({
          "uid": uid,
          "email": user.email,
          "fullName": user.displayName ?? "User",
          "name": user.displayName ?? "User",
          "role": role,
          "profileComplete": false,
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await publicUserRef.set({
          "name": user.displayName ?? "User",
          "role": role,
          "city": "",
          "photoUrl": user.photoURL,
          if (role == "employee") ...{
            "profession": "",
            "professionEmoji": "",
            "fare": 0,
          },
        }, SetOptions(merge: true));

        await prefs.setString("role", role);
        await prefs.setBool("profileComplete", false);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CompleteProfileScreen(
              email: user.email ?? "",
              name: user.displayName ?? "User",
              role: role,
            ),
          ),
        );
        return;
      }

      // Existing user
      final data = snap.data() ?? {};
      final role = (data["role"] as String?)?.toLowerCase() ?? "";
      final profileComplete = data["profileComplete"] == true;

      if (!mounted) return;

      if (!profileComplete || role.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CompleteProfileScreen(
              email: user.email ?? "",
              name: (data["name"] as String?) ?? user.displayName ?? "User",
              role: role.isEmpty ? "customer" : role,
            ),
          ),
        );
        return;
      }

      if (role == "customer") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerDashboardScreen()),
        );
      } else if (role == "employee") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EmployeeDashboardScreen()),
        );
      } else {
        _snack("Unknown role found. Please contact support.");
        await FirebaseAuth.instance.signOut();
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint("❌ Google login failed: $e");
      _snack("Login failed: $e");
    }
  }

  Future<Map<String, String>?> _chooseRoleDialog() async {
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text("Choose Your Role"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size.fromHeight(45),
                ),
                icon: const Icon(Icons.person, color: Colors.white),
                label: const Text("Customer"),
                onPressed: () async {
                  final confirm = await _confirmRole("Customer");
                  if (confirm) {
                    Navigator.pop(ctx, {"role": "customer"});
                  }
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size.fromHeight(45),
                ),
                icon: const Icon(Icons.engineering, color: Colors.white),
                label: const Text("Employee"),
                onPressed: () async {
                  final confirm = await _confirmRole("Employee");
                  if (confirm) {
                    Navigator.pop(ctx, {"role": "employee"});
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _confirmRole(String rolePretty) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Confirm Role"),
            content: Text(
              "Are you sure you want to continue as $rolePretty?\n"
              "⚠️ Once your profile is complete, this cannot be changed.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 65, 1, 1),
                ),
                child: const Text("Yes, Continue"),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Stack(
              children: [
                FadeInDown(
                  duration: const Duration(milliseconds: 1000),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.42,
                    width: double.infinity,
                    child: Image.asset(
                      'assets/images/banner2.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FadeIn(
              duration: const Duration(milliseconds: 900),
              child: Text(
                isUrdu ? 'پاکستان فکس می' : 'SmartFixOman',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 252, 0, 0),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FadeIn(
              delay: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  isUrdu
                      ? 'آپ کی دہلیز پر آن ڈیمانڈ گھریلو مرمت کی خدمات۔'
                      : 'Household Services.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: kCategories.length,
                itemBuilder: (_, i) {
                  final c = kCategories[i];
                  return Container(
                    margin: const EdgeInsets.only(right: 14),
                    padding: const EdgeInsets.all(14),
                    width: 100,
                    decoration: BoxDecoration(
                      color: c.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(c.icon, size: 34, color: c.color),
                        const SizedBox(height: 6),
                        Text(
                          c.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
            FadeInUp(
              delay: const Duration(milliseconds: 600),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Image.asset('assets/icons/google2.png', height: 22),
                    label: Text(
                      isUrdu
                          ? 'گوگل کے ساتھ سائن ان کریں'
                          : 'Continue with Google',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: pakistanGreen),
                      ),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: signInWithGoogle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}