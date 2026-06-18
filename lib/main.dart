import 'package:flutter/material.dart';
import 'ui/app_orchestrator.dart';
import 'ui/screens/root_screen.dart';
import 'modes/tuner/tuner_mode.dart';
import 'modes/bpm/bpm_mode.dart';
import 'modes/metronome/metronome_mode.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register all modes here. To add a new mode:
  //   1. Create a class extending AppMode
  //   2. Add it to this list
  //   3. Handle its id in RootScreen._buildModeUI
  final orchestrator = AppOrchestrator(
    modes: [
      TunerMode(),
      BpmMode(),
      MetronomeMode(),
    ],
  );

  runApp(TuningVibesApp(orchestrator: orchestrator));
}

class TuningVibesApp extends StatelessWidget {
  final AppOrchestrator orchestrator;

  const TuningVibesApp({super.key, required this.orchestrator});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tuning Vibes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.greenAccent,
          surface: Color(0xFF0D0F13),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: Colors.cyanAccent,
          inactiveTrackColor: Colors.grey[800],
          thumbColor: Colors.cyanAccent,
          overlayColor: Colors.cyanAccent.withOpacity(0.2),
          valueIndicatorColor: Colors.cyanAccent,
          valueIndicatorTextStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: ListenableBuilder(
        listenable: orchestrator,
        builder: (context, _) => RootScreen(orchestrator: orchestrator),
      ),
    );
  }
}
