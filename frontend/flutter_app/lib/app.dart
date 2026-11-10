import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087F6B)),
      scaffoldBackgroundColor: const Color(0xFFF8FAFB),
    ),
    home: const SplashScreen(),
  );
}
