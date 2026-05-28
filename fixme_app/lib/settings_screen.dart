import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fixme_app/customer_dashboard.dart';
import 'package:fixme_app/employee_dashboard.dart';
import 'package:fixme_app/employee_registration.dart';
import 'package:fixme_app/feedback_screen.dart';

typedef LanguageChanged = Future<void> Function(Locale locale);
typedef RoleSwitched = void Function(String newRole);
typedef LogoutRequested = Future<void> Function();

const Color _brand = Color(0xFF01411C);
const Color _brand2 = Color(0xFF0E7A35);
const Color _brandLight = Color(0xFFEAF7EF);
const Color _danger = Color(0xFFDC2626);

class SettingsScreen extends StatefulWidget {
  final bool isEmployee;
  final String currentTheme;
  final String currentLanguage;
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

  static const List<String> _professionOptions = <String>[
    'Plumber',
    'Technician',
    'Electrician',
    'Handyman',
    'Painter',
    'Carpenter',
  ];

  String _lang = 'en';

  bool _notifEnabled = true;
  bool _vibrate = true;
  bool _shareLocation = true;
  bool _employeeOnline = true;

  bool _busy = false;
  bool _loadingStats = false;
  bool _uploadingImage = false;
  bool _bootstrapping = true;

  double _rating = 0.0;
  int _ratingCount = 0;
  double _earnings = 0.0;
  int _completedJobs = 0;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  String? _profession;
  String? _photoUrl;

  User? get _user => FirebaseAuth.instance.currentUser;
@override
void initState() {

  super.initState();

  FirebaseFirestore.instance

      .collection('ratings')

      .where(
        'employeeId',
        isEqualTo:
            FirebaseAuth
                .instance
                .currentUser
                ?.uid,
      )

      .snapshots()

      .listen((_) {

    _loadStats();
  });

  _bootstrap();
}

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    try {
      await Future.wait([
        _loadLocalPrefs(),
        _loadProfile(),
      ]);

      await _loadStats();
    } finally {
      if (mounted) {
        setState(() => _bootstrapping = false);
      }
    }

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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
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
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final userData = userDoc.data() ?? <String, dynamic>{};

      String? photoUrl = (userData['photoUrl'] as String?) ??
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
        _nameCtrl.text =
            (userData['name'] ?? userData['fullName'] ?? user.displayName ?? '')
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
      _showSnack('Failed to load profile');
    }
  }

  Future<void> _loadStats() async {
    final user = _user;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingStats = false;
        });
      }

      return;
    }

    try {
      final uid = user.uid;

      ////////////////////////////////////////////////////////////
      /// RATINGS
      ////////////////////////////////////////////////////////////

      final ratingsSnap = await FirebaseFirestore.instance
          .collection('serviceRequests')
          .where(
            'providerId',
            isEqualTo: uid,
          )
          .get();

      double totalRating = 0;

      for (final doc in ratingsSnap.docs) {
        final data = doc.data();

        final rating = (data['rating'] ?? 0);

        if (rating is num) {
          totalRating += rating.toDouble();
        }
      }

      ////////////////////////////////////////////////////////////
      /// COMPLETED JOBS
      ////////////////////////////////////////////////////////////

      final jobsSnap = await FirebaseFirestore.instance
          .collection(
            'serviceRequests',
          )
          .where(
            'employeeId',
            isEqualTo: uid,
          )
          .where(
            'status',
            isEqualTo: 'completed',
          )
          .get();

      ////////////////////////////////////////////////////////////
      /// EARNINGS
      ////////////////////////////////////////////////////////////

      double totalEarnings = 0;

      for (final doc in jobsSnap.docs) {
        final data = doc.data();

        final fare =
            (data['agreedFare'] ?? data['fare'] ?? data['priceOffer'] ?? 0);

        if (fare is num) {
          totalEarnings += fare.toDouble();
        }
      }

      ////////////////////////////////////////////////////////////
      /// UPDATE STATE
      ////////////////////////////////////////////////////////////

      if (!mounted) return;

      final reviewCount = ratingsSnap.docs.length;

      final double avgRating =
          reviewCount == 0 ? 0.0 : totalRating / reviewCount;

setState(() {

  _ratingCount =
      reviewCount;

  _rating =
      avgRating;

  _earnings =
      totalEarnings;

  _completedJobs =
      jobsSnap.docs.length;

  _loadingStats =
      false;
});
    } catch (e) {
      debugPrint(
        'Stats load failed: $e',
      );

      if (!mounted) return;

setState(() {

  _loadingStats = false;

});
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
    if (user == null || _busy) return;

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
          if (!mounted) return;
          await Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
        }
      }
    } catch (e) {
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

      if (widget.onLogout != null) {
        await widget.onLogout!();
      } else {
        await FirebaseAuth.instance.signOut();
      }

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      _showSnack('Logout failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _bgColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF0F1512) : const Color(0xFFF4F7F5);
  }

  Color _textSecondary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white70 : Colors.black54;
  }

  Widget _sectionCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1B241F),
                  const Color(0xFF151C18),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF7FBF8),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : _brand.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : const Color(0x1401411C),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: _brand.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: _brand),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildTopBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [_brand, _brand2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3301411C),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Premium Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isEmployee
                      ? 'Manage your profile, availability, earnings, and app preferences.'
                      : 'Manage your profile, app appearance, and experience.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return _sectionCard(
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _brand.withOpacity(0.18), width: 2),
                ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: _brandLight,
                  backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
                      ? NetworkImage(_photoUrl!)
                      : null,
                  child: (_photoUrl == null || _photoUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 34, color: _brand)
                      : null,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: InkWell(
                  onTap: _uploadingImage ? null : _pickAndUploadImage,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: _brand,
                      shape: BoxShape.circle,
                    ),
                    child: _uploadingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameCtrl.text.isEmpty ? 'Your Profile' : _nameCtrl.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _user?.email ?? 'No email',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textSecondary(context),
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _brand.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    widget.isEmployee ? 'Employee Account' : 'Customer Account',
                    style: const TextStyle(
                      color: _brand,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? _brand : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? _brand : _brand.withOpacity(0.14),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _brand.withOpacity(0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              if (icon != null)
                Icon(
                  icon,
                  color: selected ? Colors.white : _brand,
                  size: 20,
                ),
              if (icon != null) const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : _brand,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _brand),
      filled: true,
      fillColor:
          isDark ? Colors.white.withOpacity(0.03) : _brand.withOpacity(0.035),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: _brand.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: _brand.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _brand, width: 1.4),
      ),
    );
  }

  Widget _buildProfileCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Profile Information', Icons.badge_rounded),
          const SizedBox(height: 18),
          TextField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration('Name', Icons.person_outline_rounded),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration('Phone', Icons.phone_rounded),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _cityCtrl,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration('City', Icons.location_city_rounded),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _addressCtrl,
            textInputAction: TextInputAction.done,
            decoration: _fieldDecoration('Address', Icons.home_rounded),
          ),
          if (widget.isEmployee) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _profession,
              decoration:
                  _fieldDecoration('Profession', Icons.work_outline_rounded),
              borderRadius: BorderRadius.circular(18),
              items: _professionOptions
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text('${_emojiFor(item.toLowerCase())}  $item'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _profession = value),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _saveProfile,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_busy ? 'Saving...' : 'Save Profile'),
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color iconBg = _brand,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _brand.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _brand.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: iconBg.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconBg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _textSecondary(context),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: _brand,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Preferences', Icons.tune_rounded),
          const SizedBox(height: 16),
          _buildPremiumSwitchTile(
            title: 'Notifications',
            subtitle: 'Receive updates, alerts, and important activity.',
            icon: Icons.notifications_active_rounded,
            value: _notifEnabled,
            onChanged: (value) async {
              setState(() => _notifEnabled = value);
              await _savePrefBool(_kNotif, value);
            },
          ),
          _buildPremiumSwitchTile(
            title: 'Vibration',
            subtitle: 'Allow vibration feedback inside the app.',
            icon: Icons.vibration_rounded,
            value: _vibrate,
            onChanged: (value) async {
              setState(() => _vibrate = value);
              await _savePrefBool(_kVibrate, value);
            },
          ),
          _buildPremiumSwitchTile(
            title: 'Share Location',
            subtitle: 'Enable live location sharing when needed.',
            icon: Icons.my_location_rounded,
            value: _shareLocation,
            onChanged: (value) async {
              setState(() => _shareLocation = value);
              await _savePrefBool(_kLocationShare, value);
              await _mirrorPrivacyToFirestore();
            },
          ),
          if (widget.isEmployee)
            _buildPremiumSwitchTile(
              title: 'Available for Jobs',
              subtitle: 'Show customers that you are ready to accept work.',
              icon: Icons.wifi_tethering_rounded,
              value: _employeeOnline,
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

  

//////////////////////////////////////////////////////////////
/// PREMIUM STAT CARD
//////////////////////////////////////////////////////////////

Widget _statCard({
  required IconData icon,
  required String title,
  required String value,
  required Color color,
}) {

  return Container(

    padding: const EdgeInsets.all(16),

    decoration: BoxDecoration(

      color: color.withOpacity(0.10),

      borderRadius:
          BorderRadius.circular(24),
    ),

    child: Column(

      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,

      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        ////////////////////////////////////////////////////////
        /// ICON
        ////////////////////////////////////////////////////////

        Container(

          width: 44,
          height: 44,

          decoration: BoxDecoration(

            color:
                color.withOpacity(0.16),

            borderRadius:
                BorderRadius.circular(14),
          ),

          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),

        ////////////////////////////////////////////////////////
        /// TEXT
        ////////////////////////////////////////////////////////

        Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            Text(

              value,

              maxLines: 1,

              overflow:
                  TextOverflow.ellipsis,

              style: const TextStyle(

                fontSize: 14,

                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 2),

            Text(

              title,

              style: TextStyle(

                color: Colors.grey[700],

                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

//////////////////////////////////////////////////////////////
/// PERFORMANCE STATS CARD
//////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////
/// PERFORMANCE STATS CARD
//////////////////////////////////////////////////////////////

Widget _buildStatsCard() {

  return _sectionCard(

    child: Column(

      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        ////////////////////////////////////////////////////////
        /// TITLE
        ////////////////////////////////////////////////////////

        _sectionTitle(
          'Performance Stats',
          Icons.bar_chart_rounded,
        ),

        const SizedBox(height: 18),

        ////////////////////////////////////////////////////////
        /// COMPLETED JOBS STREAM
        ////////////////////////////////////////////////////////

        StreamBuilder<QuerySnapshot>(

          stream: FirebaseFirestore.instance

              .collection('serviceRequests')

              .where(
                'employeeId',
                isEqualTo:
                    FirebaseAuth
                        .instance
                        .currentUser
                        ?.uid,
              )

              .where(
                'status',
                isEqualTo: 'completed',
              )

              .snapshots(),

          builder: (context, jobsSnapshot) {

            ////////////////////////////////////////////////////
            /// LOADING
            ////////////////////////////////////////////////////

            if (jobsSnapshot.connectionState ==
                ConnectionState.waiting) {

              return const Center(

                child:
                    CircularProgressIndicator(),
              );
            }

            ////////////////////////////////////////////////////
            /// JOB DOCS
            ////////////////////////////////////////////////////

            final jobDocs =
                jobsSnapshot.data?.docs ?? [];

            ////////////////////////////////////////////////////
            /// RATINGS STREAM
            ////////////////////////////////////////////////////

            return StreamBuilder<QuerySnapshot>(

              stream: FirebaseFirestore.instance

                  .collection('ratings')

                  .where(
                    'employeeId',
                    isEqualTo:
                        FirebaseAuth
                            .instance
                            .currentUser
                            ?.uid,
                  )

                  .snapshots(),

              builder: (
                context,
                ratingsSnapshot,
              ) {

                //////////////////////////////////////////////////
                /// LOADING
                //////////////////////////////////////////////////

                if (ratingsSnapshot
                        .connectionState ==
                    ConnectionState.waiting) {

                  return const Center(

                    child:
                        CircularProgressIndicator(),
                  );
                }

                //////////////////////////////////////////////////
                /// RATING DATA
                //////////////////////////////////////////////////

                final ratingDocs =
                    ratingsSnapshot
                            .data
                            ?.docs ??
                        [];

                double totalRating = 0;

                int reviewCount = 0;

                for (final doc
                    in ratingDocs) {

                  final data =
                      doc.data()
                          as Map<String, dynamic>;

                  final rating =
                      data['rating'];

                  if (rating is num &&
                      rating > 0) {

                    totalRating +=
                        rating.toDouble();

                    reviewCount++;
                  }
                }

                //////////////////////////////////////////////////
                /// EARNINGS
                //////////////////////////////////////////////////

                double totalEarnings = 0;

                for (final doc
                    in jobDocs) {

                  final data =
                      doc.data()
                          as Map<String, dynamic>;

                  final fare =
                      data['agreedFare'] ??
                      data['fare'] ??
                      data['priceOffer'] ??
                      0;

                  if (fare is num) {

                    totalEarnings +=
                        fare.toDouble();
                  }
                }

                //////////////////////////////////////////////////
                /// FINAL VALUES
                //////////////////////////////////////////////////

                final avgRating =

                    reviewCount == 0
                        ? 0.0
                        : totalRating /
                            reviewCount;

                final completedJobs =
                    jobDocs.length;

                //////////////////////////////////////////////////
                /// UI
                //////////////////////////////////////////////////

                return GridView.count(

                  crossAxisCount: 2,

                  shrinkWrap: true,

                  physics:
                      const NeverScrollableScrollPhysics(),

                  crossAxisSpacing: 16,

                  mainAxisSpacing: 16,

                  childAspectRatio: 1.18,

                  children: [

                    //////////////////////////////////////////////////
                    /// RATING
                    //////////////////////////////////////////////////

                    _statCard(

                      icon:
                          Icons.star_rounded,

                      title:
                          'Rating',

                      value:
                          avgRating
                              .toStringAsFixed(
                                  1),

                      color:
                          Colors.amber,
                    ),

                    //////////////////////////////////////////////////
                    /// REVIEWS
                    //////////////////////////////////////////////////

                    _statCard(

                      icon:
                          Icons.reviews_rounded,

                      title:
                          'Reviews',

                      value:
                          '$reviewCount',

                      color:
                          Colors.blue,
                    ),

                    //////////////////////////////////////////////////
                    /// EARNINGS
                    //////////////////////////////////////////////////

                    _statCard(

                      icon:
                          Icons.account_balance_wallet,

                      title:
                          'Earnings',

                      value:
                          'OMR ${totalEarnings.toStringAsFixed(2)}',

                      color:
                          Colors.green,
                    ),

                    //////////////////////////////////////////////////
                    /// COMPLETED
                    //////////////////////////////////////////////////

                    _statCard(

                      icon:
                          Icons.task_alt_rounded,

                      title:
                          'Completed',

                      value:
                          '$completedJobs',

                      color:
                          Colors.purple,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    ),
  );
}
  Widget _actionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    Color color = _brand,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: color.withOpacity(0.07),
              border: Border.all(color: color.withOpacity(0.10)),
            ),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: color == _danger ? _danger : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: _textSecondary(context),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: color.withOpacity(0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Actions', Icons.flash_on_rounded),
          const SizedBox(height: 16),
          if (!widget.isEmployee)
            _actionTile(
              title: 'Switch to Employee',
              subtitle: 'Change your role and access provider features.',
              icon: Icons.engineering_rounded,
              onTap: _busy ? null : () => _switchRoleAndRoute('employee'),
            ),
          if (widget.isEmployee)
            _actionTile(
              title: 'Switch to Customer',
              subtitle: 'Go back to the customer experience.',
              icon: Icons.person_rounded,
              onTap: _busy ? null : () => _switchRoleAndRoute('customer'),
            ),
          _actionTile(
            title: 'Feedback',
            subtitle: 'Tell us how we can improve the app.',
            icon: Icons.feedback_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeedbackScreen()),
              );
            },
          ),
          _actionTile(
            title: 'Device Settings',
            subtitle: 'Open your phone settings for permissions and controls.',
            icon: Icons.settings_applications_rounded,
            onTap: _openNativeSettings,
          ),
          _actionTile(
            title: 'Logout',
            subtitle: 'Sign out from your current account safely.',
            icon: Icons.logout_rounded,
            color: _danger,
            onTap: _busy ? null : _handleLogout,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      return Scaffold(
        backgroundColor: _bgColor(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor(context),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _buildTopBanner(),
            _buildHeader(),
            _buildProfileCard(),
            _buildPreferencesCard(),
            if (widget.isEmployee) _buildStatsCard(),
            _buildActionsCard(),
          ],
        ),
      ),
    );
  }
}
