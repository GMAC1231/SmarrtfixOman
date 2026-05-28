import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_rating_detail_screen.dart';

class AdminRatingsScreen
    extends StatefulWidget {

  const AdminRatingsScreen({
    super.key,
  });

  @override
  State<AdminRatingsScreen>
      createState() =>
          _AdminRatingsScreenState();
}

class _AdminRatingsScreenState
    extends State<AdminRatingsScreen> {

  ////////////////////////////////////////////////////////////
  /// SEARCH
  ////////////////////////////////////////////////////////////

  final TextEditingController _searchController =
      TextEditingController();

  ////////////////////////////////////////////////////////////
  /// DELETE
  ////////////////////////////////////////////////////////////

  Future<void> _deleteRating(
    String docId,
  ) async {

    await FirebaseFirestore.instance
        .collection('ratings')
        .doc(docId)
        .delete();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(

        const SnackBar(
          behavior:
              SnackBarBehavior.floating,

          content:
              Text('Rating deleted'),
        ),
      );
  }

  ////////////////////////////////////////////////////////////
  /// ACTION SHEET
  ////////////////////////////////////////////////////////////

  void _showActions({

    required BuildContext context,

    required String docId,

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
                const EdgeInsets.symmetric(
              vertical: 10,
            ),

            child: Wrap(

              children: [

                //////////////////////////////////////////////////
                /// DETAILS
                //////////////////////////////////////////////////

                ListTile(

                  leading: Container(

                    width: 42,
                    height: 42,

                    decoration: BoxDecoration(

                      color:
                          const Color(0xFF2563EB)
                              .withOpacity(0.10),

                      borderRadius:
                          BorderRadius.circular(14),
                    ),

                    child: const Icon(

                      Icons.visibility,

                      color:
                          Color(0xFF2563EB),
                    ),
                  ),

                  title: const Text(
                    'View Details',
                  ),

                  onTap: () {

                    Navigator.pop(context);

                    Navigator.push(

                      context,

                      MaterialPageRoute(

                        builder: (_) =>
                            AdminRatingDetailScreen(

                          docId: docId,

                          data: data,
                        ),
                      ),
                    );
                  },
                ),

                //////////////////////////////////////////////////
                /// DELETE
                //////////////////////////////////////////////////

                ListTile(

                  leading: Container(

                    width: 42,
                    height: 42,

                    decoration: BoxDecoration(

                      color:
                          Colors.red
                              .withOpacity(0.10),

                      borderRadius:
                          BorderRadius.circular(14),
                    ),

                    child: const Icon(

                      Icons.delete,

                      color: Colors.red,
                    ),
                  ),

                  title: const Text(
                    'Delete Rating',
                  ),

                  onTap: () async {

                    Navigator.pop(context);

                    await _deleteRating(
                      docId,
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

  ////////////////////////////////////////////////////////////
  /// STAR ROW
  ////////////////////////////////////////////////////////////

  Widget _starRow(
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

          size: 18,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
          const Color(0xFFF4F7FC),

      //////////////////////////////////////////////////////////
      /// APP BAR
      //////////////////////////////////////////////////////////

      appBar: AppBar(

        elevation: 0,

        backgroundColor:
            Colors.white,

        title: const Text(

          'Ratings & Reviews',

          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),

      //////////////////////////////////////////////////////////
      /// BODY
      //////////////////////////////////////////////////////////

      body: Column(

        children: [

          //////////////////////////////////////////////////////
          /// SEARCH
          //////////////////////////////////////////////////////

          Container(

            color: Colors.white,

            padding:
                const EdgeInsets.all(16),

            child: TextField(

              controller:
                  _searchController,

              onChanged: (_) {

                setState(() {});
              },

              decoration: InputDecoration(

                hintText:
                    'Search employee...',

                prefixIcon:
                    const Icon(Icons.search),

                filled: true,

                fillColor:
                    const Color(0xFFF4F7FC),

                border:
                    OutlineInputBorder(

                  borderRadius:
                      BorderRadius.circular(20),

                  borderSide:
                      BorderSide.none,
                ),
              ),
            ),
          ),

          //////////////////////////////////////////////////////
          /// LIST
          //////////////////////////////////////////////////////

          Expanded(

            child: StreamBuilder<QuerySnapshot>(

              stream: FirebaseFirestore.instance
                  .collection('ratings')
                  .orderBy(
                    'createdAt',
                    descending: true,
                  )
                  .snapshots(),

              builder: (
                context,
                snapshot,
              ) {

                //////////////////////////////////////////////////
                /// ERROR
                //////////////////////////////////////////////////

                if (snapshot.hasError) {

                  return Center(

                    child: Text(
                      'Error: ${snapshot.error}',
                    ),
                  );
                }

                //////////////////////////////////////////////////
                /// LOADING
                //////////////////////////////////////////////////

                if (!snapshot.hasData) {

                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                //////////////////////////////////////////////////
                /// DOCS
                //////////////////////////////////////////////////

                final docs =
                    snapshot.data!.docs;

                //////////////////////////////////////////////////
                /// FILTERED
                //////////////////////////////////////////////////

                final filtered = docs.where((doc) {

                  final data =
                      doc.data()
                          as Map<String, dynamic>;

                  final employee =
                      (data['employeeId'] ?? '')
                          .toString()
                          .toLowerCase();

                  final customer =
                      (data['customerId'] ?? '')
                          .toString()
                          .toLowerCase();

                  final review =
                      (data['review'] ?? '')
                          .toString()
                          .toLowerCase();

                  final search =
                      _searchController.text
                          .trim()
                          .toLowerCase();

                  if (search.isEmpty) {
                    return true;
                  }

                  return employee.contains(search) ||
                      customer.contains(search) ||
                      review.contains(search);

                }).toList();

                //////////////////////////////////////////////////
                /// EMPTY
                //////////////////////////////////////////////////

                if (filtered.isEmpty) {

                  return const Center(

                    child: Text(
                      'No ratings found',
                    ),
                  );
                }

                //////////////////////////////////////////////////
                /// LIST
                //////////////////////////////////////////////////

                return ListView.builder(

                  padding:
                      const EdgeInsets.all(16),

                  itemCount:
                      filtered.length,

                  itemBuilder: (
                    context,
                    index,
                  ) {

                    final doc =
                        filtered[index];

                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    final rating =
                        ((data['rating'] ?? 0)
                                as num)
                            .toDouble();

                    final review =
                        (data['review'] ??
                                'No review')
                            .toString();

                    final employeeId =
                        (data['employeeId'] ??
                                'Unknown')
                            .toString();

                    final customerId =
                        (data['customerId'] ??
                                'Unknown')
                            .toString();

                    //////////////////////////////////////////////////
                    /// CARD
                    //////////////////////////////////////////////////

                    return GestureDetector(

                      onTap: () {

                        _showActions(

                          context: context,

                          docId: doc.id,

                          data: data,
                        );
                      },

                      child: Container(

                        margin:
                            const EdgeInsets.only(
                          bottom: 18,
                        ),

                        padding:
                            const EdgeInsets.all(18),

                        decoration: BoxDecoration(

                          color: Colors.white,

                          borderRadius:
                              BorderRadius.circular(28),

                          boxShadow: [

                            BoxShadow(

                              color:
                                  Colors.black
                                      .withOpacity(0.05),

                              blurRadius: 18,

                              offset:
                                  const Offset(0, 6),
                            ),
                          ],
                        ),

                        child: Column(

                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [

                            //////////////////////////////////////////////////
                            /// TOP
                            //////////////////////////////////////////////////

                            Row(

                              children: [

                                //////////////////////////////////////////////////
                                /// AVATAR
                                //////////////////////////////////////////////////

                                Container(

                                  width: 62,
                                  height: 62,

                                  decoration: BoxDecoration(

                                    gradient:
                                        const LinearGradient(

                                      colors: [

                                        Color(0xFFFBBF24),

                                        Color(0xFFF59E0B),
                                      ],
                                    ),

                                    borderRadius:
                                        BorderRadius.circular(22),
                                  ),

                                  child: const Icon(

                                    Icons.star_rounded,

                                    color: Colors.white,

                                    size: 34,
                                  ),
                                ),

                                const SizedBox(width: 16),

                                //////////////////////////////////////////////////
                                /// INFO
                                //////////////////////////////////////////////////

                                Expanded(

                                  child: Column(

                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [

                                      Text(

                                        'Employee Rating',

                                        style:
                                            TextStyle(

                                          color:
                                              Colors.grey[600],

                                          fontSize: 13,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      Text(

                                        rating
                                            .toStringAsFixed(1),

                                        style:
                                            const TextStyle(

                                          fontSize: 28,

                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      _starRow(
                                        rating,
                                      ),
                                    ],
                                  ),
                                ),

                                //////////////////////////////////////////////////
                                /// MENU
                                //////////////////////////////////////////////////

                                IconButton(

                                  onPressed: () {

                                    _showActions(

                                      context: context,

                                      docId: doc.id,

                                      data: data,
                                    );
                                  },

                                  icon: const Icon(
                                    Icons.more_vert,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            //////////////////////////////////////////////////
                            /// REVIEW
                            //////////////////////////////////////////////////

                            Container(

                              padding:
                                  const EdgeInsets.all(16),

                              decoration: BoxDecoration(

                                color:
                                    const Color(0xFFF4F7FC),

                                borderRadius:
                                    BorderRadius.circular(20),
                              ),

                              child: Text(

                                review,

                                style:
                                    TextStyle(

                                  color:
                                      Colors.grey[800],

                                  height: 1.4,

                                  fontSize: 14,
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            //////////////////////////////////////////////////
                            /// IDS
                            //////////////////////////////////////////////////

                            Row(

                              children: [

                                Expanded(

                                  child: _infoChip(

                                    icon:
                                        Icons.engineering,

                                    label:
                                        'Employee',

                                    value:
                                        employeeId,
                                  ),
                                ),

                                const SizedBox(width: 10),

                                Expanded(

                                  child: _infoChip(

                                    icon:
                                        Icons.person,

                                    label:
                                        'Customer',

                                    value:
                                        customerId,
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

  ////////////////////////////////////////////////////////////
  /// INFO CHIP
  ////////////////////////////////////////////////////////////

  Widget _infoChip({

    required IconData icon,

    required String label,

    required String value,
  }) {

    return Container(

      padding:
          const EdgeInsets.all(14),

      decoration: BoxDecoration(

        color:
            const Color(0xFFF4F7FC),

        borderRadius:
            BorderRadius.circular(18),
      ),

      child: Row(

        children: [

          Icon(

            icon,

            size: 18,

            color:
                const Color(0xFF2563EB),
          ),

          const SizedBox(width: 8),

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

                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 2),

                Text(

                  value,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(

                    fontWeight:
                        FontWeight.bold,

                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}