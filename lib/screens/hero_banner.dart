import 'package:flutter/material.dart';

import '../theme.dart';

/// Banner sambutan di Home: teks di kiri, kolase poster film miring di kanan
/// dengan gradasi. Kalau poster belum ada (atau tanpa API key), dipakai
/// dekorasi gradasi dan ikon film.
class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key, required this.posters});
  final List<String> posters;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 190),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: C.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.glow, C.card],
        ),
      ),
      child: Stack(
        children: [
          // Dekorasi kanan: kolase poster atau ikon film.
          Positioned(
            right: -26,
            top: -44,
            child: posters.length >= 6
                ? _Mosaic(urls: posters)
                : const _FallbackArt(),
          ),
          // Gradasi dari kiri supaya teks tetap terbaca.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    C.card,
                    C.card.withValues(alpha: 0.94),
                    C.card.withValues(alpha: 0.35),
                    C.card.withValues(alpha: 0.05),
                  ],
                  stops: const [0, 0.5, 0.78, 1],
                ),
              ),
            ),
          ),
          // Cahaya merah lembut di pojok kiri bawah.
          Positioned(
            left: -60,
            bottom: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  C.accent.withValues(alpha: 0.22),
                  C.accent.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: C.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.movie, size: 12, color: C.accent),
                          SizedBox(width: 5),
                          Text('MOVIE NIGHT',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: C.accent)),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      const Text('Nonton bareng tanpa perdebatan.',
                          style: TextStyle(
                              fontSize: 24,
                              height: 1.22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text(
                          'Masukkan kode 5-digit dari host temanmu untuk langsung masuk ke ruang voting film bersama.',
                          style: TextStyle(
                              fontSize: 12.5, height: 1.45, color: C.muted)),
                    ],
                  ),
                ),
                const Expanded(flex: 3, child: SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiga kolom poster berselang-seling, dimiringkan.
class _Mosaic extends StatelessWidget {
  const _Mosaic({required this.urls});
  final List<String> urls;

  static const _w = 74.0;
  static const _h = 111.0;

  Widget _poster(String url) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: _w,
            height: _h,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(color: C.chip),
              frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 400),
                child: child,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _w * 3 + 24,
      height: _h * 3 + 90,
      child: Transform.rotate(
        angle: -0.2,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var col = 0; col < 3; col++)
              Padding(
                padding: EdgeInsets.only(left: col == 0 ? 0 : 8, top: col == 1 ? 34 : 0),
                child: Column(
                  children: [
                    for (var r = 0; r < 3; r++)
                      if (col * 3 + r < urls.length) _poster(urls[col * 3 + r]),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dekorasi cadangan: lingkaran cahaya dan ikon film berukuran besar.
class _FallbackArt extends StatelessWidget {
  const _FallbackArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 300,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  C.accent.withValues(alpha: 0.35),
                  C.accent.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
          Positioned(
            right: 36,
            top: 70,
            child: Transform.rotate(
              angle: -0.2,
              child: Icon(Icons.movie_filter,
                  size: 120, color: C.accent.withValues(alpha: 0.28)),
            ),
          ),
          Positioned(
            right: 120,
            top: 150,
            child: Transform.rotate(
              angle: 0.25,
              child: Icon(Icons.local_movies,
                  size: 60, color: C.accent.withValues(alpha: 0.18)),
            ),
          ),
        ],
      ),
    );
  }
}
