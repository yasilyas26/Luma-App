import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data.dart';
import '../services.dart';
import '../theme.dart';
import '../tmdb_service.dart';
import 'h_scroll.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.code});
  final String code;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  /// Urutan genre pada baris chip (yang paling sering dipakai di depan).
  static const _chipOrder = [
    'Sci-Fi', 'Action', 'Drama', 'Horror', 'Comedy', 'Thriller', 'Adventure',
    'Animation', 'Fantasy', 'Romance', 'Crime', 'Mystery', 'Family', 'History',
    'War', 'Western', 'Music', 'Documentary',
  ];

  final _genreCtl = ScrollController();
  final _sourceCtl = ScrollController();

  final _recent = <String>[];
  /// 0 = Semua, 1 = Teratas.
  int _tab = 0;

  /// Filter aktif. Nilai awalnya mengikuti pilihan host saat membuat room
  /// (genre, platform streaming, In Theater), dan bisa diubah pengguna.
  final Set<String> _genres = {};
  final Set<String> _platforms = {};
  bool _inTheater = false;

  Timer? _debounce;
  RoomData? _room;
  List<Film> _items = const [];
  bool _loading = true;
  String? _error;
  int _req = 0;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    RoomService.findRoom(widget.code).then((r) {
      _room = r;
      _applyRoomFilters();
      if (mounted) _load();
    }).catchError((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Samakan filter dengan pilihan host di room.
  void _applyRoomFilters() {
    final r = _room;
    if (r == null) return;
    _genres
      ..clear()
      ..addAll(r.genres);
    _platforms
      ..clear()
      ..addAll(r.providers);
    _inTheater = r.inTheater;
  }

  bool get _sameAsRoom {
    final r = _room;
    if (r == null) return true;
    return setEquals(_genres, r.genres.toSet()) &&
        setEquals(_platforms, r.providers.toSet()) &&
        _inTheater == r.inTheater;
  }

  void _onQueryChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _load);
  }

  Future<void> _load() async {
    final id = ++_req;
    final q = _controller.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<Film> r;
      if (!TmdbService.enabled) {
        // Tanpa API key: pakai data contoh lokal.
        r = allFilms
            .where((f) => _genres.isEmpty || f.genres.any(_genres.contains))
            .where((f) => q.isEmpty || f.title.toLowerCase().contains(q.toLowerCase()))
            .toList();
      } else if (q.isEmpty) {
        r = await TmdbService.discover(
          genres: _genres.toList(),
          yearFrom: _room?.yearFrom,
          yearTo: _room?.yearTo,
          topRated: _tab == 1,
          platforms: _platforms.toList(),
          inTheater: _inTheater,
        );
      } else {
        r = await TmdbService.search(q, genres: _genres.toList());
      }
      // "Teratas": urutkan dari rating tertinggi.
      if (_tab == 1) r = [...r]..sort((a, b) => b.rating.compareTo(a.rating));
      if (id != _req || !mounted) return;
      setState(() {
        _items = r;
        _loading = false;
      });
    } on AppError catch (e) {
      if (id != _req || !mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(Film f, PickData? existing) async {
    try {
      if (existing != null) {
        await RoomService.removePick(widget.code, f.id);
      } else {
        await RoomService.addPick(widget.code, f);
        _submitSearch(_controller.text);
      }
    } on AppError catch (e) {
      if (mounted) showMsg(context, e.message);
    } catch (_) {
      if (mounted) showMsg(context, 'Terjadi kesalahan, coba lagi');
    }
  }

  String get _recentKey => 'recent_searches_${AuthService.uid}';

  Future<void> _loadRecent() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = p.getStringList(_recentKey) ?? const <String>[];
      if (mounted) {
        setState(() => _recent
          ..clear()
          ..addAll(list));
      }
    } catch (_) {}
  }

  Future<void> _saveRecent() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_recentKey, _recent);
    } catch (_) {}
  }

  void _submitSearch(String v) {
    final t = v.trim();
    if (t.isEmpty) return;
    setState(() {
      _recent.remove(t);
      _recent.insert(0, t);
      if (_recent.length > 6) _recent.removeLast();
    });
    _saveRecent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<PickData>>(
          stream: RoomService.watchPicks(widget.code),
          builder: (context, snap) {
            final picks = snap.data ?? const <PickData>[];
            final mine = picks.where((p) => p.mine).length;
            final results = _items;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _header(context),
                      _tabs(),
                      _genreChips(),
                      _sourceChips(),
                      _filterNotice(),
                      Divider(height: 1, color: C.border),
                      if (_recent.isNotEmpty) _recentSection(),
                      if (!TmdbService.enabled)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: C.gold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: C.gold.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                              'Mode contoh: API key TMDb belum terbaca. Jalankan ulang dengan --dart-define-from-file=env.json.',
                              style: TextStyle(fontSize: 11.5, color: C.gold)),
                        ),
                      _resultHeader(_loading ? 0 : results.length),
                      if (_loading)
                        ...[
                          for (var i = 0; i < 4; i++) const FilmCardSkeleton(),
                        ]
                      else if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(_error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: C.pink)),
                          ),
                        )
                      else if (results.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('Film tidak ditemukan',
                                style: TextStyle(color: C.muted)),
                          ),
                        ),
                      if (!_loading && _error == null)
                        for (final f in results)
                        _filmCard(
                          f,
                          picks.where((p) => p.film.id == f.id).firstOrNull,
                          mine,
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                _bottomBanner(mine),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          SquareIconButton(
              icon: Icons.arrow_back,
              size: 36,
              onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.only(left: 10, right: 6),
              decoration: BoxDecoration(
                color: C.field,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: (_) => _onQueryChanged(),
                      onSubmitted: _submitSearch,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Cari film...',
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      _controller.clear();
                      _onQueryChanged();
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                          color: C.border, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _chipText =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

  /// Chip pilihan umum (dipakai di baris chip dan di lembar filter).
  Widget _chip(
      {required String label,
      required bool on,
      required VoidCallback onTap,
      Widget? leading}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 36,
        padding: EdgeInsets.symmetric(horizontal: leading == null ? 16 : 12),
        decoration: BoxDecoration(
          color: on ? C.accent : C.chipFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? C.accent : C.chipBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (leading != null) ...[leading, const SizedBox(width: 7)],
          Text(label,
              maxLines: 1,
              style: _chipText.copyWith(color: on ? Colors.white : C.text)),
          if (on && leading != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.check, size: 14, color: Colors.white),
          ],
        ]),
      ),
    );
  }

  Widget _dot(String platform, bool on) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: TmdbService.platformColors[platform] ?? C.muted,
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withValues(alpha: on ? 0.8 : 0.0)),
        ),
      );

  Widget _theaterIcon(bool on) =>
      Icon(Icons.local_movies, size: 15, color: on ? Colors.white : C.accent);

  /// Chip aktif pindah ke kiri (berurutan sesuai urutan dipilih); baris
  /// digulir ke awal supaya chip yang baru aktif langsung terlihat.
  void _toggleFilter<T>(Set<T> set, T v, ScrollController ctl) {
    setState(() => set.contains(v) ? set.remove(v) : set.add(v));
    _toStart(ctl);
    _load();
  }

  void _toStart(ScrollController ctl) {
    if (!ctl.hasClients) return;
    ctl.animateTo(0,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Widget _genreChip(String g) => _chip(
        label: g,
        on: _genres.contains(g),
        onTap: () => _toggleFilter(_genres, g, _genreCtl),
      );

  Widget _platformChip(String p) => _chip(
        label: p,
        on: _platforms.contains(p),
        leading: _dot(p, _platforms.contains(p)),
        onTap: () => _toggleFilter(_platforms, p, _sourceCtl),
      );

  String get _firstPlatform => _platforms.isNotEmpty
      ? _platforms.first
      : TmdbService.providers.keys.first;

  Widget _theaterChip() => _chip(
        label: 'In Theater',
        on: _inTheater,
        leading: _theaterIcon(_inTheater),
        onTap: () {
          setState(() => _inTheater = !_inTheater);
          _toStart(_sourceCtl);
          _load();
        },
      );

  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: SegTabs(
        labels: const ['Semua', 'Teratas'],
        icons: const [Icons.local_movies, Icons.star],
        index: _tab,
        onChanged: (i) {
          if (i == _tab) return;
          setState(() => _tab = i);
          _load();
        },
      ),
    );
  }

  /// Baris 1: genre (bisa dipilih lebih dari satu) + tombol Filter di kanan.
  Widget _genreChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
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
                    for (final g in [
                      ..._genres,
                      ..._chipOrder.where((g) => !_genres.contains(g)),
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
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _openFilterSheet,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: C.accent.withValues(alpha: 0.7)),
                color: C.accent.withValues(alpha: 0.08),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.tune, size: 16, color: C.accent),
                SizedBox(width: 6),
                Text('Filter',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: C.accent)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Baris 2: In Theater dan platform streaming.
  Widget _sourceChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.92, 1],
        ).createShader(r),
        child: HScroll(
          controller: _sourceCtl,
          padding: const EdgeInsets.only(right: 24),
          child: Row(
            children: [
              // Yang aktif di kiri: In Theater dulu, lalu platform sesuai
              // urutan dipilih; sisanya menyusul.
              if (_inTheater) _theaterChip(),
              for (final p in [
                ..._platforms,
                ...TmdbService.providers.keys.where((p) => !_platforms.contains(p)),
              ])
                Padding(
                    padding: EdgeInsets.only(
                        left: (_inTheater || p != _firstPlatform) ? 8 : 0),
                    child: _platformChip(p)),
              if (!_inTheater)
                Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _theaterChip()),
            ],
          ),
        ),
      ),
    );
  }

  /// Menjelaskan bahwa filter mengikuti room, dan memberi jalan kembali.
  Widget _filterNotice() {
    final same = _sameAsRoom;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(Icons.tune, size: 14, color: same ? C.muted : C.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                same
                    ? 'Filter mengikuti pengaturan room.'
                    : 'Filter berbeda dari pengaturan room.',
                style: TextStyle(
                    fontSize: 11.5, color: same ? C.muted : C.text)),
          ),
          if (!same)
            TextButton(
              onPressed: () {
                setState(_applyRoomFilters);
                _load();
              },
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Kembali ke filter room',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: C.accent)),
            ),
        ],
      ),
    );
  }

  Widget _sheetSection(String title, List<Widget> chips) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 10),
            child: Text(title,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: C.muted)),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      );

  /// Lembar filter lengkap: genre, platform streaming, dan In Theater.
  Future<void> _openFilterSheet() async {
    final g = {..._genres};
    final p = {..._platforms};
    var t = _inTheater;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Filter',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setSheet(() {
                          g
                            ..clear()
                            ..addAll(_room?.genres ?? const []);
                          p
                            ..clear()
                            ..addAll(_room?.providers ?? const []);
                          t = _room?.inTheater ?? false;
                        }),
                        child: Text('Reset ke filter room',
                            style: TextStyle(fontSize: 12.5, color: C.muted)),
                      ),
                    ],
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sheetSection('GENRE', [
                            for (final x in _chipOrder)
                              _chip(
                                label: x,
                                on: g.contains(x),
                                onTap: () => setSheet(() =>
                                    g.contains(x) ? g.remove(x) : g.add(x)),
                              ),
                          ]),
                          _sheetSection('PLATFORM STREAMING', [
                            for (final x in TmdbService.providers.keys)
                              _chip(
                                label: x,
                                on: p.contains(x),
                                leading: _dot(x, p.contains(x)),
                                onTap: () => setSheet(() =>
                                    p.contains(x) ? p.remove(x) : p.add(x)),
                              ),
                          ]),
                          _sheetSection('BIOSKOP', [
                            _chip(
                              label: 'In Theater',
                              on: t,
                              leading: _theaterIcon(t),
                              onTap: () => setSheet(() => t = !t),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Terapkan',
                    icon: Icons.check,
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (applied != true) return;
    setState(() {
      _genres
        ..clear()
        ..addAll(g);
      _platforms
        ..clear()
        ..addAll(p);
      _inTheater = t;
    });
    _load();
  }

  Widget _recentSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 16, color: C.muted),
              const SizedBox(width: 6),
              Text('TERAKHIR DICARI',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: C.muted)),
              const Spacer(),
              InkWell(
                onTap: () {
                  setState(_recent.clear);
                  _saveRecent();
                },
                child: Text('Hapus Semua',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: C.pink)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _recent)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    _controller.text = r;
                    _onQueryChanged();
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
                    decoration: BoxDecoration(
                      color: C.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: C.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(r, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          setState(() => _recent.remove(r));
                          _saveRecent();
                        },
                        child:
                            Icon(Icons.close, size: 15, color: C.muted),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultHeader(int count) {
    final q = _controller.text.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: q.isEmpty
                        ? (_tab == 1 ? 'Film teratas' : 'Semua film')
                        : 'Hasil untuk '),
                if (q.isNotEmpty)
                  TextSpan(
                      text: '"$q"', style: const TextStyle(color: C.accent)),
                TextSpan(
                  text: '  ($count Film)',
                  style: TextStyle(
                      fontSize: 11, color: C.muted, fontWeight: FontWeight.w500),
                ),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filmCard(Film f, PickData? pick, int mine) {
    final byMe = pick?.mine ?? false;
    final byOther = pick != null && !byMe;
    final disabled = byOther || (pick == null && mine >= RoomService.picksPerMember);
    final label = byMe
        ? 'Terpilih'
        : byOther
            ? 'Dipilih ${pick.pickedByName}'
            : 'Pilih Film Ini';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Poster(f, width: 88, height: 132),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(f.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                    Text('${f.year}',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: C.muted)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final g in f.genres) ...[
                      Tag(g),
                      const SizedBox(width: 6),
                    ],
                    Icon(Icons.schedule, size: 12, color: C.muted),
                    const SizedBox(width: 3),
                    Text(f.duration,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: C.muted)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(f.synopsis,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, height: 1.35, color: C.soft)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: disabled ? null : () => _toggle(f, pick),
                    icon: Icon(byMe ? Icons.check : Icons.add, size: 18),
                    label: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      foregroundColor: byMe ? Colors.white : C.text,
                      disabledForegroundColor: C.muted,
                      backgroundColor: byMe ? C.accent : C.chip,
                      disabledBackgroundColor: C.chip,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBanner(int mine) {
    final remaining = RoomService.picksPerMember - mine;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: C.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: C.accent.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.bookmark_border, size: 16, color: C.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    remaining == 0
                        ? 'Pilihan sudah lengkap!'
                        : 'Pilih $remaining film lagi!',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Grup siap voting segera setelah semua slot terisi',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: C.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 50,
              height: 6,
              child: LinearProgressIndicator(
                value: mine / RoomService.picksPerMember,
                backgroundColor: C.chip,
                valueColor: const AlwaysStoppedAnimation(C.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
