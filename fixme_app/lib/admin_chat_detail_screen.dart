////////////////////////////////////////////////////////////
/// ADMIN CHAT DETAIL SCREEN
////////////////////////////////////////////////////////////

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminChatDetailScreen
    extends StatelessWidget {

  final String chatId;

  final Map<String, dynamic> data;

  const AdminChatDetailScreen({
    super.key,
    required this.chatId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {

    final members =
        (data['members'] as List?) ?? [];

    return Scaffold(

      backgroundColor:
          const Color(0xFFF4F7FC),

      body: CustomScrollView(

        slivers: [

          //////////////////////////////////////////////////////
          /// APP BAR
          //////////////////////////////////////////////////////

          SliverAppBar(

            expandedHeight: 250,

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

                            Icons.chat_rounded,

                            color: Colors.white,

                            size: 48,
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(

                          'Chat Details',

                          style:
                              TextStyle(

                            color: Colors.white,

                            fontSize: 34,

                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(

                          chatId,

                          overflow:
                              TextOverflow.ellipsis,

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
          /// MEMBERS
          //////////////////////////////////////////////////////

          SliverToBoxAdapter(

            child: Padding(

              padding:
                  const EdgeInsets.all(18),

              child: Wrap(

                spacing: 10,

                runSpacing: 10,

                children: members
                    .map<Widget>(

                  (member) {

                    return Container(

                      padding:
                          const EdgeInsets.symmetric(

                        horizontal: 14,

                        vertical: 10,
                      ),

                      decoration: BoxDecoration(

                        color:
                            const Color(
                              0xFF8B5CF6,
                            ).withOpacity(0.12),

                        borderRadius:
                            BorderRadius.circular(24),
                      ),

                      child: Text(

                        member.toString(),

                        style:
                            const TextStyle(

                          color:
                              Color(
                                0xFF6D28D9,
                              ),

                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
          ),

          //////////////////////////////////////////////////////
          /// MESSAGES
          //////////////////////////////////////////////////////

          SliverToBoxAdapter(

            child: StreamBuilder<QuerySnapshot>(

              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy(
                    'createdAt',
                    descending: true,
                  )
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
                      'No messages found',
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

                    final msg =
                        docs[index].data()
                            as Map<String, dynamic>;

                    final text =
                        (msg['text'] ?? '')
                            .toString();

                    final sender =
                        (msg['senderId'] ??
                                'Unknown')
                            .toString();

                    return Container(

                      margin:
                          const EdgeInsets.only(
                        bottom: 16,
                      ),

                      decoration: BoxDecoration(

                        color: Colors.white,

                        borderRadius:
                            BorderRadius.circular(26),

                        boxShadow: [

                          BoxShadow(

                            color:
                                const Color(
                                  0xFF8B5CF6,
                                ).withOpacity(0.10),

                            blurRadius: 14,

                            offset:
                                const Offset(0, 6),
                          ),
                        ],
                      ),

                      child: Padding(

                        padding:
                            const EdgeInsets.all(18),

                        child: Column(

                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [

                            Row(

                              children: [

                                Container(

                                  width: 44,
                                  height: 44,

                                  decoration: BoxDecoration(

                                    gradient:
                                        const LinearGradient(

                                      colors: [

                                        Color(0xFF8B5CF6),

                                        Color(0xFF6D28D9),
                                      ],
                                    ),

                                    borderRadius:
                                        BorderRadius.circular(16),
                                  ),

                                  child: const Icon(

                                    Icons.person_rounded,

                                    color: Colors.white,
                                  ),
                                ),

                                const SizedBox(width: 14),

                                Expanded(

                                  child: Column(

                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [

                                      Text(

                                        sender,

                                        overflow:
                                            TextOverflow.ellipsis,

                                        style:
                                            const TextStyle(

                                          fontWeight:
                                              FontWeight.bold,

                                          fontSize: 15,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      Text(

                                        'Message ${index + 1}',

                                        style:
                                            TextStyle(

                                          color:
                                              Colors.grey[600],

                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 16),

Column(

  crossAxisAlignment:
      CrossAxisAlignment.start,

  children: [

    //////////////////////////////////////////////////////
    /// TEXT MESSAGE
    //////////////////////////////////////////////////////

    if (text.isNotEmpty)

      Text(

        text,

        style:
            const TextStyle(

          fontSize: 16,

          height: 1.5,
        ),
      ),

    //////////////////////////////////////////////////////
    /// IMAGE MESSAGE
    //////////////////////////////////////////////////////

    if (msg['imageUrl'] != null &&
        msg['imageUrl']
            .toString()
            .isNotEmpty)

      Padding(

        padding:
            const EdgeInsets.only(
          top: 14,
        ),

        child: ClipRRect(

          borderRadius:
              BorderRadius.circular(22),

          child: Image.network(

            msg['imageUrl'],

            width: double.infinity,

            height: 240,

            fit: BoxFit.cover,

            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {

              return Container(

                height: 220,

                decoration: BoxDecoration(

                  color:
                      Colors.grey.shade200,

                  borderRadius:
                      BorderRadius.circular(22),
                ),

                child: const Center(

                  child: Column(

                    mainAxisSize:
                        MainAxisSize.min,

                    children: [

                      Icon(

                        Icons.broken_image_rounded,

                        size: 40,

                        color: Colors.grey,
                      ),

                      SizedBox(height: 10),

                      Text(
                        'Failed to load image',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
  ],
),
                          ],
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