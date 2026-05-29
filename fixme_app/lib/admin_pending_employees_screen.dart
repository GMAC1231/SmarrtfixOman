

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import 'package:http/http.dart'
    as http;

import 'home_page.dart';

class AdminPendingEmployeesScreen
    extends StatelessWidget {

  const AdminPendingEmployeesScreen({
    super.key,
  });

  ////////////////////////////////////////////////////////////
  /// COLORS
  ////////////////////////////////////////////////////////////

  static const darkGreen =
      Color(0xFF01411C);

////////////////////////////////////////////////////////////
/// APPROVE EMPLOYEE
////////////////////////////////////////////////////////////

Future<void> approveEmployee(

  String uid,

  Map<String, dynamic> data,

) async {

  //////////////////////////////////////////////////////////
  /// USERS
  //////////////////////////////////////////////////////////

  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .update({

    'role': 'employee',

    'employeeApprovalStatus':
        'approved',

    'employeeVerified': true,

    'isApprovedEmployee':
        true,

    'online': true,

    'available': true,

    'verifiedAt':
        FieldValue.serverTimestamp(),
  });

  //////////////////////////////////////////////////////////
  /// PUBLIC USERS
  //////////////////////////////////////////////////////////

  await FirebaseFirestore.instance
      .collection('publicUsers')
      .doc(uid)
      .set({

    'role': 'employee',

    'isApprovedEmployee': true,

    'online': true,

    'available': true,

  }, SetOptions(merge: true));

  //////////////////////////////////////////////////////////
  /// SEND EMAIL
  //////////////////////////////////////////////////////////

  try {

    print(
      "APPROVE EMAIL API START",
    );

    final response = await http.post(

      Uri.parse(
        '${Config.apiBaseUrl}/approve-employee',
      ),

      headers: {

        'Content-Type':
            'application/json',
      },

      body: jsonEncode({

        'email':
            data['email'],

      'name':
    data['name'] ??
    data['displayName'] ??
    'Employee',
      }),
    );

    print(
      "APPROVE RESPONSE => ${response.body}",
    );

  } catch (e) {

    debugPrint(
      'Approve email error: $e',
    );
  }
}

////////////////////////////////////////////////////////////
/// REJECT EMPLOYEE
////////////////////////////////////////////////////////////

Future<void> rejectEmployee(

  String uid,

  Map<String, dynamic> data,

) async {

  //////////////////////////////////////////////////////////
  /// USERS
  //////////////////////////////////////////////////////////

  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .update({

    'employeeApprovalStatus':
        'rejected',

    'employeeVerified': false,

    'isApprovedEmployee':
        false,

    'online': false,

    'available': false,
  });

  //////////////////////////////////////////////////////////
  /// PUBLIC USERS
  //////////////////////////////////////////////////////////

  await FirebaseFirestore.instance
      .collection('publicUsers')
      .doc(uid)
      .set({

    'online': false,

    'available': false,

    'isApprovedEmployee': false,

  }, SetOptions(merge: true));

  //////////////////////////////////////////////////////////
  /// SEND EMAIL
  //////////////////////////////////////////////////////////

  try {

    print(
      "REJECT EMAIL API START",
    );

    final response = await http.post(

      Uri.parse(
        '${Config.apiBaseUrl}/reject-employee',
      ),

      headers: {

        'Content-Type':
            'application/json',
      },

      body: jsonEncode({

        'email':
            data['email'],

      'name':
    data['name'] ??
    data['displayName'] ??
    'Employee',
      }),
    );

    print(
      "REJECT RESPONSE => ${response.body}",
    );

  } catch (e) {

    debugPrint(
      'Reject email error: $e',
    );
  }
}
  ////////////////////////////////////////////////////////////
  /// BUILD
  ////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
          Colors.grey.shade100,

      appBar: AppBar(

        elevation: 0,

        backgroundColor:
            darkGreen,

        title: const Text(

          "Pending Employees",

          style: TextStyle(

            color: Colors.white,

            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),

      //////////////////////////////////////////////////////////
      /// STREAM
      //////////////////////////////////////////////////////////

      body: StreamBuilder<QuerySnapshot>(

        stream: FirebaseFirestore.instance
            .collection('users')
            .where(
              'employeeApprovalStatus',
              isEqualTo: 'pending',
            )
            .snapshots(),

        builder: (
          context,
          snapshot,
        ) {

          //////////////////////////////////////////////////////
          /// LOADING
          //////////////////////////////////////////////////////

          if (!snapshot.hasData) {

            return const Center(

              child:
                  CircularProgressIndicator(),
            );
          }

          final docs =
              snapshot.data!.docs;

          //////////////////////////////////////////////////////
          /// EMPTY
          //////////////////////////////////////////////////////

          if (docs.isEmpty) {

            return Center(

              child: Column(

                mainAxisAlignment:
                    MainAxisAlignment.center,

                children: [

                  Icon(

                    Icons.verified_user,

                    size: 70,

                    color:
                        Colors.grey.shade400,
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  Text(

                    "No pending employee requests",

                    style: TextStyle(

                      fontSize: 18,

                      color:
                          Colors.grey.shade700,

                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          //////////////////////////////////////////////////////
          /// LIST
          //////////////////////////////////////////////////////

          return ListView.builder(

            padding:
                const EdgeInsets.all(
              14,
            ),

            itemCount:
                docs.length,

            itemBuilder: (
              context,
              index,
            ) {

              final doc =
                  docs[index];

              final data =
                  doc.data()
                      as Map<String, dynamic>;

              final uid =
                  doc.id;

              return Container(

                margin:
                    const EdgeInsets.only(
                  bottom: 18,
                ),

                decoration:
                    BoxDecoration(

                  color:
                      Colors.white,

                  borderRadius:
                      BorderRadius.circular(
                    22,
                  ),

                  boxShadow: [

                    BoxShadow(

                      color:
                          Colors.black.withOpacity(
                        0.05,
                      ),

                      blurRadius:
                          18,

                      offset:
                          const Offset(
                        0,
                        8,
                      ),
                    ),
                  ],
                ),

                child: Padding(

                  padding:
                      const EdgeInsets.all(
                    20,
                  ),

                  child: Column(

                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [

                      //////////////////////////////////////////////////
                      /// HEADER
                      //////////////////////////////////////////////////

                      Row(

                        children: [

                          CircleAvatar(

                            radius: 30,

                            backgroundColor:
                                darkGreen
                                    .withOpacity(
                              0.1,
                            ),

                            child: const Icon(

                              Icons.engineering,

                              color:
                                  darkGreen,

                              size: 30,
                            ),
                          ),

                          const SizedBox(
                            width: 16,
                          ),

                          Expanded(

                            child: Column(

                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [

                                Text(

                                  data['name'] ??
                                      'Unknown',

                                  style:
                                      const TextStyle(

                                    fontSize: 20,

                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(
                                  height: 4,
                                ),

                                Text(

                                  data['email'] ??
                                      '',

                                  style: TextStyle(

                                    color:
                                        Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 22,
                      ),

                      //////////////////////////////////////////////////
                      /// DETAILS
                      //////////////////////////////////////////////////

                      _infoTile(

                        Icons.work,

                        "Profession",

                        data['profession'] ??
                            'N/A',
                      ),

                      _infoTile(

                        Icons.phone,

                        "Phone",

                        data['phone'] ??
                            'N/A',
                      ),

                      _infoTile(

                        Icons.location_city,

                        "City",

                        data['city'] ??
                            'N/A',
                      ),

                      const SizedBox(
                        height: 24,
                      ),

                      //////////////////////////////////////////////////
                      /// BUTTONS
                      //////////////////////////////////////////////////

                      Row(

                        children: [

                          //////////////////////////////////////////////
                          /// APPROVE
                          //////////////////////////////////////////////

                          Expanded(

                            child:
                                ElevatedButton.icon(

                              style:
                                  ElevatedButton.styleFrom(

                                backgroundColor:
                                    Colors.green,

                                padding:
                                    const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),

                                shape:
                                    RoundedRectangleBorder(

                                  borderRadius:
                                      BorderRadius.circular(
                                    16,
                                  ),
                                ),
                              ),

                              onPressed: () async {

                                await approveEmployee(

                                  uid,

                                  data,
                                );

                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(

                                  const SnackBar(

                                    content: Text(
                                      "Employee approved successfully",
                                    ),
                                  ),
                                );
                              },

                              icon: const Icon(
                                Icons.check,
                              ),

                              label: const Text(

                                "Approve",

                                style: TextStyle(

                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 14,
                          ),

                          //////////////////////////////////////////////
                          /// REJECT
                          //////////////////////////////////////////////

                          Expanded(

                            child:
                                ElevatedButton.icon(

                              style:
                                  ElevatedButton.styleFrom(

                                backgroundColor:
                                    Colors.red,

                                padding:
                                    const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),

                                shape:
                                    RoundedRectangleBorder(

                                  borderRadius:
                                      BorderRadius.circular(
                                    16,
                                  ),
                                ),
                              ),

                              onPressed: () async {

                                await rejectEmployee(

                                  uid,

                                  data,
                                );

                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(

                                  const SnackBar(

                                    content: Text(
                                      "Employee rejected",
                                    ),
                                  ),
                                );
                              },

                              icon: const Icon(
                                Icons.close,
                              ),

                              label: const Text(

                                "Reject",

                                style: TextStyle(

                                  fontWeight:
                                      FontWeight.bold,
                                ),
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
    );
  }

  ////////////////////////////////////////////////////////////
  /// INFO TILE
  ////////////////////////////////////////////////////////////

  Widget _infoTile(

    IconData icon,

    String title,

    String value,

  ) {

    return Padding(

      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),

      child: Row(

        children: [

          Icon(

            icon,

            color:
                darkGreen,

            size: 20,
          ),

          const SizedBox(
            width: 12,
          ),

          Text(

            "$title: ",

            style: const TextStyle(

              fontWeight:
                  FontWeight.bold,
            ),
          ),

          Expanded(

            child: Text(
              value,
            ),
          ),
        ],
      ),
    );
  }
}

