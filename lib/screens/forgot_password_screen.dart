import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import 'password_widgets.dart';

/// Lupa kata sandi: pengguna mengisi email, lalu tautan reset dikirim ke sana.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});
  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.email);
  bool _busy = false;
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return showMsg(context, 'Alamat email tidak valid');
    }
    setState(() => _busy = true);
    try {
      await AuthService.resetPassword(email);
      if (mounted) setState(() => _sentTo = email);
    } on AppError catch (e) {
      if (mounted) showMsg(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sentTo != null;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SquareIconButton(
                  icon: Icons.arrow_back,
                  size: 40,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
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
                          sent
                              ? Icons.mark_email_read_outlined
                              : Icons.lock_reset,
                          size: 40,
                          color: C.accent),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(sent ? 'Cek Email Kamu' : 'Lupa Kata Sandi?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                      sent
                          ? 'Kami mengirim tautan untuk mengatur ulang kata sandi ke $_sentTo. Buka email itu dan ikuti langkahnya. Cek folder spam kalau belum masuk.'
                          : 'Masukkan email akunmu. Kami akan mengirim tautan untuk membuat kata sandi baru.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13.5, height: 1.5, color: C.muted)),
                  const SizedBox(height: 28),
                  if (!sent) ...[
                    const Text('Alamat Email',
                        style:
                            TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    AuthTextField(
                      controller: _email,
                      hint: 'nama@email.com',
                      icon: Icons.mail_outline,
                      type: TextInputType.emailAddress,
                      autofocus: true,
                      onSubmitted: (_) => _busy ? null : _send(),
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: _busy ? 'Mengirim...' : 'Kirim Tautan Reset',
                      trailing: Icons.send_outlined,
                      height: 50,
                      onTap: _busy ? null : _send,
                    ),
                  ] else ...[
                    PrimaryButton(
                      label: 'Kembali ke Halaman Masuk',
                      trailing: Icons.arrow_forward,
                      height: 50,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _busy ? null : _send,
                        child: Text(_busy ? 'Mengirim...' : 'Kirim ulang email',
                            style: const TextStyle(color: C.accent)),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _sentTo = null),
                        child: Text('Gunakan email lain',
                            style: TextStyle(color: C.muted)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
