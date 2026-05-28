import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_request_detail_screen.dart';

class AdminRequestsScreen extends StatelessWidget {
  const AdminRequestsScreen({super.key});

  Future<void> _deleteRequest(String docId) async {
    await FirebaseFirestore.instance.collection('serviceRequests').doc(docId).delete();
  }

  Future<void> _setStatus(String docId, String status) async {
    await FirebaseFirestore.instance.collection('serviceRequests').doc(docId).set({
      'status': status,
    }, SetOptions(merge: true));
  }

  void _showActions(BuildContext context, String docId, Map<String, dynamic> data) {
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
                      builder: (_) => AdminRequestDetailScreen(
                        docId: docId,
                        data: data,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('Mark completed'),
                onTap: () async {
                  Navigator.pop(context);
                  await _setStatus(docId, 'completed');
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Mark cancelled'),
                onTap: () async {
                  Navigator.pop(context);
                  await _setStatus(docId, 'cancelled');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete request'),
                onTap: () async {
                  Navigator.pop(context);
                  await _deleteRequest(docId);
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
      appBar: AppBar(title: const Text('Service Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('serviceRequests')
            .orderBy('createdAt', descending: true)
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
            return const Center(child: Text('No requests found'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: const Icon(Icons.build),
                  title: Text((data['serviceType'] ?? 'Unknown service').toString()),
                  subtitle: Text('Status: ${(data['status'] ?? 'Unknown').toString()}'),
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