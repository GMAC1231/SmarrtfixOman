import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';



class SelectRoleScreen extends StatefulWidget {

  const SelectRoleScreen({
    super.key,
  });

  @override
  State<SelectRoleScreen> createState() =>
      _SelectRoleScreenState();
}

class _SelectRoleScreenState
    extends State<SelectRoleScreen> {

  ////////////////////////////////////////////////////////////
  /// SELECTED ROLE
  ////////////////////////////////////////////////////////////

  String selectedRole = 'customer';

  ////////////////////////////////////////////////////////////
  /// ROLE CARD
  ////////////////////////////////////////////////////////////

  Widget roleCard({

    required String role,

    required String title,

    required String subtitle,

    required IconData icon,

    required List<Color> gradient,
  }) {

    final isSelected =
        selectedRole == role;

    return AnimatedContainer(

      duration: const Duration(
        milliseconds: 250,
      ),

      margin: const EdgeInsets.only(
        bottom: 18,
      ),

      decoration: BoxDecoration(

        gradient: LinearGradient(
          colors: isSelected

              ? gradient

              : [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.04),
                ],
        ),

        borderRadius:
            BorderRadius.circular(30),

        border: Border.all(

          color: isSelected

              ? Colors.white

              : Colors.white.withOpacity(0.15),

          width: isSelected ? 2 : 1,
        ),

        boxShadow: [

          if (isSelected)

            BoxShadow(
              color:
                  gradient.first.withOpacity(0.35),

              blurRadius: 24,

              offset: const Offset(
                0,
                12,
              ),
            ),
        ],
      ),

      child: InkWell(

        borderRadius:
            BorderRadius.circular(30),

        onTap: () {

          setState(() {

            selectedRole = role;
          });
        },

        child: Padding(

          padding: const EdgeInsets.all(22),

          child: Row(

            children: [

              //////////////////////////////////////////////////
              /// ICON
              //////////////////////////////////////////////////

              Container(

                width: 72,
                height: 72,

                decoration: BoxDecoration(

                  color:
                      Colors.white.withOpacity(0.18),

                  borderRadius:
                      BorderRadius.circular(24),
                ),

                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 38,
                ),
              ),

              const SizedBox(width: 18),

              //////////////////////////////////////////////////
              /// TEXT
              //////////////////////////////////////////////////

              Expanded(

                child: Column(

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(

                      title,

                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(

                      subtitle,

                      style: TextStyle(
                        color: Colors.white
                            .withOpacity(0.75),

                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              //////////////////////////////////////////////////
              /// CHECK
              //////////////////////////////////////////////////

              AnimatedContainer(

                duration: const Duration(
                  milliseconds: 250,
                ),

                width: 30,
                height: 30,

                decoration: BoxDecoration(

                  shape: BoxShape.circle,

                  color: isSelected
                      ? Colors.white
                      : Colors.transparent,

                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),

                child: isSelected

                    ? const Icon(
                        Icons.check,
                        color: Colors.black,
                        size: 18,
                      )

                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// CONTINUE
  ////////////////////////////////////////////////////////////

  void continueRole() {

    Navigator.pop(
      context,
      selectedRole,
    );
  }

  @override
  Widget build(BuildContext context) {

    ////////////////////////////////////////////////////////////
    /// ADMIN AUTO BYPASS
    ////////////////////////////////////////////////////////////

    final email =

        FirebaseAuth.instance.currentUser
            ?.email
            ?.toLowerCase()
            .trim() ??

        "";

if (
    email ==
    'pakistanfixme.service1@gmail.com'
) {

  Future.microtask(() {

    Navigator.pop(
      context,
      'admin',
    );
  });
}
    return Scaffold(

      backgroundColor:
          const Color(0xFF0F172A),

      body: Stack(

        children: [

          //////////////////////////////////////////////////////
          /// BACKGROUND
          //////////////////////////////////////////////////////

          Positioned(
            top: -120,
            right: -100,

            child: Container(
              width: 260,
              height: 260,

              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue
                    .withOpacity(0.18),
              ),
            ),
          ),

          Positioned(
            bottom: -140,
            left: -120,

            child: Container(
              width: 320,
              height: 320,

              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green
                    .withOpacity(0.18),
              ),
            ),
          ),

          //////////////////////////////////////////////////////
          /// CONTENT
          //////////////////////////////////////////////////////

          SafeArea(

            child: Padding(

              padding: const EdgeInsets.all(
                24,
              ),

              child: Column(

                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  const SizedBox(height: 30),

                  //////////////////////////////////////////////////
                  /// TITLE
                  //////////////////////////////////////////////////

                  const Text(

                    'Continue As',

                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(

                    'Choose how you want to use SmartFixOman.',

                    style: TextStyle(
                      color: Colors.white
                          .withOpacity(0.75),

                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 40),

                  //////////////////////////////////////////////////
                  /// CUSTOMER
                  //////////////////////////////////////////////////

                  roleCard(

                    role: 'customer',

                    title: 'Customer',

                    subtitle:
                        'Book services and hire professionals.',

                    icon: Icons.person_rounded,

                    gradient: const [

                      Color(0xFF2563EB),
                      Color(0xFF1D4ED8),
                    ],
                  ),

                  //////////////////////////////////////////////////
                  /// EMPLOYEE
                  //////////////////////////////////////////////////

                  roleCard(

                    role: 'employee',

                    title: 'Employee',

                    subtitle:
                        'Accept jobs and earn money.',

                    icon:
                        Icons.engineering_rounded,

                    gradient: const [

                      Color(0xFF10B981),
                      Color(0xFF059669),
                    ],
                  ),

                  const Spacer(),

                  //////////////////////////////////////////////////
                  /// BUTTON
                  //////////////////////////////////////////////////

                  SizedBox(

                    width: double.infinity,

                    height: 65,

                    child: ElevatedButton(

                      style: ElevatedButton.styleFrom(

                        backgroundColor:
                            Colors.white,

                        foregroundColor:
                            Colors.black,

                        elevation: 0,

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            22,
                          ),
                        ),
                      ),

                      onPressed: continueRole,

                      child: const Text(

                        'Continue',

                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}