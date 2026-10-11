import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'user_avatar.dart';

/// Tombol avatar di pojok kanan atas. Ketuk untuk membuka dialog akun di tengah
/// layar (latar gelap) berisi: Profil, Pengaturan, Log out.
class ProfileMenuButton extends StatelessWidget {
  const ProfileMenuButton(
      {super.key, required this.onChanged, this.onHistory});

  /// Dipanggil saat "Riwayat ruangan" dipilih.
  final VoidCallback? onHistory;

  /// Dipanggil setelah kembali dari Profil/Pengaturan (untuk menyegarkan nama).
  final VoidCallback onChanged;

  Future<void> _open(BuildContext context) async {
    final choice = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _AccountDialog(showHistory: onHistory != null),
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case 'profile':
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
        onChanged();
      case 'history':
        onHistory?.call();
      case 'settings':
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        onChanged();
      case 'logout':
        await _logout(context);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card,
        title: const Text('Keluar dari akun?'),
        content: const Text(
            'Kamu perlu login lagi untuk membuat atau bergabung ke room.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Batal', style: TextStyle(color: C.muted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out', style: TextStyle(color: C.accent))),
        ],
      ),
    );
    if (ok != true) return;
    ProfilePhoto.clear();
    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Menu akun',
      child: GestureDetector(
        onTap: () => _open(context),
        child: const UserAvatar(size: 44),
      ),
    );
  }
}

class _AccountDialog extends StatelessWidget {
  const _AccountDialog({required this.showHistory});
  final bool showHistory;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: C.muted),
                  tooltip: 'Tutup',
                ),
              ),
              const UserAvatar(size: 84),
              const SizedBox(height: 14),
              Text(AuthService.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(AuthService.email,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, color: C.muted)),
              const SizedBox(height: 20),
              Divider(height: 1, color: C.border),
              const SizedBox(height: 10),
              _row(context, 'profile', Icons.person_outline, 'Profil'),
              if (showHistory)
                _row(context, 'history', Icons.history, 'Riwayat ruangan'),
              _row(context, 'settings', Icons.settings_outlined, 'Pengaturan'),
              const SizedBox(height: 10),
              Divider(height: 1, color: C.border),
              const SizedBox(height: 10),
              _row(context, 'logout', Icons.logout, 'Log out', color: C.accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String value, IconData icon, String label,
      {Color? color}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.pop(context, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color ?? C.muted),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color ?? C.text)),
            const Spacer(),
            if (color == null)
              Icon(Icons.chevron_right, size: 22, color: C.muted),
          ],
        ),
      ),
    );
  }
}
