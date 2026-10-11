import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;

  static const _titles = [
    'Voting Film Semudah\nMenggeser Jari',
    'Buat Room, Undang\nTeman dengan Kode',
    'Satu Film Pemenang,\nTanpa Debat',
  ];
  static const _descs = [
    'Kumpulkan rekomendasi bareng teman, swipe film yang kamu suka, dan temukan film pemenang secara otomatis.',
    'Host membuat room dengan filter genre dan tahun, lalu teman bergabung memakai kode 5 digit.',
    'Server menghitung suara kelompok dan menampilkan satu film pemenang yang adil untuk semua.',
  ];

  void _toHome() => Navigator.of(context)
      .pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [C.glow, C.bg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 20, 0),
                child: Row(
                  children: [
                    const Icon(Icons.movie, color: C.accent, size: 26),
                    const SizedBox(width: 4),
                    const Text('LUMA',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    InkWell(
                      onTap: _toHome,
                      child: Text('Lewati',
                          style: TextStyle(fontSize: 13, color: C.muted)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _page,
                  itemCount: 3,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => Column(
                    children: [
                      Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown, child: _illustration(i))),
                      Text(_titles[i],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22,
                              height: 1.25,
                              fontWeight: FontWeight.w700)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                        child: Text(_descs[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13.5, height: 1.45, color: C.muted)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 26 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? C.accent : C.chip,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: PrimaryButton(
                  label: _index == 2 ? 'Mulai Sekarang' : 'Lanjut',
                  trailing: Icons.arrow_forward,
                  height: 52,
                  onTap: () => _index == 2
                      ? _toHome()
                      : _page.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _illustration(int i) {
    switch (i) {
      case 0:
        return Center(
          child: Transform.rotate(
            angle: 0.06,
            child: Container(
              width: 290,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: C.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Poster(interstellar,
                          height: 170, width: double.infinity, radius: 12),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: C.overlay,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(children: [
                            Icon(Icons.circle, size: 7, color: C.accent),
                            SizedBox(width: 5),
                            Text('SWIPE KANAN',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    color: C.onOverlay,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('Interstellar Odyssey',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text('Sci-Fi • 2j 49m',
                      style: TextStyle(fontSize: 12, color: C.muted)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 70,
                        height: 28,
                        child: Stack(children: [
                          Positioned(left: 0, child: Avatar('R', size: 28)),
                          Positioned(
                              left: 18,
                              child: Avatar('A', color: C.accent, size: 28)),
                          Positioned(
                              left: 36,
                              child: Avatar('M', color: C.gold, size: 28)),
                        ]),
                      ),
                      const Text('+3 Setuju',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      const CircleAvatar(
                          radius: 14,
                          backgroundColor: C.accent,
                          child: Icon(Icons.thumb_up,
                              size: 14, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      case 1:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final d in '84920'.split(''))
                    Container(
                      width: 48,
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: C.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: C.accent.withValues(alpha: 0.6)),
                      ),
                      child: Text(d,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const Wrap(
                spacing: 8,
                children: [Tag('Sci-Fi'), Tag('Drama'), Tag('2015 - 2025')],
              ),
            ],
          ),
        );
      default:
        return Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: C.card,
              shape: BoxShape.circle,
              border: Border.all(color: C.border),
              boxShadow: [
                BoxShadow(
                    color: C.gold.withValues(alpha: 0.2), blurRadius: 40),
              ],
            ),
            child: Icon(Icons.emoji_events, size: 56, color: C.gold),
          ),
        );
    }
  }
}
