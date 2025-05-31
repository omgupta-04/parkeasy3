import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parkeasy2/providers/speech_provider.dart';
import 'package:parkeasy2/widgets/voice_command_listner.dart';
import 'package:provider/provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/owner_dashboard_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SpeechProvider())],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkEasy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: VoiceCommandListener(child: const AuthGate()),
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
          // TODO: Replace this logic with your role check if needed
          // For demonstration, always show OwnerDashboardScreen
          return OwnerDashboardScreen();
          // Example for user role:
          // if (isOwner(snapshot.data!)) return OwnerDashboardScreen();
          // else return HomeScreen();
        }
        // If not logged in, show login/auth screen
        return AuthScreen();
      },
    );
  }
}

//hello
