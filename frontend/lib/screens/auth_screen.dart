import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parkeasy2/screens/map_screen.dart';
import 'package:showcaseview/showcaseview.dart';
import 'owner/owner_dashboard_screen.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

enum AuthMode { email, google }

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _selectedUserType = ''; // 'owner' or 'user'
  bool _isLoading = false;
  AuthMode _authMode = AuthMode.email;
  bool _isCreatingAccount = false;

  void showSnackBar(String message, {Color color = Colors.redAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildAuthToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: Text('Email'),
          selected: _authMode == AuthMode.email,
          onSelected: (selected) {
            setState(() {
              _authMode = AuthMode.email;
            });
          },
        ),
        SizedBox(width: 10),
        ChoiceChip(
          label: Text('Google'),
          selected: _authMode == AuthMode.google,
          onSelected: (selected) {
            setState(() {
              _authMode = AuthMode.google;
            });
          },
        ),
      ],
    );
  }

  Widget _buildUserTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Account Type',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildSelectionBox(title: 'Owner', type: 'owner'),
            SizedBox(width: 12),
            _buildSelectionBox(title: 'User', type: 'user'),
          ],
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSelectionBox({required String title, required String type}) {
    final isSelected = _selectedUserType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedUserType = type;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade100 : Colors.white,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade400,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_selectedUserType.isEmpty) {
      showSnackBar("Please select account type (Owner/User).");
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      showSnackBar("Please fill in both email and password.");
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      showSnackBar("Please enter a valid email address.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential;
      if (_isCreatingAccount) {
        userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        showSnackBar("Account created successfully!", color: Colors.green);
      } else {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      // Navigate based on user type
      if (_selectedUserType == 'owner') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => ShowCaseWidget(
                  builder: (showCaseContext) => OwnerDashboardScreen(),
                ),
          ),
        );
      } else if (_selectedUserType == 'user') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => ShowCaseWidget(
                  builder:
                      (showCaseContext) =>
                          MapScreen(email: _emailController.text),
                ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      showSnackBar(e.message ?? "Authentication failed.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_selectedUserType.isEmpty) {
      showSnackBar("Please select account type (Owner/User).");
      return;
    }
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential;
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        userCredential = await FirebaseAuth.instance.signInWithPopup(
          googleProvider,
        );
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          setState(() => _isLoading = false);
          return; // User cancelled
        }
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
      }
      // Navigate based on user type
      if (_selectedUserType == 'owner') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => ShowCaseWidget(
                  builder: (showCaseContext) => OwnerDashboardScreen(),
                ),
          ),
        );
      } else if (_selectedUserType == 'user') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => ShowCaseWidget(
                  builder:
                      (showCaseContext) =>
                          MapScreen(email: _emailController.text),
                ),
          ),
        );
      }
    } catch (e) {
      showSnackBar('Google Sign-In failed: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAuthToggle(),
              SizedBox(height: 16),
              _buildUserTypeSelector(),
              Text(
                _authMode == AuthMode.email
                    ? (_isCreatingAccount ? 'Create Account' : 'Sign in')
                    : 'Sign in with Google',
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_authMode == AuthMode.email)
                Row(
                  children: [
                    Text(
                      _isCreatingAccount ? 'Already have an account? ' : 'or ',
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isCreatingAccount = !_isCreatingAccount;
                        });
                      },
                      child: Text(
                        _isCreatingAccount ? 'sign in' : 'create an account',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 16),
              if (_authMode == AuthMode.email) ...[
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child:
                        _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                              _isCreatingAccount ? 'create account' : 'sign in',
                            ),
                  ),
                ),
                SizedBox(height: 12),
              ],
              if (_authMode == AuthMode.google) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      height: 20,
                    ),
                    label: Text('Sign in with Google'),
                    onPressed: _isLoading ? null : _signInWithGoogle,
                  ),
                ),
                SizedBox(height: 12),
              ],
              if (_authMode == AuthMode.email)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      // TODO: Implement forgot password logic if needed
                      showSnackBar('Forgot password pressed');
                    },
                    child: Text(
                      'Forgotten your password?',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
