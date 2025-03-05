import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_monitor/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ParkingMonitorApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
