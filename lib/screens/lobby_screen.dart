import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data.dart';
import '../services.dart';
import '../theme.dart';
import 'user_avatar.dart';
import 'result_screen.dart';
import 'reviews_card.dart';
import 'search_screen.dart';
import 'voting_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key, required this.code});
  final String code;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  StreamSubscription<RoomData?>? _sub;
  String? _lastStatus;
  RoomData? _room;

  String get code => widget.code;

  @override
  void initState() {
    super.initState();
    _sub = RoomService.watchRoom(code).listen(_onRoom);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onRoom(RoomData? r) {
    if (!mounted) return;
    if (r == null) {
      showMsg(context, 'Room sudah dihapus oleh host');
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _room = r);
    // Pindah layar hanya saat status berubah.
    if (r.status != _lastStatus) {
      final first = _lastStatus == null;
      _lastStatus = r.status;
      if (r.status == 'closed' && !first) {
        // Host mengakhiri sesi: langsung keluar ke beranda tanpa animasi hasil.
        final nav = Navigator.of(context);
        nav.popUntil((route) => route.isFirst);
        if (!r.isHost) {
          // Dialog dipasang di navigator utama supaya tetap tampil di beranda.
          nav.push(DialogRoute<void>(
            context: nav.context,
            barrierColor: Colors.black.withValues(alpha: 0.6),
            builder: (ctx) => AlertDialog(
              backgroundColor: C.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              icon: const Icon(Icons.lock_outline, color: C.accent, size: 34),
              title: const Text('Sesi Ditutup',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              content: Text(
                  'Host telah mengakhiri sesi room ini. Kamu dikembalikan ke beranda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, height: 1.5, color: C.muted)),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Mengerti',
                      style: TextStyle(color: C.accent)),
                ),
              ],
            ),
          ));
        }
        return;
      }
      if (r.status == 'voting') {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => VotingScreen(code: code)));
      } else if ((r.status == 'completed' || r.status == 'closed') &&
          ResultScreen.openCount == 0) {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ResultScreen(code: code)));
      }
    }
  }

  Future<void> _run(Future<void> Function() f) async {
    try {
      await f();
    } on AppError catch (e) {
      if (mounted) showMsg(context, e.message);
    } catch (_) {
      if (mounted) showMsg(context, 'Terjadi kesalahan, coba lagi');
    }
  }

  Future<void> _leaveOrDelete() async {
    final host = _room?.isHost ?? false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        title: Text(host ? 'Hapus room?' : 'Keluar dari room?'),
        content: Text(host
            ? 'Room dan semua pilihan film akan dihapus untuk semua anggota.'
            : 'Pilihan film kamu di room ini akan ikut dihapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(host ? 'Hapus' : 'Keluar',
                  style: const TextStyle(color: C.accent))),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      _sub?.cancel();
      if (host) {
        await RoomService.deleteRoom(code);
      } else {
        await RoomService.leave(code);
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PickData>>(
      stream: RoomService.watchPicks(code),
      builder: (context, picksSnap) => StreamBuilder<List<MemberData>>(
        stream: RoomService.watchMembers(code),
        builder: (context, memSnap) {
          final picks = picksSnap.data ?? const <PickData>[];
          final members = memSnap.data ?? const <MemberData>[];
          final mine = picks.where((p) => p.mine).toList();
          final me = members.where((m) => m.isMe).firstOrNull;

          // Satu ulasan per film, dengan daftar anggota yang memilihnya.
          final pickers = <String, List<String>>{};
          final films = <Film>[];
          for (final p in picks) {
            final names = pickers.putIfAbsent(p.film.id, () {
              films.add(p.film);
              return <String>[];
            });
            names.add(p.mine ? 'Kamu' : p.pickedByName);
          }

          return Scaffold(
            body: SafeArea(
              bottom: false,
              // Tombol siap melayang di atas daftar dan tetap menempel di
              // bawah layar saat di-scroll.
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    children: [
                      _topBar(context),
                      const SizedBox(height: 16),
                      _codeCard(context),
                      const SizedBox(height: 16),
                      _picks(context, mine, loading: !picksSnap.hasData),
                      _othersPicks(picks),
                      // Ulasan teratas untuk semua film pilihan anggota room.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: (!picksSnap.hasData || films.isEmpty)
                              ? const SizedBox(
                                  key: ValueKey('no_reviews'),
                                  width: double.infinity)
                              : Padding(
                                  key: ValueKey(
                                      'reviews_${films.map((f) => f.id).join(',')}'),
                                  padding: const EdgeInsets.only(top: 16),
                                  child: ReviewsCard(
                                      films: films, pickers: pickers),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _members(members, picks, loading: !memSnap.hasData),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(16, 28, 16,
                          12 + MediaQuery.paddingOf(context).bottom),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.35],
                          colors: [C.bg.withValues(alpha: 0), C.bg],
                        ),
                      ),
                      child: _confirm(
                          context, mine.length, me, members, picks.length),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  /// Film yang dipilih anggota lain.
  Widget _othersPicks(List<PickData> picks) {
    final others = picks.where((p) => !p.mine).toList();
    if (others.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: CardBox(
        padding: const EdgeInsets.all(16),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.groups_outlined, color: C.accent, size: 22),
              const SizedBox(width: 8),
              const Text('Pilihan Anggota Lain',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${others.length} film',
                  style: TextStyle(fontSize: 11.5, color: C.muted)),
            ]),
            const SizedBox(height: 12),
            for (final p in others) ...[
              Row(
                children: [
                  Poster(p.film, width: 46, height: 68, radius: 8, rating: false),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.film.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                            [
                              if (p.film.year > 0) '${p.film.year}',
                              if (p.film.genres.isNotEmpty) p.film.genres.first,
                            ].join('  •  '),
                            style: TextStyle(fontSize: 11.5, color: C.muted)),
                        const SizedBox(height: 6),
                        Row(children: [
                          MemberAvatar(
                              uid: p.pickedBy, name: p.pickedByName, size: 20),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text('Dipilih ${p.pickedByName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11.5, color: C.accent)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              if (p != others.last) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final host = _room?.isHost ?? false;
    return Row(
      children: [
        SquareIconButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.of(context).pop()),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: C.field,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(_room?.name ?? 'Room',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: C.muted)),
                ),
                const SizedBox(width: 8),
                for (var i = 0; i < 4; i++)
                  Container(
                    width: 18,
                    height: 4,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: i < 2 ? C.accent : C.chip,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Anggota tidak bisa keluar setelah voting dimulai.
        if (host || _room?.status == 'selecting') ...[
          const SizedBox(width: 12),
          SquareIconButton(
              icon: host ? Icons.delete_outline : Icons.logout,
              onTap: _leaveOrDelete),
        ],
      ],
    );
  }

  Widget _codeCard(BuildContext context) {
    return CardBox(
      padding: const EdgeInsets.all(16),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pin_outlined, color: C.accent, size: 20),
              SizedBox(width: 8),
              Text('Kode Room',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Bagikan kode ini ke teman supaya mereka bisa bergabung.',
              style: TextStyle(fontSize: 11.5, color: C.muted)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in code.split(''))
                Flexible(
                  child: Container(
                  constraints: const BoxConstraints(maxWidth: 54),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.accent.withValues(alpha: 0.6)),
                  ),
                  child: Text(d,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w600)),
                ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(
                    text: 'Gabung ke room Luma-ku! Kode: $code'));
                if (context.mounted) showMsg(context, 'Kode $code disalin');
              },
              icon: const Icon(Icons.copy, size: 16, color: C.accent),
              label: const Text('Salin Kode',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: C.text,
                backgroundColor: C.chip,
                side: BorderSide(color: C.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _picks(BuildContext context, List<PickData> mine,
      {bool loading = false}) {
    const max = RoomService.picksPerMember;
    return CardBox(
      padding: const EdgeInsets.all(16),
      radius: 16,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_border, color: C.accent, size: 22),
              const SizedBox(width: 8),
              const Text('Pilihan Film Kamu',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: C.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.accent.withValues(alpha: 0.5)),
                ),
                child: Text('${mine.length} dari $max Dipilih',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: C.accent)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < max; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  // Film terpilih (poster + nama) muncul dan hilang dengan fade.
                  child: loading
                      ? const Skeleton(height: 190, radius: 12)
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 380),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.94, end: 1)
                                  .animate(anim),
                              child: child,
                            ),
                          ),
                          child: i < mine.length
                              ? KeyedSubtree(
                                  key: ValueKey('pick_${mine[i].film.id}'),
                                  child: _pickedTile(mine[i].film))
                              : KeyedSubtree(
                                  key: ValueKey('add_$i'),
                                  child: _addTile(context)),
                        ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _pickedTile(Film f) {
    return Container(
      height: 190,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: C.deep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Poster(f, width: double.infinity, height: double.infinity),
                Positioned(
                  right: 4,
                  top: 4,
                  child: InkWell(
                    onTap: () => _run(() => RoomService.removePick(code, f.id)),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                          color: C.overlay, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 14, color: C.onOverlay),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(f.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          Text('${f.genres.first} • ${f.duration}',
              style: TextStyle(fontSize: 11, color: C.muted)),
        ],
      ),
    );
  }

  Widget _addTile(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => SearchScreen(code: code))),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.accent.withValues(alpha: 0.6), width: 1.5),
          color: C.accent.withValues(alpha: 0.04),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.accent.withValues(alpha: 0.12),
                border: Border.all(color: C.accent.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.add, color: C.accent),
            ),
            const SizedBox(height: 10),
            const Text('Tambahkan Film',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _members(List<MemberData> members, List<PickData> picks,
      {bool loading = false}) {
    final ready = members.where((m) => m.ready).length;
    return CardBox(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 9, color: C.accent),
              const SizedBox(width: 8),
              Text('Status Anggota Room (#$code)',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('$ready dari ${members.length} Siap',
                  style: TextStyle(fontSize: 11.5, color: C.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: C.border),
          const SizedBox(height: 10),
          if (loading)
            ...[
              for (var i = 0; i < 3; i++) ...[
                const Skeleton(height: 62, radius: 10),
                const SizedBox(height: 8),
              ],
            ]
          else
            for (final m in members) ...[
              _memberRow(m, picks.where((p) => p.pickedBy == m.uid).length),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _memberRow(MemberData m, int picked) {
    const max = RoomService.picksPerMember;
    final waiting = picked == 0 && !m.ready;
    final status = m.ready
        ? 'Siap'
        : waiting
            ? '0/$max Menunggu'
            : '$picked/$max Memilih';
    final statusColor = m.ready ? C.gold : (waiting ? C.muted : C.accent);
    final badge = m.isMe ? 'Anda' : (m.role == 'host' ? 'Host' : null);
    final name = m.isMe ? 'Kamu' : m.name;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: C.deep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: m.isMe ? C.accent.withValues(alpha: 0.6) : C.border),
      ),
      child: Row(
        children: [
          MemberAvatar(
              uid: m.uid,
              name: name,
              color: m.role == 'host' ? C.gold : C.chip,
              size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Row(children: [
              Flexible(
                child: Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: waiting ? C.muted : C.text)),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: m.isMe ? C.accent.withValues(alpha: 0.15) : C.chip,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: m.isMe ? C.accent : C.muted)),
                ),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Text(status,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor)),
        ],
      ),
    );
  }

  Widget _confirm(BuildContext context, int mine, MemberData? me,
      List<MemberData> members, int totalPicks) {
    const max = RoomService.picksPerMember;
    final remaining = max - mine;
    final ready = members.where((m) => m.ready).length;
    final isReady = me?.ready ?? false;
    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: C.gold),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                    isReady
                        ? 'Menunggu teman lain siap...'
                        : remaining == 0
                            ? 'Pilihan lengkap, tekan siap'
                            : 'Pilih $remaining film lagi untuk konfirmasi',
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text('$ready/${members.length} Teman Siap',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: C.accent)),
            ],
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: isReady ? 'Sudah Siap' : 'Siap untuk Voting',
            icon: Icons.check_circle_outline,
            height: 50,
            onTap: (remaining == 0 && !isReady)
                ? () => _run(() => RoomService.setReady(code))
                : null,
          ),
        ],
    );
  }
}
