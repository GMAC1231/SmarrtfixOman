import 'package:flutter/material.dart';

class AdminEmployeeDetailScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const AdminEmployeeDetailScreen({
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
            width: 130,
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
        title: const Text('Employee Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                rowItem('Document ID', docId),
                rowItem('Name', data['name']),
                rowItem('Email', data['email']),
                rowItem('Role', data['role']),
                rowItem('Phone', data['phone']),
                rowItem('Profession', data['profession']),
                rowItem('Profession Emoji', data['professionEmoji']),
                rowItem('City', data['city']),
                rowItem('Fare', data['fare']),
                rowItem('Address', data['address']),
                rowItem('UID', data['uid']),
              ],
            ),
          ),
        ),
      ),
    );
  }
}