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

        await userRef.set(
            {
              "uid": uid,

              "email": user.email,

              "fullName": user.displayName ?? "User",

              "name": user.displayName ?? "User",

              ////////////////////////////////////////////////////////////
              /// DO NOT SAVE ROLE YET
              ////////////////////////////////////////////////////////////

              "createdAt": FieldValue.serverTimestamp(),

              "updatedAt": FieldValue.serverTimestamp(),
            },
            SetOptions(
              merge: true,
            ));

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
      final profileCompleted =
          data["profileCompleted"] == true || data["profileComplete"] == true;

      if (!mounted) return;

////////////////////////////////////////////////////////////
      /// ROLE MISSING
////////////////////////////////////////////////////////////

      if (role.isEmpty) {
        //////////////////////////////////////////////////////////
        /// ASK ROLE AGAIN
        //////////////////////////////////////////////////////////

        final roleData = await _chooseRoleDialog();

        //////////////////////////////////////////////////////////
        /// USER CANCELLED
        //////////////////////////////////////////////////////////

        if (roleData == null || roleData["role"] == null) {
          await FirebaseAuth.instance.signOut();

          await _googleSignIn.signOut();

          return;
        }

        final selectedRole = roleData["role"]!;

        //////////////////////////////////////////////////////////
        /// CUSTOMER
        //////////////////////////////////////////////////////////

        if (selectedRole == "customer") {
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CompleteProfileScreen(
                email: user.email ?? "",
                name: user.displayName ?? "User",
                role: "customer",
              ),
            ),
          );

          return;
        }

//////////////////////////////////////////////////////////
        /// EMPLOYEE REGISTRATION
//////////////////////////////////////////////////////////

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CompleteProfileScreen(
              email: user.email ?? "",
              name: user.displayName ?? "User",
              role: "employee",
            ),
          ),
        );

        return;
      }
////////////////////////////////////////////////////////////
      /// PROFILE INCOMPLETE
////////////////////////////////////////////////////////////

      if (!profileCompleted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CompleteProfileScreen(
              email: user.email ?? "",
              name: (data["name"] as String?) ?? user.displayName ?? "User",
              role: role,
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

  Future<bool> _confirmRole(
    String rolePretty,
  ) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              ////////////////////////////////////////////////////
              /// STYLE
              ////////////////////////////////////////////////////

              backgroundColor: Colors.white,

              surfaceTintColor: Colors.white,

              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  28,
                ),
              ),

              ////////////////////////////////////////////////////
              /// TITLE
              ////////////////////////////////////////////////////

              title: const Text(
                "Confirm Role",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 20,
                ),
              ),

              ////////////////////////////////////////////////////
              /// CONTENT
              ////////////////////////////////////////////////////

              content: Text(
                "Are you sure you want to continue as $rolePretty?\n\n"
                "⚠️ Once your profile is complete, this cannot be changed.",
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 16,
                  height: 1.45,
                ),
              ),

              ////////////////////////////////////////////////////
              /// ACTIONS
              ////////////////////////////////////////////////////

              actions: [
                ////////////////////////////////////////////////
                /// CANCEL
                ////////////////////////////////////////////////

                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      ctx,
                      false,
                    );
                  },
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: Color(0xFF01411C),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

                ////////////////////////////////////////////////
                /// CONTINUE
                ////////////////////////////////////////////////

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        ctx,
                        true,
                      );
                    },

                    //////////////////////////////////////////////////
                    /// FIXED BUTTON STYLE
                    //////////////////////////////////////////////////

                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        const Color(
                          0xFF01411C,
                        ),
                      ),
                      foregroundColor: WidgetStateProperty.all(
                        Colors.white,
                      ),
                      overlayColor: WidgetStateProperty.all(
                        Colors.white.withOpacity(
                          0.08,
                        ),
                      ),
                      elevation: WidgetStateProperty.all(
                        0,
                      ),
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 14,
                        ),
                      ),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            18,
                          ),
                        ),
                      ),
                    ),

                    //////////////////////////////////////////////////
                    /// BUTTON TEXT
                    //////////////////////////////////////////////////

                    child: const Text(
                      "Yes, Continue",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      body: Stack(
        children: [
          /// 🔥 TOP GRADIENT HERO
          Container(
            height: size.height * 0.45,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF01411C), Color(0xFF0E7A35)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          /// 🔥 CONTENT
          SafeArea(
            child: Column(
              children: [
                /// HEADER
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.menu, color: Colors.white),
                      Row(
                        children: [
                          const Icon(Icons.language, color: Colors.white),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => isUrdu = !isUrdu),
                            child: Text(
                              isUrdu ? "UR" : "EN",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                /// TITLE
                FadeInDown(
                  child: Column(
                    children: [
                      const Icon(Icons.build_circle,
                          size: 70, color: Colors.white),
                      const SizedBox(height: 10),
                      Text(
                        "SmartFixOman",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Household Service Management System",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                /// 🔥 FLOATING CARD CONTAINER
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4F7F5),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        /// DRAG HANDLE
                        Container(
                          height: 5,
                          width: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// 🔥 CATEGORY GRID (PREMIUM)
                        Expanded(
                          child: GridView.builder(
                            itemCount: kCategories.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.9,
                            ),
                            itemBuilder: (_, i) {
                              final c = kCategories[i];

                              return FadeInUp(
                                delay: Duration(milliseconds: 100 * i),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: c.color.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(c.icon,
                                            color: c.color, size: 26),
                                      ),
                                      const SizedBox(height: 10),
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
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 15),

                        /// 🔥 PREMIUM GOOGLE BUTTON
                        FadeInUp(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF01411C), Color(0xFF0E7A35)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0x3301411C),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                )
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                minimumSize: const Size.fromHeight(55),
                              ),
                              onPressed: signInWithGoogle,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/icons/google2.png',
                                    height: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Continue with Google",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
