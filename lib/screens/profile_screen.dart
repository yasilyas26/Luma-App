import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import 'account_dialogs.dart';
import 'auth_screen.dart';
import 'user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _editName() async {
    final ctrl = TextEditingController(text: AuthService.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card,
        title: const Text('Ubah Nama Tampilan'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 30,
          decoration: InputDecoration(
            hintText: 'Nama kamu',
            filled: true,
            fillColor: C.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: C.border),
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: TextStyle(color: C.muted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Simpan', style: TextStyle(color: C.accent))),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == AuthService.name) return;
    try {
      await AuthService.updateName(name);
      if (mounted) {
        setState(() {});
        showMsg(context, 'Nama diperbarui');
      }
    } on AppError catch (e) {
      if (mounted) showMsg(context, e.message);
    }
  }

  Future<void> _changePhoto() async {
    try {
      final saved = await ProfilePhoto.pickAndSave();
      if (saved && mounted) showMsg(context, 'Foto profil diperbarui');
    } on AppError catch (e) {
      if (mounted) showMsg(context, e.message);
    } catch (_) {
      if (mounted) showMsg(context, 'Tidak bisa memilih gambar');
    }
  }

  Future<void> _useGoogle() async {
    try {
      await ProfilePhoto.useGooglePhoto();
      if (mounted) showMsg(context, 'Memakai foto akun Google');
    } on AppError catch (e) {
      if (mounted) showMsg(context, e.message);
    }
  }

  Future<void> _removePhoto() async {
    try {
      await ProfilePhoto.remove();
      if (mounted) showMsg(context, 'Foto profil dihapus');
    } on AppError catch (e) {
      if (mounted) showMsg(context, e.message);
    }
  }

  void _photoOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: C.accent),
                title: const Text('Pilih foto dari perangkat'),
                onTap: () {
                  Navigator.pop(ctx);
                  _changePhoto();
                },
              ),
              if (ProfilePhoto.googleUrl != null && !ProfilePhoto.showingGoogle)
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined,
                      color: C.accent),
                  title: const Text('Gunakan foto akun Google'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _useGoogle();
                  },
                ),
              if (ProfilePhoto.bytes.value != null || ProfilePhoto.showingGoogle)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: C.muted),
                  title: const Text('Hapus foto'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: C.muted)),
      );

  Future<void> _changePassword() async {
    final ok = await showChangePasswordDialog(context);
    if (ok && mounted) showMsg(context, 'Kata sandi berhasil diubah');
  }

  Future<void> _deleteAccount() async {
    final ok = await showDeleteAccountDialog(context);
    if (!ok || !mounted) return;
    ProfilePhoto.clear();
    showMsg(context, 'Akun berhasil dihapus');
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthService.name;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                SquareIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop()),
                const SizedBox(width: 14),
                const Text('Profil',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 28),
            Center(
              child: GestureDetector(
                onTap: _photoOptions,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: C.accent.withValues(alpha: 0.3),
                              blurRadius: 24)
                        ],
                      ),
                      child: const UserAvatar(size: 96),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: C.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: C.border, width: 1.5),
                        ),
                        child: const Icon(Icons.photo_camera_outlined,
                            size: 16, color: C.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _photoOptions,
                child: const Text('Ganti foto profil',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: C.accent)),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            Center(
              child: Text(AuthService.email,
                  style: TextStyle(fontSize: 13, color: C.muted)),
            ),
            const SizedBox(height: 28),
            CardBox(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _row(Icons.badge_outlined, 'Nama tampilan', name,
                      trailing: Icons.edit_outlined, onTap: _editName),
                  Divider(height: 1, color: C.border),
                  _row(Icons.mail_outline, 'Email', AuthService.email),
                  Divider(height: 1, color: C.border),
                  _row(Icons.login, 'Masuk dengan', AuthService.providerLabel),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _section('KEAMANAN'),
            CardBox(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (AuthService.usesPassword) ...[
                    _row(Icons.lock_outline, 'Kata sandi', 'Ubah kata sandi',
                        trailing: Icons.chevron_right, onTap: _changePassword),
                  ] else
                    _row(Icons.verified_user_outlined, 'Keamanan',
                        'Akun ini masuk lewat Google, kata sandi dikelola Google'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _section('ZONA BERBAHAYA'),
            CardBox(
              padding: EdgeInsets.zero,
              borderColor: C.accent.withValues(alpha: 0.45),
              child: _row(Icons.delete_forever, 'Hapus akun',
                  'Hapus akun dan semua datanya secara permanen',
                  trailing: Icons.chevron_right,
                  color: C.accent,
                  onTap: _deleteAccount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value,
      {IconData? trailing, VoidCallback? onTap, Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? C.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11.5, color: C.muted)),
                  const SizedBox(height: 2),
                  Text(value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ],
              ),
            ),
            if (trailing != null) Icon(trailing, size: 20, color: C.muted),
          ],
        ),
      ),
    );
  }
}
