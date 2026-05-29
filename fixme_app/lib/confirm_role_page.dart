import 'dart:ui';

import 'package:flutter/material.dart';

class ConfirmRolePage extends StatelessWidget {

  final String rolePretty;

  const ConfirmRolePage({
    super.key,
    required this.rolePretty,
  });

  ////////////////////////////////////////////////////////////
  /// IS EMPLOYEE
  ////////////////////////////////////////////////////////////

  bool get isEmployee =>
      rolePretty == "Employee";

  ////////////////////////////////////////////////////////////
  /// CONTINUE
  ////////////////////////////////////////////////////////////

  void _continue(
    BuildContext context,
  ) {

    Navigator.pop(
      context,
      true,
    );
  }

  ////////////////////////////////////////////////////////////
  /// CANCEL
  ////////////////////////////////////////////////////////////

  void _cancel(
    BuildContext context,
  ) {

    Navigator.pop(
      context,
      false,
    );
  }

  @override
  Widget build(BuildContext context) {

    ////////////////////////////////////////////////////////////
    /// DYNAMIC COLORS
    ////////////////////////////////////////////////////////////

    final primaryColor =

        isEmployee

            ? Colors.orange

            : Colors.green;

    final secondaryColor =

        isEmployee

            ? const Color(0xFFFF8A00)

            : const Color(0xFF00C853);

    return Scaffold(

      backgroundColor:
          const Color(0xFF0F172A),

      body: Stack(

        children: [

          //////////////////////////////////////////////////////
          /// BACKGROUND
          //////////////////////////////////////////////////////

          Positioned(
            top: -120,
            right: -80,

            child: Container(
              width: 260,
              height: 260,

              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(
                  0.16,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -140,
            left: -120,

            child: Container(
              width: 320,
              height: 320,

              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: secondaryColor.withOpacity(
                  0.15,
                ),
              ),
            ),
          ),

          //////////////////////////////////////////////////////
          /// CONTENT
          //////////////////////////////////////////////////////

          SafeArea(

            child: Padding(

              padding: const EdgeInsets.all(
                24,
              ),

              child: Column(

                children: [

                  //////////////////////////////////////////////////
                  /// BACK BUTTON
                  //////////////////////////////////////////////////

                  Align(

                    alignment:
                        Alignment.centerLeft,

                    child: IconButton(

                      onPressed: () =>
                          _cancel(context),

                      icon: const Icon(

                        Icons.arrow_back_ios_new_rounded,

                        color: Colors.white,
                      ),
                    ),
                  ),

                  const Spacer(),

                  //////////////////////////////////////////////////
                  /// GLASS CARD
                  //////////////////////////////////////////////////

                  ClipRRect(

                    borderRadius:
                        BorderRadius.circular(
                      36,
                    ),

                    child: BackdropFilter(

                      filter: ImageFilter.blur(
                        sigmaX: 18,
                        sigmaY: 18,
                      ),

                      child: Container(

                        width: double.infinity,

                        padding:
                            const EdgeInsets.all(
                          30,
                        ),

                        decoration: BoxDecoration(

                          color: Colors.white
                              .withOpacity(0.08),

                          borderRadius:
                              BorderRadius.circular(
                            36,
                          ),

                          border: Border.all(

                            color: Colors.white
                                .withOpacity(0.12),
                          ),
                        ),

                        child: Column(

                          children: [

                            //////////////////////////////////////////
                            /// ICON
                            //////////////////////////////////////////

                            Container(

                              width: 110,
                              height: 110,

                              decoration: BoxDecoration(

                                shape: BoxShape.circle,

                                gradient: LinearGradient(

                                  colors: [

                                    primaryColor,
                                    secondaryColor,
                                  ],
                                ),

                                boxShadow: [

                                  BoxShadow(

                                    color:
                                        primaryColor
                                            .withOpacity(
                                      0.35,
                                    ),

                                    blurRadius: 28,

                                    offset:
                                        const Offset(
                                      0,
                                      14,
                                    ),
                                  ),
                                ],
                              ),

                              child: Icon(

                                isEmployee

                                    ? Icons.admin_panel_settings_rounded

                                    : Icons.check_circle_rounded,

                                color: Colors.white,

                                size: 52,
                              ),
                            ),

                            const SizedBox(height: 30),

                            //////////////////////////////////////////
                            /// TITLE
                            //////////////////////////////////////////

                            const Text(

                              "Confirm Your Role",

                              textAlign:
                                  TextAlign.center,

                              style: TextStyle(

                                color: Colors.white,

                                fontSize: 32,

                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 18),

                            //////////////////////////////////////////
                            /// DESCRIPTION
                            //////////////////////////////////////////

                            RichText(

                              textAlign:
                                  TextAlign.center,

                              text: TextSpan(

                                style: TextStyle(

                                  color: Colors.white
                                      .withOpacity(
                                    0.75,
                                  ),

                                  fontSize: 16,

                                  height: 1.6,
                                ),

                                children: [

                                  const TextSpan(
                                    text:
                                        "You are about to continue as ",
                                  ),

                                  TextSpan(

                                    text: rolePretty,

                                    style:
                                        const TextStyle(

                                      color:
                                          Colors.white,

                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),

                                  TextSpan(

                                    text:

                                        isEmployee

                                            ? ".\n\nYour profile will require administrator approval before accepting jobs."

                                            : ".\n\nCustomer mode is available immediately.",
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            //////////////////////////////////////////
                            /// INFO CARD
                            //////////////////////////////////////////

                            Container(

                              padding:
                                  const EdgeInsets.all(
                                18,
                              ),

                              decoration:
                                  BoxDecoration(

                                color:
                                    primaryColor
                                        .withOpacity(
                                  0.12,
                                ),

                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  22,
                                ),

                                border: Border.all(

                                  color:
                                      primaryColor
                                          .withOpacity(
                                    0.30,
                                  ),
                                ),

                                boxShadow: [

                                  BoxShadow(

                                    color:
                                        primaryColor
                                            .withOpacity(
                                      0.08,
                                    ),

                                    blurRadius: 18,

                                    offset:
                                        const Offset(
                                      0,
                                      8,
                                    ),
                                  ),
                                ],
                              ),

                              child: Row(

                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [

                                  Icon(

                                    isEmployee

                                        ? Icons
                                            .warning_amber_rounded

                                        : Icons
                                            .verified_rounded,

                                    color:
                                        primaryColor,
                                  ),

                                  const SizedBox(
                                    width: 12,
                                  ),

                                  Expanded(

                                    child: Text(

                                      isEmployee

                                          ? "Employee access requires admin verification and approval."

                                          : "Customer accounts can instantly browse and request services.",

                                      style: TextStyle(

                                        color:
                                            Colors.white
                                                .withOpacity(
                                          0.88,
                                        ),

                                        fontSize: 14,

                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 34),

                            //////////////////////////////////////////
                            /// BUTTONS
                            //////////////////////////////////////////

                            Row(

                              children: [

                                //////////////////////////////////////
                                /// CANCEL
                                //////////////////////////////////////

                                Expanded(

                                  child: SizedBox(

                                    height: 60,

                                    child:
                                        OutlinedButton(

                                      onPressed: () =>
                                          _cancel(
                                        context,
                                      ),

                                      style:
                                          OutlinedButton.styleFrom(

                                        side: BorderSide(

                                          color: Colors
                                              .white
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

                                        "Cancel",

                                        style: TextStyle(

                                          color:
                                              Colors.white,

                                          fontSize: 16,

                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 14),

                                //////////////////////////////////////
                                /// CONTINUE
                                //////////////////////////////////////

                                Expanded(

                                  child: SizedBox(

                                    height: 60,

                                    child:
                                        ElevatedButton(

                                      onPressed: () =>
                                          _continue(
                                        context,
                                      ),

                                      style:
                                          ElevatedButton.styleFrom(

                                        elevation: 0,

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

                                        "Continue",

                                        style: TextStyle(

                                          fontSize: 16,

                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}