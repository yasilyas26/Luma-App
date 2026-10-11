import 'package:flutter/material.dart';

import '../data.dart';
import '../services.dart';
import '../theme.dart';
import 'result_screen.dart';
import 'user_avatar.dart';

class VotingScreen extends StatefulWidget {
  const VotingScreen({super.key, required this.code});
  final String code;

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  int _index = 0;
  double _dx = 0;
  bool _voting = false;
  bool _anim = false;

  void _skip(int total) => setState(() {
        _index = (_index + 1) % total;
        _dx = 0;
      });

  /// Kartu terbang ke kanan (vote) atau kiri (lewati), lalu aksinya dijalankan.
  Future<void> _fling(int dir, Film f, int total) async {
    if (_voting || _anim) return;
    setState(() {
      _anim = true;
      _dx = dir * 560.0;
    });
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    if (dir > 0) {
      await _vote(f);
    } else {
      _skip(total);
    }
    if (mounted) setState(() => _anim = false);
  }

  Future<void> _vote(Film f) async {
    if (_voting) return;
    setState(() => _voting = true);
    try {
      await RoomService.vote(widget.code, f.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ResultScreen(code: widget.code)));
    } catch (_) {
      if (mounted) {
        setState(() {
          _voting = false;
          _anim = false;
          _dx = 0;
        });
        showMsg(context, 'Gagal mengirim vote, coba lagi');
      }
    }
  }

  void _info(Film f) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.card,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Sutradara: ${f.director} • IMDb ${f.rating}',
                style: TextStyle(fontSize: 12.5, color: C.muted)),
            const SizedBox(height: 12),
            Text(f.synopsis, style: const TextStyle(fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<PickData>>(
          stream: RoomService.watchPicks(widget.code),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Skeleton(height: 74, radius: 12),
                    SizedBox(height: 22),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Skeleton(width: 190, height: 12)),
                    SizedBox(height: 12),
                    Expanded(child: Skeleton(height: double.infinity, radius: 16)),
                    SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Skeleton(width: 62, height: 62, circle: true),
                        SizedBox(width: 16),
                        Skeleton(width: 44, height: 44, circle: true),
                        SizedBox(width: 16),
                        Skeleton(width: 62, height: 62, circle: true),
                      ],
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              );
            }
            final films = [for (final p in snap.data ?? const <PickData>[]) p.film];
            if (films.isEmpty) {
              return Center(
                  child: Text('Belum ada kandidat film',
                      style: TextStyle(color: C.muted)));
            }
            if (_index >= films.length) _index = 0;
            final film = films[_index];
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _progress(),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('FILM ${_index + 1} DARI ${films.length} KANDIDAT FINAL',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: C.muted)),
                      const Spacer(),
                      Icon(Icons.touch_app_outlined,
                          size: 14, color: C.pink),
                      const SizedBox(width: 4),
                      Text('Interaktif',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: C.pink)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => Center(
                      child: GestureDetector(
                        onPanUpdate: (d) => setState(() => _dx += d.delta.dx),
                        onPanEnd: (_) {
                          if (_dx > 110) {
                            _fling(1, film, films.length);
                          } else if (_dx < -110) {
                            _fling(-1, film, films.length);
                          } else {
                            setState(() => _dx = 0);
                          }
                        },
                        child: AnimatedContainer(
                          duration: Duration(
                              milliseconds: _anim ? 280 : (_dx == 0 ? 200 : 0)),
                          curve: Curves.easeOut,
                          transform: Matrix4.identity()
                            ..translate(_dx)
                            ..rotateZ(_dx / 1500),
                          transformAlignment: Alignment.bottomCenter,
                          child: _card(film, (box.maxHeight - 170).clamp(150.0, 340.0)),
                        ),
                      ),
                    ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swipe, size: 18, color: C.muted),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                            'Geser ke kanan untuk vote pilihanmu, atau geser ke kiri untuk lewati',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: C.muted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _round(Icons.close, 62, C.text,
                          () => _fling(-1, film, films.length)),
                      const SizedBox(width: 16),
                      _round(Icons.info_outline, 44, C.gold, () => _info(film)),
                      const SizedBox(width: 16),
                      _round(Icons.favorite, 62, C.accent,
                          () => _fling(1, film, films.length)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _round(IconData icon, double size, Color fg, VoidCallback t) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: t,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: C.chip,
          shape: BoxShape.circle,
          border: Border.all(color: C.border),
        ),
        child: Icon(icon, color: fg, size: size * 0.42),
      ),
    );
  }

  Widget _progress() {
    return StreamBuilder<List<MemberData>>(
      stream: RoomService.watchMembers(widget.code),
      builder: (context, memSnap) => StreamBuilder<Map<String, String>>(
        stream: RoomService.watchVotes(widget.code),
        builder: (context, voteSnap) {
          final members = memSnap.data ?? const <MemberData>[];
          final votes = voteSnap.data ?? const <String, String>{};
          final total = members.isEmpty ? 1 : members.length;
          return CardBox(
            padding: const EdgeInsets.all(12),
            radius: 12,
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: C.accent),
                    const SizedBox(width: 8),
                    Text('${votes.length} dari ${members.length} anggota sudah vote',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    SizedBox(
                      width: 18.0 * members.length.clamp(1, 4) + 12,
                      height: 28,
                      child: Stack(children: [
                        for (var i = 0; i < members.length && i < 4; i++)
                          Positioned(
                              left: 18.0 * i,
                              child: MemberAvatar(
                                  uid: members[i].uid,
                                  name: members[i].name,
                                  size: 28)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: votes.length / total,
                    minHeight: 4,
                    backgroundColor: C.chip,
                    valueColor: const AlwaysStoppedAnimation(C.accent),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(Film f, double posterHeight) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _dx > 40
              ? C.accent
              : _dx < -40
                  ? C.muted
                  : C.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Poster(f,
                  width: double.infinity, height: posterHeight, radius: 0, rating: false),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, C.card.withValues(alpha: 0.95)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: C.overlay,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.border),
                  ),
                  child: Row(children: [
                    Icon(Icons.star, size: 15, color: C.gold),
                    const SizedBox(width: 4),
                    Text('${f.rating}',
                        style: const TextStyle(
                            fontSize: 14,
                            color: C.onOverlay,
                            fontWeight: FontWeight.w800)),
                    Text(' (${f.votes} votes)',
                        style: const TextStyle(
                            fontSize: 11, color: C.onOverlayMuted)),
                  ]),
                ),
              ),
              const Positioned(
                right: 12,
                top: 12,
                child: Row(children: [
                  _Badge('4K UHD'),
                  SizedBox(width: 6),
                  _Badge('DOLBY'),
                ]),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final g in f.genres) ...[
                      Tag(g),
                      const SizedBox(width: 6),
                    ],
                    Text('•  ${f.duration}  •  ${f.year}',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: C.muted)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(f.title,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                    ),
                    Text(f.age,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: C.gold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(f.synopsis,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, height: 1.4, color: C.soft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: C.overlay,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: C.border),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: C.onOverlay,
                fontWeight: FontWeight.w700)),
      );
}
