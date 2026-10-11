import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services.dart';
import '../app_info.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'auth_screen.dart';
import 'reset_password_screen.dart';
import 'verify_email_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2600), () async {
      if (!mounted) return;
      final reset = DeepLink.resetCode;
      if (reset != null) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(code: reset)));
        return;
      }
      // Dibuka dari tautan verifikasi email: terapkan kodenya dulu.
      final verify = DeepLink.verifyCode;
      if (verify != null) {
        DeepLink.verifyCode = null;
        try {
          await AuthService.applyVerifyCode(verify);
        } on AppError catch (_) {}
        await AuthService.refreshVerified();
        if (!mounted) return;
      }
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) =>
              loggedIn
              ? (AuthService.needsVerification
                  ? const VerifyEmailScreen(sendOnOpen: true)
                  : const HomeScreen())
              : const AuthScreen()));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.6, -0.6),
            radius: 1.1,
            colors: [C.glow, C.bg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 5),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: C.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: C.border),
                  boxShadow: [
                    BoxShadow(
                        color: C.accent.withValues(alpha: 0.3), blurRadius: 30),
                  ],
                ),
                child: const Icon(Icons.movie, size: 40, color: C.accent),
              ),
              const SizedBox(height: 20),
              const Text('LUMA',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: C.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: C.border),
                ),
                child: const Text('Nonton Bareng Tanpa Perdebatan',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              const Spacer(flex: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: AnimatedBuilder(
                  animation: _progress,
                  builder: (_, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _progress.value,
                      minHeight: 4,
                      backgroundColor: C.chip,
                      valueColor: const AlwaysStoppedAnimation(C.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sync, size: 13, color: C.pink),
                  SizedBox(width: 6),
                  Text('Menghubungkan ke server...',
                      style: TextStyle(
                          fontSize: 12.5, color: C.pink)),
                ],
              ),
              const SizedBox(height: 16),
              Text('V$appVersion  •  POWERED BY TMDB',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: C.muted)),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
