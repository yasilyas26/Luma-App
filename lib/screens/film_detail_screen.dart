import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import '../tmdb_service.dart';
import 'h_scroll.dart';

/// Halaman detail film: banner, sutradara, pemeran, lalu daftar film lainnya
/// (vertikal). Mengetuk film lain membuka halaman detail film itu.
class FilmDetailScreen extends StatefulWidget {
  const FilmDetailScreen({super.key, required this.film});
  final Film film;

  @override
  State<FilmDetailScreen> createState() => _FilmDetailScreenState();
}

class _FilmDetailScreenState extends State<FilmDetailScreen> {
  late Film _film = widget.film;
  FilmExtra? _extra;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final id = widget.film.tmdbId;
    if (id != null && TmdbService.enabled) {
      _loading = true;
      _load(id);
    }
  }

  Future<void> _load(int id) async {
    try {
      final r = await Future.wait([TmdbService.film(id), TmdbService.extra(id)]);
      if (!mounted) return;
      setState(() {
        _film = r[0] as Film;
        _extra = r[1] as FilmExtra;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _film;
    final extra = _extra;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _banner(f, extra),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final g in f.genres) Tag(g),
                    Text(
                        [
                          if (f.year > 0) '${f.year}',
                          if (f.duration != '-') f.duration,
                        ].join('  •  '),
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: C.muted)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Icon(Icons.star, size: 20, color: C.gold),
                  const SizedBox(width: 5),
                  Text('${f.rating}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('  (${f.votes} suara)',
                      style: TextStyle(fontSize: 12, color: C.muted)),
                ]),
                const SizedBox(height: 16),
                _heading('Sinopsis'),
                Text(f.synopsis,
                    style: TextStyle(fontSize: 13.5, height: 1.55, color: C.soft)),
                const SizedBox(height: 20),
                _heading('Sutradara'),
                if (_loading && f.director == '-')
                  const Skeleton(width: 140, height: 16)
                else
                  Row(children: [
                    Icon(Icons.movie_creation_outlined, size: 18, color: C.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f.director == '-' ? 'Belum tersedia' : f.director,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                const SizedBox(height: 22),
                _heading('Pemeran'),
                _cast(extra),
              ],
            ),
          ),
          _others(extra),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _heading(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );

  Widget _banner(Film f, FilmExtra? extra) {
    final back = extra?.backdropUrl;
    return SizedBox(
      height: 270,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Poster(f, width: double.infinity, height: 270, radius: 0, rating: false),
          if (back != null)
            Image.network(back,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.35, 1],
                colors: [Colors.transparent, C.bg],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                        color: C.overlay, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back,
                        size: 22, color: C.onOverlay),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 8,
            child: Text(f.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800, height: 1.15)),
          ),
        ],
      ),
    );
  }

  Widget _cast(FilmExtra? extra) {
    if (extra == null) {
      return _loading
          ? SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => const Column(children: [
                  Skeleton(width: 68, height: 68, circle: true),
                  SizedBox(height: 8),
                  Skeleton(width: 60, height: 10),
                ]),
              ),
            )
          : Text('Belum tersedia', style: TextStyle(fontSize: 13, color: C.muted));
    }
    if (extra.cast.isEmpty) {
      return Text('Belum tersedia', style: TextStyle(fontSize: 13, color: C.muted));
    }
    return SizedBox(
      height: 132,
      child: HScroll(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in extra.cast)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: SizedBox(
                  width: 78,
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: C.chip,
                          shape: BoxShape.circle,
                          border: Border.all(color: C.border),
                        ),
                        child: c.photoUrl == null
                            ? Icon(Icons.person, color: C.muted, size: 30)
                            : Image.network(c.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.person, color: C.muted, size: 30)),
                      ),
                      const SizedBox(height: 8),
                      Text(c.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.2,
                              fontWeight: FontWeight.w600)),
                      if (c.character.isNotEmpty)
                        Text(c.character,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, color: C.muted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Film lainnya, disusun vertikal.
  Widget _others(FilmExtra? extra) {
    if (extra == null && !_loading) return const SizedBox.shrink();
    if (extra != null && extra.similar.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Film Lainnya'),
          if (extra == null)
            for (var i = 0; i < 3; i++) ...const [
              RowSkeleton(),
              SizedBox(height: 10),
            ]
          else
            for (final o in extra.similar) ...[
              _otherRow(o),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _otherRow(Film o) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openFilmDetail(context, o),
      child: CardBox(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Poster(o, width: 62, height: 92, radius: 10, rating: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      [
                        if (o.year > 0) '${o.year}',
                        if (o.genres.isNotEmpty) o.genres.join(' / '),
                      ].join('  •  '),
                      style: TextStyle(fontSize: 11.5, color: C.muted)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.star, size: 15, color: C.gold),
                    const SizedBox(width: 4),
                    Text('${o.rating}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: C.muted),
          ],
        ),
      ),
    );
  }
}

/// Buka halaman detail film.
Future<void> openFilmDetail(BuildContext context, Film f) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => FilmDetailScreen(film: f)));
