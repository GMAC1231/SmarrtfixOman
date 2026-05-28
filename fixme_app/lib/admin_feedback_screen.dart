import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminFeedbackScreen
    extends StatefulWidget {

  const AdminFeedbackScreen({
    super.key,
  });

  @override
  State<AdminFeedbackScreen>
      createState() =>
          _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState
    extends State<AdminFeedbackScreen> {

  bool loading = true;

  List<dynamic> items = [];

  String? error;

  final TextEditingController _searchController =
      TextEditingController();

  static const String baseUrl =
      'http://192.168.100.15:5000';

  ////////////////////////////////////////////////////////////
  /// LOAD
  ////////////////////////////////////////////////////////////

  Future<void> loadFeedback() async {

    try {

      setState(() {

        loading = true;

        error = null;
      });

      final token =
          await FirebaseAuth.instance.currentUser
              ?.getIdToken();

      final response = await http.get(

        Uri.parse(
          '$baseUrl/api/admin/feedback',
        ),

        headers: {

          'Authorization':
              'Bearer $token',
        },
      );

      final body =
          jsonDecode(response.body);

      if (response.statusCode != 200) {

        throw Exception(
          body['error'],
        );
      }

      setState(() {

        items =
            body['items'] ?? [];
      });

    } catch (e) {

      setState(() {

        error = e.toString();
      });

    } finally {

      setState(() {

        loading = false;
      });
    }
  }

  ////////////////////////////////////////////////////////////
  /// DELETE
  ////////////////////////////////////////////////////////////

  Future<void> deleteFeedback(
    int id,
  ) async {

    try {

      final token =
          await FirebaseAuth.instance.currentUser
              ?.getIdToken();

      await http.delete(

        Uri.parse(
          '$baseUrl/api/admin/feedback/$id',
        ),

        headers: {

          'Authorization':
              'Bearer $token',
        },
      );

      await loadFeedback();

    } catch (_) {}
  }

  @override
  void initState() {

    super.initState();

    loadFeedback();
  }

  ////////////////////////////////////////////////////////////
  /// FEEDBACK CARD
  ////////////////////////////////////////////////////////////

  Widget _feedbackCard(
    Map<String, dynamic> item,
  ) {

    return Container(

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
                Colors.black.withOpacity(0.05),

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

          //////////////////////////////////////////////////////
          /// TOP
          //////////////////////////////////////////////////////

          Row(

            children: [

              Container(

                width: 62,
                height: 62,

                decoration: BoxDecoration(

                  gradient:
                      const LinearGradient(

                    colors: [

                      Color(0xFF2563EB),

                      Color(0xFF1D4ED8),
                    ],
                  ),

                  borderRadius:
                      BorderRadius.circular(22),
                ),

                child: const Icon(

                  Icons.feedback_rounded,

                  color: Colors.white,

                  size: 32,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(

                child: Column(

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(

                      (item['title'] ??
                              'Feedback')
                          .toString(),

                      style:
                          const TextStyle(

                        fontSize: 18,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(

                      (item['user_email'] ??
                              '-')
                          .toString(),

                      style:
                          TextStyle(

                        color:
                            Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(

                onPressed: () {

                  deleteFeedback(
                    item['id'],
                  );
                },

                icon: const Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          //////////////////////////////////////////////////////
          /// MESSAGE
          //////////////////////////////////////////////////////

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

              (item['message'] ?? '')
                  .toString(),

              style:
                  TextStyle(

                color:
                    Colors.grey[800],

                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 16),

          //////////////////////////////////////////////////////
          /// PLATFORM
          //////////////////////////////////////////////////////

          Row(

            children: [

              _chip(

                icon:
                    Icons.phone_android,

                label:
                    (item['platform'] ?? '-')
                        .toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// CHIP
  ////////////////////////////////////////////////////////////

  Widget _chip({

    required IconData icon,

    required String label,
  }) {

    return Container(

      padding:
          const EdgeInsets.symmetric(

        horizontal: 14,

        vertical: 10,
      ),

      decoration: BoxDecoration(

        color:
            const Color(0xFFEFF6FF),

        borderRadius:
            BorderRadius.circular(18),
      ),

      child: Row(

        mainAxisSize:
            MainAxisSize.min,

        children: [

          Icon(

            icon,

            size: 18,

            color:
                const Color(0xFF2563EB),
          ),

          const SizedBox(width: 8),

          Text(

            label,

            style:
                const TextStyle(

              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final search =
        _searchController.text
            .trim()
            .toLowerCase();

    final filtered =
        items.where((e) {

      final item =
          e as Map<String, dynamic>;

      final title =
          (item['title'] ?? '')
              .toString()
              .toLowerCase();

      final message =
          (item['message'] ?? '')
              .toString()
              .toLowerCase();

      return title.contains(search) ||
          message.contains(search);

    }).toList();

    return Scaffold(

      backgroundColor:
          const Color(0xFFF4F7FC),

      appBar: AppBar(

        elevation: 0,

        backgroundColor:
            Colors.white,

        title: const Text(

          'Feedback',

          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        actions: [

          IconButton(

            onPressed:
                loadFeedback,

            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      body: loading

          ? const Center(
              child:
                  CircularProgressIndicator(),
            )

          : error != null

              ? Center(
                  child:
                      Text(error!),
                )

              : Column(

                  children: [

                    //////////////////////////////////////////////////////////
                    /// SEARCH
                    //////////////////////////////////////////////////////////

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
                              'Search feedback...',

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

                    //////////////////////////////////////////////////////////
                    /// LIST
                    //////////////////////////////////////////////////////////

                    Expanded(

                      child: filtered.isEmpty

                          ? const Center(
                              child:
                                  Text('No feedback found'),
                            )

                          : ListView.builder(

                              padding:
                                  const EdgeInsets.all(16),

                              itemCount:
                                  filtered.length,

                              itemBuilder:
                                  (context, index) {

                                return _feedbackCard(

                                  filtered[index]
                                      as Map<String, dynamic>,
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}