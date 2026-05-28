////////////////////////////////////////////////////////////
/// ADMIN CUSTOMER DETAIL SCREEN
////////////////////////////////////////////////////////////

import 'package:flutter/material.dart';

class AdminCustomerDetailScreen
    extends StatelessWidget {

  final String docId;

  final Map<String, dynamic> data;

  const AdminCustomerDetailScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  Widget _infoCard({

    required IconData icon,

    required String title,

    required dynamic value,

    required List<Color> colors,
  }) {

    return Container(

      margin:
          const EdgeInsets.only(
        bottom: 18,
      ),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
            BorderRadius.circular(28),

        boxShadow: [

          BoxShadow(

            color:
                colors.first
                    .withOpacity(0.12),

            blurRadius: 16,

            offset:
                const Offset(0, 6),
          ),
        ],
      ),

      child: Padding(

        padding:
            const EdgeInsets.all(18),

        child: Row(

          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            Container(

              width: 60,
              height: 60,

              decoration: BoxDecoration(

                gradient:
                    LinearGradient(
                  colors: colors,
                ),

                borderRadius:
                    BorderRadius.circular(20),
              ),

              child: Icon(

                icon,

                color: Colors.white,

                size: 30,
              ),
            ),

            const SizedBox(width: 18),

            Expanded(

              child: Column(

                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Text(

                    title,

                    style:
                        TextStyle(

                      color:
                          Colors.grey[600],

                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  SelectableText(

                    (value ?? 'N/A')
                        .toString(),

                    style:
                        const TextStyle(

                      fontSize: 17,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final name =
        (data['name'] ??
                'Customer')
            .toString();

    final email =
        (data['email'] ??
                'No Email')
            .toString();

    final gradients = [

      [
        const Color(0xFF2563EB),
        const Color(0xFF1D4ED8),
      ],

      [
        const Color(0xFF10B981),
        const Color(0xFF059669),
      ],

      [
        const Color(0xFFF59E0B),
        const Color(0xFFD97706),
      ],

      [
        const Color(0xFF8B5CF6),
        const Color(0xFF7C3AED),
      ],
    ];

    return Scaffold(

      backgroundColor:
          const Color(0xFFF4F7FC),

      body: CustomScrollView(

        slivers: [

          //////////////////////////////////////////////////////
          /// APP BAR
          //////////////////////////////////////////////////////

          SliverAppBar(

            expandedHeight: 320,

            pinned: true,

            elevation: 0,

            backgroundColor:
                const Color(0xFF2563EB),

            flexibleSpace:
                FlexibleSpaceBar(

              background: Container(

                decoration: const BoxDecoration(

                  gradient:
                      LinearGradient(

                    colors: [

                      Color(0xFF2563EB),

                      Color(0xFF1E3A8A),
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

                          width: 120,
                          height: 120,

                          decoration: BoxDecoration(

                            color:
                                Colors.white
                                    .withOpacity(0.16),

                            borderRadius:
                                BorderRadius.circular(36),
                          ),

                          child: Center(

                            child: Text(

                              name.isNotEmpty
                                  ? name[0]
                                        .toUpperCase()
                                  : '?',

                              style:
                                  const TextStyle(

                                color: Colors.white,

                                fontSize: 48,

                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(

                          name,

                          style:
                              const TextStyle(

                            color: Colors.white,

                            fontSize: 34,

                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(

                          email,

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
          /// CONTENT
          //////////////////////////////////////////////////////

          SliverToBoxAdapter(

            child: Padding(

              padding:
                  const EdgeInsets.all(18),

              child: Column(

                children: [

                  _infoCard(

                    icon:
                        Icons.badge_rounded,

                    title:
                        'Document ID',

                    value:
                        docId,

                    colors:
                        gradients[0],
                  ),

                  _infoCard(

                    icon:
                        Icons.phone_rounded,

                    title:
                        'Phone',

                    value:
                        data['phone'],

                    colors:
                        gradients[1],
                  ),

                  _infoCard(

                    icon:
                        Icons.location_city_rounded,

                    title:
                        'City',

                    value:
                        data['city'],

                    colors:
                        gradients[2],
                  ),

                  _infoCard(

                    icon:
                        Icons.home_rounded,

                    title:
                        'Address',

                    value:
                        data['address'],

                    colors:
                        gradients[3],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}