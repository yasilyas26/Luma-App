import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'data.dart';
import 'photo_picker.dart';

/// Link ke room, dipakai untuk "Salin Link" dan tautan ajakan.
class AppLinks {
  static const _prodOrigin = 'https://luma-app-3d8b7.web.app';

  /// Contoh: https://luma-app-3d8b7.web.app/?room=48203
  static String roomLink(String code) {
    final origin = kIsWeb ? Uri.base.origin : _prodOrigin;
    return '$origin/?room=$code';
  }

  /// Kode verifikasi email dari tautan (?mode=verifyEmail&oobCode=...).
  static String? verifyFromUri(Uri uri) {
    final q = uri.queryParameters;
    final code = q['oobCode'];
    return (q['mode'] == 'verifyEmail' && code != null && code.isNotEmpty)
        ? code
        : null;
  }

  /// Kode reset sandi dari tautan email (?mode=resetPassword&oobCode=...).
  static String? resetFromUri(Uri uri) {
    final q = uri.queryParameters;
    final code = q['oobCode'];
    return (q['mode'] == 'resetPassword' && code != null && code.isNotEmpty)
        ? code
        : null;
  }

  /// Kode room dari link yang dibuka (?room=12345), atau null.
  static String? roomFromUri(Uri uri) {
    final c = uri.queryParameters['room'];
    return (c != null && RegExp(r'^\d{5}$').hasMatch(c)) ? c : null;
  }
}

/// Kode room dari link yang menunggu diproses setelah pengguna login.
class DeepLink {
  static String? roomCode;

  /// Kode reset sandi dari tautan email yang menunggu diproses.
  static String? resetCode;

  /// Kode verifikasi email dari tautan yang menunggu diproses.
  static String? verifyCode;
}

/// Aturan kata sandi: harus kombinasi huruf besar, huruf kecil, dan angka.
class PasswordRules {
  static const labels = [
    'Minimal 8 karakter',
    'Huruf besar (A-Z)',
    'Huruf kecil (a-z)',
    'Angka (0-9)',
  ];

  static const hint =
      'Kata sandi minimal 8 karakter dan harus kombinasi huruf besar, huruf kecil, dan angka';

  static List<bool> check(String p) => [
        p.length >= 8,
        RegExp(r'[A-Z]').hasMatch(p),
        RegExp(r'[a-z]').hasMatch(p),
        RegExp(r'\d').hasMatch(p),
      ];

  static bool valid(String p) => check(p).every((e) => e);
}

/// Error dengan pesan siap tampil ke pengguna.
class AppError implements Exception {
  AppError(this.message);
  final String message;
  @override
  String toString() => message;
}

// ---------------------------------------------------------------- Auth

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static User? get user => _auth.currentUser;
  static String get uid => user!.uid;

  static String get name {
    final u = user;
    if (u == null) return 'Tamu';
    final n = u.displayName;
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return (u.email ?? 'Pengguna').split('@').first;
  }

  static String get email => user?.email ?? '-';

  /// Cara login yang dipakai akun ini.
  static String get providerLabel {
    final ids = user?.providerData.map((p) => p.providerId).toList() ?? const [];
    if (ids.contains('google.com')) return 'Google';
    if (ids.contains('password')) return 'Email & kata sandi';
    return '-';
  }

  static bool get usesPassword =>
      user?.providerData.any((p) => p.providerId == 'password') ?? false;

  static Future<void> updateName(String name) => _wrap(() async {
        await user?.updateDisplayName(name);
        await user?.reload();
      });

  /// Konfirmasi ulang identitas sebelum aksi sensitif.
  static Future<void> _reauth(String? password) async {
    final u = user!;
    if (usesPassword) {
      if (password == null || password.isEmpty) {
        throw AppError('Masukkan kata sandi kamu');
      }
      await u.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: u.email!, password: password));
    } else {
      await u.reauthenticateWithPopup(GoogleAuthProvider());
    }
  }

  /// Ubah kata sandi (butuh kata sandi saat ini).
  static Future<void> changePassword(String current, String next) => _wrap(
        () async {
          await _reauth(current);
          await user!.updatePassword(next);
        },
        wrongPassword: 'Kata sandi saat ini salah',
      );

  /// Hapus akun beserta data room dan fotonya.
  static Future<void> deleteAccount({String? password}) => _wrap(
        () async {
          await _reauth(password);
          await RoomService.deleteMyData();
          await user!.delete();
        },
        wrongPassword: 'Kata sandi salah',
      );

  static Future<void> signIn(String email, String pass) => _wrap(
      () => _auth.signInWithEmailAndPassword(email: email, password: pass));

  static Future<void> register(String name, String email, String pass) =>
      _wrap(() async {
        final c = await _auth.createUserWithEmailAndPassword(
            email: email, password: pass);
        await c.user?.updateDisplayName(name);
        await c.user?.reload();
        // Email harus valid: kirim tautan verifikasi ke alamat tersebut.
        await c.user?.sendEmailVerification();
      });

  /// Akun email & kata sandi yang emailnya belum diverifikasi.
  static bool get needsVerification =>
      user != null && usesPassword && !(user!.emailVerified);

  static Future<void> sendVerification() =>
      _wrap(() async => user!.sendEmailVerification());

  /// Muat ulang data akun; true kalau email sudah terverifikasi.
  static Future<bool> refreshVerified() async {
    try {
      await user?.reload();
    } catch (_) {}
    return user?.emailVerified ?? false;
  }

  static Future<void> applyVerifyCode(String code) =>
      _wrap(() => _auth.applyActionCode(code));

  /// Masuk dengan Google. Mengembalikan true kalau akunnya baru dibuat.
  static Future<bool> google() async {
    var isNew = false;
    await _wrap(() async {
      final c = await _auth.signInWithPopup(GoogleAuthProvider());
      isNew = c.additionalUserInfo?.isNewUser ?? false;
    });
    return isNew;
  }

  /// Cek kode dari tautan reset; mengembalikan email pemiliknya.
  static Future<String> verifyResetCode(String code) async {
    late String email;
    await _wrap(() async => email = await _auth.verifyPasswordResetCode(code));
    return email;
  }

  static Future<void> confirmReset(String code, String password) =>
      _wrap(() => _auth.confirmPasswordReset(code: code, newPassword: password));

  static Future<void> resetPassword(String email) =>
      _wrap(() => _auth.sendPasswordResetEmail(email: email));

  static Future<void> signOut() => _auth.signOut();

  static Future<void> _wrap(Future<dynamic> Function() f,
      {String? wrongPassword}) async {
    try {
      await f();
    } on FirebaseAuthException catch (e) {
      if (wrongPassword != null &&
          (e.code == 'wrong-password' || e.code == 'invalid-credential')) {
        throw AppError(wrongPassword);
      }
      throw AppError(_authMessage(e.code));
    }
  }

  static String _authMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Format email tidak valid';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau kata sandi salah';
      case 'email-already-in-use':
        return 'Email sudah terdaftar, silakan masuk';
      case 'requires-recent-login':
        return 'Sesi login sudah lama, silakan login ulang lalu coba lagi';
      case 'expired-action-code':
        return 'Tautan sudah kedaluwarsa';
      case 'invalid-action-code':
        return 'Tautan tidak valid atau sudah dipakai';
      case 'weak-password':
        return 'Kata sandi terlalu lemah';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Login Google dibatalkan';
      case 'operation-not-allowed':
        return 'Metode login ini belum diaktifkan di Firebase';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan, coba lagi nanti';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet';
      default:
        return 'Terjadi kesalahan ($code)';
    }
  }
}

// --------------------------------------------------------- Foto profil

/// Foto profil disimpan sebagai gambar kecil (base64) di dokumen `users/{uid}`
/// supaya tetap gratis tanpa Firebase Storage.
class ProfilePhoto {
  /// Foto yang diunggah pengguna (kalau ada).
  static final bytes = ValueNotifier<Uint8List?>(null);

  /// Pakai foto akun Google bila tidak ada foto unggahan.
  static final useGoogle = ValueNotifier<bool>(true);

  static const _maxBytes = 300 * 1024;

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('users').doc(AuthService.uid);

  /// URL foto akun Google (null kalau login bukan lewat Google).
  static String? get googleUrl {
    final u = AuthService.user;
    if (u == null) return null;
    for (final p in u.providerData) {
      if (p.providerId == 'google.com' && (p.photoURL ?? '').isNotEmpty) {
        return _bigger(p.photoURL!);
      }
    }
    return null;
  }

  // Minta ukuran lebih besar dari Google (default 96px).
  static String _bigger(String url) =>
      url.replaceAll(RegExp(r'=s\d+(-c)?$'), '=s256-c');

  /// Sedang menampilkan foto Google (bukan unggahan)?
  static bool get showingGoogle =>
      bytes.value == null && useGoogle.value && googleUrl != null;

  static Future<void> load() async {
    try {
      final d = await _doc.get();
      final data = d.data();
      final b64 = data?['photo'] as String?;
      bytes.value = b64 == null ? null : base64Decode(b64);
      useGoogle.value = data?['useGoogle'] as bool? ?? true;
      // Simpan URL foto Google supaya anggota lain bisa menampilkannya.
      final g = googleUrl;
      if (g != null && data?['gphoto'] != g) {
        await _doc.set({'gphoto': g}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  /// Pilih foto dari perangkat, kecilkan, lalu simpan. Mengembalikan false
  /// kalau pengguna membatalkan.
  static Future<bool> pickAndSave() async {
    final data = await pickProfileImage();
    if (data == null) return false;
    if (data.length > _maxBytes) {
      throw AppError('Gambar terlalu besar, pilih foto lain');
    }
    await _write({
      'photo': base64Encode(data),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    bytes.value = data;
    return true;
  }

  /// Pakai foto dari akun Google (menghapus foto unggahan).
  static Future<void> useGooglePhoto() async {
    await _write({
      'photo': FieldValue.delete(),
      'useGoogle': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    bytes.value = null;
    useGoogle.value = true;
  }

  /// Hapus foto sama sekali, kembali ke inisial nama.
  static Future<void> remove() async {
    await _write({
      'photo': FieldValue.delete(),
      'useGoogle': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    bytes.value = null;
    useGoogle.value = false;
  }

  static Future<void> _write(Map<String, Object?> data) async {
    try {
      await _doc.set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AppError('Gagal menyimpan foto (${e.code}). Pastikan rules Firestore sudah di-deploy.');
    }
  }

  /// Dipanggil saat logout.
  static void clear() {
    bytes.value = null;
    useGoogle.value = true;
  }
}

/// Foto profil milik pengguna lain (untuk daftar anggota).
class UserPhoto {
  const UserPhoto({this.bytes, this.url});
  final Uint8List? bytes;
  final String? url;
}

class UserPhotos {
  static final _cache = <String, Future<UserPhoto>>{};

  static Future<UserPhoto> of(String uid) => _cache.putIfAbsent(uid, () async {
        try {
          final d = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          final m = d.data();
          if (m == null) return const UserPhoto();
          final b64 = m['photo'] as String?;
          if (b64 != null) return UserPhoto(bytes: base64Decode(b64));
          if (m['useGoogle'] != false && (m['gphoto'] as String?) != null) {
            return UserPhoto(url: m['gphoto'] as String);
          }
          return const UserPhoto();
        } catch (_) {
          _cache.remove(uid);
          return const UserPhoto();
        }
      });
}

// -------------------------------------------------------------- Models

class RoomData {
  RoomData({
    required this.code,
    required this.name,
    required this.hostId,
    required this.hostName,
    required this.status,
    required this.genres,
    required this.yearFrom,
    required this.yearTo,
    required this.maxMembers,
    required this.pool,
    this.providers = const [],
    this.inTheater = false,
    required this.memberIds,
    this.createdAt,
  });

  final String code;
  final String name;
  final String hostId;
  final String hostName;
  final String status; // selecting | voting | completed | closed
  final List<String> genres;
  final int yearFrom;
  final int yearTo;
  final int maxMembers;
  final int pool;
  final List<String> providers;
  final bool inTheater;
  final List<String> memberIds;
  final DateTime? createdAt;

  bool get isHost => hostId == AuthService.uid;

  factory RoomData.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return RoomData(
      code: d.id,
      name: m['name'] as String? ?? 'Room',
      hostId: m['hostId'] as String? ?? '',
      hostName: m['hostName'] as String? ?? '-',
      status: m['status'] as String? ?? 'selecting',
      genres: List<String>.from(m['genres'] as List? ?? const []),
      yearFrom: (m['yearFrom'] as num?)?.toInt() ?? 1950,
      yearTo: (m['yearTo'] as num?)?.toInt() ?? 2030,
      maxMembers: (m['maxMembers'] as num?)?.toInt() ?? 10,
      pool: (m['pool'] as num?)?.toInt() ?? 15,
      providers: List<String>.from(m['providers'] as List? ?? const []),
      inTheater: m['inTheater'] == true,
      memberIds: List<String>.from(m['memberIds'] as List? ?? const []),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class MemberData {
  MemberData(this.uid, this.name, this.role, this.ready);
  final String uid;
  final String name;
  final String role; // host | member
  final bool ready;

  bool get isMe => uid == AuthService.uid;
}

class PickData {
  PickData(this.film, this.pickedBy, this.pickedByName);
  final Film film;
  final String pickedBy;
  final String pickedByName;

  bool get mine => pickedBy == AuthService.uid;
}

// ---------------------------------------------------------------- Room

class RoomService {
  static final _db = FirebaseFirestore.instance;
  static const picksPerMember = 2;

  static DocumentReference<Map<String, dynamic>> _room(String code) =>
      _db.collection('rooms').doc(code);

  // ---- Create

  static Future<String> createRoom({
    required String name,
    required List<String> genres,
    required int yearFrom,
    required int yearTo,
    required int maxMembers,
    required int pool,
    List<String> providers = const [],
    bool inTheater = false,
  }) async {
    final rnd = Random.secure();
    for (var i = 0; i < 12; i++) {
      final code = (10000 + rnd.nextInt(90000)).toString();
      if (_isGuessable(code)) continue;
      final ref = _room(code);
      final ok = await _db.runTransaction<bool>((tx) async {
        if ((await tx.get(ref)).exists) return false;
        tx.set(ref, {
          'name': name,
          'hostId': AuthService.uid,
          'hostName': AuthService.name,
          'status': 'selecting',
          'genres': genres,
          'yearFrom': yearFrom,
          'yearTo': yearTo,
          'maxMembers': maxMembers,
          'pool': pool,
          'providers': providers,
          'inTheater': inTheater,
          'memberIds': [AuthService.uid],
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(ref.collection('members').doc(AuthService.uid), {
          'name': AuthService.name,
          'role': 'host',
          'ready': false,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (ok) return code;
    }
    throw AppError('Gagal membuat kode room, coba lagi');
  }

  /// Tolak kode berpola: 11111, 12345, 54321, atau ada 3 digit berurutan/kembar.
  static bool _isGuessable(String code) {
    final d = code.codeUnits.map((c) => c - 48).toList();
    for (var i = 0; i + 2 < d.length; i++) {
      final a = d[i + 1] - d[i];
      final b = d[i + 2] - d[i + 1];
      if (a == b && a.abs() <= 1) return true;
    }
    return false;
  }

  // ---- Read

  static Future<RoomData?> findRoom(String code) async {
    final d = await _room(code).get();
    return d.exists ? RoomData.fromDoc(d) : null;
  }

  static Stream<RoomData?> watchRoom(String code) =>
      _room(code).snapshots().map((d) => d.exists ? RoomData.fromDoc(d) : null);

  static Stream<List<MemberData>> watchMembers(String code) =>
      _room(code).collection('members').orderBy('joinedAt').snapshots().map(
            (s) => [
              for (final d in s.docs)
                MemberData(d.id, d['name'] as String? ?? '-',
                    d['role'] as String? ?? 'member', d['ready'] == true),
            ],
          );

  static Stream<List<PickData>> watchPicks(String code) =>
      _room(code).collection('picks').orderBy('pickedAt').snapshots().map(
            (s) => [
              for (final d in s.docs)
                PickData(
                  Film.fromMap(Map<String, dynamic>.from(d['film'] as Map)),
                  d['pickedBy'] as String,
                  d['pickedByName'] as String? ?? '-',
                ),
            ],
          );

  /// uid -> id film yang dipilih.
  static Stream<Map<String, String>> watchVotes(String code) =>
      _room(code).collection('votes').snapshots().map(
            (s) => {for (final d in s.docs) d.id: d['filmId'] as String},
          );

  static Stream<List<RoomData>> watchMyRooms() => _db
      .collection('rooms')
      .where('memberIds', arrayContains: AuthService.uid)
      .snapshots()
      .map((s) {
        final list = [for (final d in s.docs) RoomData.fromDoc(d)];
        list.sort((a, b) => (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now()));
        return list;
      });

  // ---- Join / Leave

  static Future<void> join(String code) async {
    final ref = _room(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw AppError('Room tidak ditemukan');
      final room = RoomData.fromDoc(snap);
      final member = room.memberIds.contains(AuthService.uid);
      if (member) return;
      if (room.status == 'completed' || room.status == 'closed') {
        throw AppError('Voting sudah selesai');
      }
      if (room.status != 'selecting') {
        throw AppError('Voting sudah dimulai, tidak bisa bergabung lagi');
      }
      if (room.memberIds.length >= room.maxMembers) {
        throw AppError('Room sudah penuh');
      }
      tx.update(ref, {
        'memberIds': FieldValue.arrayUnion([AuthService.uid]),
      });
      tx.set(ref.collection('members').doc(AuthService.uid), {
        'name': AuthService.name,
        'role': 'member',
        'ready': false,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> leave(String code) async {
    final ref = _room(code);
    final picks =
        await ref.collection('picks').where('pickedBy', isEqualTo: AuthService.uid).get();
    final batch = _db.batch();
    for (final d in picks.docs) {
      batch.delete(d.reference);
    }
    batch.delete(ref.collection('members').doc(AuthService.uid));
    batch.delete(ref.collection('votes').doc(AuthService.uid));
    batch.update(ref, {
      'memberIds': FieldValue.arrayRemove([AuthService.uid]),
    });
    await batch.commit();
  }

  // ---- Create / Delete pilihan film

  static Future<void> addPick(String code, Film film) async {
    final ref = _room(code).collection('picks');
    final mine = await ref.where('pickedBy', isEqualTo: AuthService.uid).get();
    if (mine.docs.length >= picksPerMember) {
      throw AppError('Maksimal $picksPerMember film per anggota');
    }
    await ref.doc(film.id).set({
      'film': film.toMap(),
      'pickedBy': AuthService.uid,
      'pickedByName': AuthService.name,
      'pickedAt': FieldValue.serverTimestamp(),
    });
    // Pilihan berubah, status siap direset.
    await _room(code)
        .collection('members')
        .doc(AuthService.uid)
        .update({'ready': false});
  }

  static Future<void> removePick(String code, String filmId) async {
    await _room(code).collection('picks').doc(filmId).delete();
    await _room(code)
        .collection('members')
        .doc(AuthService.uid)
        .update({'ready': false});
  }

  // ---- Update status

  static Future<void> setReady(String code) async {
    final ref = _room(code);
    await ref.collection('members').doc(AuthService.uid).update({'ready': true});
    final members = await ref.collection('members').get();
    if (members.docs.isNotEmpty &&
        members.docs.every((d) => d['ready'] == true)) {
      await startVoting(code);
    }
  }

  static Future<void> startVoting(String code) async {
    final picks = await _room(code).collection('picks').get();
    if (picks.docs.isEmpty) throw AppError('Belum ada film yang dipilih');
    // Putaran baru: pastikan tidak ada suara sisa dari putaran sebelumnya.
    await _clearVotes(code);
    await _room(code).update({'status': 'voting'});
  }

  static Future<void> vote(String code, String filmId) =>
      _room(code).collection('votes').doc(AuthService.uid).set({
        'filmId': filmId,
        'name': AuthService.name,
        'votedAt': FieldValue.serverTimestamp(),
      });

  /// Anggota membuka kembali room yang belum punya pemenang: room kembali ke
  /// tahap memilih film dan suara lama dihapus (tanpa membuat room baru).
  static Future<void> reopenRoom(String code) async {
    await _room(code).update({'status': 'selecting'});
    await _clearVotes(code);
    // Status "siap" semua anggota di-reset: harus konfirmasi siap lagi.
    final members = await _room(code).collection('members').get();
    final batch = _db.batch();
    for (final d in members.docs) {
      if (d.data()['ready'] == true) batch.update(d.reference, {'ready': false});
    }
    await batch.commit();
  }

  static Future<void> _clearVotes(String code) async {
    final votes = await _room(code).collection('votes').get();
    if (votes.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in votes.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  /// Host mengakhiri sesi. Anggota yang sedang di dalam room dikeluarkan.
  static Future<void> endRoom(String code) =>
      _room(code).update({'status': 'closed'});

  static Future<void> closeRoom(String code) =>
      _room(code).update({'status': 'completed'});

  // ---- Hapus semua data milik pengguna (dipakai saat hapus akun)

  static Future<void> deleteMyData() async {
    final uid = AuthService.uid;
    try {
      final rooms = await _db
          .collection('rooms')
          .where('memberIds', arrayContains: uid)
          .get();
      for (final d in rooms.docs) {
        try {
          if (d.data()['hostId'] == uid) {
            await deleteRoom(d.id);
          } else {
            await leave(d.id);
          }
        } catch (_) {}
      }
    } catch (_) {}
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (_) {}
  }

  // ---- Delete room

  static Future<void> deleteRoom(String code) async {
    final ref = _room(code);
    for (final sub in ['picks', 'members', 'votes']) {
      final docs = await ref.collection(sub).get();
      final batch = _db.batch();
      for (final d in docs.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    await ref.delete();
  }
}
