// lib/complete_profile_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final _formKey = GlobalKey<FormState>();

  String _phone = "";
  String _city = "";
  String _address = "";
  String _gender = "male";
  bool _loading = false;

  static const pakistanGreen = Color(0xFF01411C);

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception("User not signed in");
      }

      final uid = user.uid;

      // 1) Save immediately in Firestore so app flow doesn't block on backend
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        "fullName": widget.name,
        "name": widget.name,
        "email": widget.email,
        "role": widget.role,
        "phone": _phone,
        "city": _city,
        "address": _address,
        "gender": _gender,
        "profileComplete": true,
        if (widget.role == 'customer') 'profileCompleteCustomer': true,
        if (widget.role == 'employee') 'profileCompleteEmployee': true,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection("publicUsers").doc(uid).set({
        "name": widget.name,
        "role": widget.role,
        "city": _city,
        "photoUrl": user.photoURL,
        if (widget.role == 'employee') ...{
          "profession": "",
          "professionEmoji": "",
          "fare": 0,
        },
      }, SetOptions(merge: true));

      // 2) Local cache
      await prefs.setString("role", widget.role);
      await prefs.setBool("profileComplete", true);
      await prefs.setString("phone", _phone);
      await prefs.setString("city", _city);
      await prefs.setString("address", _address);
      await prefs.setBool("isEmployee", widget.role == 'employee');

      // 3) Backend sync with timeout so UI doesn't hang forever
      try {
        final idToken = await user.getIdToken(true);

        final res = await http
            .post(
              Uri.parse("${Config.apiBaseUrl}/update-profile"),
              headers: {
                "Content-Type": "application/json",
                "Authorization": "Bearer $idToken",
              },
              body: jsonEncode({
                "email": widget.email,
                "name": widget.name,
                "role": widget.role,
                "phone": _phone,
                "city": _city,
                "address": _address,
                "gender": _gender,
              }),
            )
            .timeout(const Duration(seconds: 12));

        if (res.statusCode != 200) {
          String msg = "Backend failed";
          try {
            final err = jsonDecode(res.body);
            msg = err['error']?.toString() ?? res.body;
          } catch (_) {
            msg = res.body;
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("⚠ Backend sync failed: $msg")),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("⚠ Backend sync skipped: $e")),
          );
        }
      }

      if (!mounted) return;

      if (widget.role == "customer") {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CustomerDashboardScreen()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => EmployeeRegistrationScreen(
              email: widget.email,
              name: widget.name,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required Function(String?) onSaved,
    required String? Function(String?) validator,
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: pakistanGreen),
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: pakistanGreen, width: 2),
          ),
        ),
        maxLines: maxLines,
        keyboardType: inputType,
        onSaved: onSaved,
        validator: validator,
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ChoiceChip(
          avatar: const Text("👨"),
          label: const Text("Male"),
          selected: _gender == "male",
          selectedColor: pakistanGreen,
          labelStyle: TextStyle(
            color: _gender == "male" ? Colors.white : Colors.black,
          ),
          onSelected: (_) => setState(() => _gender = "male"),
        ),
        ChoiceChip(
          avatar: const Text("👩"),
          label: const Text("Female"),
          selected: _gender == "female",
          selectedColor: pakistanGreen,
          labelStyle: TextStyle(
            color: _gender == "female" ? Colors.white : Colors.black,
          ),
          onSelected: (_) => setState(() => _gender = "female"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text("✨ Complete Profile"),
        backgroundColor: pakistanGreen,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Logout",
            onPressed: _logout,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
                elevation: 3,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: pakistanGreen.withOpacity(0.1),
                    child: const Text("👤", style: TextStyle(fontSize: 22)),
                  ),
                  title: Text(
                    widget.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    widget.role == "customer" ? "🛒 Customer" : "🛠️ Employee",
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                label: "📞 Phone Number",
                icon: Icons.phone,
                inputType: TextInputType.phone,
                onSaved: (val) => _phone = val ?? "",
                validator: (val) =>
                    val == null || val.trim().isEmpty ? "Enter phone number" : null,
              ),
              _buildTextField(
                label: "🏙️ City",
                icon: Icons.location_city,
                onSaved: (val) => _city = val ?? "",
                validator: (val) =>
                    val == null || val.trim().isEmpty ? "Enter city" : null,
              ),
              _buildTextField(
                label: "🏠 Address",
                icon: Icons.home,
                maxLines: 2,
                onSaved: (val) => _address = val ?? "",
                validator: (val) =>
                    val == null || val.trim().isEmpty ? "Enter address" : null,
              ),
              const SizedBox(height: 16),
              const Text(
                "⚧ Gender",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildGenderSelector(),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("💾"),
                label: Text(
                  _loading ? "Saving..." : "Save & Continue ➡️",
                  style: const TextStyle(fontSize: 17, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pakistanGreen,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}