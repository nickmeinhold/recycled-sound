import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/app_bootstrap.dart';
import '../../../core/services/device_telemetry.dart';
import '../../../core/widgets/thermal_gauge.dart';

/// Initial diagnostic boot — flashes the device's specs and current thermal
/// load before the home screen mounts. Renders all telemetry rows with a
/// staggered fade-in so the screen feels like a system bring-up sequence
/// rather than a static splash.
///
/// Auto-advances to `/` after [_holdDuration]. Tap anywhere to skip.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  static const _holdDuration = Duration(milliseconds: 4200);
  static const _staggerStep = Duration(milliseconds: 80);

  final _service = DeviceTelemetryService();
  DeviceTelemetry? _telemetry;
  Timer? _advance;
  Timer? _refresh;
  int _revealed = 0;
  bool _firebaseReady = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Kick the firebase-ready watcher in parallel with the telemetry read.
    unawaited(AppBootstrap.ready.then((_) {
      if (!mounted) return;
      setState(() => _firebaseReady = true);
    }));

    try {
      final t = await _service.snapshot();
      if (!mounted) return;
      setState(() => _telemetry = t);
      _staggerReveal(t.asReadout().length);
    } catch (_) {
      // Telemetry failure shouldn't strand the user on the boot screen.
      _go();
      return;
    }
    _refresh = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final t = await _service.snapshot();
        if (!mounted) return;
        setState(() => _telemetry = t);
      } catch (_) {/* ignore */}
    });
    _advance = Timer(_holdDuration, _tryGo);
  }

  /// Wait until both the hold has elapsed AND firebase finished init —
  /// otherwise downstream screens that hit Firestore at frame zero crash.
  Future<void> _tryGo() async {
    await AppBootstrap.ready;
    _go();
  }

  void _staggerReveal(int total) {
    for (var i = 1; i <= total; i++) {
      Future.delayed(_staggerStep * i, () {
        if (!mounted) return;
        setState(() => _revealed = i);
      });
    }
  }

  void _go() {
    if (!mounted) return;
    context.go('/');
  }

  /// Tap-to-skip: still waits on firebase before navigating.
  Future<void> _onTap() async {
    await AppBootstrap.ready;
    _go();
  }

  @override
  void dispose() {
    _advance?.cancel();
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _telemetry;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 28),
                Expanded(child: _buildSpecs(t)),
                const SizedBox(height: 16),
                if (t != null) _buildThermal(t),
                const SizedBox(height: 12),
                _buildFooter(t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'RECYCLED SOUND',
              style: TextStyle(
                fontFamily: 'Menlo',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: Color(0xFFE5E7EB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'system bring-up',
          style: TextStyle(
            fontFamily: 'Menlo',
            fontSize: 10,
            color: Color(0xFF6B7280),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSpecs(DeviceTelemetry? t) {
    if (t == null) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Color(0xFF6B7280)),
          ),
        ),
      );
    }
    final entries = t.asReadout();
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final visible = i < _revealed;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: visible ? 1.0 : 0.0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            offset: visible ? Offset.zero : const Offset(0, 0.25),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '> ',
                    style: TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 12,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text(
                      entries[i].key,
                      style: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entries[i].value,
                      style: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF3F4F6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThermal(DeviceTelemetry t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: t.coolDownNeeded
              ? const Color(0xFFEF4444)
              : const Color(0xFF1F2937),
        ),
      ),
      child: ThermalGauge(
        load: t.thermalLoad,
        label: 'THERMAL LOAD',
        subLabel: '${t.thermalState.toUpperCase()} · ${t.thermalEstCelsius}',
        coolDownNeeded: t.coolDownNeeded,
      ),
    );
  }

  Widget _buildFooter(DeviceTelemetry? t) {
    final ready = t != null && _firebaseReady;
    final waitingFor = t == null
        ? 'reading sensors…'
        : !_firebaseReady
            ? 'connecting to firebase…'
            : 'tap to continue';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          waitingFor,
          style: const TextStyle(
            fontFamily: 'Menlo',
            fontSize: 10,
            color: Color(0xFF6B7280),
            letterSpacing: 1.2,
          ),
        ),
        if (ready)
          const Text(
            'OK',
            style: TextStyle(
              fontFamily: 'Menlo',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF10B981),
              letterSpacing: 1.2,
            ),
          ),
      ],
    );
  }
}
