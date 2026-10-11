import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'data.dart';
import 'services.dart';

/// Ulasan komunitas TMDb.
class Review {
  const Review(this.author, this.rating, this.content);
  final String author;
  final double? rating;
  final String content;
}

/// Pemeran film.
class CastMember {
  const CastMember(this.name, this.character, this.photoUrl);
  final String name;
  final String character;
  final String? photoUrl;
}

/// Data tambahan untuk halaman detail: banner, pemeran, film lainnya.
class FilmExtra {
  const FilmExtra({this.backdropUrl, this.cast = const [], this.similar = const []});
  final String? backdropUrl;
  final List<CastMember> cast;
  final List<Film> similar;
}

/// Data film dari TMDb (info, poster) dan OMDb (rating IMDb asli).
///
/// Key dibaca dari --dart-define / --dart-define-from-file=env.json:
///   TMDB_KEY (wajib), OMDB_KEY (opsional).
/// Catatan: key ini ikut terkirim ke browser. Untuk produksi, pindahkan
/// panggilan ke backend proxy (lihat PRD bagian 8.3).
class TmdbService {
  static const _tmdbKey = String.fromEnvironment('TMDB_KEY');
  static const _omdbKey = String.fromEnvironment('OMDB_KEY');

  static bool get enabled => _tmdbKey.isNotEmpty;
  static bool get omdbEnabled => _omdbKey.isNotEmpty;

  static const _base = 'https://api.themoviedb.org/3';
  static const _img = 'https://image.tmdb.org/t/p/w500';
  static const _maxResults = 10;

  /// Semua genre film TMDb (label -> id).
  static const genreIds = {
    'Action': 28,
    'Adventure': 12,
    'Animation': 16,
    'Comedy': 35,
    'Crime': 80,
    'Documentary': 99,
    'Drama': 18,
    'Family': 10751,
    'Fantasy': 14,
    'History': 36,
    'Horror': 27,
    'Music': 10402,
    'Mystery': 9648,
    'Romance': 10749,
    'Sci-Fi': 878,
    'Thriller': 53,
    'War': 10752,
    'Western': 37,
  };

  /// Platform streaming (label -> id penyedia TMDb untuk wilayah Indonesia).
  /// Beberapa platform punya lebih dari satu id.
  static const providers = {
    'Netflix': [8],
    'Prime Video': [119, 10],
    'Disney+': [337, 122],
    'Apple TV+': [350],
    'HBO Max': [1899, 384],
  };

  static const watchRegion = 'ID';

  static const platformColors = {
    'Netflix': Color(0xFFE50914),
    'Prime Video': Color(0xFF00A8E1),
    'Disney+': Color(0xFF113CCF),
    'Apple TV+': Color(0xFF8E8E93),
    'HBO Max': Color(0xFF7B2FF7),
  };

  static const _genreNames = {
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Sci-Fi',
    53: 'Thriller',
    10752: 'War',
    37: 'Western',
  };

  static const _placeholder = [
    Color(0xFF1A1A22),
    Color(0xFF2A2A34),
    Color(0xFF3A3A48),
  ];

  static final _cache = <int, Film>{};

  // ------------------------------------------------------------ Publik

  /// Cari film berdasarkan judul. [genre] memfilter hasil di sisi klien.
  static Future<List<Film>> search(String query,
      {List<String> genres = const []}) async {
    final json = await _get('/search/movie',
        {'query': query, 'include_adult': 'false', 'page': '1'});
    var results = (json['results'] as List).cast<Map<String, dynamic>>();
    final gids = {for (final g in genres) genreIds[g]}.whereType<int>().toSet();
    if (gids.isNotEmpty) {
      // Cocok kalau punya salah satu genre yang dipilih.
      results = results
          .where((r) => (r['genre_ids'] as List).any(gids.contains))
          .toList();
    }
    return _details(results);
  }

  /// Jelajah film populer, bisa difilter genre dan rentang tahun rilis.
  static Future<List<Film>> discover({
    List<String> genres = const [],
    int? yearFrom,
    int? yearTo,
    bool topRated = false,
    List<String> platforms = const [],
    bool inTheater = false,
  }) async {
    final ids = [for (final g in genres) if (genreIds[g] != null) genreIds[g]];
    final providerIds = [
      for (final p in platforms) ...?providers[p],
    ];
    String ymd(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final params = <String, String>{
      // "Teratas": urut rating tertinggi (dengan minimal suara agar adil).
      'sort_by': topRated ? 'vote_average.desc' : 'popularity.desc',
      'include_adult': 'false',
      'vote_count.gte': inTheater ? '30' : (topRated ? '1000' : '200'),
      if (ids.isNotEmpty) 'with_genres': ids.join('|'),
      if (providerIds.isNotEmpty) ...{
        'with_watch_providers': providerIds.join('|'),
        'watch_region': watchRegion,
        'with_watch_monetization_types': 'flatrate',
      },
    };
    if (inTheater) {
      // Sedang tayang di bioskop Indonesia (rilis bioskop 75 hari terakhir).
      // Rentang tahun room diabaikan karena artinya film terbaru.
      params['with_release_type'] = '3';
      params['region'] = watchRegion;
      params['release_date.gte'] =
          ymd(DateTime.now().subtract(const Duration(days: 75)));
      params['release_date.lte'] = _today;
    } else {
      if (yearFrom != null) params['primary_release_date.gte'] = '$yearFrom-01-01';
      params['primary_release_date.lte'] =
          yearTo != null && '$yearTo-12-31'.compareTo(_today) < 0
              ? '$yearTo-12-31'
              : _today;
    }
    final json = await _get('/discover/movie', params);
    final results = (json['results'] as List).cast<Map<String, dynamic>>();
    return _details(results);
  }

  // ------------------------------------------------------------ Rak film

  /// Pemenang Oscar Best Picture (id TMDb), dipakai sebagai "Most Awarded".
  /// TMDb tidak punya data penghargaan, jadi daftar ini disusun manual.
  static const _awardedIds = [
    872585, // Oppenheimer
    545611, // Everything Everywhere All at Once
    776503, // CODA
    581734, // Nomadland
    496243, // Parasite
    490132, // Green Book
    399055, // The Shape of Water
    376867, // Moonlight
    238, // The Godfather
    424, // Schindler's List
    597, // Titanic
    122, // The Lord of the Rings: The Return of the King
  ];

  static final _shelfCache = <String, List<Film>>{};

  /// Film dari data daftar TMDb (tanpa panggilan detail, jadi cepat).
  static Film _fromList(Map<String, dynamic> r) {
    final date = r['release_date'] as String? ?? '';
    final poster = r['poster_path'] as String?;
    final overview = (r['overview'] as String?)?.trim() ?? '';
    final rating = double.parse(
        ((r['vote_average'] as num?)?.toDouble() ?? 0).toStringAsFixed(1));
    return Film(
      title: r['title'] as String? ?? '-',
      year: date.length >= 4 ? int.tryParse(date.substring(0, 4)) ?? 0 : 0,
      genres: [
        for (final id in (r['genre_ids'] as List? ?? const []))
          if (_genreNames[(id as num).toInt()] != null)
            _genreNames[id.toInt()]!,
      ].take(2).toList(),
      duration: '-',
      synopsis: overview.isEmpty ? 'Sinopsis belum tersedia.' : overview,
      rating: rating,
      colors: _placeholder,
      votes: _compact((r['vote_count'] as num?)?.toInt() ?? 0),
      tmdbId: (r['id'] as num).toInt(),
      posterUrl: poster == null ? null : '$_img$poster',
    );
  }

  /// Rak film untuk Home. [kind]: 'top' (rating tertinggi), 'theater'
  /// (sedang tayang di bioskop Indonesia), atau 'awarded' (pemenang Oscar).
  static Future<List<Film>> shelf(String kind) async {
    if (!enabled) return const [];
    final cached = _shelfCache[kind];
    if (cached != null) return cached;

    List<Film> films;
    if (kind == 'awarded') {
      films = await Future.wait(_awardedIds.map(_detail));
    } else {
      final json = kind == 'top'
          ? await _get('/movie/top_rated', {'page': '1'})
          : await _get(
              '/movie/now_playing', {'page': '1', 'region': watchRegion});
      films = [
        for (final r in (json['results'] as List).cast<Map<String, dynamic>>())
          if (r['poster_path'] != null && _released(r)) _fromList(r),
      ].take(12).toList();
    }
    return _shelfCache[kind] = films;
  }

  // ------------------------------------------------------ Detail film

  static final _extraCache = <int, FilmExtra>{};

  /// Detail lengkap satu film (sutradara, durasi, rating).
  static Future<Film> film(int id) => _detail(id);

  /// Banner, pemeran, dan film lain yang direkomendasikan TMDb.
  static Future<FilmExtra> extra(int id) async {
    final cached = _extraCache[id];
    if (cached != null) return cached;
    final d = await _get(
        '/movie/$id', {'append_to_response': 'credits,recommendations'});
    final back = d['backdrop_path'] as String?;
    final cast = [
      for (final c in ((d['credits']?['cast'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .take(12))
        CastMember(
          c['name'] as String? ?? '-',
          c['character'] as String? ?? '',
          c['profile_path'] == null
              ? null
              : 'https://image.tmdb.org/t/p/w185${c['profile_path']}',
        ),
    ];
    final recs = [
      for (final r in ((d['recommendations']?['results'] as List?) ?? const [])
          .cast<Map<String, dynamic>>())
        if (r['poster_path'] != null && _released(r) && r['id'] != id)
          _fromList(r),
    ].take(12).toList();
    return _extraCache[id] = FilmExtra(
      backdropUrl: back == null ? null : 'https://image.tmdb.org/t/p/w780$back',
      cast: cast,
      similar: recs,
    );
  }

  // ----------------------------------------------------------- Ulasan

  static final _reviewCache = <int, Review?>{};

  /// Ulasan paling tepercaya: rating pengulas tertinggi dengan isi cukup
  /// panjang. Mengembalikan null kalau film belum punya ulasan.
  static Future<Review?> topReview(int tmdbId) async {
    if (!enabled) return null;
    if (_reviewCache.containsKey(tmdbId)) return _reviewCache[tmdbId];
    try {
      final json =
          await _get('/movie/$tmdbId/reviews', {'page': '1', 'language': 'en-US'});
      final list = (json['results'] as List).cast<Map<String, dynamic>>();
      String clean(String s) => s
          .replaceAll(RegExp(r'[\r\n]+'), ' ')
          .replaceAll(RegExp(r'[*_#>`]+'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final candidates = [
        for (final r in list)
          if (clean(r['content'] as String? ?? '').length >= 120) r,
      ];
      final pool = candidates.isNotEmpty ? candidates : list;
      if (pool.isEmpty) return _reviewCache[tmdbId] = null;

      double score(Map<String, dynamic> r) =>
          ((r['author_details']?['rating'] as num?)?.toDouble() ?? 0);
      pool.sort((a, b) {
        final c = score(b).compareTo(score(a));
        if (c != 0) return c;
        return clean(b['content'] as String? ?? '')
            .length
            .compareTo(clean(a['content'] as String? ?? '').length);
      });
      final best = pool.first;
      var text = clean(best['content'] as String? ?? '');
      if (text.length > 700) text = '${text.substring(0, 700).trimRight()}...';
      final rating = (best['author_details']?['rating'] as num?)?.toDouble();
      return _reviewCache[tmdbId] = Review(
        (best['author'] as String?)?.trim().isNotEmpty == true
            ? best['author'] as String
            : 'Anonim',
        rating,
        text,
      );
    } catch (_) {
      return null;
    }
  }

  static List<String>? _posterCache;

  /// URL poster film populer yang sudah rilis (untuk dekorasi), maks 9.
  static Future<List<String>> popularPosters() async {
    if (!enabled) return const [];
    final cached = _posterCache;
    if (cached != null) return cached;
    try {
      final json = await _get('/movie/popular', {'page': '1'});
      final list = [
        for (final r in (json['results'] as List).cast<Map<String, dynamic>>())
          if (r['poster_path'] != null && _released(r)) '$_img${r['poster_path']}'
      ];
      return _posterCache = list.take(9).toList();
    } catch (_) {
      return const [];
    }
  }

  // ----------------------------------------------------------- Internal

  static Future<Map<String, dynamic>> _get(
      String path, Map<String, String> query) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: {
      'api_key': _tmdbKey,
      'language': 'id-ID',
      ...query,
    });
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 12));
      if (r.statusCode == 401) throw AppError('API key TMDb tidak valid');
      if (r.statusCode != 200) {
        throw AppError('Gagal memuat film (${r.statusCode})');
      }
      return jsonDecode(r.body) as Map<String, dynamic>;
    } on AppError {
      rethrow;
    } catch (_) {
      throw AppError('Tidak bisa terhubung ke TMDb');
    }
  }

  static String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Hanya film yang sudah rilis (tanggal rilis ada dan tidak melewati hari ini).
  static bool _released(Map<String, dynamic> r) {
    final d = r['release_date'] as String? ?? '';
    return d.isNotEmpty && d.compareTo(_today) <= 0;
  }

  static Future<List<Film>> _details(List<Map<String, dynamic>> results) async {
    final ids = [
      for (final r in results.where(_released).take(_maxResults))
        (r['id'] as num).toInt()
    ];
    return Future.wait(ids.map(_detail));
  }

  static Future<Film> _detail(int id) async {
    final cached = _cache[id];
    if (cached != null) return cached;

    final d = await _get('/movie/$id', {'append_to_response': 'credits'});

    final genres = [
      for (final g in d['genres'] as List)
        _genreNames[(g['id'] as num).toInt()] ?? g['name'] as String,
    ];
    final runtime = (d['runtime'] as num?)?.toInt() ?? 0;
    final date = d['release_date'] as String? ?? '';
    final overview = (d['overview'] as String?)?.trim() ?? '';
    final crew = (d['credits']?['crew'] as List?) ?? const [];
    final director = crew
        .cast<Map<String, dynamic>>()
        .where((c) => c['job'] == 'Director')
        .map((c) => c['name'] as String)
        .firstOrNull;
    final poster = d['poster_path'] as String?;
    final imdbId = d['imdb_id'] as String?;

    var rating = ((d['vote_average'] as num?)?.toDouble() ?? 0);
    rating = double.parse(rating.toStringAsFixed(1));
    var votes = _compact((d['vote_count'] as num?)?.toInt() ?? 0);

    // Rating IMDb asli via OMDb (opsional).
    if (omdbEnabled && imdbId != null && imdbId.isNotEmpty) {
      final imdb = await _omdb(imdbId);
      if (imdb != null) {
        rating = imdb.$1;
        votes = imdb.$2;
      }
    }

    final film = Film(
      title: d['title'] as String? ?? '-',
      year: date.length >= 4 ? int.tryParse(date.substring(0, 4)) ?? 0 : 0,
      genres: genres.isEmpty ? const ['Film'] : genres.take(2).toList(),
      duration: runtime > 0 ? '${runtime ~/ 60}j ${runtime % 60}m' : '-',
      synopsis: overview.isEmpty ? 'Sinopsis belum tersedia.' : overview,
      rating: rating,
      colors: _placeholder,
      votes: votes,
      director: director ?? '-',
      age: d['adult'] == true ? '18+' : '13+',
      tmdbId: id,
      imdbId: imdbId,
      posterUrl: poster == null ? null : '$_img$poster',
    );
    _cache[id] = film;
    return film;
  }

  /// (rating, jumlah vote) IMDb dari OMDb, atau null kalau tidak tersedia.
  static Future<(double, String)?> _omdb(String imdbId) async {
    try {
      final uri = Uri.https(
          'www.omdbapi.com', '/', {'i': imdbId, 'apikey': _omdbKey});
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (j['Response'] != 'True') return null;
      final rating = double.tryParse('${j['imdbRating']}');
      if (rating == null) return null;
      final votes =
          int.tryParse('${j['imdbVotes']}'.replaceAll(',', '')) ?? 0;
      return (rating, _compact(votes));
    } catch (_) {
      return null;
    }
  }

  static String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).round()}k';
    return '$n';
  }
}
