import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> showRatingDialog({

  required BuildContext context,

  required String requestId,

  required String providerId,

  required String providerName,

}) async {

  ////////////////////////////////////////////////////////////
  /// INITIAL VALUES
  ////////////////////////////////////////////////////////////

  double rating = 5;

  final reviewController =
      TextEditingController();

  ////////////////////////////////////////////////////////////
  /// DIALOG
  ////////////////////////////////////////////////////////////

  await showDialog(

    context: context,

    barrierDismissible: false,

    builder: (_) {

      return StatefulBuilder(

        builder: (
          context,
          setState,
        ) {

          return AlertDialog(

            //////////////////////////////////////////////////////
            /// STYLE
            //////////////////////////////////////////////////////

            backgroundColor:
                Colors.white,

            surfaceTintColor:
                Colors.white,

            shape:
                RoundedRectangleBorder(

              borderRadius:
                  BorderRadius.circular(
                28,
              ),
            ),

            //////////////////////////////////////////////////////
            /// TITLE
            //////////////////////////////////////////////////////

            title: Text(

              'Rate $providerName',

              style: const TextStyle(

                fontWeight:
                    FontWeight.bold,

                fontSize: 22,
              ),
            ),

            //////////////////////////////////////////////////////
            /// CONTENT
            //////////////////////////////////////////////////////

            content: Column(

              mainAxisSize:
                  MainAxisSize.min,

              children: [

                //////////////////////////////////////////////////
                /// TEXT
                //////////////////////////////////////////////////

                Text(

                  'How was the service?',

                  style:
                      Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            fontSize: 16,
                          ),
                ),

                const SizedBox(
                  height: 18,
                ),

                //////////////////////////////////////////////////
                /// STARS
                //////////////////////////////////////////////////

                Row(

                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,

                  children:
                      List.generate(5, (
                    index,
                  ) {

                    final star =
                        index + 1;

                    return IconButton(

                      onPressed: () {

                        setState(() {

                          rating =
                              star.toDouble();
                        });
                      },

                      icon: Icon(

                        star <= rating

                            ? Icons.star

                            : Icons.star_border,

                        color:
                            Colors.amber,

                        size: 34,
                      ),
                    );
                  }),
                ),

                const SizedBox(
                  height: 12,
                ),

                //////////////////////////////////////////////////
                /// REVIEW FIELD
                //////////////////////////////////////////////////

                TextField(

                  controller:
                      reviewController,

                  maxLines: 3,

                  decoration:
                      InputDecoration(

                    labelText:
                        'Write a review',

                    hintText:
                        'Optional feedback',

                    border:
                        OutlineInputBorder(

                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            //////////////////////////////////////////////////////
            /// ACTIONS
            //////////////////////////////////////////////////////

            actions: [

              ////////////////////////////////////////////////////
              /// LATER
              ////////////////////////////////////////////////////

              TextButton(

                onPressed: () {

                  Navigator.pop(
                    context,
                  );
                },

                child: const Text(

                  'Later',

                  style: TextStyle(

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),

              ////////////////////////////////////////////////////
              /// SUBMIT
              ////////////////////////////////////////////////////

              FilledButton(

                style:
                    FilledButton.styleFrom(

                  backgroundColor:
                      const Color(
                    0xFF01411C,
                  ),

                  foregroundColor:
                      Colors.white,

                  padding:
                      const EdgeInsets.symmetric(

                    horizontal: 24,
                    vertical: 14,
                  ),
                ),

                onPressed: () async {

                  try {

                    //////////////////////////////////////////////////
                    /// CURRENT USER
                    //////////////////////////////////////////////////

                    final customerId =

                        FirebaseAuth
                            .instance
                            .currentUser
                            ?.uid;

                    if (customerId ==
                        null) {

                      throw Exception(
                        "User not logged in",
                      );
                    }

                    //////////////////////////////////////////////////
                    /// SAVE RATING
                    //////////////////////////////////////////////////

                    await FirebaseFirestore
                        .instance
                        .collection(
                          'ratings',
                        )
                        .add({

                      //////////////////////////////////////////////////
                      /// IDS
                      //////////////////////////////////////////////////

                      'employeeId':
                          providerId,

                      'customerId':
                          customerId,

                      'requestId':
                          requestId,

                      //////////////////////////////////////////////////
                      /// PROVIDER
                      //////////////////////////////////////////////////

                      'providerName':
                          providerName,

                      //////////////////////////////////////////////////
                      /// REVIEW
                      //////////////////////////////////////////////////

                      'rating':
                          rating,

                      'review':
                          reviewController
                              .text
                              .trim(),

                      //////////////////////////////////////////////////
                      /// TIMESTAMP
                      //////////////////////////////////////////////////

                      'createdAt':
                          FieldValue
                              .serverTimestamp(),
                    });

                    debugPrint(
                      "RATING SAVED",
                    );

                    //////////////////////////////////////////////////
                    /// SUCCESS
                    //////////////////////////////////////////////////

                    if (context.mounted) {

                      Navigator.pop(
                        context,
                      );

                      ScaffoldMessenger.of(
                              context)
                          .showSnackBar(

                        const SnackBar(

                          content: Text(
                            'Thanks for your rating ⭐',
                          ),

                          behavior:
                              SnackBarBehavior
                                  .floating,
                        ),
                      );
                    }

                  } catch (e) {

                    //////////////////////////////////////////////////
                    /// ERROR
                    //////////////////////////////////////////////////

                    debugPrint(
                      'Rating Error: $e',
                    );

                    if (context.mounted) {

                      ScaffoldMessenger.of(
                              context)
                          .showSnackBar(

                        SnackBar(

                          content: Text(
                            'Failed to submit rating: $e',
                          ),
                        ),
                      );
                    }
                  }
                },

                child: const Text(

                  'Submit',

                  style: TextStyle(

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}