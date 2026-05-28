import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_employee_detail_screen.dart';

class AdminEmployeesScreen extends StatelessWidget {
  const AdminEmployeesScreen({super.key});

  Future<void> _setEmployeeStatus(String uid, String status) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'accountStatus': status,
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('publicUsers').doc(uid).set({
      'accountStatus': status,
    }, SetOptions(merge: true));
  }

  Future<void> _deleteEmployee(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    await FirebaseFirestore.instance.collection('publicUsers').doc(uid).delete();
  }

  void _showActions(BuildContext context, String uid, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('View details'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminEmployeeDetailScreen(
                        docId: uid,
                        data: data,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Suspend employee'),
                onTap: () async {
                  Navigator.pop(context);
                  await _setEmployeeStatus(uid, 'suspended');
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('Activate employee'),
                onTap: () async {
                  Navigator.pop(context);
                  await _setEmployeeStatus(uid, 'active');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete employee'),
                onTap: () async {
                  Navigator.pop(context);
                  await _deleteEmployee(uid);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'employee')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No employees found'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = (data['accountStatus'] ?? 'active').toString();

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.engineering)),
                  title: Text((data['name'] ?? 'No name').toString()),
                  subtitle: Text(
                    '${(data['email'] ?? 'No email')} • Status: $status',
                  ),
                  trailing: const Icon(Icons.more_vert),
                  onTap: () => _showActions(context, doc.id, data),
                ),
              );
            },
          );
        },
      ),
    );
  }
}