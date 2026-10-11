import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await ThemeController.load();
  DeepLink.roomCode = AppLinks.roomFromUri(Uri.base);
  DeepLink.resetCode = AppLinks.resetFromUri(Uri.base);
  DeepLink.verifyCode = AppLinks.verifyFromUri(Uri.base);
  runApp(const LumaApp());
}

class LumaApp extends StatelessWidget {
  const LumaApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: ThemeController.dark,
        builder: (context, dark, _) => MaterialApp(
          title: 'Luma',
          debugShowCheckedModeBanner: false,
          theme: lumaTheme(dark),
          builder: phoneFrame,
          home: const SplashScreen(),
        ),
      );
}
