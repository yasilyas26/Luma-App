import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

import '../services.dart';
import '../theme.dart';
import '../tmdb_service.dart';
import 'lobby_screen.dart';
import 'film_shelf.dart';
import 'h_scroll.dart';
import 'hero_banner.dart';
import 'profile_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  // Gabung
  final _code = TextEditingController();
  Future<RoomData?>? _lookup;
  bool _busy = false;
  final _codeFocus = FocusNode();
  final _scroll = ScrollController();
  bool _scrolled = false;
  List<String> _posters = const [];

  // Buat
  static final _allGenres = TmdbService.genreIds.keys.toList();
  static const _quickGenres = ['Sci-Fi', 'Drama', 'Action', 'Horror'];
  final Set<String> _genres = {'Sci-Fi', 'Drama'};
  final Set<String> _platforms = {};
  final _genreCtl = ScrollController();
  bool _inTheater = false;

  static const _minYear = 1950;
  final int _maxYear = DateTime.now().year;
  int? _from;
  int? _to;
  bool _yearError = false;
  int? _maxMembers;
  int? _pool;

  @override
  void initState() {
    super.initState();
    ProfilePhoto.load();
    // Dibuka lewat link ?room=12345: isi kode dan cek room-nya.
    final linked = DeepLink.roomCode;
    if (linked != null) {
      DeepLink.roomCode = null;
      _code.text = linked;
      _lookup = RoomService.findRoom(linked);
    }
    TmdbService.popularPosters().then((p) {
      if (mounted) setState(() => _posters = p);
    });
    _codeFocus.addListener(() => setState(() {}));
    _code.addListener(_keepCaretAtEnd);
    _scroll.addListener(() {
      final scrolled = _scroll.hasClients && _scroll.offset > 6;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _code.removeListener(_keepCaretAtEnd);
    _scroll.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on AppError catch (e) {
      if (mounted) showMsg(context, e.message);
    } on FirebaseException catch (e) {
      debugPrint('Firebase ${e.plugin}/${e.code}: ${e.message}');
      if (mounted) {
        showMsg(
            context,
            e.code == 'permission-denied'
                ? 'Akses ditolak. Room mungkin penuh atau voting sudah dimulai (${e.code})'
                : 'Terjadi kesalahan (${e.code})');
      }
    } catch (e) {
      debugPrint('Gagal: $e');
      if (mounted) showMsg(context, 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openLobby(String code) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => LobbyScreen(code: code)));

  Future<void> _joinRoom(String code) => _guard(() async {
        await RoomService.join(code);
        _openLobby(code);
      });

  Future<void> _create() async {
    if (_genres.isEmpty) return showMsg(context, 'Pilih minimal satu genre');
    final from = _from;
    final to = _to;
    final members = _maxMembers;
    final pool = _pool;
    if (from == null || to == null || members == null || pool == null) {
      setState(() => _yearError = true);
      return showMsg(context, 'Lengkapi rentang tahun, batas anggota, dan koleksi pool dulu');
    }
    if (from > to) return showMsg(context, 'Tahun mulai melebihi tahun akhir');
    await _guard(() async {
      final code = await RoomService.createRoom(
        name: 'Room ${AuthService.name}',
        genres: _genres.toList(),
        yearFrom: from,
        yearTo: to,
        maxMembers: members,
        pool: pool,
        providers: _platforms.toList(),
        inTheater: _inTheater,
      );
      _openLobby(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    const headerHeight = 66.0;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Stack(
        children: [
          // Konten digulir di bawah header (header menutupi bagian atas).
          ListView(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(12, top + headerHeight + 14, 12, 24),
            children: [
              HeroBanner(posters: _posters),
              const SizedBox(height: 20),
              SegTabs(
                labels: const ['Gabung Room', 'Buat Room Baru'],
                icons: const [Icons.login, Icons.add_circle_outline],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _tab == 0
                    ? KeyedSubtree(key: const ValueKey(0), child: _join())
                    : KeyedSubtree(key: const ValueKey(1), child: _create_()),
              ),
            ],
          ),
          // Header: solid di atas, jadi kaca saat halaman digulir.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GlassBar(
              glass: _scrolled,
              child: Container(
                height: top + headerHeight,
                padding: EdgeInsets.fromLTRB(16, top, 16, 0),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    const LumaLogo(),
                    const Spacer(),
                    ProfileMenuButton(
                        onChanged: () => setState(() {}),
                        onHistory: _openHistory),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Gabung ----------------

  Widget _join() {
    return Column(
      children: [
        CardBox(
          padding: const EdgeInsets.all(16),
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.pin_outlined, color: C.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kode Ruang Voting',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600)),
                        SizedBox(height: 3),
                        Text('Minta 5 karakter kode unik kepada\nteman yang membuat room.',
                            style: TextStyle(
                                fontSize: 11.5, height: 1.4, color: C.muted)),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final d = await Clipboard.getData('text/plain');
                      final t = (d?.text ?? '').replaceAll(RegExp(r'\D'), '');
                      if (t.length >= 5) {
                        final c = t.substring(0, 5);
                        setState(() {
                          _code.text = c;
                          _lookup = RoomService.findRoom(c);
                        });
                      } else if (mounted) {
                        showMsg(context, 'Tidak ada kode 5 digit di clipboard');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: C.chip,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.border),
                      ),
                      child: const Column(children: [
                        Icon(Icons.content_paste, size: 14, color: C.accent),
                        Text('Tempel\nKode',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _codeBoxes(),
              if (_lookup != null) ...[
                const SizedBox(height: 16),
                FutureBuilder<RoomData?>(
                  future: _lookup,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Skeleton(height: 104, radius: 12);
                    }
                    final r = snap.data;
                    if (snap.hasError || r == null) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Room dengan kode ini tidak ditemukan',
                            style: TextStyle(
                                fontSize: 12.5, color: C.pink)),
                      );
                    }
                    return Column(children: [
                      _detectedRoom(r),
                      const SizedBox(height: 16),
                      if (!r.memberIds.contains(AuthService.uid) &&
                          (r.status != 'selecting' ||
                              r.memberIds.length >= r.maxMembers))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                              r.status == 'completed' || r.status == 'closed'
                                  ? 'Voting sudah selesai'
                                  : r.status != 'selecting'
                                      ? 'Voting sudah dimulai, tidak bisa bergabung lagi'
                                      : 'Room sudah penuh',
                              style: TextStyle(fontSize: 12.5, color: C.pink)),
                        ),
                      PrimaryButton(
                        label: _busy ? 'Memproses...' : 'Gabung ke Room Sekarang',
                        trailing: Icons.meeting_room_outlined,
                        height: 50,
                        onTap: _busy ? null : () => _joinRoom(r.code),
                      ),
                    ]);
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (TmdbService.enabled) ...[
          FilmShelf(
            title: 'Most Awarded',
            subtitle: 'Pemenang Oscar Best Picture, film paling banyak dihargai.',
            icon: Icons.emoji_events,
            loader: () => TmdbService.shelf('awarded'),
          ),
          FilmShelf(
            title: 'Film Teratas',
            subtitle: 'Rating tertinggi sepanjang masa menurut TMDb.',
            icon: Icons.star,
            loader: () => TmdbService.shelf('top'),
          ),
          FilmShelf(
            title: 'In Theater',
            subtitle: 'Sedang tayang di bioskop Indonesia.',
            icon: Icons.local_movies,
            loader: () => TmdbService.shelf('theater'),
          ),
        ],
        const SizedBox(height: 28),
      ],
    );
  }

  /// Kursor selalu di akhir, jadi angka selalu terisi dari kotak paling kiri.
  void _keepCaretAtEnd() {
    final end = _code.text.length;
    if (_code.selection.baseOffset != end || _code.selection.extentOffset != end) {
      _code.selection = TextSelection.collapsed(offset: end);
    }
  }

  Widget _codeBoxes() {
    final text = _code.text;
    final focused = _codeFocus.hasFocus;
    // Kotak aktif = kotak kosong pertama dari kiri (atau kotak terakhir kalau penuh).
    final active = text.length < 5 ? text.length : 4;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _codeFocus.requestFocus();
        _keepCaretAtEnd();
      },
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < 5; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 58),
                      child: _codeBox(
                        char: i < text.length ? text[i] : '',
                        isActive: focused && i == active,
                        showCaret: focused && i == active && text.length < 5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Kolom input tersembunyi: hanya menerima angka dan tidak bisa
          // diseleksi, jadi isiannya selalu berurutan dari kiri.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _code,
                focusNode: _codeFocus,
                keyboardType: TextInputType.number,
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                onChanged: (v) => setState(() {
                  _lookup = v.length == 5 ? RoomService.findRoom(v) : null;
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeBox(
      {required String char, required bool isActive, required bool showCaret}) {
    return AnimatedScale(
      scale: isActive ? 1.06 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isActive ? C.accent : C.border, width: isActive ? 2 : 1),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: C.accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 0.5)
                ]
              : const [],
        ),
        child: char.isNotEmpty
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim, child: FadeTransition(opacity: anim, child: child)),
                child: Text(char,
                    key: ValueKey(char),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w600)),
              )
            : (showCaret ? const _BlinkingCaret() : const SizedBox.shrink()),
      ),
    );
  }

  Widget _detectedRoom(RoomData r) {
    return CardBox(
      color: C.deep,
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 8, color: C.accent),
              const SizedBox(width: 6),
              const Text('RUANG TERDETEKSI',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: C.accent)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: C.chip,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_statusLabel(r.status),
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: C.gold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(r.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Divider(height: 1, color: C.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: C.muted),
              const SizedBox(width: 6),
              Text('Host: ${r.hostName}',
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
              const Spacer(),
              Icon(Icons.group_outlined, size: 16, color: C.muted),
              const SizedBox(width: 6),
              Text('Anggota: ${r.memberIds.length}/${r.maxMembers}',
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
            ],
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String s) => switch (s) {
        'voting' => 'Sedang Voting',
        'completed' || 'closed' => 'Selesai',
        _ => 'Menunggu Peserta',
      };

  static String _ago(DateTime? d) {
    if (d == null) return 'Baru saja';
    final days = DateTime.now().difference(d).inDays;
    if (days <= 0) return 'Hari ini';
    if (days == 1) return 'Kemarin';
    return '$days hari lalu';
  }

  /// Riwayat ruangan, dibuka dari menu akun.
  Future<void> _openHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        child: SafeArea(
          child: StreamBuilder<List<RoomData>>(
            stream: RoomService.watchMyRooms(),
            builder: (context, snap) {
              final rooms = snap.data ?? const <RoomData>[];
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                children: [
                  Row(children: [
                    const Icon(Icons.history, size: 20),
                    const SizedBox(width: 8),
                    const Text('Riwayat ruangan',
                        style:
                            TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${rooms.length} Room',
                        style: TextStyle(fontSize: 11, color: C.muted)),
                  ]),
                  const SizedBox(height: 14),
                  if (!snap.hasData)
                    const RowSkeleton()
                  else if (rooms.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                          child: Text('Belum ada ruangan yang pernah diikuti.',
                              style: TextStyle(fontSize: 13, color: C.muted))),
                    )
                  else
                    ..._historyItems(rooms, ctx),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _historyItems(List<RoomData> rooms, BuildContext sheet) {
    return [
            for (final r in rooms) ...[
              CardBox(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: C.chip,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.border),
                      ),
                      child: const Icon(Icons.movie_filter_outlined,
                          size: 22, color: C.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                          Text('#${r.code}',
                              style: TextStyle(
                                  fontSize: 12.5, color: C.muted)),
                          Text(
                              '${_ago(r.createdAt)} • ${r.memberIds.length} Anggota • ${_statusLabel(r.status)}',
                              style: TextStyle(
                                  fontSize: 11.5, color: C.muted)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              Navigator.pop(sheet);
                              _joinRoom(r.code);
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.text,
                        backgroundColor: C.chip,
                        side: BorderSide(color: C.border),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Gabung Kembali',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
    ];
  }

  // ---------------- Buat ----------------

  Widget _create_() {
    return CardBox(
      padding: const EdgeInsets.all(24),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter Film',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Tetapkan preferensi sebelum mengundang teman',
              style: TextStyle(fontSize: 12.5, color: C.soft)),
          const SizedBox(height: 32),
          Text('PILIH GENRE',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: C.soft)),
          const SizedBox(height: 10),
          // Urutan tetap: chip yang dipilih tidak berpindah tempat.
          Row(
            children: [
              Expanded(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0, 0.9, 1],
                  ).createShader(r),
                  child: HScroll(
                    controller: _genreCtl,
                    padding: const EdgeInsets.only(right: 24),
                    child: Row(
                      children: [
                        // Genre aktif di kiri (urutan dipilih), sisanya menyusul.
                        for (final g in [
                          ..._genres,
                          ..._quickGenres.where((g) => !_genres.contains(g)),
                          ..._allGenres.where(
                              (g) => !_genres.contains(g) && !_quickGenres.contains(g)),
                        ])
                          Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _genreChip(g)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _filterButton(),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Text('PLATFORM & BIOSKOP',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: C.soft)),
              const SizedBox(width: 8),
              Text('(opsional)',
                  style: TextStyle(fontSize: 11, color: C.muted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              'Kosongkan untuk semua. "In Theater" menampilkan film yang sedang tayang di bioskop (rentang tahun diabaikan).',
              style: TextStyle(fontSize: 11.5, color: C.muted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Yang aktif di kiri.
              if (_inTheater) _theaterChip(),
              for (final p in [
                ..._platforms,
                ...TmdbService.providers.keys.where((p) => !_platforms.contains(p)),
              ])
                _platformChip(p),
              if (!_inTheater) _theaterChip(),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Text('RENTANG TAHUN RILIS',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: C.soft)),
              const Spacer(),
              Text('Tahun: $_minYear - $_maxYear',
                  style: TextStyle(fontSize: 10.5, color: C.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _yearBox('MULAI', _from, (y) => _from = y)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(Icons.arrow_right_alt, color: C.muted, size: 20),
              ),
              Expanded(child: _yearBox('AKHIR', _to, (y) => _to = y)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statBox('BATAS ANGGOTA',
                    _maxMembers == null ? null : 'Maks $_maxMembers',
                    Icons.group_outlined, () async {
                  final v = await _pickNumber('Batas Anggota', _maxMembers ?? 10,
                      min: 2, max: 10, step: 1, unit: 'orang');
                  if (v != null) setState(() => _maxMembers = v);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statBox('KOLEKSI POOL', _pool == null ? null : '$_pool Film',
                    Icons.collections_outlined, () async {
                  final v = await _pickNumber('Koleksi Pool', _pool ?? 15,
                      min: 5, max: 50, step: 5, unit: 'film');
                  if (v != null) setState(() => _pool = v);
                }),
              ),
            ],
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: _busy ? 'Membuat room...' : 'Buat Room & Dapatkan Kode',
            icon: Icons.add_box_outlined,
            height: 50,
            onTap: _busy ? null : _create,
          ),
        ],
      ),
    );
  }

  /// Pemilih tahun: roda yang digulir (atau diketuk), dengan sorotan di tengah.
  Future<int?> _pickYear(String title, int initial) {
    final years = [for (var y = _maxYear; y >= _minYear; y--) y];
    var index = years.indexOf(initial.clamp(_minYear, _maxYear));
    final ctrl = FixedExtentScrollController(initialItem: index);
    const extent = 46.0;

    return showDialog<int>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Dialog(
          backgroundColor: C.card,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: C.border)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    const Icon(Icons.event, size: 20, color: C.accent),
                    const SizedBox(width: 8),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('$_minYear - $_maxYear',
                        style: TextStyle(fontSize: 11, color: C.muted)),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: extent * 5,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Sorotan tahun terpilih.
                        IgnorePointer(
                          child: Container(
                            height: extent,
                            decoration: BoxDecoration(
                              color: C.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: C.accent.withValues(alpha: 0.7)),
                            ),
                          ),
                        ),
                        ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (r) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.white,
                              Colors.white,
                              Colors.transparent
                            ],
                            stops: [0, 0.3, 0.7, 1],
                          ).createShader(r),
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(ctx).copyWith(
                              dragDevices: {
                                PointerDeviceKind.touch,
                                PointerDeviceKind.mouse,
                                PointerDeviceKind.trackpad,
                              },
                              scrollbars: false,
                            ),
                            child: ListWheelScrollView.useDelegate(
                              controller: ctrl,
                              itemExtent: extent,
                              diameterRatio: 2.2,
                              perspective: 0.003,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (i) =>
                                  setSheet(() => index = i),
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: years.length,
                                builder: (_, i) {
                                  final on = i == index;
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => ctrl.animateToItem(i,
                                        duration:
                                            const Duration(milliseconds: 250),
                                        curve: Curves.easeOut),
                                    child: Center(
                                      child: AnimatedDefaultTextStyle(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        style: TextStyle(
                                          fontSize: on ? 26 : 19,
                                          fontWeight: on
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: on ? C.accent : C.muted,
                                        ),
                                        child: Text('${years[i]}'),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: C.text,
                          side: BorderSide(color: C.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Pilih ${years[index]}',
                        height: 44,
                        onTap: () => Navigator.pop(ctx, years[index]),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Dialog angka: tombol kurang/tambah atau ketik sendiri.
  Future<int?> _pickNumber(String title, int value,
      {required int min, required int max, required int step, required String unit}) {
    final ctrl = TextEditingController(text: '$value');
    int current() => (int.tryParse(ctrl.text) ?? value).clamp(min, max);
    void set(int v) {
      final c = v.clamp(min, max);
      ctrl.value = TextEditingValue(
          text: '$c', selection: TextSelection.collapsed(offset: '$c'.length));
    }

    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SquareIconButton(
                    icon: Icons.remove, onTap: () => set(current() - step)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter('$max'.length),
                      _MaxValueFormatter(max),
                    ],
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      suffixText: unit.isEmpty ? null : unit,
                      filled: true,
                      fillColor: C.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: C.border),
                      ),
                    ),
                    onSubmitted: (_) => Navigator.pop(ctx, current()),
                  ),
                ),
                const SizedBox(width: 12),
                SquareIconButton(
                    icon: Icons.add, onTap: () => set(current() + step)),
              ],
            ),
            const SizedBox(height: 10),
            Text('Minimal $min, maksimal $max${unit.isEmpty ? '' : ' $unit'}',
                style: TextStyle(fontSize: 11.5, color: C.muted)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, current()),
              child: const Text('Simpan',
                  style: TextStyle(color: C.accent))),
        ],
      ),
    );
  }

  Widget _platformChip(String p) {
    final on = _platforms.contains(p);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => on ? _platforms.remove(p) : _platforms.add(p)),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? C.accent : C.chipFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? C.accent : C.chipBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: TmdbService.platformColors[p] ?? C.muted,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: on ? 0.8 : 0.0)),
            ),
          ),
          const SizedBox(width: 7),
          Text(p,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on ? Colors.white : C.text)),
          if (on) ...[
            const SizedBox(width: 4),
            const Icon(Icons.check, size: 14, color: Colors.white),
          ],
        ]),
      ),
    );
  }

  Widget _theaterChip() {
    final on = _inTheater;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _inTheater = !_inTheater),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? C.accent : C.chipFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? C.accent : C.chipBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_movies, size: 15, color: on ? Colors.white : C.accent),
          const SizedBox(width: 7),
          Text('In Theater',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on ? Colors.white : C.text)),
          if (on) ...[
            const SizedBox(width: 4),
            const Icon(Icons.check, size: 14, color: Colors.white),
          ],
        ]),
      ),
    );
  }

  Widget _filterButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _openGenreSheet,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.accent.withValues(alpha: 0.6)),
          color: C.accent.withValues(alpha: 0.08),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.tune, size: 16, color: C.accent),
          SizedBox(width: 6),
          Text('Filter',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: C.accent)),
        ]),
      ),
    );
  }

  /// Bottom sheet berisi semua genre untuk dipilih.
  Future<void> _openGenreSheet() async {
    final temp = {..._genres};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Pilih Genre',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${temp.length} dipilih',
                        style: TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final g in _allGenres)
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => setSheet(() =>
                                temp.contains(g) ? temp.remove(g) : temp.add(g)),
                            child: Container(
                              height: 34,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: temp.contains(g) ? C.accent : C.chipFill,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: temp.contains(g) ? C.accent : C.chipBorder),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(g,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: temp.contains(g)
                                                ? Colors.white
                                                : C.text)),
                                    if (temp.contains(g)) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.check,
                                          size: 14, color: Colors.white),
                                    ],
                                  ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setSheet(temp.clear),
                      child: Text('Reset',
                          style: TextStyle(color: C.muted)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Terapkan',
                        height: 46,
                        onTap: () => Navigator.pop(ctx, temp),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) {
      setState(() => _genres
        ..clear()
        ..addAll(result));
    }
  }

  Widget _genreChip(String g) {
    final on = _genres.contains(g);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() => on ? _genres.remove(g) : _genres.add(g));
        if (_genreCtl.hasClients) {
          _genreCtl.animateTo(0,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: on ? C.accent : C.chipFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? C.accent : C.chipBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(g,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on ? Colors.white : C.text)),
          if (on) ...[
            const SizedBox(width: 4),
            const Icon(Icons.check, size: 14, color: Colors.white),
          ],
        ]),
      ),
    );
  }

  Widget _yearBox(String label, int? year, void Function(int) set) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final y = await _pickYear(
            label == 'MULAI' ? 'Tahun Mulai' : 'Tahun Akhir', year ?? _maxYear);
        if (y != null) {
          setState(() {
            set(y);
            _yearError = false;
          });
        }
      },
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _yearError && year == null ? C.accent : C.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9.5, fontWeight: FontWeight.w700, color: C.muted)),
            Text(year?.toString() ?? 'Pilih tahun',
                style: TextStyle(
                    fontSize: year == null ? 13 : 15,
                    fontWeight: year == null ? FontWeight.w500 : FontWeight.w700,
                    color: year == null ? C.muted : C.text,
                    fontFamily: year == null ? null : 'monospace')),
          ],
        ),
      ),
    );
  }

  Widget _statBox(
      String label, String? value, IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 70,
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _yearError && value == null ? C.accent : C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9.5, fontWeight: FontWeight.w700, color: C.muted)),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(value ?? 'Pilih',
                      style: TextStyle(
                          fontSize: value == null ? 13 : 15,
                          fontWeight:
                              value == null ? FontWeight.w500 : FontWeight.w700,
                          color: value == null ? C.muted : C.text)),
                ),
                Icon(icon, size: 18, color: C.pink),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


/// Garis kursor berkedip di kotak yang sedang aktif.
class _BlinkingCaret extends StatefulWidget {
  const _BlinkingCaret();

  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _c,
        child: Container(width: 2, height: 26, color: C.accent),
      );
}

/// Menolak ketikan yang membuat angka melebihi [max].
class _MaxValueFormatter extends TextInputFormatter {
  _MaxValueFormatter(this.max);
  final int max;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final v = int.tryParse(newValue.text);
    return (v == null || v > max) ? oldValue : newValue;
  }
}
