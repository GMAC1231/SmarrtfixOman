import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'complete_profile_screen.dart';
import 'customer_dashboard.dart';
import 'employee_dashboard.dart';
import 'home_page.dart';
import 'employee_pending_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState
    extends State<SplashScreen> {

  ////////////////////////////////////////////////////////////
  /// ADMIN EMAIL
  ////////////////////////////////////////////////////////////

  static const String adminEmail =
      'pakistanfixme.service1@gmail.com';

  Widget? _next;

  ////////////////////////////////////////////////////////////
  /// INIT
  ////////////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();
    _decide();
  }

  ////////////////////////////////////////////////////////////
  /// ROUTING LOGIC
  ////////////////////////////////////////////////////////////

  Future<void> _decide() async {

    //////////////////////////////////////////////////////////
    /// SPLASH DELAY
    //////////////////////////////////////////////////////////

    await Future.delayed(
      const Duration(milliseconds: 900),
    );

    try {

      ////////////////////////////////////////////////////////
      /// FIREBASE USER
      ////////////////////////////////////////////////////////

      final auth =
          FirebaseAuth.instance;

      final user =
          auth.currentUser;

      ////////////////////////////////////////////////////////
      /// NOT LOGGED IN
      ////////////////////////////////////////////////////////

      if (user == null) {

        if (!mounted) return;

        setState(() {

          _next =
              const HomePage();
        });

        return;
      }

      ////////////////////////////////////////////////////////
      /// ADMIN
      ////////////////////////////////////////////////////////

      final email =
          (user.email ?? '')
              .trim()
              .toLowerCase();

      if (email == adminEmail) {

        if (!mounted) return;

        setState(() {

          _next =
              const AdminDashboardScreen();
        });

        return;
      }

      ////////////////////////////////////////////////////////
      /// USER DOC
      ////////////////////////////////////////////////////////

      final userRef =
          FirebaseFirestore
              .instance
              .collection('users')
              .doc(user.uid);

      final snap =
          await userRef.get();

      final data =
          snap.data() ??
              <String, dynamic>{};

      ////////////////////////////////////////////////////////
      /// ROLE
      ////////////////////////////////////////////////////////

      final role =
          (data['role']
                      as String?)
                  ?.toLowerCase() ??
              '';

      ////////////////////////////////////////////////////////
      /// PROFILE COMPLETE
      ////////////////////////////////////////////////////////

      final profileCompleted =
          data['profileCompleted'] == true;

      ////////////////////////////////////////////////////////
      /// DEBUG
      ////////////////////////////////////////////////////////

      debugPrint(
        "ROLE: $role",
      );

      debugPrint(
        "PROFILE COMPLETED: "
        "$profileCompleted",
      );

      ////////////////////////////////////////////////////////
      /// NO ROLE SELECTED
      ////////////////////////////////////////////////////////
////////////////////////////////////////////////////////
/// NO ROLE SELECTED
////////////////////////////////////////////////////////

if (role.isEmpty) {

  //////////////////////////////////////////////////////
  /// GO TO HOMEPAGE
  /// HOMEPAGE ALREADY HAS ROLE SELECTION
  //////////////////////////////////////////////////////

  if (!mounted) return;

  setState(() {

    _next =
        const HomePage();
  });

  return;
}

      ////////////////////////////////////////////////////////
      /// PROFILE NOT COMPLETED
      ////////////////////////////////////////////////////////

      if (!profileCompleted) {

        if (!mounted) return;

        setState(() {

          _next =
              CompleteProfileScreen(

            email:
                (data['email']
                            as String?) ??
                        user.email ??
                    '',

            name:
                (data['name']
                            as String?) ??
                        user.displayName ??
                    'User',

            role: role,
          );
        });

        return;
      }



////////////////////////////////////////////////////////
/// EMPLOYEE
////////////////////////////////////////////////////////

if (

    role == 'employee' ||

    data['requestedRole'] == 'employee'

) {

  //////////////////////////////////////////////////////
  /// APPROVAL STATUS
  //////////////////////////////////////////////////////

  final approvalStatus =

      (data[
        'employeeApprovalStatus'
      ] as String?)

          ?.toLowerCase() ??

      'pending';

  //////////////////////////////////////////////////////
  /// APPROVED
  //////////////////////////////////////////////////////

  if (
      approvalStatus ==
      'approved'
  ) {

    if (!mounted) return;

    setState(() {

      _next =
          const EmployeeDashboardScreen();
    });

    return;
  }

  //////////////////////////////////////////////////////
  /// PENDING
  //////////////////////////////////////////////////////

  if (
      approvalStatus ==
      'pending'
  ) {

    if (!mounted) return;

    setState(() {

      _next =
          const EmployeePendingScreen();
    });

    return;
  }

  //////////////////////////////////////////////////////
  /// REJECTED
  //////////////////////////////////////////////////////

  if (
      approvalStatus ==
      'rejected'
  ) {

    if (!mounted) return;

    setState(() {

      _next =
          const EmployeePendingScreen();
    });

    return;
  }
}
      ////////////////////////////////////////////////////////
      /// CUSTOMER
      ////////////////////////////////////////////////////////

      if (role == 'customer') {

        if (!mounted) return;

        setState(() {

          _next =
              const CustomerDashboardScreen();
        });

        return;
      }

      ////////////////////////////////////////////////////////
      /// FALLBACK
      ////////////////////////////////////////////////////////

      if (!mounted) return;

      setState(() {

        _next =
            const HomePage();
      });

    } catch (e) {

      debugPrint(
        "Splash Error: $e",
      );

      if (!mounted) return;

      setState(() {

        _next =
            const HomePage();
      });
    }
  }

  ////////////////////////////////////////////////////////////
  /// UI
  ////////////////////////////////////////////////////////////

  @override
  Widget build(
    BuildContext context,
  ) {

    //////////////////////////////////////////////////////////
    /// NEXT SCREEN
    //////////////////////////////////////////////////////////

    if (_next != null) {
      return _next!;
    }

    final h =
        MediaQuery.of(context)
            .size
            .height;

    return Scaffold(

      backgroundColor:
          const Color(0xFF01411C),

      body: SafeArea(

        child: Center(

          child: Padding(

            padding:
                const EdgeInsets.symmetric(
              horizontal: 24,
            ),

            child: Column(

              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: [

                //////////////////////////////////////////////////
                /// LOGO
                //////////////////////////////////////////////////

                BounceInDown(

                  duration:
                      const Duration(
                    milliseconds: 900,
                  ),

                  child: Image.asset(

                    'assets/icons/google2.png',

                    height:
                        h * 0.18,

                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 24),

                //////////////////////////////////////////////////
                /// TITLE
                //////////////////////////////////////////////////

                FadeIn(

                  duration:
                      const Duration(
                    milliseconds: 600,
                  ),

                  child: const Text(

                    'SmartFixOman',

                    style: TextStyle(

                      fontSize: 30,

                      fontWeight:
                          FontWeight.w900,

                      color:
                          Colors.white,

                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                //////////////////////////////////////////////////
                /// SUBTITLE
                //////////////////////////////////////////////////

                FadeIn(

                  delay:
                      const Duration(
                    milliseconds: 150,
                  ),

                  duration:
                      const Duration(
                    milliseconds: 600,
                  ),

                  child: const Text(

                    'Household Service Management System.',

                    textAlign:
                        TextAlign.center,

                    style: TextStyle(

                      fontSize: 14,

                      color:
                          Colors.white70,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                //////////////////////////////////////////////////
                /// LOADER
                //////////////////////////////////////////////////

                FadeInUp(

                  delay:
                      const Duration(
                    milliseconds: 200,
                  ),

                  duration:
                      const Duration(
                    milliseconds: 500,
                  ),

                  child:
                      const CircularProgressIndicator(

                    color:
                        Color(0xFFCDE7D1),

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