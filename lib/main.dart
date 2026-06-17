import 'package:flutter/material.dart';
import 'ui/screens/tuner_screen.dart';
import 'ui/tuner_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final TunerViewModel viewModel = TunerViewModel();
  runApp(MyApp(viewModel: viewModel));
}

class MyApp extends StatelessWidget {
  final TunerViewModel viewModel;

  const MyApp({
    super.key,
    required this.viewModel,
  });

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
      home: TunerScreen(viewModel: viewModel),
    );
  }
}
