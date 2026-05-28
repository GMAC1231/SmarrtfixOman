import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_dashboard.dart';
import 'app_theme.dart';
import 'complete_profile_screen.dart';
import 'customer_dashboard.dart';
import 'employee_dashboard.dart';
import 'home_page.dart';
import 'shared/services/profile_bootstrap.dart';
import 'shared/services/push_notification_service.dart';
import 'splash_screen.dart';

class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  Future<void> loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    final theme = sp.getString('pref_theme') ?? 'system';
    final lang = sp.getString('pref_lang') ?? 'en';

    _themeMode = _themeFromString(theme);
    _locale = Locale(lang);
  }

  Future<void> setTheme(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;

    final sp = await SharedPreferences.getInstance();
    await sp.setString('pref_theme', _themeToString(mode));

    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale.languageCode == locale.languageCode) return;
    _locale = locale;

    final sp = await SharedPreferences.getInstance();
    await sp.setString('pref_lang', locale.languageCode);

    notifyListeners();
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

  ThemeMode _themeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState appState,
    required Widget child,
  }) : super(notifier: appState, child: child);

  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in widget tree');
    return scope!.notifier!;
  }

  static AppState read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<AppStateScope>();
    final scope = element?.widget as AppStateScope?;
    assert(scope != null, 'AppStateScope not found in widget tree');
    return scope!.notifier!;
  }
}

Future<void> _initFirebase() async {
  await Firebase.initializeApp();

  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
    appleProvider:
        kReleaseMode ? AppleProvider.deviceCheck : AppleProvider.debug,
  );

  debugPrint('Firebase ready: ${Firebase.app().options.projectId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initFirebase();
  await PushNotificationService.init();

  final appState = AppState();
  await appState.loadPrefs();

  final current = FirebaseAuth.instance.currentUser;
  if (current != null) {
    await ProfileBootstrap.ensureProfile();
  }

  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      ProfileBootstrap.ensureProfile().catchError((_) {});
    }
  });

  runApp(MyAppWrapper(appState: appState));
}

class MyAppWrapper extends StatefulWidget {
  final AppState appState;

  const MyAppWrapper({super.key, required this.appState});

  @override
  State<MyAppWrapper> createState() => _MyAppWrapperState();
}

class _MyAppWrapperState extends State<MyAppWrapper> {
  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      appState: widget.appState,
      child: PakistanFixMeApp(appState: widget.appState),
    );
  }
}

class PakistanFixMeApp extends StatelessWidget {
  final AppState appState;

  const PakistanFixMeApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PakistanFixMe',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: appState.themeMode,
      locale: appState.locale,
      home: const SplashScreen(),
      routes: {
        '/home': (_) => const HomePage(),
        '/customer_dashboard': (_) => const CustomerDashboardScreen(),
        '/employee_dashboard': (_) => const EmployeeDashboardScreen(),
        '/admin_dashboard': (_) => const AdminDashboardScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/complete_profile') {
          final args = (settings.arguments ?? {}) as Map;
          return MaterialPageRoute(
            builder: (_) => CompleteProfileScreen(
              email: (args['email'] ?? '') as String,
              name: (args['name'] ?? 'User') as String,
              role: (args['role'] ?? 'customer') as String,
            ),
          );
        }
        return null;
      },
    );
  }
}