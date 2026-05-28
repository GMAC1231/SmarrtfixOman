import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  bool loading = true;
  List<dynamic> items = [];
  String? error;

  static const String baseUrl = 'http://192.168.100.15:5000'; // emulator
  // use your real backend URL on device

  Future<void> loadFeedback() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });

      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) {
        throw Exception('No Firebase token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/feedback'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final body = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(body['error'] ?? 'Failed to load feedback');
      }

      setState(() {
        items = body['items'] ?? [];
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> deleteFeedback(int id) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw Exception('No Firebase token found');

      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/feedback/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final body = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(body['error'] ?? 'Delete failed');
      }

      await loadFeedback();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    loadFeedback();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        actions: [
          IconButton(
            onPressed: loadFeedback,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : items.isEmpty
                  ? const Center(child: Text('No feedback found'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index] as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.all(10),
                          child: ListTile(
                            leading: const Icon(Icons.feedback),
                            title: Text((item['title'] ?? 'No title').toString()),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((item['message'] ?? '').toString()),
                                const SizedBox(height: 4),
                                Text('Email: ${(item['user_email'] ?? '-').toString()}'),
                                Text('Platform: ${(item['platform'] ?? '-').toString()}'),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => deleteFeedback(item['id'] as int),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}