import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'employee_registration.dart';
import 'employee_dashboard.dart';
import 'home_page.dart';

class EmployeePendingScreen extends StatelessWidget {
  const EmployeePendingScreen({
    super.key,
  });

  ////////////////////////////////////////////////////////////
  /// LOGOUT
  ////////////////////////////////////////////////////////////

  Future<void> logout(
    BuildContext context,
  ) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePage(),
      ),
      (route) => false,
    );
  }

  ////////////////////////////////////////////////////////////
  /// CHECK STATUS
  ////////////////////////////////////////////////////////////

  Future<void> checkApprovalStatus(
    BuildContext context,
  ) async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final snap =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final data =
          snap.data() ?? {};

      final status =
          (data['employeeApprovalStatus']
                  as String?)
              ?.toLowerCase() ??
          'pending';

      ////////////////////////////////////////////////////////
      /// APPROVED
      ////////////////////////////////////////////////////////

      if (status == 'approved') {
        if (!context.mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const EmployeeDashboardScreen(),
          ),
        );

        return;
      }

      ////////////////////////////////////////////////////////
      /// REJECTED
      ////////////////////////////////////////////////////////

      if (status == 'rejected') {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "Your request was rejected by admin.",
            ),
          ),
        );

        return;
      }

      ////////////////////////////////////////////////////////
      /// STILL PENDING
      ////////////////////////////////////////////////////////

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Still waiting for admin approval.",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Error: $e",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ////////////////////////////////////////////////////////////
    /// CURRENT USER
    ////////////////////////////////////////////////////////////

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            "User not found",
          ),
        ),
      );
    }

    ////////////////////////////////////////////////////////////
    /// STREAM
    ////////////////////////////////////////////////////////////

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        ////////////////////////////////////////////////////////
        /// LOADING
        ////////////////////////////////////////////////////////

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        ////////////////////////////////////////////////////////
        /// DATA
        ////////////////////////////////////////////////////////

        final data =
            snapshot.data!.data()
                    as Map<String, dynamic>? ??
                {};

        ////////////////////////////////////////////////////////
        /// STATUS
        ////////////////////////////////////////////////////////

        final status =
            (data['employeeApprovalStatus']
                        as String?)
                    ?.toLowerCase() ??
                'pending';

        ////////////////////////////////////////////////////////
        /// APPROVED
        ////////////////////////////////////////////////////////

        if (status == 'approved') {
          Future.microtask(() {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const EmployeeDashboardScreen(),
              ),
            );
          });
        }

        ////////////////////////////////////////////////////////
        /// REJECTED
        ////////////////////////////////////////////////////////

        final rejected =
            status == 'rejected';

        ////////////////////////////////////////////////////////
        /// REJECTION REASON
        ////////////////////////////////////////////////////////

        final rejectionReason =
            data['rejectionReason'] ??
                'Your request was rejected by admin.';

        ////////////////////////////////////////////////////////
        /// UI
        ////////////////////////////////////////////////////////

        return Scaffold(
          backgroundColor:
              const Color(0xFF0F172A),
          body: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                24,
              ),
              child: Column(
                children: [
                  const Spacer(),

                  //////////////////////////////////////////////////
                  /// ICON
                  //////////////////////////////////////////////////

                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: rejected
                            ? [
                                Colors.red,
                                Colors.redAccent,
                              ]
                            : [
                                Colors.orange,
                                Colors.deepOrange,
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: rejected
                              ? Colors.red
                                  .withOpacity(
                                  0.35,
                                )
                              : Colors.orange
                                  .withOpacity(
                                  0.35,
                                ),
                          blurRadius: 30,
                          offset:
                              const Offset(
                            0,
                            14,
                          ),
                        ),
                      ],
                    ),
                    child: Icon(
                      rejected
                          ? Icons.close_rounded
                          : Icons.pending_actions_rounded,
                      color: Colors.white,
                      size: 70,
                    ),
                  ),

                  const SizedBox(height: 40),

                  //////////////////////////////////////////////////
                  /// TITLE
                  //////////////////////////////////////////////////

                  Text(
                    rejected
                        ? "Request Rejected"
                        : "Verification Pending",
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 18),

                  //////////////////////////////////////////////////
                  /// DESCRIPTION
                  //////////////////////////////////////////////////

                  Text(
                    rejected
                        ? rejectionReason
                        : "Your employee verification request has been submitted successfully.\n\nAdmin approval is required before you can start accepting jobs.",
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: Colors.white
                          .withOpacity(
                        0.75,
                      ),
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 34),

                  //////////////////////////////////////////////////
                  /// STATUS BOX
                  //////////////////////////////////////////////////

                  Container(
                    padding:
                        const EdgeInsets.all(
                      20,
                    ),
                    decoration: BoxDecoration(
                      color: rejected
                          ? Colors.red
                              .withOpacity(
                              0.12,
                            )
                          : Colors.orange
                              .withOpacity(
                              0.12,
                            ),
                      borderRadius:
                          BorderRadius.circular(
                        24,
                      ),
                      border: Border.all(
                        color: rejected
                            ? Colors.red
                                .withOpacity(
                                0.30,
                              )
                            : Colors.orange
                                .withOpacity(
                                0.30,
                              ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          rejected
                              ? Icons.error_outline
                              : Icons.info_outline,
                          color: rejected
                              ? Colors.red
                              : Colors.orange,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            rejected
                                ? "Please contact support or submit your documents again."
                                : "You will automatically enter the employee dashboard once approved.",
                            style:
                                TextStyle(
                              color: Colors.white
                                  .withOpacity(
                                0.88,
                              ),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                
//////////////////////////////////////////////////
// RESUBMIT BUTTON
//////////////////////////////////////////////////

if (rejected) ...[

  const SizedBox(
    height: 24,
  ),

  SizedBox(

    width: double.infinity,

    height: 58,

    child: ElevatedButton.icon(

      style: ElevatedButton.styleFrom(

        backgroundColor:
            Colors.orange,

        shape:
            RoundedRectangleBorder(

          borderRadius:
              BorderRadius.circular(
            22,
          ),
        ),
      ),

      onPressed: () async {

        //////////////////////////////////////////////////////
        /// CURRENT USER
        //////////////////////////////////////////////////////

        final currentUser =
            FirebaseAuth
                .instance
                .currentUser;

        if (currentUser == null) {
          return;
        }

        //////////////////////////////////////////////////////
        /// USERS COLLECTION
        //////////////////////////////////////////////////////

        await FirebaseFirestore
            .instance
            .collection('users')
            .doc(currentUser.uid)
            .set({

          'employeeApprovalStatus':
              'pending',

          'employeeVerified':
              false,

          'isApprovedEmployee':
              false,

          'rejectionReason':
              FieldValue.delete(),

        }, SetOptions(
          merge: true,
        ));

        //////////////////////////////////////////////////////
        /// PUBLIC USERS
        //////////////////////////////////////////////////////

        await FirebaseFirestore
            .instance
            .collection('publicUsers')
            .doc(currentUser.uid)
            .set({

          'employeeApprovalStatus':
              'pending',

          'isApprovedEmployee':
              false,

        }, SetOptions(
          merge: true,
        ));

        //////////////////////////////////////////////////////
        /// NAVIGATE
        //////////////////////////////////////////////////////

        if (!context.mounted) {
          return;
        }

        Navigator.pushReplacement(

          context,

          MaterialPageRoute(

            builder: (_) =>
                EmployeeRegistrationScreen(

              email:
                  currentUser.email ??
                  '',

              name:
                  currentUser.displayName ??
                  'Employee',
            ),
          ),
        );
      },

      icon: const Icon(
        Icons.refresh,
        color: Colors.white,
      ),

      label: const Text(

        "Resubmit Documents",

        style: TextStyle(

          color: Colors.white,

          fontWeight:
              FontWeight.bold,

          fontSize: 16,
        ),
      ),
    ),
  ),
],

                  const Spacer(),

                  //////////////////////////////////////////////////
                  /// CHECK BUTTON
                  //////////////////////////////////////////////////

                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: ElevatedButton(
                      onPressed: () =>
                          checkApprovalStatus(
                        context,
                      ),
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.white,
                        foregroundColor:
                            Colors.black,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            22,
                          ),
                        ),
                      ),
                      child: const Text(
                        "Check Approval Status",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  //////////////////////////////////////////////////
                  /// LOGOUT
                  //////////////////////////////////////////////////

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: OutlinedButton(
                      onPressed: () =>
                          logout(context),
                      style:
                          OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white
                              .withOpacity(
                            0.20,
                          ),
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            22,
                          ),
                        ),
                      ),
                      child: const Text(
                        "Logout",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}