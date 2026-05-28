import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'active_job_tab.dart';
import 'dashboard_home_tab.dart';
import 'employee_requets_tab.dart';
import 'main.dart';
import 'map_tab.dart';
import 'session_utils.dart';
import 'settings_screen.dart';
import 'shared/models/service_request.dart';
import 'shared/services/location_tracking_service.dart';
import 'shared/services/request_service.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({
    super.key,
  });

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<MapTabState> _mapTabKey = GlobalKey<MapTabState>();

  late final LocationTrackingService _trackingService;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ratingsSub;

  int _selectedIndex = 0;

  double _rating = 0;
  int _reviews = 0;
  double _earnings = 0;
  int _completedJobs = 0;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();

    _trackingService = LocationTrackingService();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _trackingService.startTracking(
        role: 'employee',
      );

      _loadStats();

      _ratingsSub = FirebaseFirestore.instance
          .collection('ratings')
          .where(
            'employeeId',
            isEqualTo: user.uid,
          )
          .snapshots()
          .listen(
        (snapshot) {
          debugPrint(
            'RATINGS CHANGED: ${snapshot.docs.length}',
          );

          if (mounted) {
            _loadStats();
          }
        },
        onError: (error) {
          debugPrint(
            'Ratings listener error: $error',
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _ratingsSub?.cancel();
    _trackingService.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final uid = _user?.uid;

    debugPrint(
      'CURRENT EMPLOYEE UID: $uid',
    );

    if (uid == null) return;

    try {
      final jobsSnap = await FirebaseFirestore.instance
          .collection('serviceRequests')
          .where(
            'employeeId',
            isEqualTo: uid,
          )
          .where(
            'status',
            isEqualTo: 'completed',
          )
          .get();

      if (!mounted) return;

      double totalEarnings = 0;

      for (final doc in jobsSnap.docs) {
        final data = doc.data();
        final fare = data['fare'];

        if (fare is num) {
          totalEarnings += fare.toDouble();
        }
      }

////////////////////////////////////////////////////////////
/// LOAD RATINGS COLLECTION
////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////
/// CALCULATE REVIEWS + RATINGS
////////////////////////////////////////////////////////////

double totalRating = 0;

int reviewCount = 0;

for (final doc in jobsSnap.docs) {

  final data = doc.data();

  //////////////////////////////////////////////////////////
  /// CUSTOMER RATING
  //////////////////////////////////////////////////////////

  final rating =
      data['customerRating'];

  //////////////////////////////////////////////////////////
  /// COUNT ONLY RATED JOBS
  //////////////////////////////////////////////////////////

  if (rating is num) {

    totalRating += rating.toDouble();

    reviewCount++;
  }
}

////////////////////////////////////////////////////////////
/// AVERAGE RATING
////////////////////////////////////////////////////////////

final avgRating =

    reviewCount > 0

        ? totalRating / reviewCount

        : 0.0;

////////////////////////////////////////////////////////////
/// SAVE STATS TO FIRESTORE
////////////////////////////////////////////////////////////

await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .set({

      //////////////////////////////////////////////////////
      /// STATS
      //////////////////////////////////////////////////////

      'totalEarnings': totalEarnings,

      'totalJobs': jobsSnap.docs.length,

      'totalReviews': reviewCount,

      'rating': avgRating,

    }, SetOptions(merge: true));

debugPrint(
  "ADMIN STATS SAVED",
);

////////////////////////////////////////////////////////////
/// UPDATE UI
////////////////////////////////////////////////////////////

setState(() {

  _earnings = totalEarnings;

  _completedJobs = jobsSnap.docs.length;

  _reviews = reviewCount;

  _rating = avgRating;
});
    } catch (e) {
      debugPrint(
        'Stats Error: $e',
      );
    }
  }

  void _goToTab(int index) {
    if (!mounted) return;

    setState(() {
      _selectedIndex = index;
    });
  }

  void _recenterMap() {
    _goToTab(1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapTabKey.currentState?.centerToEmployee();
    });
  }

  void _openProfile() {
    final appState = AppStateScope.read(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          isEmployee: true,
          currentTheme: appState.themeMode.name,
          currentLanguage: appState.locale.languageCode,
          onLanguageChanged: (locale) async {
            await appState.setLocale(locale);
          },
        ),
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final selected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      child: Material(
        color: selected
            ? const Color(0xFF2563EB).withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          leading: Icon(
            icon,
            color: selected
                ? const Color(0xFF2563EB)
                : Colors.grey[700],
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.w500,
              color: selected
                  ? const Color(0xFF2563EB)
                  : Colors.black87,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            _goToTab(index);
          },
        ),
      ),
    );
  }

  Widget _loggedOutRedirect() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (_) => false,
      );
    });

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

if (user == null) {
  return _loggedOutRedirect();
}

////////////////////////////////////////////////////////////
/// ACCOUNT SUSPENSION CHECK
////////////////////////////////////////////////////////////

return FutureBuilder<DocumentSnapshot>(
  future: FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get(),
  builder: (context, userSnapshot) {

    ////////////////////////////////////////////////////////
    /// LOADING
    ////////////////////////////////////////////////////////

    if (userSnapshot.connectionState ==
        ConnectionState.waiting) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    ////////////////////////////////////////////////////////
    /// USER DATA
    ////////////////////////////////////////////////////////

    final userData =
        userSnapshot.data?.data()
            as Map<String, dynamic>?;

    final bool isSuspended =
        userData?['suspended'] == true;

    ////////////////////////////////////////////////////////
    /// SUSPENDED ACCOUNT
    ////////////////////////////////////////////////////////

    if (isSuspended) {

      Future.microtask(() async {

        await FirebaseAuth.instance
            .signOut();
      });

      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Your account has been suspended',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<List<ServiceRequestModel>>(
      stream: RequestService.providerJobsStream(
        user.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error: ${snapshot.error}',
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final jobs =
            snapshot.data ?? const <ServiceRequestModel>[];

        final activeJobs = jobs.where((j) {
          return j.isAccepted || j.isOngoing;
        }).length;

        final appState = AppStateScope.of(context);

        final pages = <Widget>[
          DashboardHomeTab(
            onRecenterMap: _recenterMap,
            onProfile: _openProfile,
            activeJobs: activeJobs,
            completedJobs: _completedJobs,
            earnings: _earnings,
            rating: _rating,
            reviews: _reviews,
          ),
          MapTab(
            key: _mapTabKey,
            requestId: null,
            providerId: user.uid,
            trackLiveDriver: true,
            listenToAssignedRequest: false,
          ),
          const EmployeeRequestsTab(),
          const ActiveJobTab(),
          SettingsScreen(
            isEmployee: true,
            currentTheme: appState.themeMode.name,
            currentLanguage: appState.locale.languageCode,
            onLanguageChanged: (locale) async {
              await appState.setLocale(locale);
            },
          ),
        ];

        final safeIndex = _selectedIndex.clamp(
          0,
          pages.length - 1,
        );

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFFF5F7FB),
          drawer: Drawer(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(
                    top: 72,
                    bottom: 28,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2563EB),
                        Color(0xFF1E40AF),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: Text(
                          (user.displayName?.isNotEmpty == true
                                  ? user.displayName![0]
                                  : 'P')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user.displayName ?? 'Provider',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.email ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    children: [
                      _drawerTile(
                        icon: Icons.home_rounded,
                        title: 'Home',
                        index: 0,
                      ),
                      _drawerTile(
                        icon: Icons.map_rounded,
                        title: 'Map',
                        index: 1,
                      ),
                      _drawerTile(
                        icon: Icons.list_alt_rounded,
                        title: 'Requests',
                        index: 2,
                      ),
                      _drawerTile(
                        icon: Icons.work_rounded,
                        title: 'Active Jobs',
                        index: 3,
                      ),
                      _drawerTile(
                        icon: Icons.settings_rounded,
                        title: 'Settings',
                        index: 4,
                      ),
                      const Divider(height: 32),
                      ListTile(
                        leading: const Icon(
                          Icons.logout_rounded,
                          color: Colors.red,
                        ),
                        title: const Text('Logout'),
                        onTap: () async {
                          Navigator.pop(context);
                          await SessionUtils.logout(context);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF2563EB),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            child: const Icon(Icons.menu_rounded),
          ),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(safeIndex),
                child: pages[safeIndex],
              ),
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              0,
              14,
              14,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: NavigationBar(
                height: 74,
                selectedIndex: safeIndex,
                onDestinationSelected: _goToTab,
                backgroundColor: Colors.white,
                indicatorColor:
                    const Color(0xFF2563EB).withOpacity(0.12),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.map_outlined),
                    selectedIcon: Icon(Icons.map),
                    label: 'Map',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.list_alt_outlined),
                    selectedIcon: Icon(Icons.list_alt),
                    label: 'Requests',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.work_outline),
                    selectedIcon: Icon(Icons.work),
                    label: 'Jobs',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  },
);
  }
}
