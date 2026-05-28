import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _sending = false;
  bool _anonymous = false;

  static const String _apiBase = String.fromEnvironment(
    'PUBLIC_BASE_URL',
    defaultValue: 'http://192.168.100.15:5000',
  );

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;

    final user = FirebaseAuth.instance.currentUser;

    if (!_anonymous && user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in or enable anonymous mode.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    try {
      final String title = _titleCtrl.text.trim();
      final String message = _descCtrl.text.trim();
      final info = await PackageInfo.fromPlatform();
      final appVersion = info.version;
      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'other';

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (!_anonymous && user != null) {
        final token = await user.getIdToken();
        headers['Authorization'] = 'Bearer $token';
      }

      final body = {
        'title': title,
        'message': message,
        'appVersion': appVersion,
        'platform': platform,
        'anonymous': _anonymous,
        if (!_anonymous && user?.email?.isNotEmpty == true)
          'userEmail': user!.email,
      };

      final uri = Uri.parse('$_apiBase/api/feedback');
      final resp = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        _showSnack('Thanks! Your feedback was sent.');
        Navigator.pop(context);
      } else if (resp.statusCode == 202) {
        _showSnack('Feedback saved. Email failed: ${resp.body}', isError: true);
        if (kDebugMode) debugPrint("Backend 202: ${resp.body}");
        Navigator.pop(context);
      } else {
        throw Exception('Backend error ${resp.statusCode}: ${resp.body}');
      }

      // Optional: Store in Firestore
      /*
      await FirebaseFirestore.instance.collection('feedback').add({
        'title': title,
        'message': message,
        'userId': _anonymous ? null : user?.uid,
        'userEmail': _anonymous ? null : user?.email,
        'anonymous': _anonymous,
        'createdAt': FieldValue.serverTimestamp(),
        'appVersion': appVersion,
        'platform': platform,
      });
      */
    } catch (e, stack) {
      _showSnack('Could not send feedback: $e', isError: true);
      if (kDebugMode) {
        debugPrint('Feedback error: $e');
        debugPrint('$stack');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sending ? null : _send,
        icon: const Icon(Icons.send),
        label: Text(_sending ? 'Sending…' : 'Send'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  maxLines: null,
                  expands: true,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Please enter a description' : null,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Send anonymously'),
                value: _anonymous,
                onChanged: (v) => setState(() => _anonymous = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
