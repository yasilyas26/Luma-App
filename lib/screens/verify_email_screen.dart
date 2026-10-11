import 'dart:async';

import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'register_success_screen.dart';

/// Verifikasi email: pengguna membuka email dari LUMA dan menekan tautan
/// verifikasinya. Layar ini mengecek otomatis, lalu melanjutkan.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen(
      {super.key, this.newAccount = false, this.sendOnOpen = false});

  /// Akun baru: setelah terverifikasi tampil "Akun Berhasil Dibuat" + onboarding.
  final bool newAccount;

  /// Kirim email verifikasi begitu layar dibuka (untuk akun lama yang belum
  /// pernah diverifikasi). Akun baru sudah dikirimi saat mendaftar.
  final bool sendOnOpen;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _cooldown = 60;
  Timer? _poll;
  Timer? _tick;
  int _wait = _cooldown;
  bool _checking = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.sendOnOpen) {
      _send();
    } else {
      _startCooldown();
    }
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _tick?.cancel();
    setState(() => _wait = _cooldown);
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_wait <= 1) {
        t.cancel();
        setState(() => _wait = 0);
      } else {
        setState(() => _wait--);
      }
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await AuthService.sendVerification();
      if (mounted) {
        showMsg(context, 'Email verifikasi dikirim ke ${AuthService.email}');
        _startCooldown();
      }
    } on AppError catch (e) {
      if (mounted) {
        showMsg(context, e.message);
        _startCooldown();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    _checking = true;
    if (!silent) setState(() {});
    try {
      final ok = await AuthService.refreshVerified();
      if (!mounted) return;
      if (ok) {
        _poll?.cancel();
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => widget.newAccount
                ? const RegisterSuccessScreen()
                : const HomeScreen()));
        return;
      }
      if (!silent) {
        showMsg(context, 'Email belum terverifikasi. Buka email dan tekan tautannya.');
      }
    } finally {
      _checking = false;
      if (mounted && !silent) setState(() {});
    }
  }

  Future<void> _useOther() async {
    _poll?.cancel();
    ProfilePhoto.clear();
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 64, 20, 20),
          children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: C.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.border),
                ),
                child: const Icon(Icons.mark_email_unread_outlined,
                    size: 40, color: C.accent),
              ),
            ),
            const SizedBox(height: 22),
            const Text('Verifikasi Email Kamu',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Kami mengirim email verifikasi ke',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: C.muted)),
            const SizedBox(height: 4),
            Text(AuthService.email,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Text(
                'Buka email itu lalu tekan tautan verifikasinya. Halaman ini akan lanjut otomatis setelah email terverifikasi. Cek folder spam kalau belum masuk.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5, color: C.muted)),
            const SizedBox(height: 28),
            PrimaryButton(
              label: _checking ? 'Memeriksa...' : 'Saya Sudah Verifikasi',
              trailing: Icons.arrow_forward,
              height: 50,
              onTap: _checking ? null : _check,
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: (_wait > 0 || _sending) ? null : _send,
                child: Text(
                    _sending
                        ? 'Mengirim...'
                        : _wait > 0
                            ? 'Kirim ulang email ($_wait dtk)'
                            : 'Kirim ulang email',
                    style: TextStyle(
                        color: (_wait > 0 || _sending) ? C.muted : C.accent)),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _useOther,
                child: Text('Salah email? Keluar dan daftar ulang',
                    style: TextStyle(color: C.muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
