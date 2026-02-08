import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/screens/title_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: CTOSimulatorApp(),
    ),
  );
}

class CTOSimulatorApp extends StatelessWidget {
  const CTOSimulatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CTO Simulator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const TitleScreen(),
    );
  }
}
