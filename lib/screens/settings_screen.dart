import 'package:flutter/material.dart';

import '../app_info.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
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
                const Text('Pengaturan',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 24),
            _section('TAMPILAN'),
            CardBox(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(C.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                          size: 20, color: C.accent),
                      const SizedBox(width: 10),
                      const Text('Tema aplikasi',
                          style: TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Pilih tampilan yang paling nyaman di matamu.',
                      style: TextStyle(fontSize: 12, color: C.muted)),
                  const SizedBox(height: 14),
                  SegTabs(
                    labels: const ['Sistem', 'Terang', 'Gelap'],
                    icons: const [
                      Icons.brightness_auto_outlined,
                      Icons.light_mode_outlined,
                      Icons.dark_mode_outlined,
                    ],
                    index: switch (ThemeController.mode.value) {
                      ThemeMode.system => 0,
                      ThemeMode.light => 1,
                      ThemeMode.dark => 2,
                    },
                    onChanged: (i) async {
                      await ThemeController.setMode(
                          [ThemeMode.system, ThemeMode.light, ThemeMode.dark][i]);
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                      ThemeController.mode.value == ThemeMode.system
                          ? 'Mengikuti pengaturan perangkat (sekarang: ${C.dark ? 'gelap' : 'terang'}).'
                          : 'Tema diatur manual.',
                      style: TextStyle(fontSize: 11.5, color: C.muted)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _section('TENTANG'),
            CardBox(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _info(Icons.info_outline, 'Versi', appVersion),
                  Divider(height: 1, color: C.border),
                  _info(Icons.movie_filter_outlined, 'Data film', 'TMDb & OMDb'),
                ],
              ),
            ),
          ],
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

  Widget _info(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: C.accent),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 13.5, color: C.muted)),
          ],
        ),
      );
}
