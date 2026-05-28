import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminEmployeeDetailScreen extends StatelessWidget {

  final String docId;

  final String employeeId;

  const AdminEmployeeDetailScreen({
    super.key,
    required this.docId,
    required this.employeeId,
  });

  ////////////////////////////////////////////////////////////
  /// STAT CARD
  ////////////////////////////////////////////////////////////

  Widget _statCard({

    required IconData icon,

    required String title,

    required String value,

    required Color color,
  }) {

    return Container(

      padding:
          const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color:
            color.withOpacity(0.10),

        borderRadius:
            BorderRadius.circular(24),
      ),

      child: Column(

        crossAxisAlignment:
            CrossAxisAlignment.start,

        mainAxisAlignment:
            MainAxisAlignment.start,

        children: [

          Container(

            padding:
                const EdgeInsets.all(10),

            decoration: BoxDecoration(

              color:
                  color.withOpacity(0.16),

              borderRadius:
                  BorderRadius.circular(16),
            ),

            child: Icon(

              icon,

              color: color,

              size: 24,
            ),
          ),

          const SizedBox(height: 16),

          Text(

            value,

            maxLines: 1,

            overflow:
                TextOverflow.ellipsis,

            style:
                const TextStyle(

              fontSize: 20,

              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(

            title,

            maxLines: 1,

            overflow:
                TextOverflow.ellipsis,

            style:
                TextStyle(

              color:
                  Colors.grey[700],

              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// INFO CARD
  ////////////////////////////////////////////////////////////

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
                    .withOpacity(0.10),

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

                      fontSize: 13,
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

                      height: 1.4,
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

  ////////////////////////////////////////////////////////////
  /// STATUS CHIP
  ////////////////////////////////////////////////////////////

  Widget _statusChip({

    required String text,

    required Color color,
  }) {

    return Container(

      padding:
          const EdgeInsets.symmetric(

        horizontal: 16,

        vertical: 10,
      ),

      decoration: BoxDecoration(

        color:
            color.withOpacity(0.14),

        borderRadius:
            BorderRadius.circular(28),
      ),

      child: Text(

        text.toUpperCase(),

        style:
            TextStyle(

          color: color,

          fontWeight:
              FontWeight.bold,

          letterSpacing: 0.7,

          fontSize: 11,
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// GRADIENTS
  ////////////////////////////////////////////////////////////

  static const List<List<Color>> gradients = [

    [
      Color(0xFF2563EB),
      Color(0xFF1D4ED8),
    ],

    [
      Color(0xFF10B981),
      Color(0xFF059669),
    ],

    [
      Color(0xFFF59E0B),
      Color(0xFFD97706),
    ],

    [
      Color(0xFF8B5CF6),
      Color(0xFF7C3AED),
    ],

    [
      Color(0xFFEF4444),
      Color(0xFFDC2626),
    ],

    [
      Color(0xFF06B6D4),
      Color(0xFF0891B2),
    ],
  ];

  @override
  Widget build(BuildContext context) {

    return StreamBuilder<DocumentSnapshot>(

      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(employeeId)
              .snapshots(),

      builder: (context, snapshot) {

        if (!snapshot.hasData) {

          return const Scaffold(

            body: Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        final data =

            snapshot.data!.data()
                as Map<String, dynamic>;

        final name =
            (data['name'] ??
                    'Employee')
                .toString();

        final email =
            (data['email'] ??
                    'No Email')
                .toString();

        final role =
            (data['role'] ??
                    'employee')
                .toString();

        final profession =
            (data['profession'] ??
                    'Unknown')
                .toString();

        final emoji =
            (data['professionEmoji'] ??
                    '🛠️')
                .toString();

        ////////////////////////////////////////////////////////
        /// LIVE FIRESTORE VALUES
        ////////////////////////////////////////////////////////

        final totalEarnings =

            data['totalEarnings'] != null

                ? double.tryParse(
                      data['totalEarnings']
                          .toString(),
                  ) ??
                  0.0

                : 0.0;

        final totalJobs =

            data['totalJobs'] != null

                ? data['totalJobs']
                    .toString()

                : '0';

        final totalReviews =

            data['totalReviews'] != null

                ? data['totalReviews']
                    .toString()

                : '0';

        final rating =

            data['rating'] != null

                ? double.tryParse(
                      data['rating']
                          .toString(),
                  ) ??
                  0.0

                : 0.0;

        final formattedRating =
            rating.toStringAsFixed(1);

        final formattedEarnings =
            totalEarnings.toStringAsFixed(2);

        return Scaffold(

          backgroundColor:
              const Color(0xFFF4F7FC),

          body: CustomScrollView(

            slivers: [

              //////////////////////////////////////////////////
              /// APP BAR
              //////////////////////////////////////////////////

              SliverAppBar(

                expandedHeight: 340,

                pinned: true,

                elevation: 0,

                backgroundColor:
                    const Color(0xFF10B981),

                leading: IconButton(

                  onPressed: () {

                    Navigator.pop(context);
                  },

                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                ),

                flexibleSpace:
                    FlexibleSpaceBar(

                  background: Container(

                    decoration:
                        const BoxDecoration(

                      gradient:
                          LinearGradient(

                        begin:
                            Alignment.topLeft,

                        end:
                            Alignment.bottomRight,

                        colors: [

                          Color(0xFF10B981),

                          Color(0xFF047857),
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

                            Row(

                              children: [

                                Container(

                                  width: 120,
                                  height: 120,

                                  decoration:
                                      BoxDecoration(

                                    color:
                                        Colors.white
                                            .withOpacity(
                                      0.16,
                                    ),

                                    borderRadius:
                                        BorderRadius.circular(
                                      36,
                                    ),
                                  ),

                                  child: Center(

                                    child: Text(

                                      emoji,

                                      style:
                                          const TextStyle(
                                        fontSize: 56,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 20),

                                Expanded(

                                  child: Column(

                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [

                                      Text(

                                        name,

                                        style:
                                            const TextStyle(

                                          color:
                                              Colors.white,

                                          fontSize: 32,

                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      Text(

                                        profession,

                                        style:
                                            TextStyle(

                                          color:
                                              Colors.white
                                                  .withOpacity(
                                            0.95,
                                          ),

                                          fontSize: 17,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            Row(

                              children: [

                                Icon(

                                  Icons.email_rounded,

                                  color:
                                      Colors.white
                                          .withOpacity(
                                    0.92,
                                  ),

                                  size: 18,
                                ),

                                const SizedBox(width: 8),

                                Expanded(

                                  child: Text(

                                    email,

                                    overflow:
                                        TextOverflow.ellipsis,

                                    style:
                                        TextStyle(

                                      color:
                                          Colors.white
                                              .withOpacity(
                                        0.92,
                                      ),

                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 22),

                            Wrap(

                              spacing: 10,

                              runSpacing: 10,

                              children: [

                                _statusChip(

                                  text: role,

                                  color:
                                      Colors.white,
                                ),

                                _statusChip(

                                  text:
                                      profession,

                                  color:
                                      const Color(
                                    0xFFFFD54F,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              //////////////////////////////////////////////////
              /// CONTENT
              //////////////////////////////////////////////////

              SliverToBoxAdapter(

                child: Padding(

                  padding:
                      const EdgeInsets.all(18),

                  child: Column(

                    children: [

                      //////////////////////////////////////////////////////
                      /// STATS
                      //////////////////////////////////////////////////////

                      GridView.count(

                        crossAxisCount: 2,

                        shrinkWrap: true,

                        physics:
                            const NeverScrollableScrollPhysics(),

                        crossAxisSpacing: 14,

                        mainAxisSpacing: 14,

                        childAspectRatio: 1.05,

                        children: [

                          _statCard(

                            icon:
                                Icons.star_rounded,

                            title:
                                'Rating',

                            value:
                                formattedRating,

                            color:
                                Colors.amber,
                          ),

                          _statCard(

                            icon:
                                Icons.reviews_rounded,

                            title:
                                'Reviews',

                            value:
                                totalReviews,

                            color:
                                Colors.blue,
                          ),

                          _statCard(

                            icon:
                                Icons.account_balance_wallet,

                            title:
                                'Earnings',

                            value:
                                'OMR $formattedEarnings',

                            color:
                                Colors.green,
                          ),

                          _statCard(

                            icon:
                                Icons.task_alt_rounded,

                            title:
                                'Completed',

                            value:
                                totalJobs,

                            color:
                                Colors.purple,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      //////////////////////////////////////////////////////
                      /// INFO
                      //////////////////////////////////////////////////////

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
                            Icons.fingerprint_rounded,

                        title:
                            'UID',

                        value:
                            data['uid'],

                        colors:
                            gradients[1],
                      ),

                      _infoCard(

                        icon:
                            Icons.phone_rounded,

                        title:
                            'Phone Number',

                        value:
                            data['phone'],

                        colors:
                            gradients[2],
                      ),

                      _infoCard(

                        icon:
                            Icons.work_rounded,

                        title:
                            'Profession',

                        value:
                            '$emoji  $profession',

                        colors:
                            gradients[3],
                      ),

                      _infoCard(

                        icon:
                            Icons.location_city_rounded,

                        title:
                            'City',

                        value:
                            data['city'],

                        colors:
                            gradients[4],
                      ),

                      _infoCard(

                        icon:
                            Icons.home_rounded,

                        title:
                            'Address',

                        value:
                            data['address'],

                        colors:
                            gradients[5],
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}