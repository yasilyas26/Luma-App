import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import '../tmdb_service.dart';

/// Kartu "Ulasan Teratas": satu ulasan komunitas TMDb yang paling tepercaya
/// (rating pengulas tertinggi, cukup panjang) untuk tiap film yang dipilih
/// anggota room. Muncul dengan animasi fade dan geser halus.
class ReviewsCard extends StatelessWidget {
  const ReviewsCard({super.key, required this.films, this.pickers = const {}});
  final List<Film> films;

  /// id film -> nama anggota yang memilihnya.
  final Map<String, List<String>> pickers;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: CardBox(
        padding: const EdgeInsets.all(16),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, size: 20, color: C.accent),
                const SizedBox(width: 8),
                const Text('Ulasan Teratas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                const Tag('TMDb'),
              ],
            ),
            const SizedBox(height: 4),
            Text('Ulasan komunitas paling tepercaya untuk semua film pilihan anggota room.',
                style: TextStyle(fontSize: 11.5, color: C.muted)),
            for (final f in films) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: C.border),
              const SizedBox(height: 16),
              _ReviewItem(film: f, pickers: pickers[f.id] ?? const []),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewItem extends StatefulWidget {
  const _ReviewItem({required this.film, this.pickers = const []});
  final Film film;
  final List<String> pickers;

  @override
  State<_ReviewItem> createState() => _ReviewItemState();
}

class _ReviewItemState extends State<_ReviewItem> {
  late final Future<Review?> _future = widget.film.tmdbId == null
      ? Future.value(null)
      : TmdbService.topReview(widget.film.tmdbId!);
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.film;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Poster(f, width: 44, height: 66, radius: 7, rating: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
                  if (widget.pickers.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Dipilih oleh ${widget.pickers.join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: C.accent)),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: C.gold),
                      const SizedBox(width: 3),
                      Text('${f.rating}',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      Text('  •  ${f.year}',
                          style: TextStyle(fontSize: 12, color: C.muted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<Review?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 130, height: 12),
                  SizedBox(height: 10),
                  Skeleton(height: 11),
                  SizedBox(height: 6),
                  Skeleton(height: 11),
                  SizedBox(height: 6),
                  Skeleton(width: 180, height: 11),
                ],
              );
            }
            final r = snap.data;
            if (r == null) {
              return Text('Belum ada ulasan untuk film ini.',
                  style: TextStyle(fontSize: 12.5, color: C.muted));
            }
            return AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(r.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                      if (r.rating != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: C.chip,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.star, size: 11, color: C.gold),
                            const SizedBox(width: 2),
                            Text(r.rating!.toStringAsFixed(0),
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('"${r.content}"',
                      maxLines: _expanded ? null : 4,
                      overflow:
                          _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                          color: C.soft)),
                  if (r.content.length > 220)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.only(top: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: Text(_expanded ? 'Tutup' : 'Selengkapnya',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: C.accent)),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
