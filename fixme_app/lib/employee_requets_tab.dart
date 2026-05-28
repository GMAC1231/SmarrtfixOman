import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'shared/models/service_request.dart';
import 'shared/services/request_service.dart';
import 'shared/widgets/employee_request_card.dart';

class EmployeeRequestsTab extends StatelessWidget {
  const EmployeeRequestsTab({
    super.key,
  });

  //////////////////////////////////////////////////////////////
  /// PROFESSION NORMALIZER
  //////////////////////////////////////////////////////////////

  String _normalizeProfession(
    String value,
  ) {
    return value.trim();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    //////////////////////////////////////////////////////////////
    /// LOGIN CHECK
    //////////////////////////////////////////////////////////////

    if (currentUser == null) {
      return const Center(
        child: Text(
          'Please login',
        ),
      );
    }

    //////////////////////////////////////////////////////////////
    /// USER PROFILE
    //////////////////////////////////////////////////////////////

    return FutureBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(

      future:
          FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get(),

      builder: (
        context,
        userSnapshot,
      ) {

        ////////////////////////////////////////////////////////////
        /// LOADING
        ////////////////////////////////////////////////////////////

        if (userSnapshot.connectionState ==
            ConnectionState.waiting) {

          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        ////////////////////////////////////////////////////////////
        /// ERROR
        ////////////////////////////////////////////////////////////

        if (userSnapshot.hasError) {

          return Center(
            child: Text(
              userSnapshot.error.toString(),
            ),
          );
        }

        ////////////////////////////////////////////////////////////
        /// USER DATA
        ////////////////////////////////////////////////////////////

        final userData =
            userSnapshot.data?.data() ??
                {};

        ////////////////////////////////////////////////////////////
        /// PROFESSION
        ////////////////////////////////////////////////////////////

        final profession =
            (userData['profession'] ??
                    '')
                .toString()
                .trim();

        ////////////////////////////////////////////////////////////
        /// EMPTY PROFESSION
        ////////////////////////////////////////////////////////////

        if (profession.isEmpty) {

          return const Center(
            child: Text(
              'Please complete your profile profession',
            ),
          );
        }

        ////////////////////////////////////////////////////////////
        /// REQUEST STREAM
        ////////////////////////////////////////////////////////////

        return StreamBuilder<
            List<ServiceRequestModel>>(

          stream:
              RequestService
                  .openRequestsStream(
            serviceType: profession,
          ),

          builder: (
            context,
            snapshot,
          ) {

            ////////////////////////////////////////////////////////
            /// LOADING
            ////////////////////////////////////////////////////////

            if (snapshot.connectionState ==
                ConnectionState.waiting) {

              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            ////////////////////////////////////////////////////////
            /// ERROR
            ////////////////////////////////////////////////////////

            if (snapshot.hasError) {

              return Center(
                child: Text(
                  snapshot.error.toString(),
                ),
              );
            }

            ////////////////////////////////////////////////////////
            /// FILTER REQUESTS
            ////////////////////////////////////////////////////////

            final requests =
                (snapshot.data ?? [])

                    .where((r) {

                  final requestType =
                      r.serviceType.trim();

                  return requestType ==
                          profession &&
                      (r.status ==
                              'pending' ||
                          r.status ==
                              ServiceRequestModel
                                  .statusBidding);
                }).toList();

            ////////////////////////////////////////////////////////
            /// EMPTY
            ////////////////////////////////////////////////////////

            if (requests.isEmpty) {

              return Center(

                child: Column(

                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,

                  children: [

                    Icon(

                      Icons.inbox_rounded,

                      size: 80,

                      color:
                          Colors.grey[400],
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    Text(

                      'No $profession requests available',

                      style: TextStyle(

                        fontSize: 18,

                        color:
                            Colors.grey[700],

                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            ////////////////////////////////////////////////////////
            /// REQUEST LIST
            ////////////////////////////////////////////////////////

            return ListView.separated(

              padding:
                  const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                120,
              ),

              itemCount:
                  requests.length,

              separatorBuilder:
                  (_, __) =>
                      const SizedBox(
                height: 16,
              ),

              itemBuilder:
                  (context, index) {

                final req =
                    requests[index];

                ////////////////////////////////////////////////////
                /// CARD
                ////////////////////////////////////////////////////

                return EmployeeRequestCard(

                  title:
                      req.serviceType,

                  subtitle:
                      req.customerName,

                  price:
                      req.displayFare,

                  //////////////////////////////////////////////////
                  /// OFFER
                  //////////////////////////////////////////////////

                  onOffer: () async {

                    await _showOfferDialog(
                      context,
                      req,
                    );
                  },

                  //////////////////////////////////////////////////
                  /// WITHDRAW
                  //////////////////////////////////////////////////

                  onWithdraw: () async {

                    //////////////////////////////////////////////////
                    /// CONFIRM
                    //////////////////////////////////////////////////

                    final confirm =
                        await showDialog<bool>(

                      context: context,

                      builder: (_) {

                        return AlertDialog(

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              24,
                            ),
                          ),

                          title:
                              const Row(

                            children: [

                              Icon(
                                Icons
                                    .warning_amber_rounded,
                                color:
                                    Colors.orange,
                              ),

                              SizedBox(
                                width: 10,
                              ),

                              Text(
                                'Withdraw Offer',
                              ),
                            ],
                          ),

                          content:
                              const Text(

                            'Are you sure you want to withdraw this offer?\n\n'
                            'The customer will no longer see your proposal.',
                          ),

                          actions: [

                            //////////////////////////////////////////////////
                            /// CANCEL
                            //////////////////////////////////////////////////

                            TextButton(

                              onPressed: () {

                                Navigator.pop(
                                  context,
                                  false,
                                );
                              },

                              child:
                                  const Text(
                                'Cancel',
                              ),
                            ),

                            //////////////////////////////////////////////////
                            /// WITHDRAW
                            //////////////////////////////////////////////////

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

                              child:
                                  const Text(
                                'Withdraw',
                              ),
                            ),
                          ],
                        );
                      },
                    );

                    //////////////////////////////////////////////////
                    /// CANCELLED
                    //////////////////////////////////////////////////

                    if (confirm != true) {
                      return;
                    }

                    //////////////////////////////////////////////////
                    /// WITHDRAW
                    //////////////////////////////////////////////////

                    try {

                      await RequestService
                          .withdrawOffer(
                        req.id,
                      );

                      if (!context
                          .mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(
                              context)
                          .showSnackBar(

                        const SnackBar(

                          backgroundColor:
                              Colors.orange,

                          content: Text(
                            'Offer withdrawn successfully',
                          ),
                        ),
                      );

                    } catch (e) {

                      if (!context
                          .mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(
                              context)
                          .showSnackBar(

                        SnackBar(
                          content: Text(
                            'Failed: $e',
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  //////////////////////////////////////////////////////////////
  /// OFFER DIALOG
  //////////////////////////////////////////////////////////////

  static Future<void>
      _showOfferDialog(

    BuildContext context,

    ServiceRequestModel req,

  ) async {

    final priceController =
        TextEditingController(

      text:
          req.displayFare > 0
              ? req.displayFare
                  .toStringAsFixed(2)
              : '',
    );

    final noteController =
        TextEditingController();

    //////////////////////////////////////////////////////////////
    /// DIALOG
    //////////////////////////////////////////////////////////////

    final send =
        await showDialog<bool>(

      context: context,

      builder: (
        dialogContext,
      ) {

        return AlertDialog(

          title: const Text(
            'Send Offer',
          ),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              24,
            ),
          ),

          content: Column(

            mainAxisSize:
                MainAxisSize.min,

            children: [

              //////////////////////////////////////////////////////
              /// PRICE
              //////////////////////////////////////////////////////

              TextField(

                controller:
                    priceController,

                keyboardType:
                    const TextInputType
                        .numberWithOptions(
                  decimal: true,
                ),

                decoration:
                    const InputDecoration(

                  labelText:
                      'Offer Price',

                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              //////////////////////////////////////////////////////
              /// NOTE
              //////////////////////////////////////////////////////

              TextField(

                controller:
                    noteController,

                maxLines: 3,

                decoration:
                    const InputDecoration(

                  labelText:
                      'Message',

                  border:
                      OutlineInputBorder(),
                ),
              ),
            ],
          ),

          //////////////////////////////////////////////////////////
          /// ACTIONS
          //////////////////////////////////////////////////////////

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child:
                  const Text('Cancel'),
            ),

            FilledButton(

              onPressed: () {

                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
                  const Text('Send'),
            ),
          ],
        );
      },
    );

    //////////////////////////////////////////////////////////////
    /// CANCELLED
    //////////////////////////////////////////////////////////////

    if (send != true) return;

    //////////////////////////////////////////////////////////////
    /// VALIDATE PRICE
    //////////////////////////////////////////////////////////////

    final price = double.tryParse(
      priceController.text.trim(),
    );

    if (price == null ||
        price <= 0) {

      if (context.mounted) {

        ScaffoldMessenger.of(context)
            .showSnackBar(

          const SnackBar(
            content: Text(
              'Invalid price',
            ),
          ),
        );
      }

      return;
    }

    //////////////////////////////////////////////////////////////
    /// SEND OFFER
    //////////////////////////////////////////////////////////////

    try {

      await RequestService.sendOffer(

        requestId: req.id,

        price: price,

        note:
            noteController.text.trim(),
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(

        const SnackBar(
          content: Text(
            'Offer sent successfully',
          ),
        ),
      );

    } catch (e) {

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(

        SnackBar(
          content: Text(
            'Failed: $e',
          ),
        ),
      );
    }
  }
}