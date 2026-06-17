import 'package:flutter_test/flutter_test.dart';
import 'package:tuning_vibes/main.dart';
import 'package:tuning_vibes/ui/tuner_view_model.dart';

void main() {
  testWidgets('Tuner application UI smoke test', (WidgetTester tester) async {
    final TunerViewModel viewModel = TunerViewModel();
    await tester.pumpWidget(MyApp(viewModel: viewModel));

    // Verify that the title "TUNING VIBES" is displayed on screen
    expect(find.text('TUNING VIBES'), findsOneWidget);
    
    // Verify that the START TUNER button is displayed
    expect(find.text('START TUNER'), findsOneWidget);
  });
}
