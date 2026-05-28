import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_rating_detail_screen.dart';

class AdminRatingsScreen extends StatelessWidget {
  const AdminRatingsScreen({super.key});

  Future<void> _deleteRating(String docId) async {
    await FirebaseFirestore.instance.collection('ratings').doc(docId).delete();
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
                      builder: (_) => AdminRatingDetailScreen(
                        docId: docId,
                        data: data,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete rating'),
                onTap: () async {
                  Navigator.pop(context);
                  await _deleteRating(docId);
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
      appBar: AppBar(title: const Text('Ratings')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ratings').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No ratings found'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: const Icon(Icons.star),
                  title: Text('Rating: ${(data['rating'] ?? 'N/A').toString()}'),
                  subtitle: Text('Employee: ${(data['employeeId'] ?? 'Unknown').toString()}'),
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