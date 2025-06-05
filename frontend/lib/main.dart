import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:parkeasy2/screens/map_screen.dart';
import 'package:showcaseview/showcaseview.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/owner/owner_dashboard_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load();
  } catch (e) {
    print('Failed to load .env file: $e');
    print('Env loaded: ${dotenv.env}');
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkEasy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is logged in, show dashboard or home
        if (snapshot.hasData) {
          // ✅ Wrap MapScreen inside ShowCaseWidget + Builder
          return ShowCaseWidget(
            builder: (context) => MapScreen(email: snapshot.data?.email ?? ''),
          );
        }

        // If not logged in, show login/auth screen
        return AuthScreen();
      },
    );
  }
}
