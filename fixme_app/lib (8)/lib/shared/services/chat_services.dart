import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  ChatService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔑 Ensure user is logged in
  static String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }
    return user.uid;
  }

  /// 🔑 Consistent chat ID
  static String pairId(String a, String b) {
    final ids = [a.trim(), b.trim()]..sort();
    return '${ids[0]}__${ids[1]}';
  }

  /// 📌 Chat reference
  static DocumentReference<Map<String, dynamic>> chatRef(String chatId) =>
      _db.collection('chats').doc(chatId);

  /// 📌 Messages reference
  static CollectionReference<Map<String, dynamic>> messagesRef(String chatId) =>
      chatRef(chatId).collection('messages');

  /// ✅ CREATE or GET CHAT (SAFE)
  static Future<String> ensureChat({
    required String customerId,
    required String employeeId,
    required String requestId,
  }) async {
    final currentUserId = _uid;

    // 🔴 CRITICAL: ensure current user is part of chat
    if (currentUserId != customerId && currentUserId != employeeId) {
      throw Exception("User not part of this chat");
    }

    final chatId = pairId(customerId, employeeId);
    final ref = chatRef(chatId);

    final payload = <String, dynamic>{
      'members': [customerId, employeeId],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSnippet': '',
      'requestId': requestId,
    };

    try {
      // Try CREATE
      await ref.set(payload, SetOptions(merge: false));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'already-exists') {
        // Fallback UPDATE (allowed fields only)
        await ref.update({
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessageSnippet': '',
        });
      } else {
        rethrow;
      }
    }

    return chatId;
  }

static Future<String?> sendMessage({
  required String chatId,
  required String text,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || text.trim().isEmpty) return null;

  final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

  final msgRef = chatRef.collection('messages').doc();

  await msgRef.set({
    'senderId': user.uid,
    'text': text.trim(),
    'createdAt': FieldValue.serverTimestamp(),
  });

  await chatRef.set({
    'lastMessageAt': FieldValue.serverTimestamp(),
    'lastMessageSnippet': text.trim(),
  }, SetOptions(merge: true));

  return msgRef.id;
}
  /// 📡 STREAM MESSAGES
  static Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(
      String chatId) {
    return messagesRef(chatId)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// ✅ MARK MESSAGE READ / DELIVERED
  static Future<void> markMessageRead({
    required String chatId,
    required String msgId,
    bool delivered = false,
  }) async {
    final field = delivered ? 'deliveredAt' : 'readAt';

    await messagesRef(chatId).doc(msgId).update({
      field: FieldValue.serverTimestamp(),
    });
  }
}