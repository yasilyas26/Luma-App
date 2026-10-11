import 'package:flutter/material.dart';

class Film {
  const Film({
    required this.title,
    required this.year,
    required this.genres,
    required this.duration,
    required this.synopsis,
    required this.rating,
    required this.colors,
    this.votes = '1M',
    this.director = '-',
    this.age = '13+',
    this.tmdbId,
    this.imdbId,
    this.posterUrl,
  });
  final String title;
  final int year;
  final List<String> genres;
  final String duration;
  final String synopsis;
  final double rating;
  final List<Color> colors;
  final String votes;
  final String director;
  final String age;
  final int? tmdbId;
  final String? imdbId;
  final String? posterUrl;

  String get id => tmdbId != null
      ? 'tmdb_$tmdbId'
      : title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'year': year,
        'genres': genres,
        'duration': duration,
        'synopsis': synopsis,
        'rating': rating,
        // ignore: deprecated_member_use
        'colors': [for (final c in colors) c.value],
        'votes': votes,
        'director': director,
        'age': age,
        'tmdbId': tmdbId,
        'imdbId': imdbId,
        'posterUrl': posterUrl,
      };

  factory Film.fromMap(Map<String, dynamic> m) => Film(
        title: m['title'] as String,
        year: (m['year'] as num).toInt(),
        genres: List<String>.from(m['genres'] as List),
        duration: m['duration'] as String,
        synopsis: m['synopsis'] as String,
        rating: (m['rating'] as num).toDouble(),
        colors: [for (final c in m['colors'] as List) Color((c as num).toInt())],
        votes: m['votes'] as String? ?? '1M',
        director: m['director'] as String? ?? '-',
        age: m['age'] as String? ?? '13+',
        tmdbId: (m['tmdbId'] as num?)?.toInt(),
        imdbId: m['imdbId'] as String?,
        posterUrl: m['posterUrl'] as String?,
      );
}

const interstellar = Film(
  title: 'Interstellar',
  year: 2014,
  genres: ['Sci-Fi', 'Adventure'],
  duration: '2j 49m',
  synopsis: 'Perjalanan luar angkasa melewati wormhole untuk mencari harapan baru',
  rating: 8.7,
  votes: '2M',
  director: 'Christopher Nolan',
  colors: [Color(0xFF0B0F1E), Color(0xFF3A2A1E), Color(0xFF8C5A2B)],
);
const bladeRunner = Film(
  title: 'Blade Runner 2049',
  year: 2017,
  genres: ['Sci-Fi', 'Mystery'],
  duration: '2j 44m',
  synopsis:
      'Detektif merekonstruksi jejak misteri lama yang mampu mengubah tatanan masyarakat',
  rating: 8.0,
  votes: '600k',
  director: 'Denis Villeneuve',
  age: '17+',
  colors: [Color(0xFFE08A3C), Color(0xFF8A4A2A), Color(0xFF2B1A14)],
);
const martian = Film(
  title: 'The Martian',
  year: 2015,
  genres: ['Sci-Fi', 'Drama'],
  duration: '2j 24m',
  synopsis: 'Seorang astronot terdampar di Mars dan harus bertahan hidup sendirian.',
  rating: 8.0,
  votes: '900k',
  director: 'Ridley Scott',
  colors: [Color(0xFF2A1A1A), Color(0xFFB5593A), Color(0xFF6B2E22)],
);
const dune = Film(
  title: 'Dune: Part Two',
  year: 2024,
  genres: ['Sci-Fi', 'Adventure'],
  duration: '2j 46m',
  synopsis:
      'Paul Atreides bersatu kembali dengan Chani dan Fremen untuk membalas dendam terhadap para konspirator yang menghancurkan keluarganya.',
  rating: 8.5,
  votes: '410k',
  director: 'Denis Villeneuve',
  colors: [Color(0xFF1B1411), Color(0xFF7A4A28), Color(0xFFD08A45)],
);
const oppenheimer = Film(
  title: 'Oppenheimer',
  year: 2023,
  genres: ['Drama', 'History'],
  duration: '3j 0m',
  synopsis:
      'Kisah J. Robert Oppenheimer dan perannya dalam pengembangan bom atom.',
  rating: 8.3,
  votes: '800k',
  director: 'Christopher Nolan',
  age: '17+',
  colors: [Color(0xFF141018), Color(0xFF5A2A1E), Color(0xFFE0782C)],
);

const searchResults = [interstellar, bladeRunner, martian];
const allFilms = [interstellar, bladeRunner, martian, dune, oppenheimer];
