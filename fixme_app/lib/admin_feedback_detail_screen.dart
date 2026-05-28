import 'package:flutter/material.dart';

class AdminFeedbackDetailScreen
    extends StatelessWidget {

  final String docId;

  final Map<String, dynamic> data;

  const AdminFeedbackDetailScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  Widget _tile({

    required IconData icon,

    required String label,

    required dynamic value,
  }) {

    return Container(

      margin:
          const EdgeInsets.only(
        bottom: 16,
      ),

      padding:
          const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
            BorderRadius.circular(24),

        boxShadow: [

          BoxShadow(

            color:
                Colors.black.withOpacity(0.04),

            blurRadius: 14,

            offset:
                const Offset(0, 5),
          ),
        ],
      ),

      child: Row(

        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Container(

            width: 52,
            height: 52,

            decoration: BoxDecoration(

              color:
                  const Color(0xFF2563EB)
                      .withOpacity(0.10),

              borderRadius:
                  BorderRadius.circular(18),
            ),

            child: Icon(

              icon,

              color:
                  const Color(0xFF2563EB),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(

                  label,

                  style:
                      TextStyle(

                    color:
                        Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 6),

                SelectableText(

                  (value ?? 'N/A')
                      .toString(),

                  style:
                      const TextStyle(

                    fontSize: 16,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
          const Color(0xFFF4F7FC),

      appBar: AppBar(

        elevation: 0,

        backgroundColor:
            Colors.white,

        title: const Text(

          'Feedback Details',

          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),

      body: ListView(

        padding:
            const EdgeInsets.all(18),

        children: [

          _tile(

            icon:
                Icons.badge,

            label:
                'Feedback ID',

            value:
                docId,
          ),

          _tile(

            icon:
                Icons.person,

            label:
                'User ID',

            value:
                data['userId'],
          ),

          _tile(

            icon:
                Icons.email,

            label:
                'Email',

            value:
                data['email'],
          ),

          _tile(

            icon:
                Icons.person_outline,

            label:
                'Name',

            value:
                data['name'],
          ),

          _tile(

            icon:
                Icons.message,

            label:
                'Message',

            value:
                data['message'],
          ),

          _tile(

            icon:
                Icons.calendar_today,

            label:
                'Timestamp',

            value:
                data['timestamp'],
          ),
        ],
      ),
    );
  }
}