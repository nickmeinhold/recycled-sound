import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recycled_sound/features/devices/data/models/device.dart';
import 'package:recycled_sound/features/devices/presentation/device_detail_screen.dart';
import 'package:recycled_sound/features/devices/providers/device_providers.dart';

Widget _wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: child),
  );
}

void main() {
  const id = 'abc';

  testWidgets('renders detail view when the stream emits a device',
      (tester) async {
    const device = Device(
      id: id,
      brand: 'Phonak',
      model: 'Audéo P90',
      type: 'RIC',
      year: '2021',
      batterySize: '312',
      qaStatus: QaStatus.passed,
      status: DeviceStatus.ready,
    );

    await tester.pumpWidget(_wrap(
      const DeviceDetailScreen(deviceId: id),
      overrides: [
        incomingDeviceByIdProvider(id)
            .overrideWith((_) => Stream.value(device)),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Phonak Audéo P90'), findsOneWidget);
    expect(find.text('Identification'), findsOneWidget);
    expect(find.text('Specifications'), findsOneWidget);
    expect(find.text('Status'), findsWidgets);
  });

  testWidgets('shows "Device not found" on null emission', (tester) async {
    await tester.pumpWidget(_wrap(
      const DeviceDetailScreen(deviceId: id),
      overrides: [
        incomingDeviceByIdProvider(id).overrideWith((_) => Stream.value(null)),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Device not found.'), findsOneWidget);
  });

  testWidgets('shows loading spinner before first emit', (tester) async {
    await tester.pumpWidget(_wrap(
      const DeviceDetailScreen(deviceId: id),
      overrides: [
        incomingDeviceByIdProvider(id).overrideWith(
          (_) => const Stream<Device?>.empty(),
        ),
      ],
    ));
    // Don't pumpAndSettle — we want the loading state.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state shows failure message', (tester) async {
    await tester.pumpWidget(_wrap(
      const DeviceDetailScreen(deviceId: id),
      overrides: [
        incomingDeviceByIdProvider(id).overrideWith(
          (_) => Stream.error(StateError('boom')),
        ),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Failed to load'), findsOneWidget);
  });
}
