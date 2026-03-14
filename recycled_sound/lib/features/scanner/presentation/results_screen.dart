import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/rs_button.dart';
import '../../../core/widgets/rs_card.dart';
import '../../../core/widgets/rs_chip.dart';
import '../../../core/widgets/rs_spec_row.dart';
import '../data/models/scan_result.dart';
import '../providers/scanner_providers.dart';

/// Results screen (Screen 1D) — shows identified specs with inline editing.
///
/// Each spec field can be tapped to correct the AI's identification. Corrections
/// are tracked for future model training.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, required this.scanId});

  final String scanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(scanResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Results'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Confidence summary ─────────────────────────────────
              RsCard(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check_circle,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Device Identified', style: AppTypography.h4),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the pencil icon to correct any field',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Primary identification ─────────────────────────────
              Text('Identification', style: AppTypography.h3),
              const SizedBox(height: 8),
              RsCard(
                child: Column(
                  children: [
                    _EditableSpecRow(
                      label: 'Brand',
                      field: result.brand,
                      onSave: (v) => ref
                          .read(scanResultProvider.notifier)
                          .updateField('brand', v),
                    ),
                    const Divider(),
                    _EditableSpecRow(
                      label: 'Model',
                      field: result.model,
                      onSave: (v) => ref
                          .read(scanResultProvider.notifier)
                          .updateField('model', v),
                    ),
                    const Divider(),
                    _EditableSpecRow(
                      label: 'Type',
                      field: result.type,
                      onSave: (v) => ref
                          .read(scanResultProvider.notifier)
                          .updateField('type', v),
                    ),
                    const Divider(),
                    _EditableSpecRow(
                      label: 'Year',
                      field: result.year,
                      onSave: (v) => ref
                          .read(scanResultProvider.notifier)
                          .updateField('year', v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Specifications ─────────────────────────────────────
              Text('Specifications', style: AppTypography.h3),
              const SizedBox(height: 8),
              RsCard(
                child: Column(
                  children: [
                    _EditableSpecRow(
                      label: 'Battery',
                      field: result.batterySize,
                      onSave: (v) => ref
                          .read(scanResultProvider.notifier)
                          .updateField('batterySize', v),
                    ),
                    const Divider(),
                    _EditableSpecRow(
                      label: 'Dome',
                      field: result.domeType,
                      onSave: (v) => ref
                          .read(scanResultProvider.notifier)
                          .updateField('domeType', v),
                    ),
                    const Divider(),
                    _EditableSpecRow(
                      label: 'Wax Filter',
                      field: result.waxFilter,
                      onSave: (v) => ref
                          .read(scanResultProvider.notifier)
                          .updateField('waxFilter', v),
                    ),
                    const Divider(),
                    _EditableSpecRow(
                      label: 'Receiver',
                      field: result.receiver,
                      onSave: (v) => ref
                          .read(scanResultProvider.notifier)
                          .updateField('receiver', v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── AI labels ──────────────────────────────────────────
              if (result.rawLabels.isNotEmpty) ...[
                Text('AI Labels', style: AppTypography.h3),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: result.rawLabels
                      .map((l) => RsChip(label: l, variant: RsChipVariant.info))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],

              // ── Actions ────────────────────────────────────────────
              RsButton(
                label: 'Add to Device Register',
                icon: Icons.add_circle_outline,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Device added to register (pending QA)'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  context.go('/devices');
                },
              ),
              const SizedBox(height: 12),
              RsButton(
                label: 'Scan Another',
                variant: RsButtonVariant.outline,
                onPressed: () => context.pushReplacement('/scan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A spec row that switches to inline editing on tap.
class _EditableSpecRow extends StatefulWidget {
  const _EditableSpecRow({
    required this.label,
    required this.field,
    required this.onSave,
  });

  final String label;
  final SpecField field;
  final ValueChanged<String> onSave;

  @override
  State<_EditableSpecRow> createState() => _EditableSpecRowState();
}

class _EditableSpecRowState extends State<_EditableSpecRow> {
  bool _editing = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.field.value);
  }

  @override
  void didUpdateWidget(_EditableSpecRow old) {
    super.didUpdateWidget(old);
    if (old.field.value != widget.field.value) {
      _controller.text = widget.field.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final newValue = _controller.text.trim();
    if (newValue.isNotEmpty && newValue != widget.field.value) {
      widget.onSave(newValue);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(widget.label, style: AppTypography.caption),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: AppTypography.body,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check, size: 18, color: AppColors.primary),
              onPressed: _save,
            ),
          ],
        ),
      );
    }

    return RsSpecRow(
      label: widget.label,
      value: widget.field.value,
      confidence: widget.field.confidence,
      onEdit: () => setState(() => _editing = true),
    );
  }
}
