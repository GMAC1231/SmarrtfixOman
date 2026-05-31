import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_dashboard.dart';
import 'complete_profile_screen.dart';
import 'customer_dashboard.dart';
import 'employee_dashboard.dart';
import 'home_page.dart';
import 'shared/services/profile_bootstrap.dart';
import 'shared/services/push_notification_service.dart';
import 'splash_screen.dart';


////////////////////////////////////////////////////////////
/// APP STATE
////////////////////////////////////////////////////////////

class AppState extends ChangeNotifier {

  ThemeMode _themeMode =
      ThemeMode.light;

  Locale _locale =
      const Locale('en');

  ThemeMode get themeMode =>
      _themeMode;

  Locale get locale =>
      _locale;

  ////////////////////////////////////////////////////////////
  /// LOAD PREFS
  ////////////////////////////////////////////////////////////

  Future<void> loadPrefs() async {

    final sp =
        await SharedPreferences.getInstance();

    final theme =
        sp.getString('pref_theme') ??
            'light';

    final lang =
        sp.getString('pref_lang') ??
            'en';

    _themeMode =
        _themeFromString(theme);

    _locale =
        Locale(lang);
  }

  ////////////////////////////////////////////////////////////
  /// SET THEME
  ////////////////////////////////////////////////////////////

  Future<void> setTheme(
    ThemeMode mode,
  ) async {

    _themeMode = mode;

    final sp =
        await SharedPreferences.getInstance();

    await sp.setString(
      'pref_theme',
      _themeToString(mode),
    );

    notifyListeners();
  }

  ////////////////////////////////////////////////////////////
  /// SET LANGUAGE
  ////////////////////////////////////////////////////////////

  Future<void> setLocale(
    Locale locale,
  ) async {

    _locale = locale;

    final sp =
        await SharedPreferences.getInstance();

    await sp.setString(
      'pref_lang',
      locale.languageCode,
    );

    notifyListeners();
  }

  ////////////////////////////////////////////////////////////
  /// THEME TO STRING
  ////////////////////////////////////////////////////////////

  String _themeToString(
    ThemeMode mode,
  ) {

    switch (mode) {

      case ThemeMode.light:
        return 'light';

      case ThemeMode.dark:
        return 'dark';

      case ThemeMode.system:
        return 'system';
    }
  }

  ////////////////////////////////////////////////////////////
  /// STRING TO THEME
  ////////////////////////////////////////////////////////////

  ThemeMode _themeFromString(
    String value,
  ) {

    switch (value) {

      case 'dark':
        return ThemeMode.dark;

      case 'system':
        return ThemeMode.system;

      default:
        return ThemeMode.light;
    }
  }
}

////////////////////////////////////////////////////////////
/// APP STATE SCOPE
////////////////////////////////////////////////////////////

class AppStateScope
    extends InheritedNotifier<AppState> {

  const AppStateScope({
    super.key,
    required AppState appState,
    required Widget child,
  }) : super(
          notifier: appState,
          child: child,
        );

  ////////////////////////////////////////////////////////////
  /// OF
  ////////////////////////////////////////////////////////////

  static AppState of(
    BuildContext context,
  ) {

    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();

    assert(
      scope != null,
      'AppStateScope not found',
    );

    return scope!.notifier!;
  }

  ////////////////////////////////////////////////////////////
  /// READ
  ////////////////////////////////////////////////////////////

  static AppState read(
    BuildContext context,
  ) {

    final element =

        context.getElementForInheritedWidgetOfExactType<AppStateScope>();

    final scope =
        element?.widget
            as AppStateScope?;

    assert(
      scope != null,
      'AppStateScope not found',
    );

    return scope!.notifier!;
  }
}



////////////////////////////////////////////////////////////
/// FIREBASE INIT
////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////
/// FIREBASE INIT
////////////////////////////////////////////////////////////

Future<void> _initFirebase() async {
  await Firebase.initializeApp();

  ////////////////////////////////////////////////////////////
  /// APP CHECK
  ///
  /// For development:
  /// - Debug provider avoids Play Integrity issues
  /// - Register debug token in Firebase App Check
  ///
  /// For production:
  /// - Use AndroidProvider.playIntegrity
  ////////////////////////////////////////////////////////////

  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );

    debugPrint(
      'Firebase App Check initialized',
    );
  } catch (e) {
    debugPrint(
      'App Check init failed: $e',
    );
  }

  debugPrint(
    'Firebase initialized successfully',
  );
}



////////////////////////////////////////////////////////////
/// MAIN
////////////////////////////////////////////////////////////

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  ////////////////////////////////////////////////////////////
  /// FIREBASE
  ////////////////////////////////////////////////////////////

  await _initFirebase();

  ////////////////////////////////////////////////////////////
  /// PUSH NOTIFICATIONS
  ////////////////////////////////////////////////////////////

  try {

    await PushNotificationService.initialize();

  } catch (e) {

    debugPrint(
      'Push notification init error: $e',
    );
  }

  ////////////////////////////////////////////////////////////
  /// APP STATE
  ////////////////////////////////////////////////////////////

  final appState =
      AppState();

  await appState.loadPrefs();

  ////////////////////////////////////////////////////////////
  /// PROFILE BOOTSTRAP
  ////////////////////////////////////////////////////////////

  final currentUser =
      FirebaseAuth.instance.currentUser;

if (currentUser != null) {

  try {

    //////////////////////////////////////////////////////////
    /// PROFILE
    //////////////////////////////////////////////////////////

    await ProfileBootstrap.ensureProfile();

    //////////////////////////////////////////////////////////
    /// SOCKET CONNECT
    //////////////////////////////////////////////////////////

  } catch (e) {

    debugPrint(
      'Profile bootstrap error: $e',
    );
  }
}

  ////////////////////////////////////////////////////////////
  /// AUTH LISTENER
  ////////////////////////////////////////////////////////////

FirebaseAuth.instance
    .authStateChanges()
    .listen((user) async {

  if (user != null) {

    try {

      //////////////////////////////////////////////////////////
      /// LOAD USER DOCUMENT
      //////////////////////////////////////////////////////////

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final data =
          userDoc.data();

      //////////////////////////////////////////////////////////
      /// CHECK SUSPENSION
      //////////////////////////////////////////////////////////

      if (data?['accountStatus'] ==
          'suspended') {

        debugPrint(
          'Suspended user detected',
        );

        ////////////////////////////////////////////////////////
        /// FORCE LOGOUT
        ////////////////////////////////////////////////////////

        await FirebaseAuth.instance
            .signOut();

        return;
      }

      //////////////////////////////////////////////////////////
      /// NORMAL PROFILE BOOTSTRAP
      //////////////////////////////////////////////////////////
await ProfileBootstrap
    .ensureProfile();


    } catch (e) {

      debugPrint(
        'Auth listener error: $e',
      );
    }
  }
});

  ////////////////////////////////////////////////////////////
  /// RUN APP
  ////////////////////////////////////////////////////////////

  runApp(
    MyAppWrapper(
      appState: appState,
    ),
  );
}

////////////////////////////////////////////////////////////
/// WRAPPER
////////////////////////////////////////////////////////////

class MyAppWrapper
    extends StatelessWidget {

  final AppState appState;

  const MyAppWrapper({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {

    return AppStateScope(

      appState: appState,

      child: PakistanFixMeApp(
        appState: appState,
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// MAIN APP
////////////////////////////////////////////////////////////

class PakistanFixMeApp
    extends StatelessWidget {

  final AppState appState;

  const PakistanFixMeApp({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {

    return MaterialApp(

      //////////////////////////////////////////////////////////
      /// GENERAL
      //////////////////////////////////////////////////////////

      debugShowCheckedModeBanner: false,

      title: 'PakistanFixMe',

      //////////////////////////////////////////////////////////
      /// THEME
      //////////////////////////////////////////////////////////

      themeMode: ThemeMode.light,

      theme: ThemeData(

        brightness:
            Brightness.light,

        useMaterial3: true,

        scaffoldBackgroundColor:
            Colors.white,

        colorScheme:
            const ColorScheme.light(

          primary:
              Color(0xFF01411C),

          surface:
              Colors.white,

          onSurface:
              Colors.black,
        ),

        appBarTheme:
            const AppBarTheme(

          backgroundColor:
              Colors.white,

          foregroundColor:
              Colors.black,

          elevation: 0,
        ),
      ),

      darkTheme:
          ThemeData.light(),

      //////////////////////////////////////////////////////////
      /// LANGUAGE
      //////////////////////////////////////////////////////////

      locale:
          appState.locale,

      //////////////////////////////////////////////////////////
      /// HOME
      //////////////////////////////////////////////////////////

      home:
          const SplashScreen(),

      //////////////////////////////////////////////////////////
      /// ROUTES
      //////////////////////////////////////////////////////////

      routes: {

        '/home':
            (_) => const HomePage(),

        '/customer_dashboard':
            (_) => const CustomerDashboardScreen(),

        '/employee_dashboard':
            (_) => const EmployeeDashboardScreen(),

        '/admin_dashboard':
            (_) => const AdminDashboardScreen(),
      },

      //////////////////////////////////////////////////////////
      /// GENERATE ROUTE
      //////////////////////////////////////////////////////////

      onGenerateRoute: (settings) {

        if (settings.name ==
            '/complete_profile') {

          final args =
              (settings.arguments ?? {})
                  as Map;

          return MaterialPageRoute(

            builder: (_) =>
                CompleteProfileScreen(

              email:
                  (args['email'] ?? '')
                      as String,

              name:
                  (args['name'] ?? 'User')
                      as String,

              role:
                  (args['role'] ?? 'customer')
                      as String,
            ),
          );
        }

        return null;
      },
    );
  }
}