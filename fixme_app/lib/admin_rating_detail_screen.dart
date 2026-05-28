import 'package:flutter/material.dart';

class AdminRatingDetailScreen
    extends StatelessWidget {

  final String docId;

  final Map<String, dynamic> data;

  const AdminRatingDetailScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  ////////////////////////////////////////////////////////////
  /// STAR ROW
  ////////////////////////////////////////////////////////////

  Widget _stars(
    double rating,
  ) {

    return Row(

      children: List.generate(5, (index) {

        return Icon(

          index < rating.round()
              ? Icons.star_rounded
              : Icons.star_border_rounded,

          color:
              const Color(0xFFFBBF24),

          size: 24,
        );
      }),
    );
  }

  ////////////////////////////////////////////////////////////
  /// INFO TILE
  ////////////////////////////////////////////////////////////

  Widget _infoTile({

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

                    fontSize: 13,
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

    final rating =
        ((data['rating'] ?? 0)
                as num)
            .toDouble();

    return Scaffold(

      backgroundColor:
          const Color(0xFFF4F7FC),

      body: CustomScrollView(

        slivers: [

          //////////////////////////////////////////////////////
          /// APPBAR
          //////////////////////////////////////////////////////

          SliverAppBar(

            expandedHeight: 360,

            pinned: true,

            elevation: 0,

            backgroundColor:
                const Color(0xFFF59E0B),

            leading: IconButton(

              onPressed: () {

                Navigator.pop(context);
              },

              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
              ),
            ),

            flexibleSpace:
                FlexibleSpaceBar(

              background: Container(

                decoration: const BoxDecoration(

                  gradient:
                      LinearGradient(

                    colors: [

                      Color(0xFFFBBF24),

                      Color(0xFFF59E0B),
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
                                    .withOpacity(0.15),

                            borderRadius:
                                BorderRadius.circular(30),
                          ),

                          child: const Icon(

                            Icons.star_rounded,

                            color: Colors.white,

                            size: 50,
                          ),
                        ),

                        const SizedBox(height: 22),

                        Text(

                          rating
                              .toStringAsFixed(1),

                          style:
                              const TextStyle(

                            color: Colors.white,

                            fontSize: 42,

                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        _stars(rating),

                        const SizedBox(height: 16),

                        Text(

                          docId,

                          style:
                              TextStyle(

                            color:
                                Colors.white
                                    .withOpacity(0.9),
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

                  _infoTile(

                    icon:
                        Icons.engineering,

                    label:
                        'Employee ID',

                    value:
                        data['employeeId'],
                  ),

                  _infoTile(

                    icon:
                        Icons.person,

                    label:
                        'Customer ID',

                    value:
                        data['customerId'],
                  ),

                  _infoTile(

                    icon:
                        Icons.reviews,

                    label:
                        'Review',

                    value:
                        data['review'],
                  ),

                _infoTile(

  icon:
      Icons.calendar_today,

  label:
      'Timestamp',

  value:
      data['createdAt'] != null

          ? (data['createdAt']
                  as dynamic)
              .toDate()
              .toString()

          : 'N/A',
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