import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/library_screen.dart';

void main() => runApp(const NotenleserApp());

class NotenleserApp extends StatelessWidget {
  const NotenleserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notenleser',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const LibraryScreen(),
    );
  }
}
