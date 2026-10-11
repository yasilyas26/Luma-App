import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';

/// Avatar pengguna: foto unggahan, atau foto Google, atau inisial nama.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.size = 40, this.borderColor});
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ProfilePhoto.bytes, ProfilePhoto.useGoogle]),
      builder: (context, _) {
        final name = AuthService.name;
        final photo = ProfilePhoto.bytes.value;
        final googleUrl = ProfilePhoto.useGoogle.value ? ProfilePhoto.googleUrl : null;

        Widget? image;
        if (photo != null) {
          image = Image.memory(photo, fit: BoxFit.cover);
        } else if (googleUrl != null) {
          image = Image.network(
            googleUrl,
            fit: BoxFit.cover,
            // Gagal dimuat: biarkan inisial yang tampil.
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          );
        }

        return Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: C.accent,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor ?? C.border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(name[0].toUpperCase(),
                    style: TextStyle(
                        fontSize: size * 0.42,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
              if (image != null) image,
            ],
          ),
        );
      },
    );
  }
}

/// Avatar anggota room: foto profilnya (unggahan atau Google), atau inisial.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar(
      {super.key,
      required this.uid,
      required this.name,
      this.size = 40,
      this.color});
  final String uid;
  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (uid == AuthService.uid) return UserAvatar(size: size);
    return FutureBuilder<UserPhoto>(
      future: UserPhotos.of(uid),
      builder: (context, snap) {
        final p = snap.data;
        Widget? image;
        if (p?.bytes != null) {
          image = Image.memory(p!.bytes!, fit: BoxFit.cover);
        } else if (p?.url != null) {
          image = Image.network(p!.url!,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox());
        }
        final letter = name.isEmpty ? '?' : name[0].toUpperCase();
        return Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: color ?? C.chip,
            shape: BoxShape.circle,
            border: Border.all(color: C.border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(letter,
                    style: TextStyle(
                        fontSize: size * 0.42,
                        fontWeight: FontWeight.w800,
                        color: C.text)),
              ),
              if (image != null) image,
            ],
          ),
        );
      },
    );
  }
}
