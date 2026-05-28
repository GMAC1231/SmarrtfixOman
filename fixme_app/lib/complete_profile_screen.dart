// lib/complete_profile_screen.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'customer_dashboard.dart';
import 'employee_registration.dart';
import 'home_page.dart' show Config, HomePage;

class CompleteProfileScreen
    extends StatefulWidget {

  final String email;
  final String name;
  final String role;

  const CompleteProfileScreen({

    super.key,

    required this.email,

    required this.name,

    required this.role,
  });

  @override
  State<CompleteProfileScreen>
      createState() =>
          _CompleteProfileScreenState();
}

class _CompleteProfileScreenState
    extends State<CompleteProfileScreen> {

  ////////////////////////////////////////////////////////////
  /// FORM
  ////////////////////////////////////////////////////////////

  final _formKey =
      GlobalKey<FormState>();

  ////////////////////////////////////////////////////////////
  /// FIELDS
  ////////////////////////////////////////////////////////////

  String _phone = "";
  String _city = "";
  String _address = "";
  String _gender = "male";

  bool _loading = false;

  ////////////////////////////////////////////////////////////
  /// COLORS
  ////////////////////////////////////////////////////////////

  static const pakistanGreen =
      Color(0xFF01411C);

  ////////////////////////////////////////////////////////////
  /// INIT
  ////////////////////////////////////////////////////////////

  @override
  void initState() {

    super.initState();

    //////////////////////////////////////////////////////////
    /// EMPLOYEE REDIRECT
    //////////////////////////////////////////////////////////

    if (widget.role == 'employee') {

      WidgetsBinding.instance
          .addPostFrameCallback((_) {

        Navigator.pushReplacement(

          context,

          MaterialPageRoute(

            builder: (_) =>

                EmployeeRegistrationScreen(

              email: widget.email,

              name: widget.name,
            ),
          ),
        );
      });
    }
  }

  ////////////////////////////////////////////////////////////
  /// RESET INCOMPLETE PROFILE
  ////////////////////////////////////////////////////////////

  Future<void>
      _resetIncompleteProfile()
      async {

    try {

      final user =
          FirebaseAuth
              .instance
              .currentUser;

      if (user == null) return;

      final ref =
          FirebaseFirestore
              .instance
              .collection('users')
              .doc(user.uid);

      final snap =
          await ref.get();

      final data =
          snap.data() ?? {};

      final completed =

          data['profileCompleted'] ==
                  true ||

              data['profileComplete'] ==
                  true;

      ////////////////////////////////////////////////////////
      /// RESET ONLY IF NOT COMPLETE
      ////////////////////////////////////////////////////////

      if (!completed) {

        await ref.set({

          'role':
              FieldValue.delete(),

          'profileCompleted':
              FieldValue.delete(),

          'profileComplete':
              FieldValue.delete(),

          'verified':
              FieldValue.delete(),

        }, SetOptions(
          merge: true,
        ));

        debugPrint(
          "Incomplete profile reset",
        );
      }

    } catch (e) {

      debugPrint(
        "Reset profile error: $e",
      );
    }
  }

  ////////////////////////////////////////////////////////////
  /// SUBMIT
  ////////////////////////////////////////////////////////////

Future<void> _submit() async {

  if (_loading) return;

  if (!_formKey.currentState!.validate()) {
    return;
  }

  _formKey.currentState!.save();

  setState(() {
    _loading = true;
  });

  try {

    //////////////////////////////////////////////////////////
    /// AUTH USER
    //////////////////////////////////////////////////////////

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("User not signed in");
    }

    print("AUTH UID = ${user.uid}");

    final uid = user.uid;

    //////////////////////////////////////////////////////////
    /// SHARED PREFS
    //////////////////////////////////////////////////////////

    final prefs =
        await SharedPreferences.getInstance();

    //////////////////////////////////////////////////////////
    /// USER REFERENCE
    //////////////////////////////////////////////////////////

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid);

    //////////////////////////////////////////////////////////
    /// SAVE USER
    //////////////////////////////////////////////////////////

    await userRef.set({

      "uid": uid,

      "fullName": widget.name,

      "name": widget.name,

      "email": widget.email,

      "role": "customer",

      "phone": _phone,

      "city": _city,

      "address": _address,

      "gender": _gender,

      "profileCompleted": true,

      "profileCompleteCustomer": true,

      "accountStatus": "active",

      "photoUrl": user.photoURL,

      "updatedAt":
          FieldValue.serverTimestamp(),

      "createdAt":
          FieldValue.serverTimestamp(),

    }, SetOptions(merge: true));

    print("USER SAVED");

    //////////////////////////////////////////////////////////
    /// PUBLIC USER
    //////////////////////////////////////////////////////////

    await FirebaseFirestore.instance
        .collection("publicUsers")
        .doc(uid)
        .set({

      "uid": uid,

      "name": widget.name,

      "role": "customer",

      "city": _city,

      "photoUrl": user.photoURL,

      "updatedAt":
          FieldValue.serverTimestamp(),

    }, SetOptions(
      merge: true,
    ));

    print("PUBLIC USER SAVED");

    //////////////////////////////////////////////////////////
    /// LOCAL CACHE
    //////////////////////////////////////////////////////////

    await prefs.setString(
      "role",
      "customer",
    );

    await prefs.setBool(
      "profileCompleted",
      true,
    );

    //////////////////////////////////////////////////////////
    /// BACKEND SYNC
    //////////////////////////////////////////////////////////

    try {

      final idToken =
          await user.getIdToken(true);

      await http.post(

        Uri.parse(
          "${Config.apiBaseUrl}/update-profile",
        ),

        headers: {

          "Content-Type":
              "application/json",

          "Authorization":
              "Bearer $idToken",
        },

        body: jsonEncode({

          "uid": uid,

          "email": widget.email,

          "name": widget.name,

          "role": "customer",

          "phone": _phone,

          "city": _city,

          "address": _address,

          "gender": _gender,
        }),

      ).timeout(

        const Duration(seconds: 12),
      );

    } catch (e) {

      debugPrint(
        "Backend sync skipped: $e",
      );
    }

    //////////////////////////////////////////////////////////
    /// SUCCESS
    //////////////////////////////////////////////////////////

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(

      context,

      MaterialPageRoute(

        builder: (_) =>
            const CustomerDashboardScreen(),
      ),

      (route) => false,
    );

  } catch (e) {

    debugPrint("PROFILE ERROR: $e");

    if (mounted) {

      ScaffoldMessenger.of(context)
          .showSnackBar(

        SnackBar(

          backgroundColor: Colors.red,

          content: Text(
            "❌ Error: $e",
          ),
        ),
      );
    }

  } finally {

    if (mounted) {

      setState(() {
        _loading = false;
      });
    }
  }
}

  ////////////////////////////////////////////////////////////
  /// LOGOUT
  ////////////////////////////////////////////////////////////

  Future<void> _logout()
      async {

    await _resetIncompleteProfile();

    await FirebaseAuth.instance
        .signOut();

    await GoogleSignIn()
        .signOut();

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(

      context,

      MaterialPageRoute(

        builder: (_) =>
            const HomePage(),
      ),

      (route) => false,
    );
  }

  ////////////////////////////////////////////////////////////
  /// TEXT FIELD
  ////////////////////////////////////////////////////////////

  Widget _buildTextField({

    required String label,

    required IconData icon,

    required Function(String?)
        onSaved,

    required String? Function(
      String?,
    ) validator,

    int maxLines = 1,

    TextInputType inputType =
        TextInputType.text,
  }) {

    return Padding(

      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),

      child: TextFormField(

        decoration:
            InputDecoration(

          prefixIcon: Icon(

            icon,

            color:
                pakistanGreen,
          ),

          labelText: label,

          filled: true,

          fillColor:
              Colors.white,

          border:
              OutlineInputBorder(

            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),

        maxLines: maxLines,

        keyboardType: inputType,

        onSaved: onSaved,

        validator: validator,
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// GENDER SELECTOR
  ////////////////////////////////////////////////////////////

  Widget _buildGenderSelector() {

    return Row(

      mainAxisAlignment:
          MainAxisAlignment
              .spaceEvenly,

      children: [

        ChoiceChip(

          avatar:
              const Text("👨"),

          label:
              const Text("Male"),

          selected:
              _gender == "male",

          selectedColor:
              pakistanGreen,

          labelStyle: TextStyle(

            color:
                _gender == "male"

                    ? Colors.white

                    : Colors.black,
          ),

          onSelected: (_) {

            setState(() {

              _gender = "male";
            });
          },
        ),

        ChoiceChip(

          avatar:
              const Text("👩"),

          label:
              const Text("Female"),

          selected:
              _gender == "female",

          selectedColor:
              pakistanGreen,

          labelStyle: TextStyle(

            color:
                _gender == "female"

                    ? Colors.white

                    : Colors.black,
          ),

          onSelected: (_) {

            setState(() {

              _gender = "female";
            });
          },
        ),
      ],
    );
  }

  ////////////////////////////////////////////////////////////
  /// BUILD
  ////////////////////////////////////////////////////////////

  @override
  Widget build(
    BuildContext context,
  ) {

    //////////////////////////////////////////////////////////
    /// EMPLOYEE REDIRECT LOADER
    //////////////////////////////////////////////////////////

    if (widget.role ==
        'employee') {

      return Scaffold(

        backgroundColor:
            const Color(0xFFF5F7F8),

        body: Center(

          child: Column(

            mainAxisAlignment:
                MainAxisAlignment.center,

            children: const [

              CircularProgressIndicator(
                color:
                    pakistanGreen,
              ),

              SizedBox(
                height: 24,
              ),

              Text(

                'Redirecting to Provider Registration...',

                style: TextStyle(

                  fontWeight:
                      FontWeight.bold,

                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }

    //////////////////////////////////////////////////////////
    /// CUSTOMER PROFILE
    //////////////////////////////////////////////////////////

    return WillPopScope(

      onWillPop: () async {

        await _resetIncompleteProfile();

        return true;
      },

      child: Scaffold(

        backgroundColor:
            const Color(0xFFF5F7F8),

        appBar: AppBar(

          title: const Text(
            "✨ Complete Profile",
          ),

          backgroundColor:
              pakistanGreen,

          centerTitle: true,

          actions: [

            IconButton(

              icon: const Icon(
                Icons.logout,
                color: Colors.white,
              ),

              onPressed: _logout,
            ),
          ],
        ),

        body: Padding(

          padding:
              const EdgeInsets.all(
            18,
          ),

          child: Form(

            key: _formKey,

            child: ListView(

              children: [

                //////////////////////////////////////////////////
                /// PROFILE CARD
                //////////////////////////////////////////////////

                Card(

                  shape:
                      RoundedRectangleBorder(

                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),

                  elevation: 3,

                  child: ListTile(

                    leading:
                        CircleAvatar(

                      backgroundColor:
                          pakistanGreen
                              .withOpacity(
                        0.1,
                      ),

                      child:
                          const Text(
                        "👤",
                      ),
                    ),

                    title: Text(

                      widget.name,

                      style:
                          const TextStyle(

                        fontWeight:
                            FontWeight.bold,

                        fontSize: 18,
                      ),
                    ),

                    subtitle:
                        const Text(
                      "🛒 Customer",
                    ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                _buildTextField(

                  label:
                      "📞 Phone Number",

                  icon:
                      Icons.phone,

                  inputType:
                      TextInputType.phone,

                  onSaved: (val) {

                    _phone =
                        val ?? "";
                  },

                  validator: (val) {

                    if (val == null ||
                        val.trim().isEmpty) {

                      return "Enter phone number";
                    }

                    return null;
                  },
                ),

                _buildTextField(

                  label:
                      "🏙️ City",

                  icon:
                      Icons.location_city,

                  onSaved: (val) {

                    _city =
                        val ?? "";
                  },

                  validator: (val) {

                    if (val == null ||
                        val.trim().isEmpty) {

                      return "Enter city";
                    }

                    return null;
                  },
                ),

                _buildTextField(

                  label:
                      "🏠 Address",

                  icon:
                      Icons.home,

                  maxLines: 2,

                  onSaved: (val) {

                    _address =
                        val ?? "";
                  },

                  validator: (val) {

                    if (val == null ||
                        val.trim().isEmpty) {

                      return "Enter address";
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 16,
                ),

                const Text(

                  "⚧ Gender",

                  style: TextStyle(

                    fontWeight:
                        FontWeight.bold,

                    fontSize: 16,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                _buildGenderSelector(),

                const SizedBox(
                  height: 24,
                ),

                //////////////////////////////////////////////////
                /// SAVE BUTTON
                //////////////////////////////////////////////////

                ElevatedButton.icon(

                  onPressed:
                      _loading
                          ? null
                          : _submit,

                  icon:
                      _loading

                          ? const SizedBox(

                              width: 18,

                              height: 18,

                              child:
                                  CircularProgressIndicator(

                                strokeWidth:
                                    2,

                                color:
                                    Colors.white,
                              ),
                            )

                          : const Text(
                              "💾",
                            ),

                  label: Text(

                    _loading

                        ? "Saving..."

                        : "Save & Continue ➡️",

                    style:
                        const TextStyle(

                      fontSize: 17,

                      color:
                          Colors.white,
                    ),
                  ),

                  style:
                      ElevatedButton.styleFrom(

                    backgroundColor:
                        pakistanGreen,

                    minimumSize:
                        const Size.fromHeight(
                      52,
                    ),

                    shape:
                        RoundedRectangleBorder(

                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                //////////////////////////////////////////////////
                /// CANCEL BUTTON
                //////////////////////////////////////////////////

                OutlinedButton.icon(

                  icon: const Icon(
                    Icons.arrow_back_rounded,
                  ),

                  label: const Text(
                    'Cancel Registration',
                  ),

                  style:
                      OutlinedButton.styleFrom(

                    foregroundColor:
                        pakistanGreen,

                    side:
                        const BorderSide(
                      color:
                          pakistanGreen,
                    ),

                    padding:
                        const EdgeInsets.symmetric(

                      horizontal: 22,
                      vertical: 14,
                    ),

                    shape:
                        RoundedRectangleBorder(

                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),

                  onPressed: () async {

                    await _resetIncompleteProfile();

                    if (!mounted) return;

                    Navigator.pushAndRemoveUntil(

                      context,

                      MaterialPageRoute(

                        builder: (_) =>
                            const HomePage(),
                      ),

                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}