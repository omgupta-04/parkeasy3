import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/owner_dashboard_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If you don't use showcaseview, you can remove ShowCaseWidget below
    return ShowCaseWidget(
      builder: (context) => MaterialApp(
        title: 'ParkEasy',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  Future<String?> _getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role'); // 'owner' or 'user'
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return FutureBuilder<String?>(
            future: _getRole(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final role = roleSnapshot.data;
              final email = snapshot.data!.email ?? '';
              if (role == 'owner') {
                return OwnerDashboardScreen();
              }
              return HomeScreen(email: email);
            },
          );
        }
        return AuthScreen();
      },
    );
  }
}
