import 'package:flutter/material.dart';

class AdminFeedbackDetailScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const AdminFeedbackDetailScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  Widget rowItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text((value ?? 'N/A').toString()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                rowItem('Feedback ID', docId),
                rowItem('User ID', data['userId']),
                rowItem('Message', data['message']),
                rowItem('Email', data['email']),
                rowItem('Name', data['name']),
                rowItem('Timestamp', data['timestamp']),
              ],
            ),
          ),
        ),
      ),
    );
  }
}