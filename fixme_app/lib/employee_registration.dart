

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'employee_pending_screen.dart';
import 'home_page.dart' show Config;

class ProfessionOption {
  final String label;
  final String value;
  final String emoji;

  const ProfessionOption({
    required this.label,
    required this.value,
    required this.emoji,
  });
}

const List<ProfessionOption> professions = [
  ProfessionOption(label: "Technician", value: "Technician", emoji: "🛠️"),
  ProfessionOption(label: "Electrician", value: "Electrician", emoji: "💡"),
  ProfessionOption(label: "Plumber", value: "Plumber", emoji: "🔧"),
  ProfessionOption(label: "Painter", value: "Painter", emoji: "🎨"),
  ProfessionOption(label: "Cleaner", value: "Cleaner", emoji: "🧹"),
  ProfessionOption(label: "Carpenter", value: "Carpenter", emoji: "🪚"),
  ProfessionOption(label: "Handyman", value: "Handyman", emoji: "🔨"),
];

class EmployeeRegistrationScreen extends StatefulWidget {
  final String email;
  final String name;
  final Map<String, dynamic>? existingData;

  const EmployeeRegistrationScreen({
    super.key,
    required this.email,
    required this.name,
    this.existingData,
  });

  @override
  State<EmployeeRegistrationScreen> createState() =>
      _EmployeeRegistrationScreenState();
}

class _EmployeeRegistrationScreenState
    extends State<EmployeeRegistrationScreen> {
  static const Color primaryGreen = Color(0xFF01411C);
  static const Color secondaryGreen = Color(0xFF0B6B33);

  final _formKey = GlobalKey<FormState>();

  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final licenseCtrl = TextEditingController();
  final carModelCtrl = TextEditingController();
  final carPlateCtrl = TextEditingController();

  String? selectedProfession;
  File? profileImage;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    final data = widget.existingData;

    if (data != null) {
      firstNameCtrl.text = data['firstName'] ?? '';
      lastNameCtrl.text = data['lastName'] ?? '';
      phoneCtrl.text = data['phone'] ?? '';
      cityCtrl.text = data['city'] ?? '';
      addressCtrl.text = data['address'] ?? '';
      licenseCtrl.text = data['license'] ?? '';
      carModelCtrl.text = data['carModel'] ?? '';
      carPlateCtrl.text = data['carPlate'] ?? '';
      selectedProfession = data['profession'];
    }
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    phoneCtrl.dispose();
    cityCtrl.dispose();
    addressCtrl.dispose();
    licenseCtrl.dispose();
    carModelCtrl.dispose();
    carPlateCtrl.dispose();
    super.dispose();
  }

  Future<void> pickProfileImage() async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
      maxWidth: 900,
    );

    if (picked != null) {
      setState(() {
        profileImage = File(picked.path);
      });
    }
  }

  Future<void> _resetIncompleteEmployeeProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snap = await ref.get();
      final data = snap.data() ?? {};

      final completed =
          data['profileCompleted'] == true || data['profileComplete'] == true;

      if (!completed) {
        await ref.set({
          'role': FieldValue.delete(),
          'profileCompleted': FieldValue.delete(),
          'profileComplete': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Reset error: $e");
    }
  }

  InputDecoration fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: label,
      prefixIcon: Icon(icon, color: primaryGreen),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: primaryGreen, width: 2),
      ),
    );
  }

  Widget buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Required";
          }
          return null;
        },
        decoration: fieldDecoration(label: label, icon: icon),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 8),
        child: Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<String> _getFcmTokenSafe() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      return token ?? '';
    } catch (e) {
      debugPrint("FCM token error: $e");
      return '';
    }
  }

Future<void> _sendPendingEmail({
  required String email,
  required String name,
}) async {

  try {

    final url =
        '${Config.apiBaseUrl}/pending-employee';

    debugPrint(
      'EMAIL API URL: $url',
    );

    final response = await http.post(

      Uri.parse(url),

      headers: {

        'Content-Type':
            'application/json',
      },

      body: jsonEncode({

        'email': email,

        'name': name,
      }),
    );

    debugPrint(
      'EMAIL STATUS: ${response.statusCode}',
    );

    debugPrint(
      'EMAIL RESPONSE: ${response.body}',
    );

  } catch (e) {

    debugPrint(
      'Pending employee email error: $e',
    );
  }
}



  Future<void> submit() async {
    if (!_formKey.currentState!.validate() || selectedProfession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all fields")),
      );
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception("User not logged in");
      }

      final profession = professions.firstWhere(
        (e) => e.value == selectedProfession,
      );

      final fcmToken = await _getFcmTokenSafe();

      final fullName =
          "${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}".trim();

      final userData = {
        'uid': user.uid,
        'name': fullName,
        'displayName': fullName,
        'email': widget.email,
        'role': 'employee',
        'requestedRole': 'employee',
        'employeeApprovalStatus': 'pending',
        'employeeVerified': false,
        'isApprovedEmployee': false,
        'profession': profession.value,
        'professionEmoji': profession.emoji,
        'firstName': firstNameCtrl.text.trim(),
        'lastName': lastNameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'city': cityCtrl.text.trim(),
        'address': addressCtrl.text.trim(),
        'license': licenseCtrl.text.trim(),
        'carModel': carModelCtrl.text.trim(),
        'carPlate': carPlateCtrl.text.trim(),
        'providerRating': 5.0,
        'rating': 5.0,
        'totalReviews': 0,
        'totalJobs': 0,
'profileCompleted': true,

'profileComplete': true,

'profileCompleteEmployee': true,
        'fcmToken': fcmToken,
        'online': false,
        'available': false,
        'requestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final publicUserData = {
        'uid': user.uid,
        'name': fullName,
        'email': widget.email,
        'role': 'employee',
        'requestedRole': 'employee',
        'employeeApprovalStatus': 'pending',
        'employeeVerified': false,
        'isApprovedEmployee': false,
        'profession': profession.value,
        'professionEmoji': profession.emoji,
        'phone': phoneCtrl.text.trim(),
        'photoUrl': '',
        'carModel': carModelCtrl.text.trim(),
        'carPlate': carPlateCtrl.text.trim(),
        'rating': 5.0,
        'totalReviews': 0,
        'totalJobs': 0,
        'online': false,
        'available': false,
        'currentLat': 0.0,
        'currentLng': 0.0,
        'fcmToken': fcmToken,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final batch = FirebaseFirestore.instance.batch();

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final publicUserRef =
          FirebaseFirestore.instance.collection('publicUsers').doc(user.uid);

      batch.set(userRef, userData, SetOptions(merge: true));
      batch.set(publicUserRef, publicUserData, SetOptions(merge: true));

      await batch.commit();

      await _sendPendingEmail(
        email: widget.email,
        name: fullName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Employee request submitted for admin approval."),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const EmployeePendingScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _resetIncompleteEmployeeProfile();
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F6),
        appBar: AppBar(
          backgroundColor: primaryGreen,
          elevation: 0,
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                ),
                onPressed: () async {
                  await _resetIncompleteEmployeeProfile();

                  if (!mounted) return;

                  Navigator.pushReplacementNamed(context, '/home');
                },
              ),
            ),
          ),
          title: const Text(
            "Join SmartFixOman",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 42,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      gradient: const LinearGradient(
                        colors: [
                          primaryGreen,
                          secondaryGreen,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryGreen.withOpacity(0.25),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Column(
                      children: [
                        Text(
                          "Become a Service Provider",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 18),
                        Text(
                          "Create your professional profile. Admin approval is required before you can accept jobs.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  sectionTitle("Personal Information"),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        buildField(
                          controller: firstNameCtrl,
                          label: "First Name",
                          icon: Icons.person_outline,
                        ),
                        buildField(
                          controller: lastNameCtrl,
                          label: "Last Name",
                          icon: Icons.badge_outlined,
                        ),
                        buildField(
                          controller: phoneCtrl,
                          label: "Phone Number",
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                        buildField(
                          controller: cityCtrl,
                          label: "City",
                          icon: Icons.location_city,
                        ),
                        buildField(
                          controller: addressCtrl,
                          label: "Address",
                          icon: Icons.home_outlined,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: DropdownButtonFormField<String>(
                            value: selectedProfession,
                            decoration: fieldDecoration(
                              label: "Select Profession",
                              icon: Icons.handyman,
                            ),
                            items: professions.map((e) {
                              return DropdownMenuItem(
                                value: e.value,
                                child: Text("${e.emoji} ${e.label}"),
                              );
                            }).toList(),
                            validator: (value) {
                              if (value == null) {
                                return "Select profession";
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setState(() {
                                selectedProfession = value;
                              });
                            },
                          ),
                        ),
                        buildField(
                          controller: licenseCtrl,
                          label: "License / National ID",
                          icon: Icons.credit_card,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  sectionTitle("Car Information"),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        buildField(
                          controller: carModelCtrl,
                          label: "Car Model",
                          icon: Icons.directions_car_filled,
                        ),
                        buildField(
                          controller: carPlateCtrl,
                          label: "Car Number Plate",
                          icon: Icons.confirmation_number_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "After admin approval, customers will see:",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text("• Your name and phone number"),
                        Text("• Your profession"),
                        Text("• Your rating and total reviews"),
                        Text("• Your car model"),
                        Text("• Your car number plate"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline),
                                SizedBox(width: 10),
                                Text(
                                  "Submit for Approval",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

