import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Pilih gambar dari perangkat. Mengembalikan null kalau dibatalkan.
Future<Uint8List?> pickProfileImage() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 256,
    maxHeight: 256,
    imageQuality: 85,
  );
  return file?.readAsBytes();
}
