import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'admin_customers_screen.dart';
import 'admin_employees_screen.dart';
import 'admin_feedback_screen.dart';
import 'admin_ratings_screen.dart';
import 'admin_chats_screen.dart';
import 'admin_requests_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<int> _count(String collection) async {
    final snap = await FirebaseFirestore.instance.collection(collection).get();
    return snap.docs.length;
  }

  Future<Map<String, int>> _loadStats() async {
    final users = await _count('users');
    final publicUsers = await _count('publicUsers');
    final requests = await _count('serviceRequests');
    final feedback = await _count('feedback');
    final ratings = await _count('ratings');
    final chats = await _count('chats');

    return {
      'users': users,
      'publicUsers': publicUsers,
      'serviceRequests': requests,
      'feedback': feedback,
      'ratings': ratings,
      'chats': chats,
    };
  }

Future<void> _logout(BuildContext context) async {
  await FirebaseAuth.instance.signOut();
  await GoogleSignIn().signOut();
  Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
}
  Widget _navCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget screen,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      },
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, int value, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text('Admin'),
              accountEmail: Text(email),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.admin_panel_settings, size: 30),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Customers'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminCustomersScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.engineering),
              title: const Text('Employees'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                   builder: (_) => const AdminEmployeesScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.build),
              title: const Text('Requests'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminRequestsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.feedback),
              title: const Text('Feedback'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminFeedbackScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('Ratings'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminRatingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Chats'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminChatsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _loadStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _statCard('Users', data['users'] ?? 0, Icons.people),
                    _statCard('Public Users', data['publicUsers'] ?? 0, Icons.public),
                    _statCard('Requests', data['serviceRequests'] ?? 0, Icons.build),
                    _statCard('Feedback', data['feedback'] ?? 0, Icons.feedback),
                    _statCard('Ratings', data['ratings'] ?? 0, Icons.star),
                    _statCard('Chats', data['chats'] ?? 0, Icons.chat),
                  ],
                ),
                const SizedBox(height: 18),
                _navCard(
                  context: context,
                  title: 'Customers',
                  subtitle: 'View all customers and their profiles',
                  icon: Icons.people,
                  screen: const AdminCustomersScreen(),
                ),
                _navCard(
                  context: context,
                  title: 'Employees',
                  subtitle: 'View employees and service providers',
                  icon: Icons.engineering,
                  screen: const AdminEmployeesScreen(),
                ),
                _navCard(
                  context: context,
                  title: 'Service Requests',
                  subtitle: 'See all ongoing and completed requests',
                  icon: Icons.build,
                  screen: const AdminRequestsScreen(),
                ),
                _navCard(
                  context: context,
                  title: 'Feedback',
                  subtitle: 'Read customer complaints and comments',
                  icon: Icons.feedback,
                  screen: const AdminFeedbackScreen(),
                ),
                _navCard(
                  context: context,
                  title: 'Ratings',
                  subtitle: 'View all submitted ratings and reviews',
                  icon: Icons.star,
                  screen: const AdminRatingsScreen(),
                ),
                _navCard(
                  context: context,
                  title: 'Chats',
                  subtitle: 'Inspect chat rooms and messages',
                  icon: Icons.chat,
                  screen: const AdminChatsScreen(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}