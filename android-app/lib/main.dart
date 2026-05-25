import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'theme.dart';
import 'screens/library_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  runApp(const NotenleserApp());
}

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
