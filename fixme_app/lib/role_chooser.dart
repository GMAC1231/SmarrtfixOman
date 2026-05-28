import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/admin_whitelist.dart';

Future<String?> pickRole(BuildContext context) async {

  final email =
      FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim() ?? "";

  /// 🔐 ADMIN BYPASS
  if (AdminWhitelist.isAdmin(email)) {
    return 'admin';
  }

  String selected = 'customer';

  await Future.delayed(Duration.zero); // ensure a frame exists

  return showDialog<String>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('Continue as'),
      content: StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'customer',
              groupValue: selected,
              onChanged: (v) => setState(() => selected = v!),
              title: const Text('Customer'),
            ),
            RadioListTile<String>(
              value: 'employee',
              groupValue: selected,
              onChanged: (v) => setState(() => selected = v!),
              title: const Text('Employee'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(selected),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}