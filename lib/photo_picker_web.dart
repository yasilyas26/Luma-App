// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Pilih gambar lewat pemilih berkas browser, lalu potong persegi dan kecilkan
/// jadi JPEG 256x256 (sekitar 20-40 KB). Mengembalikan null kalau dibatalkan.
///
/// Harus dipanggil langsung dari aksi pengguna (klik), tanpa `await` sebelumnya,
/// karena browser hanya mengizinkan membuka pemilih berkas dari klik.
Future<Uint8List?> pickProfileImage() {
  final done = Completer<Uint8List?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..style.display = 'none';
  html.document.body?.append(input);

  void finish(Uint8List? bytes) {
    if (!done.isCompleted) done.complete(bytes);
    input.remove();
  }

  input.onChange.first.then((_) async {
    try {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) return finish(null);
      finish(await _resize(file));
    } catch (e) {
      if (!done.isCompleted) done.completeError(e);
      input.remove();
    }
  });
  // Pengguna menutup pemilih berkas tanpa memilih.
  input.addEventListener('cancel', (_) => finish(null));

  input.click();
  return done.future;
}

Future<Uint8List> _resize(html.File file) async {
  const size = 256;

  final reader = html.FileReader()..readAsDataUrl(file);
  await reader.onLoad.first;

  final img = html.ImageElement(src: reader.result as String);
  await img.onLoad.first;

  final w = img.naturalWidth;
  final h = img.naturalHeight;
  if (w == 0 || h == 0) throw StateError('Gambar tidak valid');

  // Potong persegi dari tengah supaya pas untuk avatar bulat.
  final side = w < h ? w : h;
  final sx = (w - side) / 2;
  final sy = (h - side) / 2;

  final canvas = html.CanvasElement(width: size, height: size);
  canvas.context2D.drawImageScaledFromSource(
      img, sx, sy, side, side, 0, 0, size, size);

  final blob = await canvas.toBlob('image/jpeg', 0.85);
  final out = html.FileReader()..readAsArrayBuffer(blob);
  await out.onLoad.first;
  return Uint8List.fromList(out.result as List<int>);
}
