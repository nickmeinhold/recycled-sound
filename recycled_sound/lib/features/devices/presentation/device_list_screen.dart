import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/rs_card.dart';
import '../../../core/widgets/rs_chip.dart';
import '../data/models/device.dart';

/// Device list screen (Screen 2A / QA Queue) — shows all registered devices.
class DeviceListScreen extends StatelessWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final devices = Device.mockDevices();

    return Scaffold(
      appBar: AppBar(title: const Text('Device Register')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: devices.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final d = devices[i];
          return _DeviceCard(
            device: d,
            onTap: () => context.push('/devices/${d.id}'),
          );
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onTap});

  final Device device;
  final VoidCallback onTap;

  RsChipVariant _qaVariant(String status) => switch (status) {
        'passed' => RsChipVariant.success,
        'failed' => RsChipVariant.error,
        _ => RsChipVariant.warning,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: RsCard(
        child: Row(
          children: [
            // Device icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.hearing, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${device.brand} ${device.model}',
                      style: AppTypography.h4),
                  const SizedBox(height: 4),
                  Text(
                    '${device.type} · ${device.year} · Battery ${device.batterySize}',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            // QA badge
            RsChip(
              label: device.qaStatus.replaceAll('_', ' ').toUpperCase(),
              variant: _qaVariant(device.qaStatus),
            ),
          ],
        ),
      ),
    );
  }
}
