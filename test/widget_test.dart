import 'package:flutter_test/flutter_test.dart';
import 'package:dawishcam/main.dart';

void main() {
  testWidgets('DaWishCamApp builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(const DaWishCamApp());
    expect(find.byType(DaWishCamApp), findsOneWidget);
  });
}
