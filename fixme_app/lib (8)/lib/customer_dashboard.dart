import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'chat_screen.dart';
import 'main.dart';
import 'map_screen.dart';
import 'session_utils.dart';
import 'settings_screen.dart';
import 'shared/models/service_request.dart';
import 'shared/services/location_tracking_service.dart';
import 'shared/services/request_service.dart';

const Color _brand = Color(0xFF01411C);
const Color _brand2 = Color(0xFF0E7A35);
const Color _panel = Color(0xFFF6F8F7);

const List<Map<String, String>> _serviceCategories = [
  {'key': 'Technician', 'emoji': '🔧'},
  {'key': 'Plumber', 'emoji': '🚰'},
  {'key': 'Electrician', 'emoji': '💡'},
  {'key': 'Carpenter', 'emoji': '🪚'},
  {'key': 'Painter', 'emoji': '🎨'},
  {'key': 'Handyman', 'emoji': '🛠️'},
  {'key': 'Cleaner', 'emoji': '🧹'},
];

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() => _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  final LocationTrackingService _locationService = LocationTrackingService();

  int _currentIndex = 0;
  Position? _position;
  bool _loadingLocation = false;
  bool _creatingRequest = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }

  String _themeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> _loadLocation() async {
    if (!mounted) return;
    setState(() => _loadingLocation = true);

    try {
      final pos = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() => _position = pos);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load location: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
    }
  }

  Future<void> _createRequest({
    required String serviceType,
    required double fare,
    String? note,
  }) async {
    if (_creatingRequest) return;

    setState(() => _creatingRequest = true);
    try {
      await RequestService.createRequest(
        serviceType: serviceType,
        fare: fare,
        lat: _position?.latitude,
        lng: _position?.longitude,
        note: note,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request created successfully')),
      );
      setState(() => _currentIndex = 1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create request: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _creatingRequest = false);
      }
    }
  }

  Future<void> _openRequestDialog([String? preset]) async {
    final fareController = TextEditingController();
    final noteController = TextEditingController();
    String selected = preset ?? _serviceCategories.first['key']!;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool submitting = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final bottom = MediaQuery.of(context).viewInsets.bottom;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(bottom: bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Book a service',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selected,
                        decoration: InputDecoration(
                          labelText: 'Service category',
                          filled: true,
                          fillColor: _panel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: _serviceCategories
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item['key'],
                                child: Text('${item['emoji']} ${item['key']}'),
                              ),
                            )
                            .toList(),
                        onChanged: submitting
                            ? null
                            : (value) {
                                if (value != null) {
                                  setStateDialog(() => selected = value);
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: fareController,
                        enabled: !submitting,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Your budget / fare offer',
                          prefixText: 'OMR ',
                          filled: true,
                          fillColor: _panel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        enabled: !submitting,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Describe the issue',
                          filled: true,
                          fillColor: _panel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: submitting
                              ? null
                              : () async {
                                  final fare = double.tryParse(fareController.text.trim());
                                  if (fare == null || fare <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Enter a valid fare amount'),
                                      ),
                                    );
                                    return;
                                  }

                                  setStateDialog(() => submitting = true);
                                  Navigator.pop(sheetContext);

                                  await _createRequest(
                                    serviceType: selected,
                                    fare: fare,
                                    note: noteController.text.trim().isEmpty
                                        ? null
                                        : noteController.text.trim(),
                                  );
                                },
                          icon: submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.local_taxi),
                          label: Text(submitting ? 'Sending...' : 'Confirm request'),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in first')),
      );
    }

    final appState = AppStateScope.of(context);

    final pages = [
      _CustomerHomeTab(
        user: user,
        position: _position,
        loadingLocation: _loadingLocation,
        onRefreshLocation: _loadLocation,
        onBookNow: _openRequestDialog,
      ),
      _CustomerRequestsTab(
        userId: user.uid,
        customerPosition: _position,
        onBookAnother: _openRequestDialog,
      ),
      const MapScreen(),
      SettingsScreen(
        isEmployee: false,
        currentTheme: _themeToString(appState.themeMode),
        currentLanguage: appState.locale.languageCode,
        onThemeChanged: (mode) async => appState.setTheme(mode),
        onLanguageChanged: (locale) async => appState.setLocale(locale),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: const Text(
          'FixMe',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loadLocation,
            icon: const Icon(Icons.my_location_outlined),
          ),
        ],
      ),
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_brand, _brand2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              accountName: Text(user.displayName ?? 'Customer'),
              accountEmail: Text(user.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  (user.displayName?.isNotEmpty == true
                          ? user.displayName![0]
                          : 'C')
                      .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _brand,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('My Requests'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Map'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 3);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('New Request'),
              onTap: () async {
                Navigator.pop(context);
                await _openRequestDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await SessionUtils.logout(context);
              },
            ),
          ],
        ),
      ),
      body: SafeArea(child: pages[_currentIndex]),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              onPressed: _creatingRequest ? null : _openRequestDialog,
              icon: _creatingRequest
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add),
              label: Text(_creatingRequest ? 'Creating...' : 'Book now'),
            )
          : null,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: NavigationBar(
            height: 72,
            backgroundColor: Colors.transparent,
            indicatorColor: _brand.withOpacity(0.12),
            selectedIndex: _currentIndex,
            onDestinationSelected: (value) => setState(() => _currentIndex = value),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Requests'),
              NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerHomeTab extends StatelessWidget {
  final User user;
  final Position? position;
  final bool loadingLocation;
  final Future<void> Function() onRefreshLocation;
  final Future<void> Function([String? preset]) onBookNow;

  const _CustomerHomeTab({
    required this.user,
    required this.position,
    required this.loadingLocation,
    required this.onRefreshLocation,
    required this.onBookNow,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefreshLocation,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_brand, _brand2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2201411C),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, ${user.displayName ?? 'Customer'} 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.email ?? '',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          loadingLocation
                              ? 'Detecting your location...'
                              : position == null
                                  ? 'Location unavailable'
                                  : 'Lat ${position!.latitude.toStringAsFixed(5)}, '
                                      'Lng ${position!.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Choose a service',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: _serviceCategories.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 104,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final item = _serviceCategories[index];
              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => onBookNow(item['key']),
                child: Ink(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x10000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Text(item['emoji']!, style: const TextStyle(fontSize: 30)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item['key']!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRefreshLocation,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh location'),
          ),
        ],
      ),
    );
  }
}

class _CustomerRequestsTab extends StatelessWidget {
  final String userId;
  final Position? customerPosition;
  final Future<void> Function([String? preset]) onBookAnother;

  const _CustomerRequestsTab({
    required this.userId,
    required this.customerPosition,
    required this.onBookAnother,
  });

  String _providerNameFrom(ServiceRequestModel req) {
    if (req.assignedWorkerName.isNotEmpty) {
      return req.assignedWorkerName;
    }
    return 'Waiting for provider';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ServiceRequestModel>>(
      stream: RequestService.customerRequestsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 56, color: Colors.black38),
                  const SizedBox(height: 12),
                  const Text(
                    'No requests yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Book your first service and nearby providers will start bidding.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => onBookAnother(),
                    icon: const Icon(Icons.add),
                    label: const Text('Book a service'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final req = requests[index];
            final providerName = _providerNameFrom(req);

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: RequestService.requestStream(req.id),
              builder: (context, reqSnap) {
                final liveReq = reqSnap.data?.data() ?? <String, dynamic>{};
                final liveStatus = (liveReq['status'] ?? req.status).toString();
                final liveProviderId =
                    (liveReq['assignedWorkerId'] ?? liveReq['employeeId'] ?? '').toString();
                final liveProviderName =
                    (liveReq['assignedWorkerName'] ?? liveReq['employeeName'] ?? providerName)
                        .toString();

                final rawFare = liveReq['agreedFare'] ?? liveReq['priceOffer'] ?? req.displayFare ?? 0;
                final shownFare = rawFare is num ? rawFare.toDouble() : 0.0;

                final canChat = liveProviderId.isNotEmpty &&
                    (liveStatus == 'accepted' ||
                        liveStatus == 'ongoing' ||
                        liveStatus == 'arriving' ||
                        liveStatus == 'completed');

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x11000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _CircleIcon(req.serviceType),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                req.serviceType,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _RequestStatusChip(status: liveStatus),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _InfoRow(label: 'Fare', value: 'OMR ${shownFare.toStringAsFixed(2)}'),
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'Provider',
                          value: liveProviderName.isEmpty
                              ? 'Waiting for provider'
                              : liveProviderName,
                        ),
                        if (req.createdAt != null) ...[
                          const SizedBox(height: 8),
                          _InfoRow(label: 'Created', value: req.createdAt!.toDate().toString()),
                        ],
                        if (liveProviderId.isNotEmpty &&
                            (liveStatus == 'accepted' ||
                                liveStatus == 'ongoing' ||
                                liveStatus == 'arriving')) ...[
                          const SizedBox(height: 14),
                          _LiveTrackingPanel(
                            requestId: req.id,
                            providerId: liveProviderId,
                            customerPosition: customerPosition,
                          ),
                        ],
                        if (liveStatus == 'bidding') ...[
                          const SizedBox(height: 14),
                          _OffersSection(
                            requestId: req.id,
                            requestStatus: liveStatus,
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (canChat)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _brand,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        chatId: '${req.id}-$liveProviderId',
                                        otherUserId: liveProviderId,
                                        title: liveProviderName,
                                        requestId: req.id,
                                        iAmCustomer: true,
                                        providerId: liveProviderId,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Chat'),
                              ),
                            if (liveProviderId.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () {
                                 Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => MapScreen(
      requestId: req.id,
      providerId: liveProviderId,
      customerLat: customerPosition?.latitude,
      customerLng: customerPosition?.longitude,
    ),
  ),
);
                                },
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Open map'),
                              ),
                            if (liveStatus == 'bidding' ||
                                liveStatus == 'pending' ||
                                liveStatus == 'searching')
                              OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    await RequestService.cancelRequest(req.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Request cancelled')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancel'),
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
        );
      },
    );
  }
}


class _OffersSection extends StatelessWidget {
  final String requestId;
  final String requestStatus;

  const _OffersSection({
    required this.requestId,
    required this.requestStatus,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RequestService.offersStream(requestId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Failed to load offers: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final offers = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final status = (data['status'] ?? 'pending').toString();
          return status == 'pending' || status == 'accepted';
        }).toList();

        if (offers.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text('Looking for nearby providers...'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nearby provider offers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ...offers.map((doc) {
              final data = doc.data();
              final employeeId = doc.id;
              final employeeName =
                  (data['employeeName'] ?? data['providerName'] ?? 'Provider').toString();
              final proposedFare = (data['proposedFare'] as num?)?.toDouble() ?? 0;
              final eta = data['etaMinutes'];
              final distance = data['distanceKm'];
              final status = (data['status'] ?? 'pending').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0x1401411C),
                      child: Icon(Icons.person, color: _brand),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employeeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'OMR ${proposedFare.toStringAsFixed(2)}'
                            '${eta != null ? ' • ETA $eta min' : ''}'
                            '${distance != null ? ' • ${distance.toString()} km' : ''}'
                            '${status == 'accepted' ? ' • accepted' : ''}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    if (requestStatus == 'bidding')
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          try {
                            await RequestService.acceptOffer(
                              requestId: requestId,
                              employeeId: employeeId,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Offer accepted')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        },
                        child: const Text('Accept'),
                      ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _LiveTrackingPanel extends StatelessWidget {
  final String requestId;
  final String providerId;
  final Position? customerPosition;

  const _LiveTrackingPanel({
    required this.requestId,
    required this.providerId,
    required this.customerPosition,
  });

  Stream<DocumentSnapshot<Map<String, dynamic>>> _providerStream() {
    final db = FirebaseFirestore.instance;

    return db.collection('users').doc(providerId).snapshots();
  }

  double? _readLat(Map<String, dynamic> data) {
    final liveLocation = data['liveLocation'];
    if (liveLocation is GeoPoint) return liveLocation.latitude;
    if (liveLocation is Map<String, dynamic>) {
      final lat = liveLocation['lat'] ?? liveLocation['latitude'];
      if (lat is num) return lat.toDouble();
    }
    final lat = data['lat'] ?? data['latitude'];
    if (lat is num) return lat.toDouble();
    return null;
  }

  double? _readLng(Map<String, dynamic> data) {
    final liveLocation = data['liveLocation'];
    if (liveLocation is GeoPoint) return liveLocation.longitude;
    if (liveLocation is Map<String, dynamic>) {
      final lng = liveLocation['lng'] ?? liveLocation['longitude'];
      if (lng is num) return lng.toDouble();
    }
    final lng = data['lng'] ?? data['longitude'];
    if (lng is num) return lng.toDouble();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _providerStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _trackingShell(
            child: const Text('Waiting for provider live location...'),
          );
        }

        final data = snapshot.data!.data() ?? <String, dynamic>{};
        final lat = _readLat(data);
        final lng = _readLng(data);

        if (lat == null || lng == null) {
          return _trackingShell(
            child: const Text('Provider location is not available yet.'),
          );
        }

        final customerLat = customerPosition?.latitude;
        final customerLng = customerPosition?.longitude;

        double? km;
        int? eta;
        if (customerLat != null && customerLng != null) {
          km = Geolocator.distanceBetween(customerLat, customerLng, lat, lng) / 1000.0;
          eta = math.max(1, ((km / 0.45) * 1).round());
        }

        return _trackingShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.route, color: _brand),
                  SizedBox(width: 8),
                  Text(
                    'Live tracking',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (km != null)
                _metricRow(
                  icon: Icons.near_me_outlined,
                  label: 'Distance',
                  value: '${km.toStringAsFixed(2)} km away',
                ),
              if (eta != null)
                _metricRow(
                  icon: Icons.schedule,
                  label: 'ETA',
                  value: '$eta min',
                ),
              _metricRow(
                icon: Icons.place_outlined,
                label: 'Provider location',
                value: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
              ),
              const SizedBox(height: 10),
              const Text(
                'This panel updates automatically from Firestore in real time.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _trackingShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5FBF7), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _brand.withOpacity(0.10)),
      ),
      child: child,
    );
  }

  Widget _metricRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _brand),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _RequestStatusChip extends StatelessWidget {
  final String status;

  const _RequestStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.blueGrey;

    switch (status.toLowerCase()) {
      case 'accepted':
      case 'ongoing':
      case 'arriving':
        color = Colors.green;
        break;
      case 'pending':
      case 'bidding':
      case 'searching':
        color = Colors.orange;
        break;
      case 'cancelled':
      case 'rejected':
        color = Colors.red;
        break;
      case 'completed':
        color = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final String label;

  const _CircleIcon(this.label);

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.build_circle_outlined;

    switch (label.toLowerCase()) {
      case 'plumber':
        icon = Icons.plumbing_outlined;
        break;
      case 'electrician':
        icon = Icons.electrical_services_outlined;
        break;
      case 'cleaner':
        icon = Icons.cleaning_services_outlined;
        break;
      case 'painter':
        icon = Icons.format_paint_outlined;
        break;
      case 'carpenter':
        icon = Icons.handyman_outlined;
        break;
      default:
        icon = Icons.build_circle_outlined;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _brand.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: _brand),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }
}
