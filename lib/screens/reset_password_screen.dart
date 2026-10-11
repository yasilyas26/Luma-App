import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import 'auth_screen.dart';
import 'forgot_password_screen.dart';
import 'password_widgets.dart';

/// Halaman membuat kata sandi baru, dibuka dari tautan di email reset
/// (?mode=resetPassword&oobCode=...). Kata sandi baru wajib kombinasi.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.code});
  final String code;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  String? _email;
  String? _invalid;
  bool _checking = true;
  bool _hide = true;
  bool _busy = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    try {
      final email = await AuthService.verifyResetCode(widget.code);
      if (mounted) setState(() => _email = email);
    } on AppError catch (e) {
      if (mounted) setState(() => _invalid = e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _save() async {
    if (!PasswordRules.valid(_pass.text)) {
      return showMsg(context, PasswordRules.hint);
    }
    if (_pass.text != _confirm.text) {
      return showMsg(context, 'Konfirmasi kata sandi tidak sama');
    }
    setState(() => _busy = true);
    try {
      await AuthService.confirmReset(widget.code, _pass.text);
      if (mounted) setState(() => _done = true);
    } on AppError catch (e) {
      if (mounted) showMsg(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toLogin() {
    DeepLink.resetCode = null;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
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
                child: Icon(
                    _done
                        ? Icons.check_circle_outline
                        : (_invalid != null ? Icons.link_off : Icons.lock_reset),
                    size: 40,
                    color: C.accent),
              ),
            ),
            const SizedBox(height: 22),
            if (_checking)
              const Center(child: CircularProgressIndicator(color: C.accent))
            else if (_invalid != null) ..._invalidView()
            else if (_done) ..._doneView()
            else ..._formView(),
          ],
        ),
      ),
    );
  }

  List<Widget> _invalidView() => [
        const Text('Tautan Tidak Berlaku',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('$_invalid. Minta tautan reset yang baru.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.5, color: C.muted)),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Minta Tautan Baru',
          trailing: Icons.arrow_forward,
          height: 50,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ForgotPasswordScreen())),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
              onPressed: _toLogin,
              child: Text('Kembali ke Halaman Masuk',
                  style: TextStyle(color: C.muted))),
        ),
      ];

  List<Widget> _doneView() => [
        const Text('Kata Sandi Diperbarui',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Silakan masuk dengan kata sandi barumu.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.5, color: C.muted)),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Masuk Sekarang',
          trailing: Icons.arrow_forward,
          height: 50,
          onTap: _toLogin,
        ),
      ];

  List<Widget> _formView() {
    final mismatch = _confirm.text.isNotEmpty && _confirm.text != _pass.text;
    final eye = InkWell(
      onTap: () => setState(() => _hide = !_hide),
      child: Icon(
          _hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: C.muted),
    );
    return [
      const Text('Buat Kata Sandi Baru',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Untuk akun ${_email ?? ''}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: C.muted)),
      const SizedBox(height: 28),
      const Text('Kata Sandi Baru',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      AuthTextField(
        controller: _pass,
        hint: 'Kombinasi huruf dan angka',
        icon: Icons.lock_outline,
        obscure: _hide,
        suffix: eye,
        autofocus: true,
        onChanged: (_) => setState(() {}),
      ),
      PasswordChecklist(_pass.text),
      const SizedBox(height: 16),
      const Text('Konfirmasi Kata Sandi',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      AuthTextField(
        controller: _confirm,
        hint: 'Ulangi kata sandi',
        icon: Icons.lock_outline,
        obscure: _hide,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _busy ? null : _save(),
      ),
      if (mismatch)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Kata sandi tidak sama',
              style: TextStyle(fontSize: 12, color: C.pink)),
        ),
      const SizedBox(height: 24),
      PrimaryButton(
        label: _busy ? 'Menyimpan...' : 'Simpan Kata Sandi',
        trailing: Icons.check,
        height: 50,
        onTap: _busy ? null : _save,
      ),
    ];
  }
}
