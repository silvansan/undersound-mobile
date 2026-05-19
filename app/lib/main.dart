import 'package:flutter/material.dart';

import 'services/undersound_audio_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UnderSoundAudioService.instance.initialize();
  runApp(const AblautApp());
}

class AblautApp extends StatelessWidget {
  const AblautApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ablaut',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      home: const HomeScreen(),
    );
  }
}
