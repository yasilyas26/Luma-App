import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

/// Palet warna. Nilainya mengikuti mode terang/gelap ([dark]).
class C {
  static bool dark = true;
  static Color _p(int d, int l) => Color(dark ? d : l);

  static Color get outer => _p(0xFF0A0A0C, 0xFFE9E9EE);
  static Color get bg => _p(0xFF111114, 0xFFF4F4F7);
  static Color get card => _p(0xFF1B1B1F, 0xFFFFFFFF);
  static Color get deep => _p(0xFF0E0E11, 0xFFF0F0F4);
  static Color get field => _p(0xFF1E1E22, 0xFFFFFFFF);
  static Color get border => _p(0xFF2C2C32, 0xFFD9D9E0);
  static Color get chip => _p(0xFF2A2A2F, 0xFFECECF1);
  // Chip pilihan: di mode terang berlatar putih + garis tegas agar jelas.
  static Color get chipFill => _p(0xFF2A2A2F, 0xFFFFFFFF);
  static Color get chipBorder => _p(0xFF3A3A42, 0xFFC9C9D3);
  static Color get text => _p(0xFFF2F2F4, 0xFF17171C);
  static Color get muted => _p(0xFFA0A0A8, 0xFF6C6C78);
  static Color get soft => _p(0xFFC4C4CA, 0xFF4A4A55);
  static Color get pink => _p(0xFFE8A0A8, 0xFFD43A4C);
  static Color get gold => _p(0xFFFFC83D, 0xFFD99A00);
  static Color get glow => _p(0xFF3A1E24, 0xFFFFE1E4);

  // Sama di kedua mode.
  static const accent = Color(0xFFFF4D5E);

  // Lapisan gelap di atas poster: teksnya selalu putih.
  static const overlay = Color(0xCC111114);
  static const onOverlay = Colors.white;
  static const onOverlayMuted = Color(0xB3FFFFFF);
}

/// Mode tema: ikuti perangkat, terang, atau gelap. Disimpan di perangkat.
class ThemeController {
  static const _key = 'theme_mode';

  /// Pilihan pengguna.
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Hasil akhir (true = gelap), sudah memperhitungkan pengaturan perangkat.
  static final dark = ValueNotifier<bool>(true);

  static final _observer = _BrightnessObserver();

  static bool _effective() {
    switch (mode.value) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      var v = p.getString(_key);
      // Migrasi dari pengaturan lama (true/false).
      if (v == null && p.containsKey('theme_dark')) {
        v = (p.getBool('theme_dark') ?? true) ? 'dark' : 'light';
      }
      mode.value = switch (v) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
    } catch (_) {}
    WidgetsBinding.instance.addObserver(_observer);
    _apply(rebuild: false);
  }

  static Future<void> setMode(ThemeMode m) async {
    mode.value = m;
    _apply();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, switch (m) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      });
    } catch (_) {}
  }

  static void _apply({bool rebuild = true}) {
    final d = _effective();
    if (C.dark == d && dark.value == d) return;
    C.dark = d;
    dark.value = d;
    if (!rebuild) return;
    // Warna dibaca langsung dari C, jadi seluruh pohon widget dibangun ulang.
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }
}

/// Memantau perubahan tema perangkat saat mode "ikuti perangkat" aktif.
class _BrightnessObserver with WidgetsBindingObserver {
  @override
  void didChangePlatformBrightness() {
    if (ThemeController.mode.value == ThemeMode.system) {
      ThemeController._apply();
    }
  }
}

ThemeData lumaTheme(bool dark) {
  final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: base.colorScheme.copyWith(primary: C.accent),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .apply(bodyColor: C.text, displayColor: C.text),
  );
}

/// Tata letak responsif untuk web:
/// - layar sempit: konten memenuhi lebar layar
/// - layar lebar: konten dipusatkan dengan lebar maksimum, latar tetap seragam
///   (tanpa bingkai atau garis tepi)
Widget phoneFrame(BuildContext context, Widget? child) {
  const maxContentWidth = 640.0;
  // Cegah teks terlalu besar/kecil merusak tata letak.
  final content = MediaQuery.withClampedTextScaling(
    minScaleFactor: 0.9,
    maxScaleFactor: 1.15,
    child: child ?? const SizedBox.shrink(),
  );

  return ColoredBox(
    color: C.bg,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: content,
      ),
    ),
  );
}

class LumaMark extends StatelessWidget {
  const LumaMark({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: C.border),
        ),
        child: Icon(Icons.movie, size: size * 0.5, color: C.accent),
      );
}

class LumaLogo extends StatelessWidget {
  const LumaLogo({super.key});
  @override
  Widget build(BuildContext context) => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LumaMark(),
          SizedBox(width: 12),
          Text('LUMA',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        ],
      );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
      {super.key,
      required this.label,
      required this.onTap,
      this.icon,
      this.trailing,
      this.height = 48});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? trailing;
  final double height;
  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: C.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: C.chip,
          disabledForegroundColor: C.muted,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 8)],
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : C.muted)),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Icon(trailing, size: 19)
            ],
          ],
        ),
      ),
    );
  }
}

class CardBox extends StatelessWidget {
  const CardBox(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(14),
      this.color,
      this.borderColor,
      this.radius = 14});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? C.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor ?? C.border),
        ),
        child: child,
      );
}

class SquareIconButton extends StatelessWidget {
  const SquareIconButton(
      {super.key, required this.icon, required this.onTap, this.size = 40});
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: C.field,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.border),
          ),
          child: Icon(icon, size: 20),
        ),
      );
}

class SegTabs extends StatelessWidget {
  const SegTabs(
      {super.key,
      required this.labels,
      this.icons,
      required this.index,
      required this.onChanged});
  final List<String> labels;
  final List<IconData>? icons;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.border),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onChanged(i),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: i == index ? C.chip : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          i == index ? Border.all(color: C.border) : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icons != null) ...[
                          Icon(icons![i],
                              size: 18,
                              color: i == index ? C.accent : C.muted),
                          const SizedBox(width: 8),
                        ],
                        Text(labels[i],
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: i == index ? C.text : C.muted)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class Avatar extends StatelessWidget {
  const Avatar(this.letter, {super.key, this.color, this.size = 36});
  final String letter;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) {
    final bg = color ?? C.chip;
    final textColor = bg.computeLuminance() > 0.5
        ? Colors.black
        : (bg == C.accent ? Colors.white : C.text);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: C.bg, width: 2),
      ),
      child: Text(letter,
          style: TextStyle(
              fontSize: size * 0.38,
              fontWeight: FontWeight.w800,
              color: textColor)),
    );
  }
}

/// Poster placeholder bergradien (belum terhubung ke TMDb).
class Poster extends StatelessWidget {
  const Poster(this.film,
      {super.key, this.width, this.height, this.radius = 8, this.rating = true});
  final Film film;
  final double? width;
  final double? height;
  final double radius;
  final bool rating;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: film.colors,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.3, -0.2),
                    radius: 0.7,
                    colors: [
                      film.colors.last.withValues(alpha: 0.55),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),
            if (film.posterUrl != null)
              Positioned.fill(
                child: Image.network(
                  film.posterUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (rating)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: C.overlay,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star, size: 12, color: C.gold),
                    const SizedBox(width: 3),
                    Text('${film.rating}',
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: C.onOverlay,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
          ],
        ),
      );
}

class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.fontSize = 10.5});
  final String label;
  final double fontSize;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: C.chip,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: C.muted)),
      );
}

void showMsg(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: C.text)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.chip,
      width: 340,
    ));
}


// ------------------------------------------------------------- Skeleton

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.percent);
  final double percent;
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * percent, 0, 0);
}

/// Kotak abu-abu berkilau sebagai pengganti konten yang belum selesai dimuat.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.radius = 8,
    this.circle = false,
  });
  final double width;
  final double height;
  final double radius;
  final bool circle;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = C.dark ? const Color(0xFF25252A) : const Color(0xFFE7E7EC);
    final shine = C.dark ? const Color(0xFF35353C) : const Color(0xFFF7F7FA);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius:
              widget.circle ? null : BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            colors: [base, shine, base],
            stops: const [0.3, 0.5, 0.7],
            transform: _SlideGradient(-1 + 2 * _c.value),
          ),
        ),
      ),
    );
  }
}

/// Kerangka kartu film pada hasil pencarian.
class FilmCardSkeleton extends StatelessWidget {
  const FilmCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.border),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 88, height: 132, radius: 8),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 150, height: 18),
                  SizedBox(height: 10),
                  Row(children: [
                    Skeleton(width: 52, height: 18, radius: 5),
                    SizedBox(width: 6),
                    Skeleton(width: 52, height: 18, radius: 5),
                  ]),
                  SizedBox(height: 12),
                  Skeleton(height: 11),
                  SizedBox(height: 6),
                  Skeleton(width: 120, height: 11),
                  SizedBox(height: 14),
                  Skeleton(height: 40, radius: 10),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Kerangka baris kartu (riwayat room, dll).
class RowSkeleton extends StatelessWidget {
  const RowSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const CardBox(
        child: Row(
          children: [
            Skeleton(width: 44, height: 44, radius: 10),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 140, height: 14),
                  SizedBox(height: 7),
                  Skeleton(width: 70, height: 11),
                  SizedBox(height: 7),
                  Skeleton(width: 190, height: 11),
                ],
              ),
            ),
            SizedBox(width: 12),
            Skeleton(width: 88, height: 32, radius: 8),
          ],
        ),
      );
}


// ----------------------------------------------------------- Liquid glass

/// Panel kaca buram (frosted glass) yang tipis: blur ringan, isi tembus
/// pandang, garis tepi halus, dan kilau di sisi atas.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 24,
    this.blur = 14,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final dark = C.dark;
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.35 : 0.18),
              blurRadius: 40,
              offset: const Offset(0, 16)),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0.05),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.78),
                        Colors.white.withValues(alpha: 0.5),
                      ],
              ),
              border: Border.all(
                  color: Colors.white.withValues(alpha: dark ? 0.2 : 0.85),
                  width: 1),
            ),
            // Kilau lembut di bagian atas.
            foregroundDecoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.white.withValues(alpha: dark ? 0.1 : 0.35),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Header yang berubah jadi kaca saat konten digulir di bawahnya.
class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.child, required this.glass});
  final Widget child;

  /// true = tampil sebagai kaca (saat halaman sudah digulir).
  final bool glass;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: glass ? 1 : 0),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        builder: (context, t, child) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16 * t, sigmaY: 16 * t),
          child: Container(
            decoration: BoxDecoration(
              // Dari solid menjadi tembus pandang.
              color: C.bg.withValues(alpha: 1 - 0.45 * t),
              border: Border(
                bottom: BorderSide(
                  color: Color.lerp(
                      C.border,
                      Colors.white.withValues(alpha: C.dark ? 0.16 : 0.7),
                      t)!,
                ),
              ),
            ),
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }
}
