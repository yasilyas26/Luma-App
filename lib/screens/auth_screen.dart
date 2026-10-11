import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import 'password_widgets.dart';
import 'register_success_screen.dart';
import 'verify_email_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _tab = 0;
  bool _hide = true;
  bool _busy = false;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Akun baru: layar "berhasil" lalu onboarding. Akun lama: langsung Home.
  void _next(bool isNew) {
    final Widget page;
    if (AuthService.needsVerification) {
      // Daftar baru sudah dikirimi email; login akun lama yang belum
      // terverifikasi dikirimi sekarang.
      page = VerifyEmailScreen(newAccount: isNew, sendOnOpen: !isNew);
    } else {
      page = isNew ? const RegisterSuccessScreen() : const HomeScreen();
    }
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _run(Future<bool> Function() action) async {
    setState(() => _busy = true);
    try {
      final isNew = await action();
      if (mounted) _next(isNew);
    } on AppError catch (e) {
      if (mounted) showMsg(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    if (_tab == 1 && _name.text.trim().isEmpty) {
      return showMsg(context, 'Nama tampilan wajib diisi');
    }
    if (!_email.text.contains('@')) {
      return showMsg(context, 'Alamat email tidak valid');
    }
    if (_pass.text.length < 8) {
      return showMsg(context, 'Kata sandi minimal 8 karakter');
    }
    if (_tab == 1 && !PasswordRules.valid(_pass.text)) {
      return showMsg(context, PasswordRules.hint);
    }
    if (_tab == 1 && _confirm.text != _pass.text) {
      return showMsg(context, 'Konfirmasi kata sandi tidak sama');
    }
    final email = _email.text.trim();
    _run(() async {
      if (_tab == 0) {
        await AuthService.signIn(email, _pass.text);
        return false;
      }
      await AuthService.register(_name.text.trim(), email, _pass.text);
      return true;
    });
  }

  void _forgot() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ForgotPasswordScreen(email: _email.text.trim())));

  @override
  Widget build(BuildContext context) {
    final login = _tab == 0;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: Text('LUMA',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
                children: [
                  const Text('Selamat Datang di LUMA',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                      'Masuk atau buat akun untuk mulai membuat room voting bersama teman.',
                      style:
                          TextStyle(fontSize: 13, height: 1.4, color: C.muted)),
                  const SizedBox(height: 22),
                  SegTabs(
                      labels: const ['Masuk', 'Daftar'],
                      index: _tab,
                      onChanged: (i) => setState(() => _tab = i)),
                  const SizedBox(height: 22),
                  if (!login) ...[
                    _label('Nama Tampilan'),
                    _field(_name, 'Nama kamu', Icons.person_outline),
                    const SizedBox(height: 14),
                  ],
                  _label('Alamat Email'),
                  _field(_email, 'nama@email.com', Icons.mail_outline,
                      type: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  _label('Kata Sandi'),
                  _field(_pass, login ? 'Kata sandi kamu' : 'Kombinasi huruf dan angka', Icons.lock_outline,
                      obscure: _hide,
                      onChanged: (_) => setState(() {}),
                      suffix: InkWell(
                        onTap: () => setState(() => _hide = !_hide),
                        child: Icon(
                            _hide
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: C.muted),
                      )),
                  if (!login) ...[
                    PasswordChecklist(_pass.text),
                    const SizedBox(height: 14),
                    _label('Konfirmasi Kata Sandi'),
                    _field(_confirm, 'Ulangi kata sandi', Icons.lock_outline,
                        obscure: _hide,
                        onChanged: (_) => setState(() {})),
                    if (_confirm.text.isNotEmpty && _confirm.text != _pass.text)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Kata sandi tidak sama',
                            style: TextStyle(fontSize: 12, color: C.pink)),
                      )
                    else if (_confirm.text.isNotEmpty && _confirm.text == _pass.text)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Kata sandi cocok',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF2EAD6B))),
                      ),
                  ],
                  if (login)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: InkWell(
                          onTap: _forgot,
                          child: Text('Lupa kata sandi?',
                              style: TextStyle(
                                  fontSize: 12.5, color: C.pink)),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 22),
                  PrimaryButton(
                    label: _busy
                        ? 'Memproses...'
                        : (login ? 'Masuk ke Akun' : 'Buat Akun'),
                    trailing: Icons.arrow_forward,
                    height: 50,
                    onTap: _busy ? null : _submit,
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Divider(color: C.border)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('atau lanjutkan dengan',
                          style: TextStyle(fontSize: 12, color: C.muted)),
                    ),
                    Expanded(child: Divider(color: C.border)),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _run(AuthService.google),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: C.field,
                        foregroundColor: C.text,
                        side: BorderSide(color: C.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('G',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4285F4))),
                          SizedBox(width: 10),
                          Text('Lanjutkan dengan Google',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: Text.rich(
                TextSpan(
                  text: 'Dengan melanjutkan, kamu menyetujui ',
                  children: [
                    TextSpan(
                        text: 'Ketentuan Layanan',
                        style: TextStyle(
                            color: C.text,
                            decoration: TextDecoration.underline)),
                    TextSpan(text: ' & '),
                    TextSpan(
                        text: 'Kebijakan Privasi',
                        style: TextStyle(
                            color: C.text,
                            decoration: TextDecoration.underline)),
                    TextSpan(text: ' LUMA.'),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, height: 1.5, color: C.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _field(TextEditingController c, String hint, IconData icon,
      {bool obscure = false,
      Widget? suffix,
      TextInputType? type,
      ValueChanged<String>? onChanged}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: C.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: C.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: c,
              obscureText: obscure,
              onChanged: onChanged,
              keyboardType: type,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintStyle: TextStyle(color: C.muted),
              ),
            ),
          ),
          if (suffix != null) suffix,
        ],
      ),
    );
  }
}
