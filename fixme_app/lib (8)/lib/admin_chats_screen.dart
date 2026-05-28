import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_chat_detail_screen.dart';

class AdminChatsScreen extends StatelessWidget {
  const AdminChatsScreen({super.key});

  Future<void> _deleteChat(String chatId) async {
    final messages = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    for (final doc in messages.docs) {
      await doc.reference.delete();
    }

    await FirebaseFirestore.instance.collection('chats').doc(chatId).delete();
  }

  void _showActions(BuildContext context, String chatId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('Open chat'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminChatDetailScreen(
                        chatId: chatId,
                        data: data,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete chat'),
                onTap: () async {
                  Navigator.pop(context);
                  await _deleteChat(chatId);
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
      appBar: AppBar(title: const Text('Chats')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No chats found'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final members = (data['members'] as List?) ?? [];

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: const Icon(Icons.chat),
                  title: Text('Chat ID: ${doc.id}'),
                  subtitle: Text('Members: ${members.join(', ')}'),
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