import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/rs_card.dart';
import '../../../core/widgets/rs_chip.dart';
import '../../../core/widgets/rs_spec_row.dart';
import '../data/models/device.dart';

/// Device detail screen (Screen 2C) — full spec view for a single device.
class DeviceDetailScreen extends StatelessWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    // In MVP, look up from mock data. Will be a Firestore stream later.
    final device = Device.mockDevices().firstWhere(
      (d) => d.id == deviceId,
      orElse: () => const Device(id: '0', brand: 'Unknown', model: 'Unknown'),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${device.brand} ${device.model}'),
        actions: [
          RsChip(
            label: device.qaStatus.replaceAll('_', ' ').toUpperCase(),
            variant: device.qaStatus == 'passed'
                ? RsChipVariant.success
                : device.qaStatus == 'failed'
                    ? RsChipVariant.error
                    : RsChipVariant.warning,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Identification', style: AppTypography.h3),
            const SizedBox(height: 8),
            RsCard(
              child: Column(
                children: [
                  RsSpecRow(label: 'Brand', value: device.brand),
                  RsSpecRow(label: 'Model', value: device.model),
                  RsSpecRow(label: 'Type', value: device.type),
                  RsSpecRow(label: 'Year', value: device.year),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Specifications', style: AppTypography.h3),
            const SizedBox(height: 8),
            RsCard(
              child: Column(
                children: [
                  RsSpecRow(label: 'Battery', value: device.batterySize),
                  RsSpecRow(label: 'Dome', value: device.domeType),
                  RsSpecRow(label: 'Wax Filter', value: device.waxFilter),
                  RsSpecRow(label: 'Receiver', value: device.receiver),
                  RsSpecRow(
                      label: 'Interface', value: device.programmingInterface),
                  RsSpecRow(label: 'Tech Level', value: device.techLevel),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Status', style: AppTypography.h3),
            const SizedBox(height: 8),
            RsCard(
              child: Column(
                children: [
                  RsSpecRow(label: 'QA', value: device.qaStatus),
                  RsSpecRow(label: 'Status', value: device.status),
                  RsSpecRow(label: 'Condition', value: device.condition),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
