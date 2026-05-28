import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'shared/services/sound_service.dart';
import 'shared/services/chat_service.dart';
import 'shared/services/socket_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String title;
  final String requestId;
  final bool iAmCustomer;
  final String? providerId;
  final String? otherUserPhoto;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.title,
    required this.requestId,
    required this.iAmCustomer,
    this.providerId,
    this.otherUserPhoto,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  Timer? _typingTimer;

  bool _sending = false;
  bool _initializedChat = false;
  bool _processingMessages = false;
  String? _lastPlayedMessageId;
  bool _uploadingImage = false;
  bool _showScrollToBottom = false;
  bool _showEmojiPicker = false;

  String? _replyMessageId;
  String? _replyText;
  String? _replyType;
  bool _replyIsMe = false;

  static const List<String> _quickEmojis = [
    "😀", "😂", "😍", "🥹", "😎", "😭", "🙏", "👍",
    "👏", "🔥", "❤️", "💚", "💯", "✨", "🤝", "✅",
  ];

  static const List<String> _reactionEmojis = [
    "👍", "❤️", "😂", "😮", "😢", "🔥",
  ];

  static const List<String> _quickMessages = [
    "📍 I am arriving",
    "🔧 I am working now",
    "✅ Job completed",
    "💰 Payment received?",
    "📞 Please call me",
  ];

  String? get me => FirebaseAuth.instance.currentUser?.uid;

  String get effectiveChatId => widget.chatId;

@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addObserver(this);
  _scrollController.addListener(_handleScroll);

  // Connect socket only after this chat screen opens.
  // This does NOT write to Firestore.
  final uid = me;
  if (uid != null) {
    SocketService.connect(uid);
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    _scrollToBottom(animated: false);
  });
}

@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);

  _typingTimer?.cancel();

  _scrollController.removeListener(_handleScroll);
  _controller.dispose();
  _scrollController.dispose();
  _focusNode.dispose();

  // Do not write online/typing status here.
  // This avoids Firestore quota loops.
  SocketService.dispose();

  super.dispose();
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
    if (me == null) return;

    if (state == AppLifecycleState.resumed) {
      _markOnline();
    } else {
      ChatService.setTyping(chatId: effectiveChatId, isTyping: false);
      ChatService.setOnline(chatId: effectiveChatId, isOnline: false);
    }
  }

  Future<void> _markOnline() async {
    await ChatService.setOnline(
      chatId: effectiveChatId,
      isOnline: true,
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final distanceFromBottom =
        _scrollController.position.maxScrollExtent -
            _scrollController.offset;

    final shouldShow = distanceFromBottom > 220;

    if (shouldShow != _showScrollToBottom && mounted) {
      setState(() {
        _showScrollToBottom = shouldShow;
      });
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;

    final target = _scrollController.position.maxScrollExtent;

    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  void _toggleEmojiPicker() {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();

    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  void _appendEmoji(String emoji) {
    final oldText = _controller.text;
    final selection = _controller.selection;
    final start = selection.start >= 0 ? selection.start : oldText.length;
    final end = selection.end >= 0 ? selection.end : oldText.length;

    final newText = oldText.replaceRange(start, end, emoji);

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + emoji.length,
      ),
    );

   // _onTypingChanged(_controller.text);
    //setState(() {});
  }

  void _setReply({
    required String messageId,
    required String text,
    required String type,
    required bool isMe,
  }) {
    setState(() {
      _replyMessageId = messageId;
      _replyText = text;
      _replyType = type;
      _replyIsMe = isMe;
    });

    HapticFeedback.lightImpact();
  }

  void _clearReply() {
    setState(() {
      _replyMessageId = null;
      _replyText = null;
      _replyType = null;
      _replyIsMe = false;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    _controller.clear();

    try {
      await ChatService.sendMessage(
        chatId: effectiveChatId,
        text: text,
        replyToMessageId: _replyMessageId,
        replyToText: _replyText,
        replyToType: _replyType,
        replyToSenderId: _replyIsMe ? me : widget.otherUserId,
      );

      final response = await http.post(
        Uri.parse('http://192.168.100.15:5000/sound_event'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'receiver_id': widget.otherUserId,
          'sender_id': me,
          'chat_id': effectiveChatId,
        }),
      );

      debugPrint('POSTGRES SOUND EVENT STATUS => ${response.statusCode}');

      await SoundService.send();

      _typingTimer?.cancel();
      _clearReply();

      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _scrollToBottom();
      });
    } catch (e) {
      debugPrint('SEND ERROR => $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Send failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _sendQuickMessage(String text) async {
    _controller.text = text;
    await _send();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_uploadingImage) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1800,
      );

      if (picked == null) return;

      setState(() {
        _uploadingImage = true;
      });

      final imageUrl = await _uploadImageOnly(
        File(picked.path),
      );

      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('No image URL returned from backend');
      }

      final msgRef =
          ChatService.messagesRef(effectiveChatId).doc();

      final user = ChatService.currentUser;

      final chatSnap =
          await ChatService.chatRef(effectiveChatId).get();

      if (!chatSnap.exists) {
        throw StateError(
          'Chat does not exist. Call ensureChat() first.',
        );
      }

      final chat =
          chatSnap.data() ?? <String, dynamic>{};

      final members =
          List<String>.from(chat['members'] ?? const <String>[]);

      final receiverId = members.firstWhere(
        (id) => id != user.uid,
        orElse: () => '',
      );

      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(msgRef, <String, dynamic>{
          'id': msgRef.id,
          'senderId': user.uid,
          'senderEmail': user.email ?? '',
          'text': '',
          'type': 'image',
          'imageUrl': imageUrl,
          'replyToMessageId': _replyMessageId,
          'replyToText': _replyText,
          'replyToType': _replyType,
          'replyToSenderId':
              _replyIsMe ? me : widget.otherUserId,
          'reactions': <String, dynamic>{},
          'deliveredAt': null,
          'readAt': null,
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.set(
          ChatService.chatRef(effectiveChatId),
          <String, dynamic>{
            'lastMessageSnippet': '📷 Image',
            'lastMessageSenderId': user.uid,
            'lastMessageAt': FieldValue.serverTimestamp(),
            if (receiverId.isNotEmpty)
              'unread_$receiverId': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      _clearReply();

      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _scrollToBottom();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send image: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
      }
    }
  }

  Future<String?> _uploadImageOnly(File file) async {
    final user = ChatService.currentUser;

    return ChatService.sendImage(
      chatId: effectiveChatId,
      file: file,
    ).then((_) async {
      final latest = await ChatService.messagesRef(effectiveChatId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (latest.docs.isNotEmpty) {
        final data = latest.docs.first.data();

        if (data['senderId'] == user.uid &&
            data['type'] == 'image') {
          await latest.docs.first.reference.delete();
          return data['imageUrl']?.toString();
        }
      }

      throw Exception('Image upload failed');
    });
  }

  void _openAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            decoration: BoxDecoration(
              color: const Color(0xFF111827).withOpacity(0.98),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                  color: Colors.black.withOpacity(0.28),
                ),
              ],
            ),
            child: Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                _AttachmentTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF22C55E),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(ImageSource.gallery);
                  },
                ),
                _AttachmentTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFF38BDF8),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onTypingChanged(String value) {
    if (me == null) return;

    final isTyping = value.trim().isNotEmpty;

    ChatService.setTyping(
      chatId: effectiveChatId,
      isTyping: isTyping,
    );

    _typingTimer?.cancel();

    _typingTimer = Timer(const Duration(seconds: 2), () {
    });
  }

  Future<void> _toggleReaction({
    required String msgId,
    required String emoji,
    required Map<String, dynamic> data,
  }) async {
    final uid = me;

    if (uid == null) return;

    final reactions =
        Map<String, dynamic>.from(data['reactions'] ?? <String, dynamic>{});

    if (reactions[uid] == emoji) {
      reactions.remove(uid);
    } else {
      reactions[uid] = emoji;
    }

    await ChatService.messagesRef(effectiveChatId)
        .doc(msgId)
        .set(
      <String, dynamic>{
        'reactions': reactions,
      },
      SetOptions(merge: true),
    );
  }

  void _showReactionBar(
    String msgId,
    Map<String, dynamic> data,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 210,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 18,
                  sigmaY: 18,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.90),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 24,
                        color: Colors.black.withOpacity(0.14),
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _reactionEmojis.map((emoji) {
                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);

                          await _toggleReaction(
                            msgId: msgId,
                            emoji: emoji,
                            data: data,
                          );
                        },
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 30),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';

    final dt = ts.toDate();
    final tod = TimeOfDay.fromDateTime(dt);

    return tod.format(context);
  }

  String _formatHeaderDate(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final msgDay = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final yesterday =
        today.subtract(const Duration(days: 1));

    if (msgDay == today) return 'Today';
    if (msgDay == yesterday) return 'Yesterday';

    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isSameDay(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  String _formatLastSeen(Timestamp? ts) {
    if (ts == null) return 'Offline';

    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inMinutes < 60) {
      return 'Last seen ${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return 'Last seen ${diff.inHours}h ago';
    }

    return 'Last seen ${dt.day}/${dt.month}/${dt.year}';
  }

  void _openImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return Scaffold(
            backgroundColor: const Color(0xFF050816),
            appBar: AppBar(
              backgroundColor: const Color(0xFF050816),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white,
                            size: 42,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Could not load image',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF06130D),
                Color(0xFF0B1220),
                Color(0xFF111827),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -40,
          child: Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22C55E).withOpacity(0.13),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -50,
          child: Container(
            width: 270,
            height: 270,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF38BDF8).withOpacity(0.10),
            ),
          ),
        ),
        Positioned(
          top: 180,
          right: 24,
          child: Icon(
            Icons.build_rounded,
            size: 96,
            color: Colors.white.withOpacity(0.025),
          ),
        ),
        Positioned(
          bottom: 250,
          left: 20,
          child: Icon(
            Icons.plumbing_rounded,
            size: 96,
            color: Colors.white.withOpacity(0.025),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ChatService.chatStream(effectiveChatId),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};

        final otherOnline =
            data['online_${widget.otherUserId}'] == true;

        final otherTyping =
            data['typing_${widget.otherUserId}'] == true;

        final lastSeen =
            data['lastSeen_${widget.otherUserId}'] as Timestamp?;

        final subtitle = otherTyping
            ? 'typing...'
            : otherOnline
                ? 'online'
                : _formatLastSeen(lastSeen);

        return AppBar(
          automaticallyImplyLeading: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          titleSpacing: 6,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 14,
                sigmaY: 14,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF064E3B).withOpacity(0.88),
                      const Color(0xFF111827).withOpacity(0.86),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
              ),
            ),
          ),
          title: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withOpacity(0.12),
                    backgroundImage: widget.otherUserPhoto != null &&
                            widget.otherUserPhoto!.trim().isNotEmpty
                        ? NetworkImage(widget.otherUserPhoto!)
                        : null,
                    child: widget.otherUserPhoto == null ||
                            widget.otherUserPhoto!.trim().isEmpty
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  if (otherOnline)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0B1220),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22C55E)
                                  .withOpacity(0.75),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        subtitle,
                        key: ValueKey(subtitle),
                        style: TextStyle(
                          fontSize: 12,
                          color: otherTyping
                              ? const Color(0xFF86EFAC)
                              : Colors.white70,
                          fontWeight: otherTyping
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestContextCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF22C55E).withOpacity(0.18),
            const Color(0xFF38BDF8).withOpacity(0.12),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.home_repair_service_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.iAmCustomer
                      ? 'Service provider chat'
                      : 'Customer chat',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Request ID: ${widget.requestId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ACTIVE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTicks(Map<String, dynamic> data) {
    final readAt = data['readAt'] as Timestamp?;
    final deliveredAt = data['deliveredAt'] as Timestamp?;

    if (readAt != null) {
      return const Icon(
        Icons.done_all_rounded,
        size: 15,
        color: Color(0xFF38BDF8),
      );
    }

    if (deliveredAt != null) {
      return Icon(
        Icons.done_all_rounded,
        size: 15,
        color: Colors.white.withOpacity(0.72),
      );
    }

    return Icon(
      Icons.done_rounded,
      size: 15,
      color: Colors.white.withOpacity(0.72),
    );
  }

  Widget _buildDateChip(String label) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.86),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(
    Map<String, dynamic> data,
    bool isMe,
  ) {
    final replyText =
        (data['replyToText'] ?? '').toString();

    final replyType =
        (data['replyToType'] ?? '').toString();

    final replySenderId =
        (data['replyToSenderId'] ?? '').toString();

    final isReply =
        replyText.isNotEmpty || replyType == 'image';

    if (!isReply) return const SizedBox.shrink();

    final label = replySenderId == me ? 'You' : widget.title;
    final preview = replyType == 'image' ? '📷 Photo' : replyText;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withOpacity(0.16)
            : Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : const Color(0xFF22C55E),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isMe ? Colors.white : const Color(0xFF0E7A35),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color:
                  isMe ? Colors.white.withOpacity(0.92) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionChips(
    Map<String, dynamic> data,
    bool isMe,
  ) {
    final reactions =
        Map<String, dynamic>.from(data['reactions'] ?? <String, dynamic>{});

    if (reactions.isEmpty) return const SizedBox.shrink();

    final entries =
        reactions.values.map((e) => e.toString()).toList();

    final counts = <String, int>{};

    for (final emoji in entries) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: counts.entries.map((entry) {
          final text = entry.value > 1
              ? '${entry.key} ${entry.value}'
              : entry.key;

          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white.withOpacity(0.18)
                  : Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMe
                    ? Colors.white.withOpacity(0.14)
                    : Colors.black12,
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildServiceBadge(String text, bool isMe) {
    final lower = text.toLowerCase();

    IconData? icon;
    String? label;
    Color color = const Color(0xFF22C55E);

    if (lower.contains('arriving')) {
      icon = Icons.location_on_rounded;
      label = 'Arriving';
      color = const Color(0xFF38BDF8);
    } else if (lower.contains('working')) {
      icon = Icons.build_rounded;
      label = 'Working';
      color = const Color(0xFFF59E0B);
    } else if (lower.contains('completed')) {
      icon = Icons.check_circle_rounded;
      label = 'Completed';
      color = const Color(0xFF22C55E);
    } else if (lower.contains('payment')) {
      icon = Icons.payments_rounded;
      label = 'Payment';
      color = const Color(0xFFA855F7);
    } else if (lower.contains('call')) {
      icon = Icons.call_rounded;
      label = 'Call';
      color = const Color(0xFFEF4444);
    }

    if (icon == null || label == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(isMe ? 0.20 : 0.13),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withOpacity(0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isMe ? Colors.white : color,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isMe ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(
    Map<String, dynamic> data,
    bool isMe,
    String msgId,
  ) {
    final type = (data['type'] ?? 'text').toString();
    final text = (data['text'] ?? '').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final ts = data['createdAt'] as Timestamp?;
    final time = _formatTime(ts);
    final isImage = type == 'image' && imageUrl.isNotEmpty;

    final bubbleGradient = isMe
        ? const LinearGradient(
            colors: [
              Color(0xFF22C55E),
              Color(0xFF15803D),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              Colors.white.withOpacity(0.97),
              Colors.white.withOpacity(0.90),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final textColor = isMe
        ? Colors.white
        : const Color(0xFF111827);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      offset: const Offset(0, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: 1,
        child: Align(
          alignment: isMe
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () => _showReactionBar(msgId, data),
            onDoubleTap: () => _toggleReaction(
              msgId: msgId,
              emoji: '❤️',
              data: data,
            ),
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              final shouldReply =
                  isMe ? velocity < -250 : velocity > 250;

              if (shouldReply) {
                _setReply(
                  messageId: msgId,
                  text: isImage ? '📷 Photo' : text,
                  type: isImage ? 'image' : 'text',
                  isMe: isMe,
                );
              }
            },
            child: Container(
              margin: EdgeInsets.only(
                left: isMe ? 72 : 12,
                right: isMe ? 12 : 72,
                top: 4,
                bottom: 4,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 12,
                    sigmaY: 12,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: bubbleGradient,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isMe
                            ? Colors.white.withOpacity(0.10)
                            : Colors.white.withOpacity(0.50),
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 16,
                          color: Colors.black.withOpacity(0.14),
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isImage ? 4 : 12,
                        isImage ? 4 : 10,
                        isImage ? 4 : 12,
                        8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildReplyPreview(data, isMe),
                          if (!isImage)
                            _buildServiceBadge(text, isMe),
                          if (isImage)
                            GestureDetector(
                              onTap: () => _openImage(imageUrl),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 320,
                                  ),
                                  child: Image.network(
                                    imageUrl,
                                    width:
                                        MediaQuery.of(context).size.width *
                                            0.64,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, progress) {
                                      if (progress == null) return child;

                                      return Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.64,
                                        height: 240,
                                        alignment: Alignment.center,
                                        color: Colors.black12,
                                        child:
                                            const CircularProgressIndicator(),
                                      );
                                    },
                                    errorBuilder:
                                        (context, error, stackTrace) {
                                      return Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.64,
                                        height: 220,
                                        alignment: Alignment.center,
                                        color: Colors.black12,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.broken_image_outlined,
                                              color: isMe
                                                  ? Colors.white
                                                  : Colors.black54,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Failed to load',
                                              style: TextStyle(
                                                color: isMe
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            )
                          else
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SelectableText(
                                text,
                                style: TextStyle(
                                  fontSize: 15.2,
                                  color: textColor,
                                  height: 1.34,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 10.3,
                                  color: isMe
                                      ? Colors.white.withOpacity(0.82)
                                      : Colors.black54,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                _buildStatusTicks(data),
                              ],
                            ],
                          ),
                          _buildReactionChips(data, isMe),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// INITIALIZE CHAT SAFELY
  ////////////////////////////////////////////////////////////

  Future<void> _initializeChat() async {
    // Disabled unread/seen writes to prevent Firestore quota loops.
    _initializedChat = true;
  }

  ////////////////////////////////////////////////////////////
  /// PROCESS DELIVERY SAFELY
  ////////////////////////////////////////////////////////////

  Future<void> _processMessagesOnce(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    // Disabled delivered/read receipt writes to prevent Firestore quota loops.
  }

  Widget _buildMessages() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ChatService.messagesStream(effectiveChatId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load messages.\n${snapshot.error}',
              style: const TextStyle(
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
                final docs = snapshot.data!.docs;

        _processMessagesOnce(docs);


        if (docs.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white.withOpacity(0.58),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Start chatting in SmartFixOman',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Messages, photos, replies and updates appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.58),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final isMe = data['senderId'] == me;

            final currentTs =
                data['createdAt'] as Timestamp?;

            final currentDate =
                currentTs?.toDate() ?? DateTime.now();

            final previousDate = index > 0
                ? (docs[index - 1].data()['createdAt'] as Timestamp?)
                    ?.toDate()
                : null;

            final showDateHeader = previousDate == null ||
                !_isSameDay(previousDate, currentDate);

            return Column(
              children: [
                if (showDateHeader)
                  _buildDateChip(
                    _formatHeaderDate(currentDate),
                  ),
                _buildBubble(
                  data,
                  isMe,
                  docs[index].id,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ChatService.chatStream(effectiveChatId),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};

        final otherTyping =
            data['typing_${widget.otherUserId}'] == true;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: otherTyping ? 34 : 0,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: otherTyping
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.title} is typing',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withOpacity(0.78),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _TypingDots(),
                  ],
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _quickMessages.length,
        itemBuilder: (_, index) {
          final text = _quickMessages[index];

          return GestureDetector(
            onTap: () => _sendQuickMessage(text),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReplyBar() {
    if (_replyText == null && _replyType == null) {
      return const SizedBox.shrink();
    }

    final preview =
        _replyType == 'image' ? '📷 Photo' : (_replyText ?? '');

    final label = _replyIsMe
        ? 'Replying to yourself'
        : 'Replying to ${widget.title}';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xFF86EFAC),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withOpacity(0.92),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearReply,
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker() {
    if (!_showEmojiPicker) return const SizedBox.shrink();

    return Container(
      height: 245,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withOpacity(0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: GridView.builder(
        itemCount: _quickEmojis.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (_, index) {
          final emoji = _quickEmojis[index];

          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _appendEmoji(emoji),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildComposer() {
    final hasText = _controller.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildReplyBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 18,
                        sigmaY: 18,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.12),
                              Colors.white.withOpacity(0.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                          ),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 18,
                              color: Colors.black.withOpacity(0.12),
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: _toggleEmojiPicker,
                              icon: Icon(
                                _showEmojiPicker
                                    ? Icons.keyboard_rounded
                                    : Icons.emoji_emotions_outlined,
                                color: Colors.white.withOpacity(0.88),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                minLines: 1,
                                maxLines: 5,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                ),
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: TextStyle(
                                    color:
                                        Colors.white.withOpacity(0.52),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  _onTypingChanged(value);
                                  setState(() {});
                                },
                                onTap: () {
                                  if (_showEmojiPicker) {
                                    setState(() {
                                      _showEmojiPicker = false;
                                    });
                                  }

                                  Future.delayed(
                                    const Duration(milliseconds: 150),
                                    () {
                                      if (mounted) _scrollToBottom();
                                    },
                                  );
                                },
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            if (!hasText)
                              IconButton(
                                onPressed: _openAttachmentSheet,
                                icon: _uploadingImage
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: Colors.white
                                            .withOpacity(0.88),
                                      ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: hasText
                          ? const [
                              Color(0xFF22C55E),
                              Color(0xFF15803D),
                            ]
                          : const [
                              Color(0xFF38BDF8),
                              Color(0xFF0EA5E9),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 18,
                        color: (hasText
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF38BDF8))
                            .withOpacity(0.35),
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: hasText
                          ? _send
                          : () => _pickAndSendImage(
                                ImageSource.camera,
                              ),
                      child: Center(
                        child: _sending
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                hasText
                                    ? Icons.send_rounded
                                    : Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildEmojiPicker(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0B1220),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildHeader(),
      ),
      body: Stack(
        children: [
          _buildChatBackground(),
          Column(
            children: [
              SizedBox(
                height:
                    MediaQuery.of(context).padding.top + kToolbarHeight,
              ),
              _buildRequestContextCard(),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _buildMessages(),
                    ),
                    _buildTypingIndicator(),
                  ],
                ),
              ),
              _buildQuickActions(),
              _buildComposer(),
            ],
          ),
          if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: _showEmojiPicker ? 330 : 145,
              child: FloatingActionButton.small(
                backgroundColor: const Color(0xFF22C55E),
                onPressed: () => _scrollToBottom(),
                child: const Icon(
                  Icons.arrow_downward_rounded,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withOpacity(0.28),
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  double _opacityFor(int index) {
    final value = (_controller.value + (index * 0.18)) % 1.0;

    if (value < 0.33) return 0.35;
    if (value < 0.66) return 0.65;

    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          children: List.generate(3, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(
                  _opacityFor(i),
                ),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}