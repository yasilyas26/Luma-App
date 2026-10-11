import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import 'film_detail_screen.dart';
import 'h_scroll.dart';

/// Rak film horizontal dengan judul (mis. Film Teratas, Sedang Tayang).
/// Data dimuat sekali lewat [loader]; saat memuat tampil skeleton.
class FilmShelf extends StatefulWidget {
  const FilmShelf({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.loader,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Future<List<Film>> Function() loader;

  @override
  State<FilmShelf> createState() => _FilmShelfState();
}

class _FilmShelfState extends State<FilmShelf> {
  late final Future<List<Film>> _future = widget.loader();

  static const _cardWidth = 116.0;
  static const _posterHeight = 172.0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Film>>(
      future: _future,
      builder: (context, snap) {
        // Gagal dimuat atau kosong: sembunyikan rak, jangan tampilkan error.
        if (snap.connectionState == ConnectionState.done &&
            (snap.hasError || (snap.data?.isEmpty ?? true))) {
          return const SizedBox.shrink();
        }
        final loading = snap.connectionState != ConnectionState.done;
        return Padding(
          padding: const EdgeInsets.only(top: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 20, color: C.accent),
                    const SizedBox(width: 8),
                    Text(widget.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 3, 4, 12),
                child: Text(widget.subtitle,
                    style: TextStyle(fontSize: 11.5, color: C.muted)),
              ),
              SizedBox(
                height: _posterHeight + 62,
                child: loading
                    ? ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 6,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, __) => const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Skeleton(
                                width: _cardWidth,
                                height: _posterHeight,
                                radius: 12),
                            SizedBox(height: 10),
                            Skeleton(width: 90, height: 12),
                            SizedBox(height: 6),
                            Skeleton(width: 46, height: 10),
                          ],
                        ),
                      )
                    : HScroll(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final f in snap.data!)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _card(context, f),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, Film f) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openFilmDetail(context, f),
      child: SizedBox(
        width: _cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Poster(f, width: _cardWidth, height: _posterHeight, radius: 12),
            const SizedBox(height: 8),
            Text(f.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(f.year > 0 ? '${f.year}' : '',
                style: TextStyle(fontSize: 11, color: C.muted)),
          ],
        ),
      ),
    );
  }
}
