import 'package:flutter/material.dart';
//import 'package:google_fonts/google_fonts.dart';
import 'auth_screen.dart';
import '../utils/helpers.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AuthScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF003973), Color(0xFF00B4DB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            width: double.infinity,
            height: double.infinity,

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/2dlogo.jpg',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 24),
                Text(
                  'SmartPark',
                  // style: GoogleFonts.poppins(
                  //   color: Colors.white,
                  //   fontSize: 28,
                  //   fontWeight: FontWeight.bold,
                  // ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Smart Parking, Simplified',
                  // style: GoogleFonts.poppins(
                  //   color: Colors.white70,
                  //   fontSize: 16,
                  // ),
                ),
              ],
            ),
          ),

          // Animated Dots
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(child: AnimatedDots()),
          ),
        ],
      ),
    );
  }
}

// Colorful animated dots
class AnimatedDots extends StatefulWidget {
  const AnimatedDots({Key? key}) : super(key: key);

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentIndex = 0;
  final List<Color> _dotColors = [
    Colors.white,
    Colors.yellow,
    Colors.pinkAccent,
    Colors.lightBlueAccent,
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % 3;
        });
        _controller.forward(from: 0);
      }
    });

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedContainer(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 12,
          height: 12,
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == _currentIndex
                ? _dotColors[_currentIndex % _dotColors.length]
                : Colors.white30,
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
