import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data.dart';
import '../services.dart';
import '../theme.dart';
import 'share_sheet.dart';
import 'user_avatar.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.code});
  final String code;

  /// Jumlah layar hasil yang sedang terbuka (cegah dobel saat status berubah).
  static int openCount = 0;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    ResultScreen.openCount++;
  }

  @override
  void dispose() {
    ResultScreen.openCount--;
    super.dispose();
  }

  /// Animasi pengumuman pemenang sudah selesai diputar.
  bool _revealed = false;

  /// Sudah menutup layar ini (cegah pop berulang yang membuang lobby juga).
  bool _leaving = false;

  String get code => widget.code;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<PickData>>(
          stream: RoomService.watchPicks(code),
          builder: (context, picksSnap) => StreamBuilder<Map<String, String>>(
            stream: RoomService.watchVotes(code),
            builder: (context, votesSnap) => StreamBuilder<List<MemberData>>(
              stream: RoomService.watchMembers(code),
              builder: (context, memSnap) => StreamBuilder<RoomData?>(
                stream: RoomService.watchRoom(code),
                builder: (context, roomSnap) {
                  final picks = picksSnap.data ?? const <PickData>[];
                  final votes = votesSnap.data ?? const <String, String>{};
                  final members = memSnap.data ?? const <MemberData>[];
                  final room = roomSnap.data;
                  if (!picksSnap.hasData) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
                      children: const [
                        Skeleton(height: 64, radius: 14),
                        SizedBox(height: 14),
                        Skeleton(height: 380, radius: 16),
                        SizedBox(height: 22),
                        Skeleton(width: 220, height: 16),
                        SizedBox(height: 12),
                        Skeleton(height: 70, radius: 10),
                        SizedBox(height: 8),
                        Skeleton(height: 70, radius: 10),
                        SizedBox(height: 8),
                        Skeleton(height: 70, radius: 10),
                      ],
                    );
                  }
                  if (picks.isEmpty) {
                    return Center(
                        child: Text('Belum ada data',
                            style: TextStyle(color: C.muted)));
                  }
                  if (room?.status == 'selecting') {
                    // Room dibuka kembali untuk memilih ulang: kembali ke lobby.
                    if (!_leaving) {
                      _leaving = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      });
                    }
                    return const Center(
                        child: CircularProgressIndicator(color: C.accent));
                  }
                  final done =
                      room?.status == 'completed' || room?.status == 'closed';                  final everyone =
                      members.isNotEmpty && votes.length >= members.length;
                  // Hasil baru muncul setelah semua anggota vote
                  // (atau host menutup sesi lebih awal).
                  if (!done && !everyone) {
                    return _waiting(context, members, votes, room);
                  }
                  // Seri atau tanpa suara: belum ada pemenang.
                  final counts = <String, int>{};
                  for (final v in votes.values) {
                    counts[v] = (counts[v] ?? 0) + 1;
                  }
                  final top = counts.values.fold<int>(0, max);
                  final leaders = [
                    for (final p in picks)
                      if (top > 0 && (counts[p.film.id] ?? 0) == top) p.film
                  ];
                  if (leaders.length != 1) {
                    return _noWinner(context, leaders, top, room);
                  }
                  if (!_revealed) {
                    return _Reveal(
                      films: [for (final p in picks) p.film],
                      winner: _winner(picks, votes),
                      onDone: () {
                        if (mounted) setState(() => _revealed = true);
                      },
                    );
                  }
                  return _content(context, picks, votes, members, room);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Film _winner(List<PickData> picks, Map<String, String> votes) {
    final cnt = <String, int>{};
    for (final v in votes.values) {
      cnt[v] = (cnt[v] ?? 0) + 1;
    }
    final films = [for (final p in picks) p.film]..sort((a, b) {
        final c = (cnt[b.id] ?? 0).compareTo(cnt[a.id] ?? 0);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return films.first;
  }

  /// Belum ada pemenang (seri atau tidak ada suara): kembali ke room yang sama.
  Widget _noWinner(
      BuildContext context, List<Film> tied, int votes, RoomData? room) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 20),
      children: [
        Icon(Icons.balance_rounded, size: 52, color: C.gold),
        const SizedBox(height: 14),
        const Text('Belum Ada Pemenang',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
            tied.isEmpty
                ? 'Belum ada suara yang masuk.'
                : 'Hasilnya seri, ${tied.length} film sama-sama mendapat $votes suara.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.5, color: C.muted)),
        const SizedBox(height: 22),
        for (final f in tied) ...[
          CardBox(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Poster(f, width: 50, height: 74, radius: 8, rating: false),
              const SizedBox(width: 12),
              Expanded(
                child: Text(f.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
              Text('$votes suara',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: C.accent)),
            ]),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'Pilih Ulang di Room Ini',
          icon: Icons.replay,
          onTap: () => RoomService.reopenRoom(code),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: C.text,
            side: BorderSide(color: C.border),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Kembali ke Room'),
        ),
      ],
    );
  }

  /// Menunggu semua anggota selesai vote.
  Widget _waiting(BuildContext context, List<MemberData> members,
      Map<String, String> votes, RoomData? room) {
    final isHost = room?.isHost ?? false;
    final total = members.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      children: [
        Icon(Icons.hourglass_top_rounded, size: 44, color: C.accent),
        const SizedBox(height: 14),
        const Text('Suaramu sudah masuk!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Hasil akan muncul setelah semua anggota selesai vote.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 22),
        CardBox(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(children: [
                Text('${votes.length} dari $total anggota sudah vote',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: total == 0 ? null : votes.length / total,
                  minHeight: 5,
                  backgroundColor: C.chip,
                  valueColor: const AlwaysStoppedAnimation(C.accent),
                ),
              ),
              const SizedBox(height: 14),
              for (final m in members)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    MemberAvatar(uid: m.uid, name: m.name, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(m.isMe ? 'Kamu' : m.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ),
                    votes.containsKey(m.uid)
                        ? const Icon(Icons.check_circle,
                            size: 20, color: C.accent)
                        : Text('Menunggu...',
                            style: TextStyle(fontSize: 12, color: C.muted)),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (isHost) ...[
          PrimaryButton(
            label: 'Tampilkan Hasil Sekarang',
            icon: Icons.flag_outlined,
            onTap: () => RoomService.closeRoom(code),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context).popUntil((r) => r.isFirst),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: C.text,
            side: BorderSide(color: C.border),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Kembali ke Beranda'),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, List<PickData> picks,
      Map<String, String> votes, List<MemberData> members, RoomData? room) {
    final names = {for (final m in members) m.uid: m.isMe ? 'Kamu' : m.name};
    final total = members.isEmpty ? 1 : members.length;
    final rows = [
      for (final p in picks)
        (
          p.film,
          [
            for (final e in votes.entries)
              if (e.value == p.film.id) names[e.key] ?? '-'
          ],
        ),
    ]..sort((a, b) {
        final c = b.$2.length.compareTo(a.$2.length);
        return c != 0 ? c : a.$1.id.compareTo(b.$1.id);
      });
    final voters = {
      for (final p in picks)
        p.film.id: [
          for (final e in votes.entries)
            if (e.value == p.film.id) e.key
        ],
    };
    final winner = rows.first.$1;
    final winners = rows.first.$2;
    final pct = (winners.length * 100 / total).round();
    final isHost = room?.isHost ?? false;
    final done = room?.status == 'completed' || room?.status == 'closed';
    final closed = room?.status == 'closed';

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
      children: [
        CardBox(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: C.chip,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.emoji_events, size: 20, color: C.gold),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      done
                          ? 'PILIHAN MUTLAK KELOMPOK'
                          : 'HASIL SEMENTARA (${votes.length}/${members.length} VOTE)',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: C.gold)),
                  Text(done ? 'Film Pemenang Terpilih' : 'Film Unggulan Saat Ini',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _winnerCard(winner, winners, voters[winner.id] ?? const [], total, pct),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.bar_chart, size: 20),
              const SizedBox(width: 6),
              const Text('Distribusi Suara Kelompok',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${members.length} Partisipan',
                  style: TextStyle(fontSize: 11, color: C.muted)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < rows.length; i++) ...[
          _voteRow(i, rows[i].$1, rows[i].$2, total),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height: 46,
          child: OutlinedButton.icon(
            onPressed: () => showShareSheet(
              context,
              ShareData(
                code: code,
                winner: winner,
                pct: pct,
                winnerVotes: winners.length,
                total: total,
                rows: rows,
              ),
            ),
            icon: Icon(Icons.share_outlined,
                size: 18, color: C.pink),
            label: const Text('Bagikan Hasil Voting',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: C.text,
              backgroundColor: C.card,
              side: BorderSide(color: C.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: isHost && !closed ? 'Tutup & Akhiri Sesi Room' : 'Kembali ke Beranda',
          icon: isHost && !closed ? Icons.lock_outline : Icons.home_outlined,
          onTap: () async {
            if (isHost && !closed) await RoomService.endRoom(code);
            if (!context.mounted) return;
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
      ],
    );
  }

  Widget _winnerCard(
      Film f, List<String> who, List<String> uids, int total, int pct) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Poster(f, width: double.infinity, height: 230, radius: 0, rating: false),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, C.card.withValues(alpha: 0.97)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: C.overlay,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.border),
                    ),
                    child: Row(children: [
                      Icon(Icons.star, size: 14, color: C.gold),
                      const SizedBox(width: 4),
                      Text('${f.rating}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: C.onOverlay,
                              fontWeight: FontWeight.w800)),
                      const Text(' IMDb',
                          style: TextStyle(
                              fontSize: 10.5, color: C.onOverlayMuted)),
                    ]),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: C.overlay,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.border),
                    ),
                    child: Text('${f.year}',
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: C.onOverlay,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MENANG TELAK!',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: C.pink)),
                          const SizedBox(height: 4),
                          Text(f.title,
                              style: const TextStyle(
                                  fontSize: 25, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: C.bg.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.border),
                      ),
                      child: Column(children: [
                        Text('Konsensus',
                            style: TextStyle(fontSize: 10.5, color: C.muted)),
                        Text('$pct%',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: C.pink)),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Tag(f.duration, fontSize: 11.5),
                  Tag(f.genres.join(' / '), fontSize: 11.5),
                  Tag('Sutradara: ${f.director}', fontSize: 11.5),
                ]),
                const SizedBox(height: 14),
                CardBox(
                  color: C.deep,
                  radius: 10,
                  child: Row(
                    children: [
                      Icon(Icons.how_to_vote_outlined,
                          size: 22, color: C.pink),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${who.length} dari $total Suara Masuk',
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600)),
                            Text('Disetujui oleh ${who.join(', ')}',
                                style: TextStyle(
                                    fontSize: 11.5, color: C.muted)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 18.0 * who.length + 12,
                        height: 28,
                        child: Stack(children: [
                          for (var i = 0; i < who.length; i++)
                            Positioned(
                                left: 18.0 * i,
                                child: MemberAvatar(
                                    uid: i < uids.length ? uids[i] : '',
                                    name: who[i],
                                    size: 28)),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                CardBox(
                  color: C.deep,
                  radius: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.rate_review_outlined,
                            size: 14, color: C.muted),
                        SizedBox(width: 6),
                        Text('ULASAN TERATAS KOMUNITAS TMDB',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: C.muted)),
                      ]),
                      SizedBox(height: 8),
                      Text(
                          '"Visual luar biasa dan tata suara yang spektakuler untuk ditonton bersama."',
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                              color: C.soft)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _voteRow(int rank, Film f, List<String> who, int total) {
    final first = rank == 0;
    final pct = who.length / total;
    return CardBox(
      padding: const EdgeInsets.all(12),
      radius: 10,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: first ? C.gold : C.chip,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text('${rank + 1}',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: first ? Colors.black : C.muted)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(who.isEmpty ? 'Tidak ada suara' : who.join(', '),
                        style: TextStyle(fontSize: 11, color: C.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${who.length} Suara',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: first ? C.accent : C.text)),
                  Text('${(pct * 100).round()}%',
                      style: TextStyle(fontSize: 11, color: C.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: C.chip,
              valueColor: AlwaysStoppedAnimation(first ? C.accent : C.muted),
            ),
          ),
        ],
      ),
    );
  }
}


/// Pengumuman pemenang: poster kandidat muncul dan hilang bergantian (fade
/// in/out), lalu berhenti di film pemenang.
class _Reveal extends StatefulWidget {
  const _Reveal(
      {required this.films, required this.winner, required this.onDone});
  final List<Film> films;
  final Film winner;
  final VoidCallback onDone;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  late final List<Film> _seq;
  int _i = 0;
  Timer? _timer;

  bool get _last => _i >= _seq.length - 1;

  @override
  void initState() {
    super.initState();
    final others = [
      for (final f in widget.films)
        if (f.id != widget.winner.id) f
    ]..shuffle(Random());
    _seq = [...others.take(5), widget.winner];
    _timer = Timer.periodic(const Duration(milliseconds: 650), (t) {
      if (_last) {
        t.cancel();
        _timer = Timer(const Duration(milliseconds: 1700), widget.onDone);
        return;
      }
      setState(() => _i++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = _seq[_i];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Text(
              _last ? 'PEMENANGNYA ADALAH' : 'MENGHITUNG SUARA...',
              key: ValueKey(_last),
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: _last ? C.gold : C.muted),
            ),
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Column(
              key: ValueKey(f.id),
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _last
                        ? [
                            BoxShadow(
                                color: C.accent.withValues(alpha: 0.45),
                                blurRadius: 36)
                          ]
                        : null,
                  ),
                  child: Poster(f,
                      width: 210, height: 310, radius: 16, rating: false),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 280,
                  child: Text(f.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
