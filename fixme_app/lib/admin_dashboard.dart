import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'admin_chats_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_employees_screen.dart';
import 'admin_feedback_screen.dart';
import 'admin_ratings_screen.dart';
import 'admin_requests_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends State<AdminDashboardScreen> {

      static const String baseUrl =
    'https://GMAC121.pythonanywhere.com';

  ////////////////////////////////////////////////////////////
  /// LOAD COUNTS
  ////////////////////////////////////////////////////////////

  Future<int> _count(
    String collection,
  ) async {

    final snap =
        await FirebaseFirestore.instance
            .collection(collection)
            .get();

    return snap.docs.length;
  }

  Future<Map<String, int>> _loadStats() async {

    final users =
        await _count('users');

    final publicUsers =
        await _count('publicUsers');

    final requests =
        await _count('serviceRequests');

final feedback =
    await _feedbackCount();

    final ratings =
        await _count('ratings');

    final chats =
        await _count('chats');

    return {

      'users': users,

      'publicUsers': publicUsers,

      'requests': requests,

      'feedback': feedback,

      'ratings': ratings,

      'chats': chats,
    };
  }

  Future<int> _feedbackCount() async {

  try {

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return 0;
    }

    final token =
        await user.getIdToken();

    final response =
        await http.get(

      Uri.parse(
        '$baseUrl/api/admin/feedback',
      ),

      headers: {

        'Authorization':
            'Bearer $token',
      },
    );

    if (response.statusCode == 200) {

      final data =
          jsonDecode(response.body);

      final items =
          data['items'] as List?;

      return items?.length ?? 0;
    }

    debugPrint(
      'Feedback API Error: ${response.body}',
    );

    return 0;

  } catch (e) {

    debugPrint(
      'Feedback Count Error: $e',
    );

    return 0;
  }
}

  ////////////////////////////////////////////////////////////
  /// LOGOUT
  ////////////////////////////////////////////////////////////

  Future<void> _logout() async {

    await FirebaseAuth.instance
        .signOut();

    await GoogleSignIn()
        .signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(

      context,

      '/home',

      (route) => false,
    );
  }

  ////////////////////////////////////////////////////////////
  /// COLORS
  ////////////////////////////////////////////////////////////

  final List<List<Color>> gradients = [

    [
      const Color(0xFF2563EB),
      const Color(0xFF1D4ED8),
    ],

    [
      const Color(0xFF10B981),
      const Color(0xFF059669),
    ],

    [
      const Color(0xFFF59E0B),
      const Color(0xFFD97706),
    ],

    [
      const Color(0xFF8B5CF6),
      const Color(0xFF7C3AED),
    ],

    [
      const Color(0xFFEF4444),
      const Color(0xFFDC2626),
    ],

    [
      const Color(0xFF06B6D4),
      const Color(0xFF0891B2),
    ],
  ];

  ////////////////////////////////////////////////////////////
  /// STAT CARD
  ////////////////////////////////////////////////////////////

  Widget _statCard({

    required String title,

    required int value,

    required IconData icon,

    required List<Color> colors,
  }) {

    return Container(

      decoration: BoxDecoration(

        gradient:
            LinearGradient(
          colors: colors,
        ),

        borderRadius:
            BorderRadius.circular(28),

        boxShadow: [

          BoxShadow(

            color:
                colors.first
                    .withOpacity(0.25),

            blurRadius: 18,

            offset:
                const Offset(0, 8),
          ),
        ],
      ),

      child: Padding(

        padding:
            const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            //////////////////////////////////////////////////////
            /// ICON
            //////////////////////////////////////////////////////

            Container(

              width: 54,
              height: 54,

              decoration: BoxDecoration(

                color:
                    Colors.white
                        .withOpacity(0.18),

                borderRadius:
                    BorderRadius.circular(18),
              ),

              child: Icon(

                icon,

                color: Colors.white,

                size: 30,
              ),
            ),

            const Spacer(),

            //////////////////////////////////////////////////////
            /// VALUE
            //////////////////////////////////////////////////////

            Text(

              value.toString(),

              style:
                  const TextStyle(

                color: Colors.white,

                fontSize: 30,

                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            //////////////////////////////////////////////////////
            /// TITLE
            //////////////////////////////////////////////////////

            Text(

              title,

              style:
                  TextStyle(

                color:
                    Colors.white
                        .withOpacity(0.92),

                fontWeight:
                    FontWeight.w600,

                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// NAVIGATION CARD
  ////////////////////////////////////////////////////////////

  Widget _navCard({

    required String title,

    required String subtitle,

    required IconData icon,

    required List<Color> colors,

    required Widget screen,
  }) {

    return GestureDetector(

      onTap: () {

        Navigator.push(

          context,

          MaterialPageRoute(

            builder: (_) => screen,
          ),
        );
      },

      child: Container(

        margin:
            const EdgeInsets.only(
          bottom: 18,
        ),

        decoration: BoxDecoration(

          gradient:
              LinearGradient(
            colors: colors,
          ),

          borderRadius:
              BorderRadius.circular(30),

          boxShadow: [

            BoxShadow(

              color:
                  colors.first
                      .withOpacity(0.30),

              blurRadius: 18,

              offset:
                  const Offset(0, 8),
            ),
          ],
        ),

        child: Padding(

          padding:
              const EdgeInsets.all(20),

          child: Row(

            children: [

              ////////////////////////////////////////////////////
              /// ICON
              ////////////////////////////////////////////////////

              Container(

                width: 72,
                height: 72,

                decoration: BoxDecoration(

                  color:
                      Colors.white
                          .withOpacity(0.16),

                  borderRadius:
                      BorderRadius.circular(24),
                ),

                child: Icon(

                  icon,

                  color: Colors.white,

                  size: 36,
                ),
              ),

              const SizedBox(width: 18),

              ////////////////////////////////////////////////////
              /// TEXT
              ////////////////////////////////////////////////////

              Expanded(

                child: Column(

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(

                      title,

                      style:
                          const TextStyle(

                        color: Colors.white,

                        fontSize: 20,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(

                      subtitle,

                      style:
                          TextStyle(

                        color:
                            Colors.white
                                .withOpacity(0.90),

                        height: 1.4,

                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              ////////////////////////////////////////////////////
              /// ARROW
              ////////////////////////////////////////////////////

              const Icon(

                Icons.arrow_forward_ios_rounded,

                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// DRAWER TILE
  ////////////////////////////////////////////////////////////

  Widget _drawerTile({

    required IconData icon,

    required String title,

    required VoidCallback onTap,

    Color color = Colors.white,
  }) {

    return ListTile(

      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(18),
      ),

      leading: Icon(
        icon,
        color: color,
      ),

      title: Text(

        title,

        style:
            TextStyle(

          color: color,

          fontWeight:
              FontWeight.w600,
        ),
      ),

      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {

    final email =
        FirebaseAuth.instance.currentUser?.email ??
            '';

    return Scaffold(

      backgroundColor:
          const Color(0xFFF4F7FC),

      //////////////////////////////////////////////////////////
      /// DRAWER
      //////////////////////////////////////////////////////////

      drawer: Drawer(

        backgroundColor:
            const Color(0xFF111827),

        child: Column(

          children: [

            //////////////////////////////////////////////////////
            /// HEADER
            //////////////////////////////////////////////////////

            Container(

              width: double.infinity,

              padding:
                  const EdgeInsets.only(

                top: 70,

                left: 24,

                right: 24,

                bottom: 30,
              ),

              decoration: const BoxDecoration(

                gradient:
                    LinearGradient(

                  colors: [

                    Color(0xFF2563EB),

                    Color(0xFF1E40AF),
                  ],
                ),
              ),

              child: Column(

                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Container(

                    width: 86,
                    height: 86,

                    decoration: BoxDecoration(

                      color:
                          Colors.white
                              .withOpacity(0.15),

                      borderRadius:
                          BorderRadius.circular(28),
                    ),

                    child: const Icon(

                      Icons.admin_panel_settings_rounded,

                      color: Colors.white,

                      size: 48,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(

                    'Admin Dashboard',

                    style:
                        TextStyle(

                      color: Colors.white,

                      fontSize: 26,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(

                    email,

                    style:
                        TextStyle(

                      color:
                          Colors.white
                              .withOpacity(0.92),
                    ),
                  ),
                ],
              ),
            ),

            //////////////////////////////////////////////////////
            /// MENU
            //////////////////////////////////////////////////////

            Expanded(

              child: ListView(

                padding:
                    const EdgeInsets.all(14),

                children: [

                  _drawerTile(

                    icon:
                        Icons.people_alt_rounded,

                    title:
                        'Customers',

                    onTap: () {

                      Navigator.push(

                        context,

                        MaterialPageRoute(

                          builder: (_) =>
                              const AdminCustomersScreen(),
                        ),
                      );
                    },
                  ),

                  _drawerTile(

                    icon:
                        Icons.engineering_rounded,

                    title:
                        'Employees',

                    onTap: () {

                      Navigator.push(

                        context,

                        MaterialPageRoute(

                          builder: (_) =>
                              const AdminEmployeesScreen(),
                        ),
                      );
                    },
                  ),

                  _drawerTile(

                    icon:
                        Icons.build_circle_rounded,

                    title:
                        'Requests',

                    onTap: () {

                      Navigator.push(

                        context,

                        MaterialPageRoute(

                          builder: (_) =>
                              const AdminRequestsScreen(),
                        ),
                      );
                    },
                  ),

                  _drawerTile(

                    icon:
                        Icons.feedback_rounded,

                    title:
                        'Feedback',

                    onTap: () {

                      Navigator.push(

                        context,

                        MaterialPageRoute(

                          builder: (_) =>
                              const AdminFeedbackScreen(),
                        ),
                      );
                    },
                  ),

                  _drawerTile(

                    icon:
                        Icons.star_rounded,

                    title:
                        'Ratings',

                    onTap: () {

                      Navigator.push(

                        context,

                        MaterialPageRoute(

                          builder: (_) =>
                              const AdminRatingsScreen(),
                        ),
                      );
                    },
                  ),

                  _drawerTile(

                    icon:
                        Icons.chat_rounded,

                    title:
                        'Chats',

                    onTap: () {

                      Navigator.push(

                        context,

                        MaterialPageRoute(

                          builder: (_) =>
                              const AdminChatsScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  _drawerTile(

                    icon:
                        Icons.logout_rounded,

                    title:
                        'Logout',

                    color: Colors.red,

                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      //////////////////////////////////////////////////////////
      /// BODY
      //////////////////////////////////////////////////////////

      body: FutureBuilder<Map<String, int>>(

        future:
            _loadStats(),

        builder: (
          context,
          snapshot,
        ) {

          //////////////////////////////////////////////////////
          /// LOADING
          //////////////////////////////////////////////////////

          if (snapshot.connectionState ==
              ConnectionState.waiting) {

            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          //////////////////////////////////////////////////////
          /// ERROR
          //////////////////////////////////////////////////////

          if (snapshot.hasError) {

            return Center(

              child: Text(
                'Error: ${snapshot.error}',
              ),
            );
          }

          final data =
              snapshot.data ?? {};

          //////////////////////////////////////////////////////
          /// MAIN UI
          //////////////////////////////////////////////////////

          return CustomScrollView(

            slivers: [

              ////////////////////////////////////////////////////
              /// APP BAR
              ////////////////////////////////////////////////////

              SliverAppBar(

                expandedHeight: 320,

                pinned: true,

                elevation: 0,

                backgroundColor:
                    const Color(0xFF2563EB),

                leading: Builder(

                  builder: (context) {

                    return IconButton(

                      onPressed: () {

                        Scaffold.of(context)
                            .openDrawer();
                      },

                      icon: const Icon(
                        Icons.menu_rounded,
                        color: Colors.white,
                      ),
                    );
                  },
                ),

                actions: [

                  IconButton(

                    onPressed: _logout,

                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],

                flexibleSpace:
                    FlexibleSpaceBar(

                  background: Container(

                    decoration: const BoxDecoration(

                      gradient:
                          LinearGradient(

                        begin:
                            Alignment.topLeft,

                        end:
                            Alignment.bottomRight,

                        colors: [

                          Color(0xFF2563EB),

                          Color(0xFF1E3A8A),
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

                            //////////////////////////////////////////////////
                            /// ICON
                            //////////////////////////////////////////////////

                            Container(

                              width: 96,
                              height: 96,

                              decoration: BoxDecoration(

                                color:
                                    Colors.white
                                        .withOpacity(0.16),

                                borderRadius:
                                    BorderRadius.circular(30),
                              ),

                              child: const Icon(

                                Icons.admin_panel_settings_rounded,

                                color: Colors.white,

                                size: 52,
                              ),
                            ),

                            const SizedBox(height: 24),

                            //////////////////////////////////////////////////
                            /// TITLE
                            //////////////////////////////////////////////////

                            const Text(

                              'Admin Dashboard',

                              style:
                                  TextStyle(

                                color: Colors.white,

                                fontSize: 34,

                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 10),

                            //////////////////////////////////////////////////
                            /// SUBTITLE
                            //////////////////////////////////////////////////

                            Text(

                              'Manage users, service requests, feedback, ratings and chats.',

                              style:
                                  TextStyle(

                                color:
                                    Colors.white
                                        .withOpacity(0.92),

                                height: 1.4,

                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              ////////////////////////////////////////////////////
              /// CONTENT
              ////////////////////////////////////////////////////

              SliverToBoxAdapter(

                child: Padding(

                  padding:
                      const EdgeInsets.all(18),

                  child: Column(

                    children: [

                      //////////////////////////////////////////////////////
                      /// STATS GRID
                      //////////////////////////////////////////////////////

                      GridView.count(

                        crossAxisCount: 2,

                        crossAxisSpacing: 16,

                        mainAxisSpacing: 16,

                        shrinkWrap: true,

                        physics:
                            const NeverScrollableScrollPhysics(),

                        childAspectRatio:
                            1.03,

                        children: [

                          _statCard(

                            title:
                                'Users',

                            value:
                                data['users'] ?? 0,

                            icon:
                                Icons.people_alt_rounded,

                            colors:
                                gradients[0],
                          ),

                          _statCard(

                            title:
                                'Public Users',

                            value:
                                data['publicUsers'] ?? 0,

                            icon:
                                Icons.public_rounded,

                            colors:
                                gradients[1],
                          ),

                          _statCard(

                            title:
                                'Requests',

                            value:
                                data['requests'] ?? 0,

                            icon:
                                Icons.build_circle_rounded,

                            colors:
                                gradients[2],
                          ),

                          _statCard(

                            title:
                                'Feedback',

                            value:
                                data['feedback'] ?? 0,

                            icon:
                                Icons.feedback_rounded,

                            colors:
                                gradients[3],
                          ),

                          _statCard(

                            title:
                                'Ratings',

                            value:
                                data['ratings'] ?? 0,

                            icon:
                                Icons.star_rounded,

                            colors:
                                gradients[4],
                          ),

                          _statCard(

                            title:
                                'Chats',

                            value:
                                data['chats'] ?? 0,

                            icon:
                                Icons.chat_rounded,

                            colors:
                                gradients[5],
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      //////////////////////////////////////////////////////
                      /// NAVIGATION CARDS
                      //////////////////////////////////////////////////////

                      _navCard(

                        title:
                            'Customers',

                        subtitle:
                            'Manage all registered customers and profiles.',

                        icon:
                            Icons.people_alt_rounded,

                        colors:
                            gradients[0],

                        screen:
                             AdminCustomersScreen(),
                      ),

                      _navCard(

                        title:
                            'Employees',

                        subtitle:
                            'Manage service providers and technicians.',

                        icon:
                            Icons.engineering_rounded,

                        colors:
                            gradients[1],

                        screen:
                            const AdminEmployeesScreen(),
                      ),

                      _navCard(

                        title:
                            'Requests',

                        subtitle:
                            'Monitor ongoing and completed service jobs.',

                        icon:
                            Icons.build_circle_rounded,

                        colors:
                            gradients[2],

                        screen:
                            const AdminRequestsScreen(),
                      ),

                      _navCard(

                        title:
                            'Feedback',

                        subtitle:
                            'Review customer comments and reports.',

                        icon:
                            Icons.feedback_rounded,

                        colors:
                            gradients[3],

                        screen:
                            const AdminFeedbackScreen(),
                      ),

                      _navCard(

                        title:
                            'Ratings',

                        subtitle:
                            'Inspect ratings and reviews from users.',

                        icon:
                            Icons.star_rounded,

                        colors:
                            gradients[4],

                        screen:
                            const AdminRatingsScreen(),
                      ),

                      _navCard(

                        title:
                            'Chats',

                        subtitle:
                            'Inspect customer and employee conversations.',

                        icon:
                            Icons.chat_rounded,

                        colors:
                            gradients[5],

                        screen:
                            const AdminChatsScreen(),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}