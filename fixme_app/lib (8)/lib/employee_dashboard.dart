import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'active_job_tab.dart';
import 'dashboard_home_tab.dart';
import 'main.dart';
import 'map_tab.dart';
import 'request_tab.dart';
import 'session_utils.dart';
import 'settings_screen.dart';
import 'shared/models/service_request.dart';
import 'shared/services/location_tracking_service.dart';
import 'shared/services/request_service.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  final GlobalKey<MapTabState> _mapTabKey = GlobalKey<MapTabState>();
  final LocationTrackingService _locationService = LocationTrackingService();

  int _selectedIndex = 0;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _locationService.startPublishing(role: 'employee');
  }

  @override
  void dispose() {
    RequestService.setProviderOnline(false);
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _onToggleOnline() async {
    final newStatus = !_isOnline;
    setState(() => _isOnline = newStatus);

    try {
      await RequestService.setProviderOnline(newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'You are ONLINE' : 'You are OFFLINE'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOnline = !newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  void _onRecenterMap() {
    _mapTabKey.currentState?.centerToEmployee();
  }

  void _openProfile() {
    final appState = AppStateScope.read(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          isEmployee: true,
          currentTheme: _themeModeToString(appState.themeMode),
          currentLanguage: appState.locale.languageCode,
          onThemeChanged: (mode) async {
            await appState.setTheme(mode);
          },
          onLanguageChanged: (locale) async {
            await appState.setLocale(locale);
          },
        ),
      ),
    );
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final appState = AppStateScope.of(context);

    return StreamBuilder<List<ServiceRequestModel>>(
      stream: RequestService.providerJobsStream(user?.uid ?? ''),
      builder: (context, snapshot) {
        final jobs = snapshot.data ?? const <ServiceRequestModel>[];

        final activeJobs = jobs
            .where((j) => j.status == 'accepted' || j.status == 'ongoing')
            .length;

        final completedJobs =
            jobs.where((j) => j.status == 'completed').length;

        final earnings =
            jobs.fold<double>(0, (sum, item) => sum + (item.displayFare ?? 0));

        final pages = <Widget>[
          DashboardHomeTab(
            onRecenterMap: _onRecenterMap,
            onProfile: _openProfile,
            onToggleOnline: _onToggleOnline,
            activeJobs: activeJobs,
            completedJobs: completedJobs,
            earnings: earnings,
            isOnline: _isOnline,
          ),
          MapTab(
            key: _mapTabKey,
            requestId: null,
          ),
          EmployeeRequestsTab(mapTabKey: _mapTabKey),
          ActiveJobTab(mapTabKey: _mapTabKey),
          SettingsScreen(
            isEmployee: true,
            currentTheme: _themeModeToString(appState.themeMode),
            currentLanguage: appState.locale.languageCode,
            onThemeChanged: (mode) async {
              await appState.setTheme(mode);
            },
            onLanguageChanged: (locale) async {
              await appState.setLocale(locale);
            },
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Employee Dashboard'),
            actions: [
              IconButton(
                icon: Icon(_isOnline ? Icons.toggle_on : Icons.toggle_off),
                onPressed: _onToggleOnline,
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _openProfile,
              ),
            ],
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(user?.displayName ?? 'No Name'),
                  accountEmail: Text(user?.email ?? ''),
                  currentAccountPicture: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Dashboard'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 0);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.map),
                  title: const Text('Map'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 1);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: const Text('Requests'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.work),
                  title: const Text('Active Job'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 3);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 4);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () async {
                    Navigator.pop(context);
                    await SessionUtils.logout(context);
                  },
                ),
              ],
            ),
          ),
          body: pages[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            type: BottomNavigationBarType.fixed,
            onTap: (index) => setState(() => _selectedIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt),
                label: 'Requests',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.work),
                label: 'Job',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}