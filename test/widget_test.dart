import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/customer/customer_app.dart';
import 'package:queueless/staff/staff_app.dart';

void main() {
  testWidgets('customer can enter the queue flow', (tester) async {
    await tester.pumpWidget(const CustomerApp());
    expect(find.text('Your table,\nwithout the wait.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Join the queue'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Join the queue'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm & join queue'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Confirm & join queue'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Confirm & join queue'));
    await tester.pumpAndSettle();
    expect(find.text('#5'), findsOneWidget);
    expect(find.text('Live location'), findsOneWidget);
    expect(find.text('Context engine'), findsOneWidget);
  });

  testWidgets('customer can navigate history and settings', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CustomerApp());
    await tester.pumpAndSettle();

    expect(find.text('My queue'), findsOneWidget);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Queue history'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings & help'), findsOneWidget);
    expect(find.text('MUC Context Simulator'), findsOneWidget);
    expect(find.text('Privacy by design'), findsOneWidget);
  });

  testWidgets('staff dashboard shows the live queue', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const StaffApp());
    await tester.pumpAndSettle();
    expect(find.text('Live queue'), findsWidgets);
    expect(find.text('Maya Chen'), findsOneWidget);
    expect(find.text('Call next'), findsOneWidget);
  });
}
