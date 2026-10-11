import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';

/// Daftar syarat kata sandi yang tercentang otomatis saat mengetik.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist(this.password, {super.key});
  final String password;

  @override
  Widget build(BuildContext context) {
    final ok = PasswordRules.check(password);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (var i = 0; i < ok.length; i++)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ok[i] ? Icons.check_circle : Icons.circle_outlined,
                  size: 14, color: ok[i] ? const Color(0xFF2EAD6B) : C.muted),
              const SizedBox(width: 5),
              Text(PasswordRules.labels[i],
                  style: TextStyle(
                      fontSize: 11.5,
                      color: ok[i] ? C.text : C.muted)),
            ]),
        ],
      ),
    );
  }
}

/// Kolom isian untuk halaman autentikasi (email atau kata sandi).
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.type,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? type;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: C.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: C.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              keyboardType: type,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintStyle: TextStyle(color: C.muted),
              ),
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}
