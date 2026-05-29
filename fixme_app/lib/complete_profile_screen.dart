import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'employee_pending_screen.dart';
import 'customer_dashboard.dart';
import 'employee_registration.dart';
import 'home_page.dart' show Config, HomePage;

class CompleteProfileScreen extends StatefulWidget {
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
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String _phone = '';
  String _city = '';
  String _address = '';
  String _gender = 'male';

  bool _loading = false;
  bool _redirectingEmployee = false;

  static const Color darkGreen = Color(0xFF01411C);
  static const Color lightGreen = Color(0xFF1B8F4D);
  static const Color bgColor = Color(0xFFF4F7F5);

  @override
  void initState() {
    super.initState();

    if (widget.role.toLowerCase().trim() == 'employee') {
      _redirectingEmployee = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmployeeRegistrationScreen(
              email: widget.email,
              name: widget.name,
            ),
          ),
        );
      });
    }
  }

  Future<void> _resetIncompleteProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snap = await userRef.get();
      final data = snap.data() ?? <String, dynamic>{};

      final bool completed = data['profileCompleted'] == true ||
          data['profileComplete'] == true ||
          data['profileCompleteCustomer'] == true ||
          data['profileCompleteEmployee'] == true;

      if (!completed) {
        await userRef.set(
          {
            'role': FieldValue.delete(),
            'profileCompleted': FieldValue.delete(),
            'profileComplete': FieldValue.delete(),
            'profileCompleteCustomer': FieldValue.delete(),
            'profileCompleteEmployee': FieldValue.delete(),
            'verified': FieldValue.delete(),
          },
          SetOptions(merge: true),
        );

        debugPrint('Incomplete profile reset');
      }
    } catch (e) {
      debugPrint('Reset profile error: $e');
    }
  }

  Future<void> _submit() async {
    if (_loading) return;

    final form = _formKey.currentState;

    if (form == null || !form.validate()) return;

    form.save();

    setState(() => _loading = true);

    try {
      //////////////////////////////////////////////////////////
      /// CURRENT USER
      //////////////////////////////////////////////////////////

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          'User not signed in',
        );
      }

      //////////////////////////////////////////////////////////
      /// VARIABLES
      //////////////////////////////////////////////////////////

      final String uid = user.uid;

      final String role = widget.role.toLowerCase().trim();

      final prefs = await SharedPreferences.getInstance();

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      //////////////////////////////////////////////////////////
      /// USERS COLLECTION
      //////////////////////////////////////////////////////////

      await userRef.set(
        {
          //////////////////////////////////////////////////////
          /// BASIC INFO
          //////////////////////////////////////////////////////

          'uid': uid,

          'fullName': widget.name,

          'name': widget.name,

          'email': widget.email,

          'role': role,

          //////////////////////////////////////////////////////
          /// CONTACT
          //////////////////////////////////////////////////////

          'phone': _phone.trim(),

          'city': _city.trim(),

          'address': _address.trim(),

          'gender': _gender,

          //////////////////////////////////////////////////////
          /// PROFILE STATUS
          //////////////////////////////////////////////////////

          'profileCompleted': true,

          'profileComplete': true,

          'accountStatus': 'active',

          //////////////////////////////////////////////////////
          /// ROLE FLAGS
          //////////////////////////////////////////////////////

          if (role == 'customer') 'profileCompleteCustomer': true,

          if (role == 'employee') ...{
            'profileCompleteEmployee': true,
            'employeeApprovalStatus': 'pending',
            'employeeVerified': false,
            'isApprovedEmployee': false,
            'requestedRole': 'employee',
          },

          //////////////////////////////////////////////////////
          /// PHOTO
          //////////////////////////////////////////////////////

          'photoUrl': user.photoURL,

          //////////////////////////////////////////////////////
          /// TIMESTAMPS
          //////////////////////////////////////////////////////

          'updatedAt': FieldValue.serverTimestamp(),

          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      //////////////////////////////////////////////////////////
      /// PUBLIC USERS COLLECTION
      //////////////////////////////////////////////////////////

      await FirebaseFirestore.instance.collection('publicUsers').doc(uid).set(
        {
          'uid': uid,

          'name': widget.name,

          'email': widget.email,

          'role': role,

          'city': _city.trim(),

          'photoUrl': user.photoURL,

          //////////////////////////////////////////////////////
          /// EMPLOYEE INFO
          //////////////////////////////////////////////////////

          if (role == 'employee') ...{
            'employeeApprovalStatus': 'pending',
            'requestedRole': 'employee',
            'online': false,
            'available': false,
          },

          //////////////////////////////////////////////////////
          /// TIMESTAMP
          //////////////////////////////////////////////////////

          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      //////////////////////////////////////////////////////////
      /// SHARED PREFERENCES
      //////////////////////////////////////////////////////////

      await prefs.setString(
        'role',
        role,
      );

      await prefs.setBool(
        'profileCompleted',
        true,
      );

      if (role == 'customer') {
        await prefs.setBool(
          'profileCompleteCustomer',
          true,
        );
      }

      if (role == 'employee') {
        await prefs.setBool(
          'profileCompleteEmployee',
          true,
        );
      }

      //////////////////////////////////////////////////////////
      /// BACKEND SYNC
      //////////////////////////////////////////////////////////

      await _syncProfileWithBackend(
        user: user,
        uid: uid,
      );

      //////////////////////////////////////////////////////////
      /// NAVIGATION
      //////////////////////////////////////////////////////////

      if (!mounted) return;

      //////////////////////////////////////////////////////////
      /// CUSTOMER
      //////////////////////////////////////////////////////////

      if (role == 'customer') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const CustomerDashboardScreen(),
          ),
          (route) => false,
        );

        return;
      }

      //////////////////////////////////////////////////////////
      /// EMPLOYEE
      //////////////////////////////////////////////////////////

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => EmployeePendingScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint(
        'PROFILE ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            '❌ Error: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _syncProfileWithBackend({
    required User user,
    required String uid,
  }) async {
    try {
      final String? idToken = await user.getIdToken(true);

      await http
          .post(
            Uri.parse('${Config.apiBaseUrl}/update-profile'),
            headers: {
              'Content-Type': 'application/json',
              if (idToken != null) 'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(
              {
                'uid': uid,
                'email': widget.email,
                'name': widget.name,
                'role': widget.role.toLowerCase().trim(),
                'phone': _phone.trim(),
                'city': _city.trim(),
                'address': _address.trim(),
                'gender': _gender,
              },
            ),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('Backend sync skipped: $e');
    }
  }

  Future<void> _logout() async {
    await _resetIncompleteProfile();

    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      debugPrint('Google sign out skipped: $e');
    }

    await FirebaseAuth.instance.signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePage(),
      ),
      (route) => false,
    );
  }

  Future<void> _cancelRegistration() async {
    await _resetIncompleteProfile();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePage(),
      ),
      (route) => false,
    );
  }

  String? _requiredValidator(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }

    return null;
  }

  Widget _premiumField({
    required String label,
    required IconData icon,
    required void Function(String?) onSaved,
    required String? Function(String?) validator,
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        keyboardType: maxLines > 1 ? TextInputType.multiline : inputType,
        textInputAction:
            maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
        maxLines: maxLines,
        onSaved: onSaved,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: darkGreen,
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: darkGreen,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.red.shade400,
              width: 1.4,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.red.shade600,
              width: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _genderCard({
    required String emoji,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? darkGreen : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? darkGreen : Colors.grey.shade300,
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: darkGreen.withOpacity(0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_redirectingEmployee) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: CircularProgressIndicator(
            color: darkGreen,
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _resetIncompleteProfile();
        return true;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    darkGreen,
                    lightGreen,
                    bgColor,
                  ],
                  stops: [0.0, 0.28, 0.28],
                ),
              ),
            ),
            SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(22),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Complete Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _loading ? null : _logout,
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Set up your SmartFixOman account',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 25,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 52,
                                backgroundColor: darkGreen.withOpacity(0.10),
                                backgroundImage: FirebaseAuth
                                            .instance.currentUser?.photoURL !=
                                        null
                                    ? NetworkImage(
                                        FirebaseAuth
                                            .instance.currentUser!.photoURL!,
                                      )
                                    : null,
                                child: FirebaseAuth
                                            .instance.currentUser?.photoURL ==
                                        null
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 54,
                                        color: darkGreen,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: darkGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            widget.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.email,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _premiumField(
                            label: 'Phone Number',
                            icon: Icons.phone_rounded,
                            inputType: TextInputType.phone,
                            onSaved: (value) => _phone = value ?? '',
                            validator: (value) => _requiredValidator(
                              value,
                              'Enter phone number',
                            ),
                          ),
                          _premiumField(
                            label: 'City',
                            icon: Icons.location_city_rounded,
                            onSaved: (value) => _city = value ?? '',
                            validator: (value) => _requiredValidator(
                              value,
                              'Enter city',
                            ),
                          ),
                          _premiumField(
                            label: 'Address',
                            icon: Icons.home_rounded,
                            maxLines: 2,
                            onSaved: (value) => _address = value ?? '',
                            validator: (value) => _requiredValidator(
                              value,
                              'Enter address',
                            ),
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Gender',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _genderCard(
                                  emoji: '👨',
                                  title: 'Male',
                                  selected: _gender == 'male',
                                  onTap: () {
                                    setState(() => _gender = 'male');
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _genderCard(
                                  emoji: '👩',
                                  title: 'Female',
                                  selected: _gender == 'female',
                                  onTap: () {
                                    setState(() => _gender = 'female');
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 34),
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: darkGreen,
                                disabledBackgroundColor: Colors.grey.shade400,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 0,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Continue',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _loading ? null : _cancelRegistration,
                            child: const Text(
                              'Cancel Registration',
                              style: TextStyle(
                                color: darkGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
