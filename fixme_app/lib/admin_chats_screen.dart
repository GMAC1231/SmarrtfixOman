////////////////////////////////////////////////////////////
/// ADMIN CHATS SCREEN
////////////////////////////////////////////////////////////

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_chat_detail_screen.dart';

class AdminChatsScreen
    extends StatefulWidget {

  const AdminChatsScreen({
    super.key,
  });

  @override
  State<AdminChatsScreen>
      createState() =>
          _AdminChatsScreenState();
}

class _AdminChatsScreenState
    extends State<AdminChatsScreen> {

  ////////////////////////////////////////////////////////////
  /// DELETE CHAT
  ////////////////////////////////////////////////////////////

  Future<void> _deleteChat(
    String chatId,
  ) async {

    final messages =
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .get();

    for (final doc in messages.docs) {

      await doc.reference.delete();
    }

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .delete();
  }

  ////////////////////////////////////////////////////////////
  /// ACTION SHEET
  ////////////////////////////////////////////////////////////

  void _showActions({

    required String chatId,

    required Map<String, dynamic> data,
  }) {

    showModalBottomSheet(

      context: context,

      backgroundColor:
          Colors.white,

      shape:
          const RoundedRectangleBorder(

        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),

      builder: (_) {

        return SafeArea(

          child: Padding(

            padding:
                const EdgeInsets.all(12),

            child: Wrap(

              children: [

                ListTile(

                  leading: Container(

                    width: 50,
                    height: 50,

                    decoration: BoxDecoration(

                      color:
                          const Color(0xFF2563EB)
                              .withOpacity(0.12),

                      borderRadius:
                          BorderRadius.circular(18),
                    ),

                    child: const Icon(

                      Icons.chat_rounded,

                      color:
                          Color(0xFF2563EB),
                    ),
                  ),

                  title: const Text(
                    'Open Chat',
                  ),

                  subtitle: const Text(
                    'View conversation',
                  ),

                  onTap: () {

                    Navigator.pop(context);

                    Navigator.push(

                      context,

                      MaterialPageRoute(

                        builder: (_) =>
                            AdminChatDetailScreen(

                          chatId: chatId,

                          data: data,
                        ),
                      ),
                    );
                  },
                ),

                ListTile(

                  leading: Container(

                    width: 50,
                    height: 50,

                    decoration: BoxDecoration(

                      color:
                          Colors.red
                              .withOpacity(0.12),

                      borderRadius:
                          BorderRadius.circular(18),
                    ),

                    child: const Icon(

                      Icons.delete_rounded,

                      color: Colors.red,
                    ),
                  ),

                  title: const Text(
                    'Delete Chat',
                  ),

                  subtitle: const Text(
                    'Remove conversation',
                  ),

                  onTap: () async {

                    Navigator.pop(context);

                    await _deleteChat(
                      chatId,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
          const Color(0xFFF4F7FC),

      body: CustomScrollView(

        slivers: [

          //////////////////////////////////////////////////////
          /// APP BAR
          //////////////////////////////////////////////////////

          SliverAppBar(

            expandedHeight: 290,

            pinned: true,

            elevation: 0,

            backgroundColor:
                const Color(0xFF8B5CF6),

            flexibleSpace:
                FlexibleSpaceBar(

              background: Container(

                decoration: const BoxDecoration(

                  gradient:
                      LinearGradient(

                    colors: [

                      Color(0xFF8B5CF6),

                      Color(0xFF6D28D9),
                    ],
                  ),
                ),

                child: SafeArea(

                  child: Padding(

                    padding:
                        const EdgeInsets.all(24),

                    child: Column(

                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      mainAxisAlignment:
                          MainAxisAlignment.end,

                      children: [

                        Container(

                          width: 90,
                          height: 90,

                          decoration: BoxDecoration(

                            color:
                                Colors.white
                                    .withOpacity(0.16),

                            borderRadius:
                                BorderRadius.circular(28),
                          ),

                          child: const Icon(

                            Icons.chat_bubble_rounded,

                            color: Colors.white,

                            size: 50,
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(

                          'Chats',

                          style:
                              TextStyle(

                            color: Colors.white,

                            fontSize: 34,

                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(

                          'Monitor all user conversations.',

                          style:
                              TextStyle(

                            color:
                                Colors.white
                                    .withOpacity(0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          //////////////////////////////////////////////////////
          /// LIST
          //////////////////////////////////////////////////////

          SliverToBoxAdapter(

            child: StreamBuilder<QuerySnapshot>(

              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .snapshots(),

              builder: (
                context,
                snapshot,
              ) {

                if (snapshot.hasError) {

                  return Padding(

                    padding:
                        const EdgeInsets.all(30),

                    child: Text(
                      'Error: ${snapshot.error}',
                    ),
                  );
                }

                if (!snapshot.hasData) {

                  return const Padding(

                    padding:
                        EdgeInsets.all(40),

                    child: CircularProgressIndicator(),
                  );
                }

                final docs =
                    snapshot.data!.docs;

                if (docs.isEmpty) {

                  return const Padding(

                    padding:
                        EdgeInsets.all(40),

                    child: Text(
                      'No chats found',
                    ),
                  );
                }

                return ListView.builder(

                  shrinkWrap: true,

                  physics:
                      const NeverScrollableScrollPhysics(),

                  padding:
                      const EdgeInsets.all(18),

                  itemCount:
                      docs.length,

                  itemBuilder: (
                    context,
                    index,
                  ) {

                    final doc =
                        docs[index];

                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    final members =
                        (data['members']
                                as List?) ??
                            [];

                    return GestureDetector(

                      onTap: () {

                        _showActions(

                          chatId: doc.id,

                          data: data,
                        );
                      },

                      child: Container(

                        margin:
                            const EdgeInsets.only(
                          bottom: 18,
                        ),

                        decoration: BoxDecoration(

                          color: Colors.white,

                          borderRadius:
                              BorderRadius.circular(30),

                          boxShadow: [

                            BoxShadow(

                              color:
                                  const Color(
                                    0xFF8B5CF6,
                                  ).withOpacity(0.12),

                              blurRadius: 18,

                              offset:
                                  const Offset(0, 6),
                            ),
                          ],
                        ),

                        child: Padding(

                          padding:
                              const EdgeInsets.all(18),

                          child: Row(

                            children: [

                              Container(

                                width: 74,
                                height: 74,

                                decoration: BoxDecoration(

                                  gradient:
                                      const LinearGradient(

                                    colors: [

                                      Color(0xFF8B5CF6),

                                      Color(0xFF6D28D9),
                                    ],
                                  ),

                                  borderRadius:
                                      BorderRadius.circular(24),
                                ),

                                child: const Icon(

                                  Icons.chat_rounded,

                                  color: Colors.white,

                                  size: 34,
                                ),
                              ),

                              const SizedBox(width: 18),

                              Expanded(

                                child: Column(

                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,

                                  children: [

                                    Text(

                                      'Chat ${index + 1}',

                                      style:
                                          const TextStyle(

                                        fontSize: 20,

                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    Text(

                                      doc.id,

                                      overflow:
                                          TextOverflow.ellipsis,

                                      style:
                                          TextStyle(

                                        color:
                                            Colors.grey[700],
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    Wrap(

                                      spacing: 8,

                                      runSpacing: 8,

                                      children: members
                                          .map<Widget>(

                                        (member) {

                                          return Container(

                                            padding:
                                                const EdgeInsets.symmetric(

                                              horizontal: 12,

                                              vertical: 8,
                                            ),

                                            decoration: BoxDecoration(

                                              color:
                                                  const Color(
                                                    0xFF8B5CF6,
                                                  ).withOpacity(0.12),

                                              borderRadius:
                                                  BorderRadius.circular(22),
                                            ),

                                            child: Text(

                                              member
                                                  .toString(),

                                              style:
                                                  const TextStyle(

                                                color:
                                                    Color(
                                                      0xFF6D28D9,
                                                    ),

                                                fontWeight:
                                                    FontWeight.bold,

                                                fontSize: 11,
                                              ),
                                            ),
                                          );
                                        },
                                      ).toList(),
                                    ),
                                  ],
                                ),
                              ),

                              IconButton(

                                onPressed: () {

                                  _showActions(

                                    chatId: doc.id,

                                    data: data,
                                  );
                                },

                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}