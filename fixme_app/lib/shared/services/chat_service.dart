import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../constants/firestore_keys.dart';

class ChatService {
  ChatService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Replace with your real backend base URL or move to config.dart
  static const String _baseUrl = 'http://192.168.100.15:5000';

  static User get currentUser {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User not logged in');
    }
    return user;
  }

  static String pairId(String a, String b) {
    final ids = [a.trim(), b.trim()]..sort();
    return '${ids.first}__${ids.last}';
  }

  static DocumentReference<Map<String, dynamic>> chatRef(String chatId) {
    return _db.collection(FirestoreCollections.chats).doc(chatId);
  }

  static CollectionReference<Map<String, dynamic>> messagesRef(String chatId) {
    return chatRef(chatId).collection(FirestoreCollections.messages);
  }

  static Future<String> ensureChat({
    required String customerId,
    required String employeeId,
    required String requestId,
    String? customerName,
    String? employeeName,
    String? customerPhoto,
    String? employeePhoto,
  }) async {
    final me = currentUser.uid;
    if (me != customerId && me != employeeId) {
      throw StateError('Current user is not a participant in this chat');
    }

    final chatId = pairId(customerId, employeeId);
    final ref = chatRef(chatId);
    final snap = await ref.get();
    final old = snap.data() ?? <String, dynamic>{};

    final payload = <String, dynamic>{
      'chatId': chatId,
      'requestId': requestId,
      'customerId': customerId,
      'employeeId': employeeId,
      'members': <String>[customerId, employeeId],
      'customerName': customerName ?? old['customerName'] ?? 'Customer',
      'employeeName': employeeName ?? old['employeeName'] ?? 'Provider',
      'customerPhoto': customerPhoto ?? old['customerPhoto'],
      'employeePhoto': employeePhoto ?? old['employeePhoto'],
      'lastMessageSnippet': old['lastMessageSnippet'] ?? '',
      'lastMessageSenderId': old['lastMessageSenderId'] ?? '',
      'lastMessageAt': old['lastMessageAt'] ?? FieldValue.serverTimestamp(),
      'typing_$customerId': old['typing_$customerId'] ?? false,
      'typing_$employeeId': old['typing_$employeeId'] ?? false,
      'online_$customerId': old['online_$customerId'] ?? false,
      'online_$employeeId': old['online_$employeeId'] ?? false,
      'lastSeen_$customerId': old['lastSeen_$customerId'],
      'lastSeen_$employeeId': old['lastSeen_$employeeId'],
      'unread_$customerId': old['unread_$customerId'] ?? 0,
      'unread_$employeeId': old['unread_$employeeId'] ?? 0,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
    };

    await ref.set(payload, SetOptions(merge: true));
    return chatId;
  }

  static Future<Map<String, dynamic>> _getChatAndReceiver(String chatId) async {
    final ref = chatRef(chatId);
    final snap = await ref.get();

    if (!snap.exists) {
      throw StateError('Chat does not exist. Call ensureChat() first.');
    }

    final chat = snap.data() ?? <String, dynamic>{};
    final user = currentUser;
    final members = List<String>.from(chat['members'] ?? const <String>[]);
    final receiverId = members.firstWhere(
      (id) => id != user.uid,
      orElse: () => '',
    );

    return {
      'ref': ref,
      'chat': chat,
      'receiverId': receiverId,
    };
  }

  static Future<String?> sendMessage({
    required String chatId,
    required String text,
    String? replyToMessageId,
    String? replyToText,
    String? replyToType,
    String? replyToSenderId,
  }) async {
    final message = text.trim();
    if (message.isEmpty) return null;

    final user = currentUser;
    final ref = chatRef(chatId);
    final msgRef = messagesRef(chatId).doc();

    await _db.runTransaction((tx) async {
      final chatSnap = await tx.get(ref);
      if (!chatSnap.exists) {
        throw StateError('Chat does not exist. Call ensureChat() first.');
      }

      final chat = chatSnap.data() ?? <String, dynamic>{};
      final members = List<String>.from(chat['members'] ?? const <String>[]);
      final receiverId = members.firstWhere(
        (id) => id != user.uid,
        orElse: () => '',
      );

      tx.set(msgRef, <String, dynamic>{
        'id': msgRef.id,
        'senderId': user.uid,
        'senderEmail': user.email ?? '',
        'text': message,
        'type': 'text',
        'imageUrl': null,
        'replyToMessageId': replyToMessageId,
        'replyToText': replyToText,
        'replyToType': replyToType,
        'replyToSenderId': replyToSenderId,
        'reactions': <String, dynamic>{},
        'deliveredAt': null,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(ref, <String, dynamic>{
        'lastMessageSnippet': message,
        'lastMessageSenderId': user.uid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'typing_${user.uid}': false,
        if (receiverId.isNotEmpty) 'unread_$receiverId': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    return msgRef.id;
  }

  /// Upload only. Does NOT create a Firestore chat message.
  static Future<String> uploadImageOnly(File file) async {
    final user = currentUser;
    final uri = Uri.parse('$_baseUrl/api/chat/upload-image');

    final request = http.MultipartRequest('POST', uri);
    final token = await user.getIdToken();
    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Server error (${response.statusCode}): $body');
    }

    late final Map<String, dynamic> data;
    try {
      data = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid JSON response: $body');
    }

    final imageUrl = data['url']?.toString() ?? '';
    if (imageUrl.isEmpty) {
      throw Exception('No image URL returned from backend');
    }

    return imageUrl;
  }

  static Future<String?> sendImageMessage({
    required String chatId,
    required String imageUrl,
    String? replyToMessageId,
    String? replyToText,
    String? replyToType,
    String? replyToSenderId,
  }) async {
    if (imageUrl.trim().isEmpty) return null;

    final user = currentUser;
    final ref = chatRef(chatId);
    final msgRef = messagesRef(chatId).doc();

    await _db.runTransaction((tx) async {
      final chatSnap = await tx.get(ref);
      if (!chatSnap.exists) {
        throw StateError('Chat does not exist. Call ensureChat() first.');
      }

      final chat = chatSnap.data() ?? <String, dynamic>{};
      final members = List<String>.from(chat['members'] ?? const <String>[]);
      final receiverId = members.firstWhere(
        (id) => id != user.uid,
        orElse: () => '',
      );

      tx.set(msgRef, <String, dynamic>{
        'id': msgRef.id,
        'senderId': user.uid,
        'senderEmail': user.email ?? '',
        'text': '',
        'type': 'image',
        'imageUrl': imageUrl,
        'replyToMessageId': replyToMessageId,
        'replyToText': replyToText,
        'replyToType': replyToType,
        'replyToSenderId': replyToSenderId,
        'reactions': <String, dynamic>{},
        'deliveredAt': null,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(ref, <String, dynamic>{
        'lastMessageSnippet': '📷 Image',
        'lastMessageSenderId': user.uid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'typing_${user.uid}': false,
        if (receiverId.isNotEmpty) 'unread_$receiverId': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    return msgRef.id;
  }

  /// Convenience method: upload + send final image message once.
  static Future<String?> sendImage({
    required String chatId,
    required File file,
    String? replyToMessageId,
    String? replyToText,
    String? replyToType,
    String? replyToSenderId,
  }) async {
    final imageUrl = await uploadImageOnly(file);

    return sendImageMessage(
      chatId: chatId,
      imageUrl: imageUrl,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      replyToType: replyToType,
      replyToSenderId: replyToSenderId,
    );
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(
    String chatId,
  ) {
    return messagesRef(chatId)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> myChatsStream() {
    final uid = currentUser.uid;
    return _db
        .collection(FirestoreCollections.chats)
        .where('members', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> chatStream(
    String chatId,
  ) {
    return chatRef(chatId).snapshots();
  }

static Future<void> setTyping({
  required String chatId,
  required bool isTyping,
}) async {
  try {
    final uid = currentUser.uid;

    await chatRef(chatId).set(
      <String, dynamic>{
        'typing_$uid': isTyping,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    print('✅ TYPING SUCCESS');
  } catch (e, s) {
    print('❌ TYPING FAILED => $e');
    print(s);
  }
}

static Future<void> setOnline({
  required String chatId,
  required bool isOnline,
}) async {
  try {
    final uid = currentUser.uid;

    await chatRef(chatId).set(
      <String, dynamic>{
        'online_$uid': isOnline,
        'lastSeen_$uid': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    print('✅ ONLINE SUCCESS');
  } catch (e, s) {
    print('❌ ONLINE FAILED => $e');
    print(s);
  }
}
static Future<void> resetUnread({
  required String chatId,
}) async {
  try {
    final uid = currentUser.uid;

    await chatRef(chatId).set(
      <String, dynamic>{
        'unread_$uid': 0,
      },
      SetOptions(merge: true),
    );

    print('✅ RESET UNREAD SUCCESS');
  } catch (e, s) {
    print('❌ RESET UNREAD FAILED => $e');
    print(s);
  }
}
static Future<void> markMessageDelivered({
  required String chatId,
  required String msgId,
}) async {
  try {
    await messagesRef(chatId).doc(msgId).set(
      <String, dynamic>{
        'deliveredAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    print('✅ DELIVERED SUCCESS => $msgId');
  } catch (e, s) {
    print('❌ DELIVERED FAILED => $e');
    print(s);
  }
}

static Future<void> markMessageRead({
  required String chatId,
  required String msgId,
}) async {
  try {
    await messagesRef(chatId).doc(msgId).set(
      <String, dynamic>{
        'readAt': FieldValue.serverTimestamp(),
        'deliveredAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    print('✅ READ SUCCESS => $msgId');
  } catch (e, s) {
    print('❌ READ FAILED => $e');
    print(s);
  }
}

  static Future<void> markIncomingMessagesAsSeen({
    required String chatId,
  }) async {
    final uid = currentUser.uid;

    final unread = await messagesRef(chatId)
        .where('senderId', isNotEqualTo: uid)
        .where('readAt', isNull: true)
        .get();

    final batch = _db.batch();

    for (final doc in unread.docs) {
      batch.set(
        doc.reference,
        <String, dynamic>{
          'readAt': FieldValue.serverTimestamp(),
          'deliveredAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    batch.set(
      chatRef(chatId),
      <String, dynamic>{
        'unread_$uid': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  static Future<void> toggleReaction({
    required String chatId,
    required String msgId,
    required String emoji,
    required Map<String, dynamic> currentData,
  }) async {
    final uid = currentUser.uid;
    final reactions =
        Map<String, dynamic>.from(currentData['reactions'] ?? <String, dynamic>{});

    if (reactions[uid] == emoji) {
      reactions.remove(uid);
    } else {
      reactions[uid] = emoji;
    }

    await messagesRef(chatId).doc(msgId).set(
      <String, dynamic>{'reactions': reactions},
      SetOptions(merge: true),
    );
  }
}