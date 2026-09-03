import 'package:flutter_test/flutter_test.dart';
import 'package:rideshares_app/app.dart';

void main() {
  testWidgets('RidesharesApp loads', (WidgetTester tester) async {
    expect(const RidesharesApp(), isNotNull);
  });
}
