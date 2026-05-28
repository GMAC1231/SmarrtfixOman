import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  ////////////////////////////////////////////////////////////
  /// CONTROLLERS
  ////////////////////////////////////////////////////////////

  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();

  final _descCtrl = TextEditingController();

  ////////////////////////////////////////////////////////////
  /// STATE
  ////////////////////////////////////////////////////////////

  bool _sending = false;

  bool _anonymous = false;

  ////////////////////////////////////////////////////////////
  /// API
  ////////////////////////////////////////////////////////////

  static const String _apiBase = String.fromEnvironment(
    'PUBLIC_BASE_URL',
    defaultValue: 'http://192.168.100.15:5000',
  );

  ////////////////////////////////////////////////////////////
  /// DISPOSE
  ////////////////////////////////////////////////////////////

  @override
  void dispose() {
    _titleCtrl.dispose();

    _descCtrl.dispose();

    super.dispose();
  }

  ////////////////////////////////////////////////////////////
  /// SEND FEEDBACK
  ////////////////////////////////////////////////////////////

  Future<void> _send() async {
    if (_sending) return;

    final user = FirebaseAuth.instance.currentUser;

    //////////////////////////////////////////////////////////
    /// LOGIN CHECK
    //////////////////////////////////////////////////////////

    if (!_anonymous && user == null) {
      _showSnack(
        'Please sign in or enable anonymous mode.',
        isError: true,
      );

      return;
    }

    //////////////////////////////////////////////////////////
    /// VALIDATE
    //////////////////////////////////////////////////////////

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      ////////////////////////////////////////////////////////
      /// VALUES
      ////////////////////////////////////////////////////////

      final String title = _titleCtrl.text.trim();

      final String message = _descCtrl.text.trim();

      final info = await PackageInfo.fromPlatform();

      final appVersion = info.version;

      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'other';

      ////////////////////////////////////////////////////////
      /// FIRESTORE SAVE
      ////////////////////////////////////////////////////////

      await FirebaseFirestore.instance.collection('feedback').add({
        'title': title,
        'message': message,
        'userId': _anonymous ? null : user?.uid,
        'userEmail': _anonymous ? null : user?.email,
        'anonymous': _anonymous,
        'platform': platform,
        'appVersion': appVersion,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ////////////////////////////////////////////////////////
      /// OPTIONAL BACKEND SEND
      ////////////////////////////////////////////////////////

      try {
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
          'anonymous': _anonymous,
          'platform': platform,
          'appVersion': appVersion,
          if (!_anonymous && user?.email != null) 'userEmail': user!.email,
        };

        final uri = Uri.parse(
          '$_apiBase/api/feedback',
        );

        final resp = await http
            .post(
              uri,
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(
              const Duration(
                seconds: 20,
              ),
            );

        debugPrint(
          "API STATUS: ${resp.statusCode}",
        );
      } catch (e) {
        debugPrint(
          "API SEND FAILED: $e",
        );
      }

      ////////////////////////////////////////////////////////
      /// SUCCESS
      ////////////////////////////////////////////////////////

      _showSnack(
        'Feedback sent successfully 🎉',
      );

      _titleCtrl.clear();

      _descCtrl.clear();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e, stack) {
      ////////////////////////////////////////////////////////
      /// ERROR
      ////////////////////////////////////////////////////////

      _showSnack(
        'Failed to send feedback: $e',
        isError: true,
      );

      if (kDebugMode) {
        debugPrint(
          'Feedback error: $e',
        );

        debugPrint('$stack');
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  ////////////////////////////////////////////////////////////
  /// SNACKBAR
  ////////////////////////////////////////////////////////////

  void _showSnack(
    String msg, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// BUILD
  ////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F9D58),
        foregroundColor: Colors.white,
        title: const Text(
          'Send Feedback',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F9D58),
              Color(0xFFF5F7FB),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  //////////////////////////////////////////////////
                  /// HEADER
                  //////////////////////////////////////////////////

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        30,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            0.06,
                          ),
                          blurRadius: 14,
                          offset: const Offset(
                            0,
                            8,
                          ),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(
                            18,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0F9D58,
                            ).withOpacity(
                              0.1,
                            ),
                            borderRadius: BorderRadius.circular(
                              24,
                            ),
                          ),
                          child: const Icon(
                            Icons.feedback_rounded,
                            size: 60,
                            color: Color(
                              0xFF0F9D58,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 18,
                        ),
                        const Text(
                          'We value your feedback',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        Text(
                          'Help us improve SmartFixOman with your suggestions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 22,
                  ),

                  //////////////////////////////////////////////////
                  /// FORM
                  //////////////////////////////////////////////////

                  Container(
                    padding: const EdgeInsets.all(
                      22,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        30,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            0.05,
                          ),
                          blurRadius: 12,
                          offset: const Offset(
                            0,
                            6,
                          ),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        //////////////////////////////////////////////////
                        /// TITLE
                        //////////////////////////////////////////////////

                        TextFormField(
                          controller: _titleCtrl,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            hintText: 'Feedback title',
                            prefixIcon: const Icon(
                              Icons.title,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                18,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter title';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        //////////////////////////////////////////////////
                        /// MESSAGE
                        //////////////////////////////////////////////////

                        TextFormField(
                          controller: _descCtrl,
                          minLines: 6,
                          maxLines: 10,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            hintText: 'Describe your issue or suggestion...',
                            alignLabelWithHint: true,
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(
                                bottom: 120,
                              ),
                              child: Icon(
                                Icons.message,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                18,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter description';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        //////////////////////////////////////////////////
                        /// ANONYMOUS
                        //////////////////////////////////////////////////

                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Send anonymously',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Hide your profile information',
                          ),
                          value: _anonymous,
                          activeColor: const Color(
                            0xFF0F9D58,
                          ),
                          onChanged: (v) {
                            setState(() {
                              _anonymous = v;
                            });
                          },
                        ),

                        const SizedBox(
                          height: 20,
                        ),

                        //////////////////////////////////////////////////
                        /// BUTTON
                        //////////////////////////////////////////////////

                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton.icon(
                            onPressed: _sending ? null : _send,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF0F9D58,
                              ),
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  18,
                                ),
                              ),
                            ),
                            icon: _sending
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                  ),
                            label: Text(
                              _sending ? 'Sending...' : 'Send Feedback',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
