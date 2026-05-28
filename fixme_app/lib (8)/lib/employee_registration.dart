// lib/employee_registration.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'employee_dashboard.dart';
import 'home_page.dart' show Config;

/// Canonical profession options
class ProfessionOption {
  final String label; // Dropdown label with emoji
  final String name;  // Clean name for DB
  final String emoji; // Emoji only
  const ProfessionOption(this.label, this.name, this.emoji);
}

const List<ProfessionOption> kProfessionOptions = [
  ProfessionOption("Technician 🛠️", "Technician", "🛠️"),
  ProfessionOption("Electrician 💡", "Electrician", "💡"),
  ProfessionOption("Plumber 🔧", "Plumber", "🔧"),
  ProfessionOption("Painter 🎨", "Painter", "🎨"),
  ProfessionOption("Cleaner 🧹", "Cleaner", "🧹"),
  ProfessionOption("Carpenter 🪚", "Carpenter", "🪚"),
  ProfessionOption("Handyman 🔨", "Handyman", "🔨"),
];

ProfessionOption _findOptionByLabel(String label) =>
    kProfessionOptions.firstWhere((o) => o.label == label,
        orElse: () => kProfessionOptions.first);

ProfessionOption _findOptionByName(String name) =>
    kProfessionOptions.firstWhere(
      (o) => o.name.toLowerCase() == name.toLowerCase(),
      orElse: () => kProfessionOptions.first,
    );

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
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  // Controllers
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final licenseCtrl = TextEditingController();
  final plateCtrl = TextEditingController();
  final fareCtrl = TextEditingController();

  String? _selectedProfessionLabel;
  File? _imageFile;
  String? _existingImageUrl;
  bool _isLoading = false;

  static const _green = Color(0xFF01411C);

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _loadExistingData(widget.existingData!);
    }
  }

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    licenseCtrl.dispose();
    plateCtrl.dispose();
    fareCtrl.dispose();
    super.dispose();
  }

  void _loadExistingData(Map<String, dynamic> data) {
    fareCtrl.text = (data["fare"] ?? "").toString();
    plateCtrl.text = (data["carPlate"] ?? "").toString();
    _existingImageUrl = data["profileImage"] as String?;

    final profName = data["profession"] as String?;
    if (profName != null && profName.trim().isNotEmpty) {
      _selectedProfessionLabel = _findOptionByName(profName).label;
    }
    setState(() {});
  }

  // ────────────────────────── UI Helpers ──────────────────────────
  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
              letterSpacing: .3,
            )),
      );

  InputDecoration _dec({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: _green, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _dec(label: label, icon: icon, hint: hint),
      validator: validator ??
          (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }

  // ───────────────────────── Image Picker ─────────────────────────
  Future<void> _pickImageSheet() async {
    final picker = ImagePicker();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () async {
              final x = await picker.pickImage(source: ImageSource.camera);
              if (x != null) setState(() => _imageFile = File(x.path));
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () async {
              final x = await picker.pickImage(source: ImageSource.gallery);
              if (x != null) setState(() => _imageFile = File(x.path));
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ───────────────────────── Submit ─────────────────────────
  Future<void> _submit() async {
  if (!_formKey.currentState!.validate() || _selectedProfessionLabel == null) {
    return;
  }
  setState(() => _isLoading = true);

  try {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not signed in");

    final uid = user.uid;
    final email = widget.email;
    final fullName = widget.name;
    final idToken = await user.getIdToken();
    final opt = _findOptionByLabel(_selectedProfessionLabel!);

    // ---- Sync with Flask (PostgreSQL) ----
    final uri = Uri.parse("${Config.apiBaseUrl}/update-profile");
    final request = http.MultipartRequest("POST", uri);
    request.headers["Authorization"] = "Bearer $idToken";

    request.fields.addAll({
      "email": email,
      "name": fullName,
      "profession": opt.name,
      "professionEmoji": opt.emoji,
      "fare": fareCtrl.text.trim(),
      "license": licenseCtrl.text.trim(),
      "carPlate": plateCtrl.text.trim(),
      "firstName": firstNameCtrl.text.trim(),
      "lastName": lastNameCtrl.text.trim(),
      "role": "employee",
    });

    if (_imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath("file", _imageFile!.path),
      );
    }

    final streamed = await request.send();
    final respStr = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw Exception("Flask update failed: $respStr");
    }

    try {
    } catch (_) {
      // ignore if Flask didn’t return JSON
    }

    // 🔑 Build backend image URL (always available after Flask save)
    final imageUrl = "${Config.apiBaseUrl}/profile-image/$email";

    // ---- Sync lightweight data to Firestore ----
    await FirebaseFirestore.instance.collection("users").doc(uid).set({
      "fullName": fullName,
      "name": fullName,
      "profession": opt.name,
      "professionEmoji": opt.emoji,
      "carPlate": plateCtrl.text.trim(),
      "fare": double.tryParse(fareCtrl.text.trim()) ?? 0.0,
      "email": email,
      "role": "employee",
      "verified": true,
      "profileImage": imageUrl, // ✅ now saved for SettingsScreen
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection("publicUsers").doc(uid).set({
      "name": fullName,
      "role": "employee",
      "city": "",
      "profession": opt.name,
      "professionEmoji": opt.emoji,
      "fare": double.tryParse(fareCtrl.text.trim()) ?? 0.0,
      "profileImage": imageUrl, // ✅ also public profile
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile saved successfully")),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EmployeeDashboardScreen()),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}


  // ───────────────────────── Build ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingData != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Profile' : 'Employee Registration'),
        centerTitle: true,
        backgroundColor: _green,
      ),
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile avatar card
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 56,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: _imageFile != null
                                  ? FileImage(_imageFile!)
                                  : (_existingImageUrl != null
                                      ? NetworkImage(_existingImageUrl!)
                                      : null) as ImageProvider<Object>?,
                              child: (_imageFile == null &&
                                      _existingImageUrl == null)
                                  ? const Icon(Icons.person,
                                      size: 48, color: Colors.black38)
                                  : null,
                            ),
                            Material(
                              color: _green,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _pickImageSheet,
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.camera_alt,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        Text(
                          widget.email,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),

                _sectionTitle('Basic information'),
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _field(
                          controller: firstNameCtrl,
                          label: 'First name',
                          icon: Icons.badge_outlined,
                          hint: 'e.g. Abdullah',
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: lastNameCtrl,
                          label: 'Last name',
                          icon: Icons.badge,
                          hint: 'e.g. Muhammad',
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedProfessionLabel,
                          decoration: _dec(
                            label: 'Profession',
                            icon: Icons.work_outline,
                            hint: 'Select your category',
                          ),
                          items: kProfessionOptions
                              .map((o) => DropdownMenuItem(
                                    value: o.label,
                                    child: Text(o.label),
                                  ))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedProfessionLabel = val),
                          validator: (v) =>
                              v == null ? 'Please select a profession' : null,
                        ),
                      ],
                    ),
                  ),
                ),

                _sectionTitle('Verification'),
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _field(
                          controller: licenseCtrl,
                          label: 'Driving license number',
                          icon: Icons.credit_card,
                          hint: 'e.g. OM-123456',
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: plateCtrl,
                          label: 'Car number plate',
                          icon: Icons.directions_car,
                          hint: 'e.g. A 1234',
                        ),
                      ],
                    ),
                  ),
                ),

                _sectionTitle('Earnings'),
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: _field(
                      controller: fareCtrl,
                      label: 'Base fare (PKR)',
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                      hint: 'Enter your standard fare',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final n = double.tryParse(v);
                        if (n == null || n < 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      widget.existingData != null
                          ? 'Save changes'
                          : 'Register & start',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
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
