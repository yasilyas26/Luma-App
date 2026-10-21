import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'user_avatar.dart';

/// Tombol avatar di pojok kanan atas. Ketuk untuk membuka sidebar akun yang
/// slide dari kanan (latar gelap) berisi: Profil, Pengaturan, Log out.
class ProfileMenuButton extends StatelessWidget {
  const ProfileMenuButton({super.key, required this.onChanged, this.onHistory});

  /// Dipanggil saat "Riwayat ruangan" dipilih.
  final VoidCallback? onHistory;

  /// Dipanggil setelah kembali dari Profil/Pengaturan (untuk menyegarkan nama).
  final VoidCallback onChanged;

  Future<void> _open(BuildContext context) async {
    final choice = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, anim, __) => _AccountSidebar(
        showHistory: onHistory != null,
        animation: CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic),
      ),
      transitionBuilder: (_, __, ___, child) => child,
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

class _AccountSidebar extends StatelessWidget {
  const _AccountSidebar({required this.showHistory, required this.animation});
  final bool showHistory;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width < 640 ? size.width : 640.0;
    // Skala ikut ukuran layar (acuan 390px) supaya font, avatar, dan ikon
    // proporsional di layar kecil maupun besar.
    final s = (width / 390).clamp(0.85, 1.2).toDouble();
    final panelW = (340 * s) < width * 0.85 ? 340 * s : width * 0.85;
    // Slide dipasang di panel (bukan di Align selebar layar) supaya offset 1
    // = lebar panel dan panel muncul tepat dari tepi kanan layar.
    // ClipRect: di layar lebar app dibatasi kolom 640px (phoneFrame), jadi
    // panel tidak boleh tergambar di luar kolom saat slide masuk.
    return ClipRect(
      child: Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(animation),
          child: Material(
            color: C.card,
            child: Container(
              width: panelW,
              height: double.infinity,
              decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: C.border))),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20 * s, 12 * s, 20 * s, 20 * s),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(Icons.close, color: C.muted, size: 24 * s),
                                  tooltip: 'Tutup',
                                ),
                              ),
                              UserAvatar(size: 84 * s),
                              SizedBox(height: 14 * s),
                              Text(AuthService.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 19 * s,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(AuthService.email,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13.5 * s, color: C.muted)),
                              SizedBox(height: 20 * s),
                              Divider(height: 1, color: C.border),
                              const SizedBox(height: 10),
                              _row(context, s, 'profile', Icons.person_outline,
                                  'Profil'),
                              if (showHistory)
                                _row(context, s, 'history', Icons.history,
                                    'Riwayat ruangan'),
                              _row(context, s, 'settings', Icons.settings_outlined,
                                  'Pengaturan'),
                            ],
                          ),
                        ),
                      ),
                      Divider(height: 1, color: C.border),
                      const SizedBox(height: 10),
                      _row(context, s, 'logout', Icons.logout, 'Log out',
                          color: C.accent),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, double s, String value, IconData icon, String label,
      {Color? color}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.pop(context, value),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 15 * s),
        child: Row(
          children: [
            Icon(icon, size: 24 * s, color: color ?? C.muted),
            SizedBox(width: 16 * s),
            Text(label,
                style: TextStyle(
                    fontSize: 16 * s,
                    fontWeight: FontWeight.w600,
                    color: color ?? C.text)),
            const Spacer(),
            if (color == null)
              Icon(Icons.chevron_right, size: 22 * s, color: C.muted),
          ],
        ),
      ),
    );
  }
}
