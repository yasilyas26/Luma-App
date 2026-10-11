import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import 'password_widgets.dart';

final _scrim = Colors.black.withValues(alpha: 0.75);

/// Dialog ubah kata sandi (kata sandi lama, baru, dan konfirmasi baru).
/// Mengembalikan true kalau berhasil.
Future<bool> showChangePasswordDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: _scrim,
    barrierDismissible: false,
    builder: (_) => const _ChangePasswordDialog(),
  );
  return ok == true;
}

/// Dialog hapus akun. Konfirmasinya: pengguna harus memasukkan ulang kata
/// sandinya (akun Google: login Google ulang). Mengembalikan true kalau terhapus.
Future<bool> showDeleteAccountDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: _scrim,
    barrierDismissible: false,
    builder: (_) => const _DeleteAccountDialog(),
  );
  return ok == true;
}

/// Kolom kata sandi dengan tombol lihat/sembunyikan.
class _PwField extends StatelessWidget {
  const _PwField({
    required this.controller,
    required this.label,
    required this.hide,
    required this.onToggle,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final bool hide;
  final VoidCallback onToggle;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: hide,
            autofocus: autofocus,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: C.bg,
              prefixIcon: Icon(Icons.lock_outline, size: 20, color: C.muted),
              suffixIcon: IconButton(
                onPressed: onToggle,
                icon: Icon(
                    hide
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: C.muted),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: C.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: C.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: C.accent, width: 1.5),
              ),
            ),
          ),
        ],
      );
}

// ---------------------------------------------------------- Ubah sandi

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    String? err;
    if (_current.text.isEmpty) {
      err = 'Masukkan kata sandi saat ini';
    } else if (!PasswordRules.valid(_next.text)) {
      err = PasswordRules.hint;
    } else if (_next.text == _current.text) {
      err = 'Kata sandi baru harus berbeda dari yang lama';
    } else if (_next.text != _confirm.text) {
      err = 'Konfirmasi kata sandi tidak sama';
    }
    if (err != null) return setState(() => _error = err);

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.changePassword(_current.text, _next.text);
      if (mounted) Navigator.pop(context, true);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan, coba lagi');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mismatch =
        _confirm.text.isNotEmpty && _confirm.text != _next.text;
    return AlertDialog(
      backgroundColor: C.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Ubah Kata Sandi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PwField(
                controller: _current,
                label: 'Kata sandi saat ini',
                hide: _hide,
                autofocus: true,
                onToggle: () => setState(() => _hide = !_hide),
              ),
              const SizedBox(height: 14),
              _PwField(
                controller: _next,
                label: 'Kata sandi baru',
                hide: _hide,
                onChanged: (_) => setState(() {}),
                onToggle: () => setState(() => _hide = !_hide),
              ),
              PasswordChecklist(_next.text),
              const SizedBox(height: 14),
              _PwField(
                controller: _confirm,
                label: 'Konfirmasi kata sandi baru',
                hide: _hide,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                onToggle: () => setState(() => _hide = !_hide),
              ),
              if (mismatch)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Kata sandi tidak sama',
                      style: TextStyle(fontSize: 12, color: C.pink)),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(fontSize: 12.5, color: C.pink)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text('Batal', style: TextStyle(color: C.muted)),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Menyimpan...' : 'Simpan',
              style: const TextStyle(color: C.accent)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------- Hapus akun

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  /// Akun email wajib mengisi kata sandi; akun Google dikonfirmasi lewat popup.
  bool get _ready => !AuthService.usesPassword || _password.text.isNotEmpty;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.deleteAccount(
          password: AuthService.usesPassword ? _password.text : null);
      if (mounted) Navigator.pop(context, true);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan, coba lagi');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: C.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Hapus Akun?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                    'Tindakan ini permanen. Akun, foto profil, dan room yang kamu buat akan dihapus. Kamu akan keluar dari room lain yang kamu ikuti.',
                    style: TextStyle(fontSize: 12.5, height: 1.45, color: C.text)),
              ),
              const SizedBox(height: 16),
              if (AuthService.usesPassword) ...[
                Text('Untuk keamanan, masukkan ulang kata sandimu untuk mengonfirmasi.',
                    style: TextStyle(fontSize: 12.5, color: C.muted)),
                const SizedBox(height: 12),
                _PwField(
                  controller: _password,
                  label: 'Kata sandi kamu',
                  hide: _hide,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                  onToggle: () => setState(() => _hide = !_hide),
                ),
              ] else
                Text(
                    'Untuk keamanan, kamu akan diminta login Google sekali lagi untuk mengonfirmasi.',
                    style: TextStyle(fontSize: 12.5, color: C.muted)),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(fontSize: 12.5, color: C.pink)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text('Batal', style: TextStyle(color: C.muted)),
        ),
        TextButton(
          onPressed: (_busy || !_ready) ? null : _submit,
          child: Text(_busy ? 'Menghapus...' : 'Hapus Akun',
              style: TextStyle(color: _ready && !_busy ? C.accent : C.muted)),
        ),
      ],
    );
  }
}
