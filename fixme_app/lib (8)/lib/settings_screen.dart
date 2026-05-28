import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fixme_app/complete_profile_screen.dart';
import 'package:fixme_app/customer_dashboard.dart';
import 'package:fixme_app/employee_dashboard.dart';
import 'package:fixme_app/employee_registration.dart';
import 'package:fixme_app/feedback_screen.dart';

typedef ThemeChanged = Future<void> Function(ThemeMode mode);
typedef LanguageChanged = Future<void> Function(Locale locale);
typedef RoleSwitched = void Function(String newRole);
typedef LogoutRequested = Future<void> Function();

class SettingsScreen extends StatefulWidget {
  final bool isEmployee;
  final String currentTheme;
  final String currentLanguage;
  final ThemeChanged? onThemeChanged;
  final LanguageChanged? onLanguageChanged;
  final RoleSwitched? onRoleSwitch;
  final LogoutRequested? onLogout;
  final bool autoLogout;
  final String? autoSwitchRole;

  const SettingsScreen({
    super.key,
    required this.isEmployee,
    required this.currentTheme,
    this.currentLanguage = 'en',
    this.onThemeChanged,
    this.onLanguageChanged,
    this.onRoleSwitch,
    this.onLogout,
    this.autoLogout = false,
    this.autoSwitchRole,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _kNotif = 'pref_notif_enabled';
  static const String _kVibrate = 'pref_vibrate';
  static const String _kLocationShare = 'pref_share_location';
  static const String _kEmployeeOnline = 'pref_employee_online';
  static const String _kIsEmployee = 'isEmployee';

  String _theme = 'system';
  String _lang = 'en';

  bool _notifEnabled = true;
  bool _vibrate = true;
  bool _shareLocation = true;
  bool _employeeOnline = true;

  bool _busy = false;
  bool _loadingStats = true;
  bool _uploadingImage = false;

  double _rating = 0.0;
  int _ratingCount = 0;
  double _earnings = 0.0;
  int _completedJobs = 0;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  static const List<String> _professionOptions = <String>[
    'Plumber',
    'Technician',
    'Electrician',
    'Handyman',
    'Painter',
    'Carpenter',
  ];

  String? _profession;
  String? _photoUrl;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _theme = _sanitizeTheme(widget.currentTheme);
    _lang = _sanitizeLanguage(widget.currentLanguage);
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newTheme = _sanitizeTheme(widget.currentTheme);
    final newLang = _sanitizeLanguage(widget.currentLanguage);

    if (newTheme != _theme || newLang != _lang) {
      setState(() {
        _theme = newTheme;
        _lang = newLang;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadLocalPrefs(),
      _loadProfile(),
      _loadStats(),
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (widget.autoSwitchRole != null) {
        await _switchRoleAndRoute(widget.autoSwitchRole!);
        return;
      }

      if (widget.autoLogout) {
        await _handleLogout();
      }
    });
  }

  String _sanitizeTheme(String value) {
    switch (value) {
      case 'light':
      case 'dark':
      case 'system':
        return value;
      default:
        return 'system';
    }
  }

  String _sanitizeLanguage(String value) {
    switch (value) {
      case 'ur':
      case 'en':
        return value;
      default:
        return 'en';
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _emojiFor(String keyLower) {
    switch (keyLower) {
      case 'plumber':
        return '🔧';
      case 'electrician':
        return '⚡';
      case 'technician':
        return '💻';
      case 'painter':
        return '🎨';
      case 'carpenter':
        return '🪚';
      case 'handyman':
        return '🛠';
      default:
        return '👷';
    }
  }

  Future<void> _loadLocalPrefs() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _notifEnabled = sp.getBool(_kNotif) ?? true;
      _vibrate = sp.getBool(_kVibrate) ?? true;
      _shareLocation = sp.getBool(_kLocationShare) ?? true;
      _employeeOnline = sp.getBool(_kEmployeeOnline) ?? true;
    });
  }

  Future<void> _savePrefBool(String key, bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(key, value);
  }

  Future<void> _loadProfile() async {
    final user = _user;
    if (user == null) return;

    try {
      final uid = user.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final userData = userDoc.data() ?? <String, dynamic>{};

      String? photoUrl =
          (userData['photoUrl'] as String?) ??
          (userData['profileImage'] as String?) ??
          user.photoURL;

      if (photoUrl == null || photoUrl.isEmpty) {
        final publicDoc = await FirebaseFirestore.instance
            .collection('publicUsers')
            .doc(uid)
            .get();

        final publicData = publicDoc.data() ?? <String, dynamic>{};
        photoUrl = publicData['photoUrl'] as String? ?? photoUrl;
      }

      if (!mounted) return;

      setState(() {
        _nameCtrl.text = (userData['name'] ??
                userData['fullName'] ??
                user.displayName ??
                '')
            .toString();
        _phoneCtrl.text = (userData['phone'] ?? '').toString();
        _cityCtrl.text = (userData['city'] ?? '').toString();
        _addressCtrl.text = (userData['address'] ?? '').toString();
        _photoUrl = photoUrl;

        if (widget.isEmployee) {
          final prof = (userData['profession'] ?? '').toString();
          _profession = _professionOptions.contains(prof) ? prof : null;
        }
      });
    } catch (e) {
      debugPrint('Profile load failed: $e');
    }
  }

  Future<void> _loadStats() async {
    final user = _user;
    if (user == null) {
      if (mounted) setState(() => _loadingStats = false);
      return;
    }

    try {
      final uid = user.uid;

      final ratingsSnap = await FirebaseFirestore.instance
          .collection('ratings')
          .where('providerId', isEqualTo: uid)
          .get();

      double totalRating = 0;
      for (final doc in ratingsSnap.docs) {
        final data = doc.data();
        totalRating += ((data['rating'] ?? 0) as num).toDouble();
      }

      final jobsSnap = await FirebaseFirestore.instance
          .collection('serviceRequests')
          .where('providerId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .get();

      double totalEarnings = 0;
      for (final doc in jobsSnap.docs) {
        final data = doc.data();
        totalEarnings +=
            ((data['agreedFare'] ?? data['priceOffer'] ?? 0) as num)
                .toDouble();
      }

      if (!mounted) return;

      setState(() {
        _ratingCount = ratingsSnap.docs.length;
        _rating = _ratingCount == 0 ? 0.0 : totalRating / _ratingCount;
        _earnings = totalEarnings;
        _completedJobs = jobsSnap.docs.length;
        _loadingStats = false;
      });
    } catch (e) {
      debugPrint('Stats load failed: $e');
      if (!mounted) return;
      setState(() => _loadingStats = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final user = _user;
    if (user == null || _uploadingImage) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (picked == null) return;

      setState(() => _uploadingImage = true);

      final file = File(picked.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images/${user.uid}.jpg');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'photoUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await FirebaseFirestore.instance
          .collection('publicUsers')
          .doc(user.uid)
          .set({'photoUrl': url}, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _photoUrl = url);

      _showSnack('Profile image updated');
    } catch (e) {
      _showSnack('Image upload failed: $e');
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = _user;
    if (user == null) return;

    try {
      setState(() => _busy = true);

      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final city = _cityCtrl.text.trim();
      final address = _addressCtrl.text.trim();

      if (name.isEmpty || phone.isEmpty || city.isEmpty || address.isEmpty) {
        _showSnack('Please fill all required fields');
        return;
      }

      final payload = <String, dynamic>{
        'name': name,
        'fullName': name,
        'phone': phone,
        'city': city,
        'address': address,
        'role': widget.isEmployee ? 'employee' : 'customer',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.isEmployee) {
        final professionKey = (_profession ?? '').trim().toLowerCase();

        if (professionKey.isEmpty) {
          _showSnack('Please select your profession');
          return;
        }

        payload.addAll({
          'profession': _profession,
          'professionEmoji': _emojiFor(professionKey),
        });
      }

      if (_photoUrl != null && _photoUrl!.isNotEmpty) {
        payload['photoUrl'] = _photoUrl;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      final publicPayload = <String, dynamic>{
        'name': name,
        'city': city,
        'role': widget.isEmployee ? 'employee' : 'customer',
        if (_photoUrl != null && _photoUrl!.isNotEmpty) 'photoUrl': _photoUrl,
        if (widget.isEmployee && _profession != null) ...{
          'profession': _profession,
          'professionEmoji': _emojiFor((_profession ?? '').toLowerCase()),
        },
      };

      await FirebaseFirestore.instance
          .collection('publicUsers')
          .doc(user.uid)
          .set(publicPayload, SetOptions(merge: true));

      _showSnack('Profile saved');
    } catch (e) {
      _showSnack('Save failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _mirrorPrivacyToFirestore() async {
    final user = _user;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'shareLocation': _shareLocation,
          if (widget.isEmployee) 'isOnline': _employeeOnline,
          'privacyUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Privacy sync failed: $e');
    }
  }

  Future<void> _changeTheme(String value) async {
    setState(() => _theme = value);

    if (widget.onThemeChanged != null) {
      await widget.onThemeChanged!(_themeModeFromString(value));
    }

    _showSnack('Theme updated');
  }

  Future<void> _changeLanguage(String value) async {
    setState(() => _lang = value);

    if (widget.onLanguageChanged != null) {
      await widget.onLanguageChanged!(_localeFromString(value));
    }

    _showSnack('Language updated');
  }

  Future<void> _switchRoleAndRoute(String targetRole) async {
    if (_busy) return;

    final user = _user;
    if (user == null) {
      _showSnack('No logged-in user found');
      return;
    }

    setState(() => _busy = true);

    try {
      final isEmployeeTarget = targetRole == 'employee';

      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_kIsEmployee, isEmployeeTarget);

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final publicRef =
          FirebaseFirestore.instance.collection('publicUsers').doc(user.uid);

      final batch = FirebaseFirestore.instance.batch();

      batch.set(
        userRef,
        {
          'role': targetRole,
          if (!isEmployeeTarget) 'isOnline': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        publicRef,
        {'role': targetRole},
        SetOptions(merge: true),
      );

      await batch.commit();

      widget.onRoleSwitch?.call(targetRole);

      final fresh = await userRef.get();
      final data = fresh.data() ?? <String, dynamic>{};

      if (isEmployeeTarget) {
        if (_isEmployeeProfileComplete(data)) {
          _routeToDashboard('employee');
        } else {
          final name =
              (data['name'] ?? data['fullName'] ?? user.displayName ?? 'User')
                  .toString();
          final email = user.email ?? '';

          if (!mounted) return;
          await Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => EmployeeRegistrationScreen(
                email: email,
                name: name,
              ),
            ),
            (route) => false,
          );
        }
      } else {
        if (_isCustomerProfileComplete(data)) {
          _routeToDashboard('customer');
        } else {
          final name =
              (data['name'] ?? data['fullName'] ?? user.displayName ?? 'User')
                  .toString();
          final email = user.email ?? '';

          if (!mounted) return;
          await Navigator.of(context).pushNamedAndRemoveUntil('/home',(route) => false);
        }
      }
    }
     catch (e) {
      _showSnack('Switch failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _routeToDashboard(String role) {
    final Widget target = role == 'employee'
        ? const EmployeeDashboardScreen()
        : const CustomerDashboardScreen();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => target),
      (route) => false,
    );
  }

  bool _isCustomerProfileComplete(Map<String, dynamic> data) {
    String s(dynamic v) => (v ?? '').toString().trim();

    final name = s(data['name'] ?? data['fullName']);
    final phone = s(data['phone']);
    final city = s(data['city']);
    final address = s(data['address']);

    return name.isNotEmpty &&
        phone.length >= 7 &&
        city.isNotEmpty &&
        address.isNotEmpty;
  }

  bool _isEmployeeProfileComplete(Map<String, dynamic> data) {
    String s(dynamic v) => (v ?? '').toString().trim();

    final name = s(data['name'] ?? data['fullName']);
    final phone = s(data['phone']);
    final city = s(data['city']);
    final address = s(data['address']);
    final profession = s(data['profession']);
    final photoUrl = s(data['photoUrl']);

    return name.isNotEmpty &&
        phone.length >= 7 &&
        city.isNotEmpty &&
        address.isNotEmpty &&
        profession.isNotEmpty &&
        photoUrl.isNotEmpty;
  }

  ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Locale _localeFromString(String value) {
    switch (value) {
      case 'ur':
        return const Locale('ur');
      default:
        return const Locale('en');
    }
  }

  Future<void> _openNativeSettings() async {
    final uri = Uri.parse('app-settings:');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
      _showSnack('Unable to open system settings');
    } catch (_) {
      _showSnack('Unable to open system settings');
    }
  }

Future<void> _handleLogout() async {
  try {
    setState(() => _busy = true);

    // 🔥 Sign out user
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    // ✅ Navigate to HomePage and clear stack
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
  } catch (e) {
    _showSnack('Logout failed: $e');
  } finally {
    if (mounted) setState(() => _busy = false);
  }
}

  Widget _buildHeader() {
    return Card(
      child: ListTile(
        leading: GestureDetector(
          onTap: _pickAndUploadImage,
          child: CircleAvatar(
            radius: 28,
            backgroundImage:
                _photoUrl != null && _photoUrl!.isNotEmpty
                    ? NetworkImage(_photoUrl!)
                    : null,
            child: (_photoUrl == null || _photoUrl!.isEmpty)
                ? const Icon(Icons.person)
                : null,
          ),
        ),
        title: Text(
          _nameCtrl.text.isEmpty ? 'Profile' : _nameCtrl.text,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          widget.isEmployee ? 'Employee account' : 'Customer account',
        ),
        trailing: _uploadingImage
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: const Icon(Icons.camera_alt_outlined),
                onPressed: _pickAndUploadImage,
              ),
      ),
    );
  }

  Widget _buildThemeCard() {
    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.palette_outlined),
            title: Text(
              'Theme',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          RadioListTile<String>(
            value: 'system',
            groupValue: _theme,
            title: const Text('System default'),
            onChanged: (value) {
              if (value != null) _changeTheme(value);
            },
          ),
          RadioListTile<String>(
            value: 'light',
            groupValue: _theme,
            title: const Text('Light mode'),
            onChanged: (value) {
              if (value != null) _changeTheme(value);
            },
          ),
          RadioListTile<String>(
            value: 'dark',
            groupValue: _theme,
            title: const Text('Dark mode'),
            onChanged: (value) {
              if (value != null) _changeTheme(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard() {
    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.language),
            title: Text(
              'Language',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          RadioListTile<String>(
            value: 'en',
            groupValue: _lang,
            title: const Text('English'),
            onChanged: (value) {
              if (value != null) _changeLanguage(value);
            },
          ),
          RadioListTile<String>(
            value: 'ur',
            groupValue: _lang,
            title: const Text('Urdu'),
            onChanged: (value) {
              if (value != null) _changeLanguage(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityCtrl,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),
            if (widget.isEmployee) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _profession,
                decoration: const InputDecoration(
                  labelText: 'Profession',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                items: _professionOptions
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _profession = value),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _saveProfile,
              icon: const Icon(Icons.save_outlined),
              label: Text(_busy ? 'Saving...' : 'Save profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: _notifEnabled,
            title: const Text('Notifications'),
            secondary: const Icon(Icons.notifications_outlined),
            onChanged: (value) async {
              setState(() => _notifEnabled = value);
              await _savePrefBool(_kNotif, value);
            },
          ),
          SwitchListTile(
            value: _vibrate,
            title: const Text('Vibration'),
            secondary: const Icon(Icons.vibration),
            onChanged: (value) async {
              setState(() => _vibrate = value);
              await _savePrefBool(_kVibrate, value);
            },
          ),
          SwitchListTile(
            value: _shareLocation,
            title: const Text('Share location'),
            secondary: const Icon(Icons.my_location),
            onChanged: (value) async {
              setState(() => _shareLocation = value);
              await _savePrefBool(_kLocationShare, value);
              await _mirrorPrivacyToFirestore();
            },
          ),
          if (widget.isEmployee)
            SwitchListTile(
              value: _employeeOnline,
              title: const Text('Available for jobs'),
              secondary: const Icon(Icons.wifi_tethering),
              onChanged: (value) async {
                setState(() => _employeeOnline = value);
                await _savePrefBool(_kEmployeeOnline, value);
                await _mirrorPrivacyToFirestore();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_loadingStats) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.bar_chart),
            title: Text(
              'Stats',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Rating'),
            trailing: Text(_rating.toStringAsFixed(1)),
          ),
          ListTile(
            leading: const Icon(Icons.reviews_outlined),
            title: const Text('Rating count'),
            trailing: Text('$_ratingCount'),
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Earnings'),
            trailing: Text(_earnings.toStringAsFixed(2)),
          ),
          ListTile(
            leading: const Icon(Icons.task_alt),
            title: const Text('Completed jobs'),
            trailing: Text('$_completedJobs'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Column(
        children: [
          if (!widget.isEmployee)
            ListTile(
              leading: const Icon(Icons.engineering_outlined),
              title: const Text('Switch to employee'),
              onTap: _busy ? null : () => _switchRoleAndRoute('employee'),
            ),
          if (widget.isEmployee)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Switch to customer'),
              onTap: _busy ? null : () => _switchRoleAndRoute('customer'),
            ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Feedback'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeedbackScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_applications_outlined),
            title: const Text('Open device settings'),
            onTap: _openNativeSettings,
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: _busy ? null : _handleLogout,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildThemeCard(),
            const SizedBox(height: 12),
            _buildLanguageCard(),
            const SizedBox(height: 12),
            _buildProfileCard(),
            const SizedBox(height: 12),
            _buildPreferencesCard(),
            const SizedBox(height: 12),
            _buildStatsCard(),
            const SizedBox(height: 12),
            _buildActionsCard(),
          ],
        ),
      ),
    );
  }
}