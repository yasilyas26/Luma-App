import 'dart:async';

import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import 'onboarding_screen.dart';

/// Ditampilkan sesaat setelah akun baru berhasil dibuat, lalu lanjut ke
/// onboarding.
class RegisterSuccessScreen extends StatefulWidget {
  const RegisterSuccessScreen({super.key});

  @override
  State<RegisterSuccessScreen> createState() => _RegisterSuccessScreenState();
}

class _RegisterSuccessScreenState extends State<RegisterSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 3200), _next);
  }

  void _next() {
    if (!mounted) return;
    _timer?.cancel();
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.0,
            colors: [C.glow, C.bg],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 3),
                ScaleTransition(
                  scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: C.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: C.accent.withValues(alpha: 0.45),
                            blurRadius: 40),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 64, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: CurvedAnimation(
                      parent: _c, curve: const Interval(0.4, 1)),
                  child: Column(
                    children: [
                      const Text('Akun Berhasil Dibuat!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text('Selamat datang di LUMA, ${AuthService.name}.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14, height: 1.4, color: C.muted)),
                    ],
                  ),
                ),
                const Spacer(flex: 4),
                PrimaryButton(
                  label: 'Lanjut',
                  trailing: Icons.arrow_forward,
                  height: 52,
                  onTap: _next,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
