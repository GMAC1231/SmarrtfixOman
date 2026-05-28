import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_request_detail_screen.dart';

class AdminRequestsScreen extends StatefulWidget {

  const AdminRequestsScreen({
    super.key,
  });

  @override
  State<AdminRequestsScreen> createState() =>
      _AdminRequestsScreenState();
}

class _AdminRequestsScreenState
    extends State<AdminRequestsScreen> {

  ////////////////////////////////////////////////////////////
  /// FILTER
  ////////////////////////////////////////////////////////////

  String _selectedFilter = 'all';

  ////////////////////////////////////////////////////////////
  /// SEARCH
  ////////////////////////////////////////////////////////////

  final TextEditingController
      _searchController =
      TextEditingController();

  ////////////////////////////////////////////////////////////
  /// DELETE REQUEST
  ////////////////////////////////////////////////////////////

  Future<void> _deleteRequest(
    String docId,
  ) async {

    await FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(docId)
        .delete();
  }

  ////////////////////////////////////////////////////////////
  /// UPDATE STATUS
  ////////////////////////////////////////////////////////////

  Future<void> _setStatus({

    required String docId,

    required String status,

  }) async {

    await FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(docId)
        .set({

      'status': status,

      'updatedAt':
          FieldValue.serverTimestamp(),

    }, SetOptions(
      merge: true,
    ));
  }

  ////////////////////////////////////////////////////////////
  /// ACTIONS
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

                  leading: const Icon(
                    Icons.visibility_rounded,
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
                            AdminRequestDetailScreen(

                          docId: docId,

                          data: data,
                        ),
                      ),
                    );
                  },
                ),

                //////////////////////////////////////////////////
                /// COMPLETE
                //////////////////////////////////////////////////

                ListTile(

                  leading: const Icon(

                    Icons.check_circle_rounded,

                    color: Colors.green,
                  ),

                  title: const Text(
                    'Mark Completed',
                  ),

                  onTap: () async {

                    Navigator.pop(context);

                    await _setStatus(

                      docId: docId,

                      status: 'completed',
                    );
                  },
                ),

                //////////////////////////////////////////////////
                /// CANCEL
                //////////////////////////////////////////////////

                ListTile(

                  leading: const Icon(

                    Icons.cancel_rounded,

                    color: Colors.orange,
                  ),

                  title: const Text(
                    'Mark Cancelled',
                  ),

                  onTap: () async {

                    Navigator.pop(context);

                    await _setStatus(

                      docId: docId,

                      status: 'cancelled',
                    );
                  },
                ),

                //////////////////////////////////////////////////
                /// DELETE
                //////////////////////////////////////////////////

                ListTile(

                  leading: const Icon(

                    Icons.delete_rounded,

                    color: Colors.red,
                  ),

                  title: const Text(
                    'Delete Request',
                  ),

                  onTap: () async {

                    Navigator.pop(context);

                    await _deleteRequest(
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
  /// STATUS COLOR
  ////////////////////////////////////////////////////////////

  Color _statusColor(
    String status,
  ) {

    switch (status.toLowerCase()) {

      case 'completed':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      case 'accepted':
        return Colors.blue;

      case 'ongoing':
        return Colors.orange;

      case 'pending':
        return Colors.amber;

      default:
        return Colors.grey;
    }
  }

  ////////////////////////////////////////////////////////////
  /// STATUS ICON
  ////////////////////////////////////////////////////////////

  IconData _statusIcon(
    String status,
  ) {

    switch (status.toLowerCase()) {

      case 'completed':
        return Icons.check_circle;

      case 'cancelled':
        return Icons.cancel;

      case 'accepted':
        return Icons.handshake;

      case 'ongoing':
        return Icons.directions_car;

      case 'pending':
        return Icons.hourglass_top;

      default:
        return Icons.info;
    }
  }

  ////////////////////////////////////////////////////////////
  /// FILTER CHIP
  ////////////////////////////////////////////////////////////

  Widget _filterChip(
    String label,
  ) {

    final selected =
        _selectedFilter == label;

    return Padding(

      padding:
          const EdgeInsets.only(
        right: 8,
      ),

      child: ChoiceChip(

        selected: selected,

        label: Text(
          label.toUpperCase(),
        ),

        onSelected: (_) {

          setState(() {

            _selectedFilter = label;
          });
        },
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// BUILD
  ////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
          const Color(0xFFF5F7FB),

      //////////////////////////////////////////////////////////
      /// APPBAR
      //////////////////////////////////////////////////////////

      appBar: AppBar(

        elevation: 0,

        backgroundColor:
            Colors.white,

        title: const Text(

          'Service Requests',

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
          /// SEARCH + FILTER
          //////////////////////////////////////////////////////

          Container(

            padding:
                const EdgeInsets.all(16),

            color: Colors.white,

            child: Column(

              children: [

                //////////////////////////////////////////////////
                /// SEARCH
                //////////////////////////////////////////////////

                TextField(

                  controller:
                      _searchController,

                  onChanged: (_) {

                    setState(() {});
                  },

                  decoration: InputDecoration(

                    hintText:
                        'Search requests...',

                    prefixIcon:
                        const Icon(
                      Icons.search,
                    ),

                    filled: true,

                    fillColor:
                        const Color(
                      0xFFF5F7FB,
                    ),

                    border:
                        OutlineInputBorder(

                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),

                      borderSide:
                          BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 14,
                ),

                //////////////////////////////////////////////////
                /// FILTERS
                //////////////////////////////////////////////////

                SingleChildScrollView(

                  scrollDirection:
                      Axis.horizontal,

                  child: Row(

                    children: [

                      _filterChip('all'),
                      _filterChip('pending'),
                      _filterChip('accepted'),
                      _filterChip('ongoing'),
                      _filterChip('completed'),
                      _filterChip('cancelled'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          //////////////////////////////////////////////////////
          /// REQUESTS LIST
          //////////////////////////////////////////////////////

          Expanded(

            child:
                StreamBuilder<QuerySnapshot>(

              stream:
                  FirebaseFirestore.instance
                      .collection(
                        'serviceRequests',
                      )
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
                /// FILTER
                //////////////////////////////////////////////////

                final filtered =
                    docs.where((doc) {

                  final data =
                      doc.data()
                          as Map<String, dynamic>;

                  final status =
                      (data['status'] ?? '')
                          .toString()
                          .toLowerCase();

                  final service =
                      (data['serviceType'] ?? '')
                          .toString()
                          .toLowerCase();

                  final customer =
                      (data['customerName'] ?? '')
                          .toString()
                          .toLowerCase();

                  final search =
                      _searchController.text
                          .trim()
                          .toLowerCase();

                  final matchesFilter =
                      _selectedFilter == 'all'

                          ? true

                          : status ==
                              _selectedFilter;

                  final matchesSearch =
                      search.isEmpty

                          ? true

                          : service.contains(
                                  search,
                                ) ||
                              customer.contains(
                                  search);

                  return matchesFilter &&
                      matchesSearch;

                }).toList();

                //////////////////////////////////////////////////
                /// EMPTY
                //////////////////////////////////////////////////

                if (filtered.isEmpty) {

                  return const Center(

                    child: Text(
                      'No requests found',
                    ),
                  );
                }

                //////////////////////////////////////////////////
                /// LIST
                //////////////////////////////////////////////////

                return ListView.builder(

                  padding:
                      const EdgeInsets.all(14),

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

                    //////////////////////////////////////////////////
                    /// BASIC INFO
                    //////////////////////////////////////////////////

                    final status =
                        (data['status'] ??
                                'pending')
                            .toString();

                    final serviceType =
                        (data['serviceType'] ??
                                'Unknown Service')
                            .toString();

                    final customerName =
                        (data['customerName'] ??
                                'Customer')
                            .toString();

                    //////////////////////////////////////////////////
                    /// SAFE ADDRESS
                    //////////////////////////////////////////////////

                    String address =
                        'No address provided';

                    if (data['address'] != null &&
                        data['address']
                            .toString()
                            .trim()
                            .isNotEmpty) {

                      address =
                          data['address']
                              .toString();

                    } else if (
                        data['locationAddress'] != null &&
                        data['locationAddress']
                            .toString()
                            .trim()
                            .isNotEmpty) {

                      address =
                          data['locationAddress']
                              .toString();

                    } else if (
                        data['customerLat'] != null &&
                        data['customerLng'] != null) {

                      address =
                          '${data['customerLat']}, ${data['customerLng']}';
                    }

                    //////////////////////////////////////////////////
                    /// SAFE DESCRIPTION
                    //////////////////////////////////////////////////

                    String description =
                        'No description provided';

                    if (data['description'] != null &&
                        data['description']
                            .toString()
                            .trim()
                            .isNotEmpty) {

                      description =
                          data['description']
                              .toString();

                    } else if (
                        data['note'] != null &&
                        data['note']
                            .toString()
                            .trim()
                            .isNotEmpty) {

                      description =
                          data['note']
                              .toString();

                    } else if (
                        data['details'] != null &&
                        data['details']
                            .toString()
                            .trim()
                            .isNotEmpty) {

                      description =
                          data['details']
                              .toString();
                    }

                    //////////////////////////////////////////////////
                    /// PRICE
                    //////////////////////////////////////////////////

                    final price =
                        data['fare'] ??
                        data['priceOffer'];

                    //////////////////////////////////////////////////
                    /// CREATED TIME
                    //////////////////////////////////////////////////

                    final createdAt =
                        data['createdAt'];

                    String createdText =
                        'N/A';

                    if (createdAt != null &&
                        createdAt is Timestamp) {

                      createdText =
                          createdAt
                              .toDate()
                              .toString();
                    }

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
                          bottom: 14,
                        ),

                        padding:
                            const EdgeInsets.all(
                          18,
                        ),

                        decoration:
                            BoxDecoration(

                          color: Colors.white,

                          borderRadius:
                              BorderRadius.circular(
                            24,
                          ),

                          boxShadow: [

                            BoxShadow(

                              color: Colors.black
                                  .withOpacity(
                                0.05,
                              ),

                              blurRadius: 16,

                              offset:
                                  const Offset(
                                0,
                                6,
                              ),
                            ),
                          ],
                        ),

                        child: Column(

                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [

                            //////////////////////////////////////////////////
                            /// TOP ROW
                            //////////////////////////////////////////////////

                            Row(

                              children: [

                                //////////////////////////////////////////////////
                                /// ICON
                                //////////////////////////////////////////////////

                                Container(

                                  width: 58,
                                  height: 58,

                                  decoration:
                                      BoxDecoration(

                                    color:
                                        _statusColor(
                                      status,
                                    ).withOpacity(
                                      0.12,
                                    ),

                                    borderRadius:
                                        BorderRadius.circular(
                                      18,
                                    ),
                                  ),

                                  child: Icon(

                                    _statusIcon(
                                      status,
                                    ),

                                    color:
                                        _statusColor(
                                      status,
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  width: 14,
                                ),

                                //////////////////////////////////////////////////
                                /// TEXT
                                //////////////////////////////////////////////////

                                Expanded(

                                  child: Column(

                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [

                                      Text(

                                        serviceType,

                                        style:
                                            const TextStyle(

                                          fontSize: 17,

                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(
                                        height: 4,
                                      ),

                                      Text(

                                        customerName,

                                        style: TextStyle(

                                          color:
                                              Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                //////////////////////////////////////////////////
                                /// STATUS BADGE
                                //////////////////////////////////////////////////

                                Container(

                                  padding:
                                      const EdgeInsets.symmetric(

                                    horizontal: 12,

                                    vertical: 7,
                                  ),

                                  decoration:
                                      BoxDecoration(

                                    color:
                                        _statusColor(
                                      status,
                                    ),

                                    borderRadius:
                                        BorderRadius.circular(
                                      30,
                                    ),
                                  ),

                                  child: Text(

                                    status
                                        .toUpperCase(),

                                    style:
                                        const TextStyle(

                                      color: Colors.white,

                                      fontSize: 11,

                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            //////////////////////////////////////////////////
                            /// ADDRESS
                            //////////////////////////////////////////////////

                            Row(

                              crossAxisAlignment:
                                  CrossAxisAlignment.start,

                              children: [

                                Icon(

                                  Icons.location_on,

                                  size: 18,

                                  color:
                                      Colors.grey[600],
                                ),

                                const SizedBox(
                                  width: 6,
                                ),

                                Expanded(

                                  child: Text(

                                    address,

                                    style: TextStyle(

                                      color:
                                          Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            //////////////////////////////////////////////////
                            /// DESCRIPTION
                            //////////////////////////////////////////////////

                            Row(

                              crossAxisAlignment:
                                  CrossAxisAlignment.start,

                              children: [

                                Icon(

                                  Icons.description,

                                  size: 18,

                                  color:
                                      Colors.grey[600],
                                ),

                                const SizedBox(
                                  width: 6,
                                ),

                                Expanded(

                                  child: Text(

                                    description,

                                    maxLines: 2,

                                    overflow:
                                        TextOverflow.ellipsis,

                                    style: TextStyle(

                                      color:
                                          Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            //////////////////////////////////////////////////
                            /// PRICE
                            //////////////////////////////////////////////////

                            if (price != null) ...[

                              const SizedBox(
                                height: 12,
                              ),

                              Row(

                                children: [

                                  Icon(

                                    Icons.payments,

                                    size: 18,

                                    color:
                                        Colors.green[700],
                                  ),

                                  const SizedBox(
                                    width: 6,
                                  ),

                                  Text(

                                    'Fare: Rs. $price',

                                    style:
                                        TextStyle(

                                      color:
                                          Colors.green[700],

                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            //////////////////////////////////////////////////
                            /// CREATED AT
                            //////////////////////////////////////////////////

                            const SizedBox(
                              height: 10,
                            ),

                            Row(

                              children: [

                                Icon(

                                  Icons.access_time,

                                  size: 18,

                                  color:
                                      Colors.grey[600],
                                ),

                                const SizedBox(
                                  width: 6,
                                ),

                                Expanded(

                                  child: Text(

                                    createdText,

                                    style: TextStyle(

                                      color:
                                          Colors.grey[700],

                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            //////////////////////////////////////////////////
                            /// BUTTONS
                            //////////////////////////////////////////////////

                            Row(

                              children: [

                                Expanded(

                                  child:
                                      OutlinedButton.icon(

                                    onPressed: () {

                                      Navigator.push(

                                        context,

                                        MaterialPageRoute(

                                          builder: (_) =>
                                              AdminRequestDetailScreen(

                                            docId: doc.id,

                                            data: data,
                                          ),
                                        ),
                                      );
                                    },

                                    icon: const Icon(
                                      Icons.visibility,
                                    ),

                                    label: const Text(
                                      'Details',
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  width: 10,
                                ),

                                Expanded(

                                  child:
                                      FilledButton.icon(

                                    style:
                                        FilledButton.styleFrom(

                                      backgroundColor:
                                          _statusColor(
                                        status,
                                      ),
                                    ),

                                    onPressed: () {

                                      _showActions(

                                        context: context,

                                        docId: doc.id,

                                        data: data,
                                      );
                                    },

                                    icon: const Icon(
                                      Icons.settings,
                                    ),

                                    label: const Text(
                                      'Manage',
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