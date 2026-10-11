import 'dart:typed_data';

/// Belum didukung di platform non-web. Mengembalikan false.
Future<bool> savePng(Uint8List bytes, String filename) async => false;
