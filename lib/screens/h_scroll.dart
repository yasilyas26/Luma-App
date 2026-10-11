import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Daftar horizontal yang bisa digeser dengan sentuhan, seret mouse, atau
/// roda mouse (saat kursor di atasnya).
class HScroll extends StatefulWidget {
  const HScroll(
      {super.key,
      required this.child,
      this.padding = EdgeInsets.zero,
      this.controller});
  final Widget child;
  final EdgeInsets padding;

  /// Controller dari luar (mis. untuk menggulir ke awal); opsional.
  final ScrollController? controller;

  @override
  State<HScroll> createState() => _HScrollState();
}

class _HScrollState extends State<HScroll> {
  final _own = ScrollController();
  ScrollController get _c => widget.controller ?? _own;

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  void _wheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !_c.hasClients) return;
    final pos = _c.position;
    final d = e.scrollDelta.dy != 0 ? e.scrollDelta.dy : e.scrollDelta.dx;
    final target = (pos.pixels + d).clamp(0.0, pos.maxScrollExtent);
    if (target == pos.pixels) return; // di ujung: biarkan halaman bergulir
    GestureBinding.instance.pointerSignalResolver
        .register(e, (_) => _c.jumpTo(target));
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: Listener(
        onPointerSignal: _wheel,
        child: SingleChildScrollView(
          controller: _c,
          scrollDirection: Axis.horizontal,
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}
