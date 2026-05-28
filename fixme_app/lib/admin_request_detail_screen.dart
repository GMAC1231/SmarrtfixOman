import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminRequestDetailScreen extends StatefulWidget {

  final String docId;

  final Map<String, dynamic> data;

  const AdminRequestDetailScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<AdminRequestDetailScreen> createState() =>
      _AdminRequestDetailScreenState();
}

class _AdminRequestDetailScreenState
    extends State<AdminRequestDetailScreen> {

  ////////////////////////////////////////////////////////////
  /// UPDATE STATUS
  ////////////////////////////////////////////////////////////

  Future<void> _updateStatus(
    String status,
  ) async {

    await FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(widget.docId)
        .set({

      'status': status,

      'updatedAt':
          FieldValue.serverTimestamp(),

    }, SetOptions(
      merge: true,
    ));

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(

        SnackBar(

          behavior:
              SnackBarBehavior.floating,

          content:
              Text(
            'Status updated to $status',
          ),
        ),
      );

    setState(() {

      widget.data['status'] =
          status;
    });
  }

  ////////////////////////////////////////////////////////////
  /// DELETE REQUEST
  ////////////////////////////////////////////////////////////

  Future<void> _deleteRequest() async {

    final confirm =
        await showDialog<bool>(

      context: context,

      builder: (_) {

        return AlertDialog(

          shape:
              RoundedRectangleBorder(

            borderRadius:
                BorderRadius.circular(24),
          ),

          title: const Text(
            'Delete Request',
          ),

          content: const Text(
            'This request will be permanently deleted.',
          ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(
                  context,
                  false,
                );
              },

              child: const Text(
                'Cancel',
              ),
            ),

            FilledButton(

              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),

              onPressed: () {

                Navigator.pop(
                  context,
                  true,
                );
              },

              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(widget.docId)
        .delete();

    if (!mounted) return;

    Navigator.pop(context);
  }

  ////////////////////////////////////////////////////////////
  /// STATUS COLOR
  ////////////////////////////////////////////////////////////

  Color _statusColor(
    String status,
  ) {

    switch (status.toLowerCase()) {

      case 'completed':
        return const Color(0xFF10B981);

      case 'cancelled':
        return const Color(0xFFEF4444);

      case 'accepted':
        return const Color(0xFF2563EB);

      case 'ongoing':
        return const Color(0xFFF59E0B);

      default:
        return const Color(0xFF6B7280);
    }
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
        bottom: 14,
      ),

      padding:
          const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
            BorderRadius.circular(22),

        boxShadow: [

          BoxShadow(

            color:
                Colors.black
                    .withOpacity(0.04),

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

          //////////////////////////////////////////////////////
          /// ICON
          //////////////////////////////////////////////////////

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

          //////////////////////////////////////////////////////
          /// TEXT
          //////////////////////////////////////////////////////

          Expanded(

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(

                  label,

                  style: TextStyle(

                    color:
                        Colors.grey[600],

                    fontSize: 13,

                    fontWeight:
                        FontWeight.w600,
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
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// ACTION BUTTON
  ////////////////////////////////////////////////////////////

  Widget _actionButton({

    required Color color,

    required IconData icon,

    required String label,

    required VoidCallback onTap,

  }) {

    return GestureDetector(

      onTap: onTap,

      child: Container(

        padding:
            const EdgeInsets.symmetric(
          vertical: 14,
        ),

        decoration: BoxDecoration(

          color: color,

          borderRadius:
              BorderRadius.circular(18),
        ),

        child: Column(

          children: [

            Icon(
              icon,
              color: Colors.white,
            ),

            const SizedBox(height: 6),

            Text(

              label,

              style:
                  const TextStyle(

                color: Colors.white,

                fontWeight:
                    FontWeight.bold,

                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// BUILD
  ////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {

    final data =
        widget.data;

    ////////////////////////////////////////////////////////////
    /// STATUS
    ////////////////////////////////////////////////////////////

    final status =
        (data['status'] ??
                'pending')
            .toString();

    final statusColor =
        _statusColor(status);

    ////////////////////////////////////////////////////////////
    /// SAFE ADDRESS
    ////////////////////////////////////////////////////////////

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

    ////////////////////////////////////////////////////////////
    /// SAFE DESCRIPTION
    ////////////////////////////////////////////////////////////

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

    ////////////////////////////////////////////////////////////
    /// CREATED TIME
    ////////////////////////////////////////////////////////////

    String createdText =
        'N/A';

    final createdAt =
        data['createdAt'];

    if (createdAt != null &&
        createdAt is Timestamp) {

      createdText =
          createdAt
              .toDate()
              .toString();
    }

    return Scaffold(

      backgroundColor:
          const Color(0xFFF4F7FC),

      //////////////////////////////////////////////////////////
      /// BODY
      //////////////////////////////////////////////////////////

      body: CustomScrollView(

        slivers: [

          //////////////////////////////////////////////////////
          /// APPBAR
          //////////////////////////////////////////////////////

          SliverAppBar(

            expandedHeight: 340,

            pinned: true,

            elevation: 0,

            backgroundColor:
                statusColor,

            leading: IconButton(

              onPressed: () {

                Navigator.pop(context);
              },

              icon: const Icon(

                Icons.arrow_back_ios_new,

                color: Colors.white,
              ),
            ),

            actions: [

              IconButton(

                onPressed:
                    _deleteRequest,

                icon: const Icon(

                  Icons.delete_rounded,

                  color: Colors.white,
                ),
              ),
            ],

            flexibleSpace:
                FlexibleSpaceBar(

              background: Container(

                decoration: BoxDecoration(

                  gradient:
                      LinearGradient(

                    begin:
                        Alignment.topLeft,

                    end:
                        Alignment.bottomRight,

                    colors: [

                      statusColor,

                      statusColor
                          .withOpacity(0.75),
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

                        //////////////////////////////////////////////////////
                        /// ICON
                        //////////////////////////////////////////////////////

                        Container(

                          width: 82,
                          height: 82,

                          decoration: BoxDecoration(

                            color:
                                Colors.white
                                    .withOpacity(0.16),

                            borderRadius:
                                BorderRadius.circular(28),
                          ),

                          child: const Icon(

                            Icons.home_repair_service,

                            color: Colors.white,

                            size: 42,
                          ),
                        ),

                        const SizedBox(height: 22),

                        //////////////////////////////////////////////////////
                        /// SERVICE
                        //////////////////////////////////////////////////////

                        Text(

                          (data['serviceType'] ??
                                  'Unknown Service')
                              .toString(),

                          style:
                              const TextStyle(

                            color: Colors.white,

                            fontSize: 28,

                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        //////////////////////////////////////////////////////
                        /// STATUS BADGE
                        //////////////////////////////////////////////////////

                        Container(

                          padding:
                              const EdgeInsets.symmetric(

                            horizontal: 10,

                            vertical: 8,
                          ),

                          decoration: BoxDecoration(

                            color:
                                Colors.white
                                    .withOpacity(0.16),

                            borderRadius:
                                BorderRadius.circular(30),
                          ),

                          child: Text(

                            status.toUpperCase(),

                            style:
                                const TextStyle(

                              color: Colors.white,

                              fontWeight:
                                  FontWeight.bold,

                              letterSpacing: 1,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        //////////////////////////////////////////////////////
                        /// DOC ID
                        //////////////////////////////////////////////////////

                        Text(

                          widget.docId,

                          style:
                              TextStyle(

                            color:
                                Colors.white
                                    .withOpacity(0.90),

                            fontSize: 13,
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

                  //////////////////////////////////////////////////////////
                  /// ACTION BUTTONS
                  //////////////////////////////////////////////////////////

                  Container(

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

                          blurRadius: 16,

                          offset:
                              const Offset(0, 6),
                        ),
                      ],
                    ),

                    child: Row(

                      children: [

                        Expanded(

                          child: _actionButton(

                            color:
                                const Color(0xFF2563EB),

                            icon:
                                Icons.handshake,

                            label:
                                'Accept',

                            onTap: () {

                              _updateStatus(
                                'accepted',
                              );
                            },
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(

                          child: _actionButton(

                            color:
                                const Color(0xFF10B981),

                            icon:
                                Icons.check_circle,

                            label:
                                'Complete',

                            onTap: () {

                              _updateStatus(
                                'completed',
                              );
                            },
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(

                          child: _actionButton(

                            color:
                                const Color(0xFFF59E0B),

                            icon:
                                Icons.cancel,

                            label:
                                'Cancel',

                            onTap: () {

                              _updateStatus(
                                'cancelled',
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  //////////////////////////////////////////////////////////
                  /// INFO
                  //////////////////////////////////////////////////////////

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
                        Icons.engineering,

                    label:
                        'Employee ID',

                    value:
                        data['employeeId'],
                  ),

                  _infoTile(

                    icon:
                        Icons.payments,

                    label:
                        'Fare',

                    value:
                        data['fare'] ??
                            data['priceOffer'],
                  ),

                  _infoTile(

                    icon:
                        Icons.location_on,

                    label:
                        'Address',

                    value:
                        address,
                  ),

                  _infoTile(

                    icon:
                        Icons.description,

                    label:
                        'Description',

                    value:
                        description,
                  ),

                  _infoTile(

                    icon:
                        Icons.pin_drop,

                    label:
                        'Longitude',

                    value:
                        data['lng'] ??
                            data['customerLng'],
                  ),

                  _infoTile(

                    icon:
                        Icons.calendar_today,

                    label:
                        'Created At',

                    value:
                        createdText,
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