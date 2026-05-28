import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectRoleScreen extends StatefulWidget {
  final User firebaseUser;
  const SelectRoleScreen({super.key, required this.firebaseUser});

  @override
  State<SelectRoleScreen> createState() => _SelectRoleScreenState();
}

class _SelectRoleScreenState extends State<SelectRoleScreen> {
  bool isLoading = false;

  Future<void> _selectRole(BuildContext context, String role) async {
    if (isLoading) return; // prevent double taps
    setState(() => isLoading = true);

    final uid = widget.firebaseUser.uid;

    try {
      // Save role in Firestore with timestamp
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'role': role,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Save role locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', role);

      // Navigate to correct dashboard
      if (!mounted) return;
      if (role == 'employee') {
        Navigator.pushReplacementNamed(context, '/employee_dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/customer_dashboard');
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Firebase error: ${e.message}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to save role: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Select Role")),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "What do you want to be?",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 50),
                      backgroundColor: scheme.primary,
                    ),
                    icon: const Icon(Icons.person),
                    label: const Text("Customer"),
                    onPressed: () => _selectRole(context, 'customer'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 50),
                      backgroundColor: scheme.secondary,
                    ),
                    icon: const Icon(Icons.handyman),
                    label: const Text("Employee"),
                    onPressed: () => _selectRole(context, 'employee'),
                  ),
                ],
              ),
      ),
    );
  }
}