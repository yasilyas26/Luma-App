// Pemilih foto profil. Di web memakai pemilih berkas bawaan browser (lebih
// andal), di platform lain memakai image_picker.
export 'photo_picker_stub.dart' if (dart.library.html) 'photo_picker_web.dart';
