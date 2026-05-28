import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'chat_screen.dart';
import 'main.dart';
import 'map_screen.dart';
import 'session_utils.dart';
import 'settings_screen.dart';

import 'shared/models/service_request.dart';
import 'shared/services/chat_service.dart';
import 'shared/services/location_tracking_service.dart';
import 'shared/services/request_service.dart';

const List<Map<String, String>> kServiceCategories = [
  {'key': 'Technician', 'emoji': '🔧'},
  {'key': 'Plumber', 'emoji': '🚰'},
  {'key': 'Electrician', 'emoji': '💡'},
  {'key': 'Carpenter', 'emoji': '🪚'},
  {'key': 'Painter', 'emoji': '🎨'},
  {'key': 'Handyman', 'emoji': '🛠️'},
  {'key': 'Cleaner', 'emoji': '🧹'},
];

const Color kBrand = Color(0xFF01411C);
const String apiBaseUrl =
    "http://192.168.100.15:5000";


class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});
  Future<Map<String, dynamic>?> loadProvider(
  String providerId,
) async {

  try {

    final response = await http.get(
      Uri.parse(
        "$apiBaseUrl/api/provider/$providerId",
      ),
    );

    if (response.statusCode == 200) {

      return jsonDecode(response.body);
    }

  } catch (e) {

    debugPrint(
      "Provider Load Error: $e",
    );
  }

  return null;
}

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
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

  void _showSnack(String text, {bool error = false}) {
    if (!mounted) return;

    final scheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? scheme.error : null,
        ),
      );
  }

  Future<void> _loadLocation() async {
    if (!mounted) return;

    setState(() => _loadingLocation = true);

    try {
      final pos = await _locationService.getCurrentPosition();

      if (!mounted) return;

      setState(() => _position = pos);
    } catch (e) {
      _showSnack('Failed to load location: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
    }
  }



  Future<void> _createRequest({
    required String serviceType,
    required double priceOffer,
    String? note,
  }) async {
    if (_creatingRequest) return;

    if (_position == null) {
      _showSnack(
        'Location not available yet. Please refresh location first.',
        error: true,
      );
      return;
    }

    setState(() => _creatingRequest = true);

    try {
      await RequestService.createRequest(
        serviceType: serviceType,
        priceOffer: priceOffer,
        customerLat: _position!.latitude,
        customerLng: _position!.longitude,
        note: note ?? '',
      );

      if (!mounted) return;

      _showSnack('Request created successfully');
      setState(() => _currentIndex = 1);
    } catch (e) {
      _showSnack('Failed to create request: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _creatingRequest = false);
      }
    }
  }

  Future<void> _openRequestDialog([String? preset]) async {
    if (_creatingRequest) return;

    final result = await showModalBottomSheet<_RequestSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestSheet(
        preset: preset,
        categories: kServiceCategories,
      ),
    );

    if (result == null) return;

    await _createRequest(
      serviceType: result.serviceType,
      priceOffer: result.priceOffer,
      note: result.note,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please sign in first'),
        ),
      );
    }

    final appState = AppStateScope.of(context);

    final pages = <Widget>[
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
      MapScreen(
        customerLat: _position?.latitude,
        customerLng: _position?.longitude,
      ),
      SettingsScreen(
        isEmployee: false,
        currentTheme: _themeToString(appState.themeMode),
        currentLanguage: appState.locale.languageCode,
      ),
    ];

    return Scaffold(
      backgroundColor: scheme.surface,

      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(24),
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: scheme.primary,
              ),
              accountName: Text(user.displayName ?? 'Customer'),
              accountEmail: Text(user.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: scheme.onPrimary,
                child: Text(
                  (user.displayName?.isNotEmpty == true
                          ? user.displayName![0]
                          : 'C')
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),

            _DrawerTile(
              icon: Icons.home_outlined,
              title: 'Home',
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),

            _DrawerTile(
              icon: Icons.receipt_long_outlined,
              title: 'My Requests',
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1);
              },
            ),

            _DrawerTile(
              icon: Icons.map_outlined,
              title: 'Map',
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 2);
              },
            ),

            _DrawerTile(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 3);
              },
            ),

            const Divider(),

            _DrawerTile(
              icon: Icons.add_circle_outline,
              title: 'New Request',
              onTap: () async {
                Navigator.pop(context);
                await _openRequestDialog();
              },
            ),

            _DrawerTile(
              icon: Icons.logout,
              title: 'Logout',
              iconColor: scheme.error,
              textColor: scheme.error,
              onTap: () async {
                Navigator.pop(context);
                await SessionUtils.logout(context);
              },
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),

      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _creatingRequest ? null : () => _openRequestDialog(),
              icon: _creatingRequest
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_creatingRequest ? 'Creating...' : 'Book now'),
            )
          : null,

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _RequestSheetResult {
  final String serviceType;
  final double priceOffer;
  final String? note;

  const _RequestSheetResult({
    required this.serviceType,
    required this.priceOffer,
    required this.note,
  });
}

class _RequestSheet extends StatefulWidget {
  final String? preset;
  final List<Map<String, String>> categories;

  const _RequestSheet({
    required this.preset,
    required this.categories,
  });

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  late final TextEditingController _fareController;
  late final TextEditingController _noteController;
  late String _selected;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    _fareController = TextEditingController();
    _noteController = TextEditingController();
    _selected = widget.preset ?? widget.categories.first['key']!;
  }

  @override
  void dispose() {
    _fareController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    String? prefixText,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _submit() {
    final priceOffer = double.tryParse(_fareController.text.trim());

    if (priceOffer == null || priceOffer <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Enter a valid fare amount'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    setState(() => _submitting = true);

    Navigator.of(context).pop(
      _RequestSheetResult(
        serviceType: _selected,
        priceOffer: priceOffer,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              const SizedBox(height: 14),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Book a service',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selected,
                decoration: _inputDecoration(
                  context,
                  label: 'Service category',
                ),
                items: widget.categories
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item['key'],
                        child: Text('${item['emoji']} ${item['key']}'),
                      ),
                    )
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selected = value);
                        }
                      },
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _fareController,
                enabled: !_submitting,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _inputDecoration(
                  context,
                  label: 'Your budget / fare offer',
                  prefixText: 'OMR ',
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _noteController,
                enabled: !_submitting,
                maxLines: 3,
                decoration: _inputDecoration(
                  context,
                  label: 'Describe the issue',
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.handyman_outlined),
                  label: Text(_submitting ? 'Sending...' : 'Confirm request'),
                ),
              ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: onRefreshLocation,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primary,
                  scheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withOpacity(0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, ${user.displayName ?? 'Customer'} 👋',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  user.email ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimary.withOpacity(0.85),
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.my_location, color: scheme.onPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          loadingLocation
                              ? 'Detecting your location...'
                              : position == null
                                  ? 'Location unavailable'
                                  : 'Lat ${position!.latitude.toStringAsFixed(5)}, '
                                      'Lng ${position!.longitude.toStringAsFixed(5)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Choose a service',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          GridView.builder(
            itemCount: kServiceCategories.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 112,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final item = kServiceCategories[index];

              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => onBookNow(item['key']),
                child: Ink(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withOpacity(0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Text(
                          item['emoji']!,
                          style: const TextStyle(fontSize: 30),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            item['key']!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
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

  Stream<List<ServiceRequestModel>> _allCustomerRequestsStream() {
    return FirebaseFirestore.instance
        .collection('serviceRequests')
        .where('customerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(ServiceRequestModel.fromDoc).toList(),
        );
  }

  String _providerNameFrom(ServiceRequestModel req) {
    if (req.employeeName.trim().isNotEmpty) {
      return req.employeeName;
    }

    if (req.isBidding) {
      return 'Waiting for offers';
    }

    if (req.isCancelled) {
      return 'Request cancelled';
    }

    return 'Provider';
  }

  Future<void> _openChat(
    BuildContext context, {
    required String employeeId,
    required String requestId,
    required String title,
  }) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;

    final chatId = await ChatService.ensureChat(
      customerId: me,
      employeeId: employeeId,
      requestId: requestId,
    );

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserId: employeeId,
          title: title,
          requestId: requestId,
          iAmCustomer: true,
          providerId: employeeId,
        ),
      ),
    );
  }

  void _openMap(
    BuildContext context, {
    required ServiceRequestModel req,
    required String providerId,
  }) {
    if (customerPosition == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          requestId: req.id,
          providerId: providerId,
          customerLat: customerPosition!.latitude,
          customerLng: customerPosition!.longitude,
          trackLiveDriver: true,
          listenToAssignedRequest: true,
        ),
      ),
    );
  }

  Future<void> _acceptOffer(
    BuildContext context, {
    required String requestId,
    required String employeeId,
  }) async {
    try {
      await RequestService.acceptOffer(
        requestId: requestId,
        employeeId: employeeId,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Provider accepted successfully'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept offer: $e'),
        ),
      );
    }
  }

  Future<void> _cancelRequest(
    BuildContext context,
    String requestId,
  ) async {
    try {
      await RequestService.cancelRequest(requestId);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request cancelled'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel request: $e'),
        ),
      );
    }
  }

  Future<void> _rateProvider(
    BuildContext context,
    ServiceRequestModel req,
  ) async {
    double rating = 5;
    final reviewController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Rate Provider'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<double>(
                    value: rating,
                    decoration: const InputDecoration(
                      labelText: 'Rating',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 Stars')),
                      DropdownMenuItem(value: 4, child: Text('4 Stars')),
                      DropdownMenuItem(value: 3, child: Text('3 Stars')),
                      DropdownMenuItem(value: 2, child: Text('2 Stars')),
                      DropdownMenuItem(value: 1, child: Text('1 Star')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => rating = value);
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Review',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      reviewController.dispose();
      return;
    }

    try {
await RequestService.rateProvider(

  ////////////////////////////////////////////////////////////
  /// IMPORTANT
  ////////////////////////////////////////////////////////////

  employeeId:
      req.employeeId,

  providerName:
      req.employeeName,

  requestId:
      req.id,

  rating:
      rating,

  review:
      reviewController.text.trim(),
);

      reviewController.dispose();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your rating'),
        ),
      );
    } catch (e) {
      reviewController.dispose();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit rating: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ServiceRequestModel>>(
      stream: _allCustomerRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final requests = snapshot.data!;

        if (requests.isEmpty) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => onBookAnother(),
              icon: const Icon(Icons.add),
              label: const Text('Book now'),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final req = requests[index];

            final providerName = _providerNameFrom(req);
            final providerId = req.employeeId.trim();
            

            final canTrack = (req.isAccepted || req.isOngoing) &&
                providerId.isNotEmpty &&
                customerPosition != null;

            final canChat = (req.isAccepted || req.isOngoing) &&
                providerId.isNotEmpty;

            final canViewOffers = req.isBidding;

            final canCancel =
                req.isBidding || req.isAccepted || req.isOngoing;

          final canRate =
    req.status ==
        ServiceRequestModel.statusCompleted &&
    req.isRated == false;

            return CustomerRequestCard(
              title: req.serviceType.trim().isEmpty
                  ? 'Service Request'
                  : req.serviceType,
              subtitle: providerName,
              price: req.displayFare,
              status: req.status,
              onTrack: canTrack
                  ? () => _openMap(
                        context,
                        req: req,
                        providerId: providerId,
                      )
                  : null,
              onChat: canChat
                  ? () => _openChat(
                        context,
                        employeeId: providerId,
                        requestId: req.id,
                        title: providerName,
                      )
                  : null,
              onOffers: canViewOffers
                  ? () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => _OffersSheet(
                          requestId: req.id,
                          onAccept: (employeeId) => _acceptOffer(
                            context,
                            requestId: req.id,
                            employeeId: employeeId,
                          ),
                        ),
                      );
                    }
                  : null,
              onCancel: canCancel
                  ? () => _cancelRequest(
                        context,
                        req.id,
                      )
                  : null,
              onRate: canRate
                  ? () => _rateProvider(
                        context,
                        req,
                      )
                  : null,
            );
          },
        );
      },
    );
  }
}

class CustomerRequestCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double price;
  final String status;

  final VoidCallback? onTrack;
  final VoidCallback? onChat;
  final VoidCallback? onOffers;
  final VoidCallback? onCancel;
  final VoidCallback? onRate;

  const CustomerRequestCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.status,
    this.onTrack,
    this.onChat,
    this.onOffers,
    this.onCancel,
    this.onRate,
  });

  Color _statusColor() {
    switch (status) {
      case ServiceRequestModel.statusBidding:
        return Colors.orange;

      case ServiceRequestModel.statusAccepted:
        return Colors.blue;

      case ServiceRequestModel.statusOngoing:
        return Colors.green;

      case ServiceRequestModel.statusCompleted:
        return Colors.purple;

      case ServiceRequestModel.statusCancelled:
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  String _statusLabel() {
    switch (status) {
      case ServiceRequestModel.statusBidding:
        return 'Bidding';

      case ServiceRequestModel.statusAccepted:
        return 'Accepted';

      case ServiceRequestModel.statusOngoing:
        return 'Ongoing';

      case ServiceRequestModel.statusCompleted:
        return 'Completed';

      case ServiceRequestModel.statusCancelled:
        return 'Cancelled';

      default:
        return status;
    }
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String text,
    VoidCallback? onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: onTap == null
                  ? scheme.outline
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: onTap == null
                    ? scheme.outline
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(subtitle),
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _statusLabel(),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'OMR ${price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),

          const SizedBox(height: 14),

const SizedBox(height: 14),

////////////////////////////////////////////////////////
/// BIDDING
////////////////////////////////////////////////////////

if (onOffers != null)
  Row(
    children: [

      Expanded(
        child: FilledButton.icon(

          onPressed: onOffers,

          icon: const Icon(
            Icons.local_offer_outlined,
          ),

          label: const Text(
            'View Offers',
          ),
        ),
      ),

      if (onCancel != null) ...[

        const SizedBox(width: 10),

        Expanded(
          child: OutlinedButton.icon(

            onPressed: onCancel,

            icon: const Icon(Icons.close),

            label: const Text(
              'Cancel',
            ),

            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ),
      ],
    ],
  ),

////////////////////////////////////////////////////////
/// ACTIVE JOB ONLY
////////////////////////////////////////////////////////

if ((status == ServiceRequestModel.statusAccepted ||
        status == ServiceRequestModel.statusOngoing) &&
    onTrack != null)
  Row(
    mainAxisAlignment:
        MainAxisAlignment.spaceAround,

    children: [

      _action(
        context,
        Icons.map_outlined,
        'Track',
        onTrack,
      ),

      _action(
        context,
        Icons.chat_bubble_outline,
        'Chat',
        onChat,
      ),
    ],
  ),
////////////////////////////////////////////////////////
/// COMPLETED
////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
/// ALREADY RATED
////////////////////////////////////////////////////////

if (status ==
        ServiceRequestModel.statusCompleted &&
    onRate == null)
  Container(

    width: double.infinity,

    padding: const EdgeInsets.symmetric(
      vertical: 16,
    ),

    decoration: BoxDecoration(

      color: Colors.green.withOpacity(0.12),

      borderRadius:
          BorderRadius.circular(14),
    ),

    child: const Row(

      mainAxisAlignment:
          MainAxisAlignment.center,

      children: [

        Icon(
          Icons.check_circle,
          color: Colors.green,
        ),

        SizedBox(width: 8),

        Text(

          'Job Completed',

          style: TextStyle(

            color: Colors.green,

            fontWeight:
                FontWeight.bold,
          ),
        ),
      ],
    ),
  ),

if (onRate != null) ...[

  SizedBox(
    width: double.infinity,

    child: FilledButton.icon(

      onPressed: onRate,

      icon: const Icon(Icons.star),

      label: const Text(
        'Rate Provider',
      ),
    ),
  ),
],

        ],
      ),
    );
  }
}

class _OffersSheet extends StatelessWidget {
  final String requestId;
  final Future<void> Function(String employeeId) onAccept;

  const _OffersSheet({
    required this.requestId,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Offers',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: RequestService.offersStream(requestId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Error loading offers:\n${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    final offers = docs.where((doc) {
                      final status = (doc.data()['status'] ?? '').toString();
                      return status == 'pending' || status.isEmpty;
                    }).toList();

                    if (offers.isEmpty) {
                      return const Center(
                        child: Text('No offers yet'),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: offers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _OfferTile(
                          offerDoc: offers[index],
                          onAccept: onAccept,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OfferTile extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> offerDoc;
  final Future<void> Function(String employeeId) onAccept;

  const _OfferTile({
    required this.offerDoc,
    required this.onAccept,
  });

  @override
  State<_OfferTile> createState() => _OfferTileState();
}

class _OfferTileState extends State<_OfferTile> {
  bool _isAccepting = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.offerDoc.data();

    final employeeId = _cleanText(
      data['employeeId'] ?? data['providerId'] ?? widget.offerDoc.id,
    );

    final employeeName = _cleanText(
      data['employeeName'] ?? data['providerName'] ?? 'Provider',
    );

    final note = _cleanText(data['note'] ?? data['message']);
    final etaMinutes = data['etaMinutes'];

    final price = _readPrice(data);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              employeeName.isEmpty ? 'Provider' : employeeName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Offer: $price',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (etaMinutes != null) ...[
              const SizedBox(height: 6),
              Text('ETA: $etaMinutes minutes'),
            ],
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(note),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: employeeId.isEmpty || _isAccepting
                    ? null
                    : () => _acceptOffer(context, employeeId),
                child: _isAccepting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Accept Offer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptOffer(BuildContext context, String employeeId) async {
    setState(() => _isAccepting = true);

    try {
      await widget.onAccept(employeeId);

      if (!context.mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offer accepted'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Accept failed: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  String _readPrice(Map<String, dynamic> data) {
    final value = data['price'] ?? data['proposedFare'] ?? data['fare'];

    if (value == null) return 'Not specified';

    if (value is num) {
      return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
    }

    final text = value.toString().trim();
    return text.isEmpty ? 'Not specified' : text;
  }

  String _cleanText(dynamic value) {
    return value?.toString().trim() ?? '';
  }
}


class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
        ),
      ),
      onTap: onTap,
    );
  }
}