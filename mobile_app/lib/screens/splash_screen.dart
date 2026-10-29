import 'dart:async';
import 'package:flutter/material.dart';
import 'home_screen.dart'; // HomeScreen එක import කරගැනීම

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final String _title = 'Kids Hand Craft App';

  final List<Color> _colors = const [
    Color(0xFFFF6B6B),
    Color(0xFFFFB02E),
    Color(0xFF4ECDC4),
    Color(0xFF5B8DEF),
    Color(0xFFB66DFF),
    Color(0xFF2ECC71),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..forward();

    Timer(const Duration(milliseconds: 3800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildLetter(String char, int index, int total) {
    final start = (index / total) * 0.6;
    final end = (start + 0.35).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final v = anim.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - anim.value)),
            child: Text(
              char,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: _colors[index % _colors.length],
                letterSpacing: 1,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final words = _title.split(' ');
    int counter = 0;
    final total = _title.replaceAll(' ', '').length;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F5E9), Color(0xFFFFF8E1), Color(0xFFE3F2FD)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Text('🎨', style: TextStyle(fontSize: 70)),
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 6,
                children: words.map((word) {
                  final letters = word.split('').map((c) {
                    final w = _buildLetter(c, counter, total);
                    counter++;
                    return w;
                  }).toList();
                  return Row(mainAxisSize: MainAxisSize.min, children: letters);
                }).toList(),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => LinearProgressIndicator(
                    value: _controller.value,
                    minHeight: 8,
                    backgroundColor: Colors.white,
                    color: const Color(0xFF2ECC71),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}