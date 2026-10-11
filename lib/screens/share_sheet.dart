import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../save_image.dart';
import '../services.dart';
import '../theme.dart';

/// Data hasil voting yang dibagikan.
class ShareData {
  const ShareData({
    required this.code,
    required this.winner,
    required this.pct,
    required this.winnerVotes,
    required this.total,
    required this.rows,
  });
  final String code;
  final Film winner;
  final int pct;
  final int winnerVotes;
  final int total;

  /// Film beserta nama pemilihnya, urut dari suara terbanyak.
  final List<(Film, List<String>)> rows;

  String get link => AppLinks.roomLink(code);

  String get text {
    final b = StringBuffer()
      ..writeln('🎬 Hasil voting film Luma (Room #$code)')
      ..writeln()
      ..writeln('🏆 Pemenang: ${winner.title} (${winner.year}) ⭐ ${winner.rating}')
      ..writeln('Konsensus: $pct% ($winnerVotes dari $total suara)')
      ..writeln()
      ..writeln('Distribusi suara:');
    for (var i = 0; i < rows.length; i++) {
      b.writeln('${i + 1}. ${rows[i].$1.title} - ${rows[i].$2.length} suara');
    }
    b
      ..writeln()
      ..write('Lihat di Luma: $link');
    return b.toString();
  }
}

/// Lembar bagikan: pratinjau kartu hasil + aksi (salin link, Discord, dll).
void showShareSheet(BuildContext context, ShareData data) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ShareSheet(data: data, rootContext: context),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.data, required this.rootContext});
  final ShareData data;
  final BuildContext rootContext;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _cardKey = GlobalKey();
  bool _saving = false;

  ShareData get d => widget.data;

  /// Tutup lembar lalu tampilkan pesan (supaya tidak tertutup lembar).
  void _done(String msg) {
    Navigator.of(context).pop();
    if (widget.rootContext.mounted) showMsg(widget.rootContext, msg);
  }

  Future<void> _copy(String text, String msg) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _done(msg);
  }

  Future<void> _open(Uri uri, String failMsg) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _done(failMsg);
  }

  Future<void> _discord() async {
    // Discord tidak punya tautan bagikan resmi: salin teks lalu buka Discord.
    await Clipboard.setData(ClipboardData(text: d.text));
    final msg = 'Teks disalin. Tempel (Ctrl+V) di chat Discord kamu.';
    if (mounted) _done(msg);
    await launchUrl(Uri.parse('https://discord.com/channels/@me'),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _saveImage() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      final ok = await savePng(
          Uint8List.fromList(bytes), 'hasil-voting-luma-${d.code}.png');
      if (mounted) {
        _done(ok
            ? 'Gambar tersimpan. Kamu bisa mengunggahnya ke Discord atau chat lain.'
            : 'Simpan gambar hanya tersedia di versi web.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showMsg(context, 'Gagal membuat gambar, coba lagi');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: C.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Bagikan Hasil Voting',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Pilih cara membagikan hasil ke teman-temanmu.',
                  style: TextStyle(fontSize: 12.5, color: C.muted)),
              const SizedBox(height: 18),
              // Kartu yang juga dipakai untuk "Simpan gambar".
              RepaintBoundary(key: _cardKey, child: ShareCard(data: d)),
              const SizedBox(height: 22),
              Wrap(
                spacing: 14,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _Action(
                    icon: Icons.link,
                    color: C.accent,
                    label: 'Salin Link',
                    onTap: () => _copy(d.link, 'Link room disalin'),
                  ),
                  _Action(
                    icon: Icons.forum,
                    color: const Color(0xFF5865F2),
                    label: 'Discord',
                    onTap: _discord,
                  ),
                  _Action(
                    icon: Icons.chat,
                    color: const Color(0xFF25D366),
                    label: 'WhatsApp',
                    onTap: () => _open(
                        Uri.https('wa.me', '/', {'text': d.text}),
                        'Tidak bisa membuka WhatsApp'),
                  ),
                  _Action(
                    icon: Icons.send,
                    color: const Color(0xFF229ED9),
                    label: 'Telegram',
                    onTap: () => _open(
                        Uri.https('t.me', '/share/url',
                            {'url': d.link, 'text': d.text.split('\n').first}),
                        'Tidak bisa membuka Telegram'),
                  ),
                  _Action(
                    icon: Icons.copy,
                    color: const Color(0xFF6C6C78),
                    label: 'Salin Teks',
                    onTap: () => _copy(d.text, 'Teks hasil voting disalin'),
                  ),
                  if (kIsWeb)
                    _Action(
                      icon: Icons.download,
                      color: const Color(0xFFE08A3C),
                      label: _saving ? 'Membuat...' : 'Simpan Gambar',
                      onTap: _saveImage,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(
      {required this.icon,
      required this.color,
      required this.label,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 82,
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.35), blurRadius: 12)
                  ],
                ),
                child: Icon(icon, size: 26, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

/// Kartu hasil voting yang siap dibagikan. Warnanya tetap (tidak mengikuti
/// tema) supaya gambar yang disimpan selalu konsisten.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.data});
  final ShareData data;

  static const _bg1 = Color(0xFF2A1118);
  static const _bg2 = Color(0xFF111114);
  static const _muted = Color(0xFFA0A0A8);
  static const _gold = Color(0xFFFFC83D);

  @override
  Widget build(BuildContext context) {
    final w = data.winner;
    return Container(
      width: 340,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bg1, _bg2],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.movie, size: 16, color: C.accent),
                ),
                const SizedBox(width: 8),
                const Text('LUMA',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: C.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('HASIL VOTING',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: C.accent)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Poster(w, width: 100, height: 150, radius: 12, rating: false),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.emoji_events, size: 14, color: _gold),
                        SizedBox(width: 5),
                        Text('PEMENANG',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: _gold)),
                      ]),
                      const SizedBox(height: 6),
                      Text(w.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 20,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 6),
                      Text(
                          [
                            if (w.year > 0) '${w.year}',
                            if (w.genres.isNotEmpty) w.genres.first,
                          ].join(' • '),
                          style: const TextStyle(fontSize: 12, color: _muted)),
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.star, size: 16, color: _gold),
                        const SizedBox(width: 4),
                        Text('${w.rating}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: C.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${data.pct}% sepakat',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < data.rows.length; i++) ...[
              _VoteBar(
                rank: i + 1,
                title: data.rows[i].$1.title,
                votes: data.rows[i].$2.length,
                total: data.total,
                first: i == 0,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Room #${data.code}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _muted)),
                const Spacer(),
                Text('${data.total} peserta',
                    style: const TextStyle(fontSize: 11, color: _muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteBar extends StatelessWidget {
  const _VoteBar(
      {required this.rank,
      required this.title,
      required this.votes,
      required this.total,
      required this.first});
  final int rank;
  final String title;
  final int votes;
  final int total;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : votes / total;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: first
                    ? ShareCard._gold
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text('$rank',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: first ? Colors.black : Colors.white)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
            Text('$votes suara',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: first ? C.accent : ShareCard._muted)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(
                first ? C.accent : Colors.white.withValues(alpha: 0.4)),
          ),
        ),
      ],
    );
  }
}
