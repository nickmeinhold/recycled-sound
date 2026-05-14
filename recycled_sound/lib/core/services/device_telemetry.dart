import 'dart:async';
import 'dart:io' show Platform;

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// One snapshot of everything we can read about the phone right now.
///
/// Kept intentionally flat so the diagnostic readout can iterate it as a list
/// of `(label, value)` pairs without having to know about each field.
@immutable
class DeviceTelemetry {
  const DeviceTelemetry({
    required this.make,
    required this.modelId,
    required this.modelName,
    required this.osName,
    required this.osVersion,
    required this.appVersion,
    required this.buildNumber,
    required this.locale,
    required this.processorCount,
    required this.physicalMemoryGb,
    required this.batteryPercent,
    required this.charging,
    required this.lowPowerMode,
    required this.networkType,
    required this.thermalState,
    required this.thermalLoad,
    required this.thermalHeadroom,
    required this.thermalEstCelsius,
    required this.coolDownNeeded,
    required this.hasLidar,
    required this.hasNeuralEngine,
    required this.socModel,
  });

  /// "Apple" / "Samsung" / etc.
  final String make;

  /// Hardware identifier — `iPhone15,2`, `SM-G991B`.
  final String modelId;

  /// Marketing name when known, falls back to `modelId`.
  final String modelName;

  final String osName;
  final String osVersion;
  final String appVersion;
  final String buildNumber;
  final String locale;
  final int processorCount;
  final double physicalMemoryGb;
  final int batteryPercent;
  final bool charging;
  final bool lowPowerMode;
  final String networkType;

  /// `nominal` / `fair` / `serious` / `critical` / `unknown`.
  final String thermalState;

  /// 0.0–1.0. Fades the gauge across green→orange→red.
  final double thermalLoad;

  /// Android-only predictive headroom, null on iOS.
  final double? thermalHeadroom;

  /// Estimated chassis-skin temperature range derived from thermal state,
  /// e.g. `"35–38°C"`. Best-effort — the OS doesn't expose CPU temp.
  final String thermalEstCelsius;

  /// True when the OS is hinting at imminent throttling (`serious` or worse).
  final bool coolDownNeeded;

  final bool hasLidar;
  final bool hasNeuralEngine;
  final String? socModel;

  /// `(label, value)` pairs for the diagnostic readout's auto-cycling display.
  /// Order matters — most "interesting" facts first.
  List<MapEntry<String, String>> asReadout() {
    return [
      MapEntry('DEVICE', '$make $modelName'),
      MapEntry('OS', '$osName $osVersion'),
      MapEntry('APP', '$appVersion+$buildNumber'),
      MapEntry('CPU CORES', '$processorCount'),
      MapEntry('RAM', '${physicalMemoryGb.toStringAsFixed(1)} GB'),
      if (socModel != null) MapEntry('SOC', socModel!),
      MapEntry('NEURAL ENGINE', hasNeuralEngine ? 'present' : 'absent'),
      MapEntry('LIDAR', hasLidar ? 'present' : 'absent'),
      MapEntry('NETWORK', networkType),
      MapEntry('BATTERY', '$batteryPercent%${charging ? ' charging' : ''}'),
      if (lowPowerMode) const MapEntry('LOW POWER', 'enabled'),
      MapEntry('THERMAL', '$thermalState · $thermalEstCelsius'),
      if (coolDownNeeded)
        const MapEntry('COOLDOWN', 'recommended — back off frame rate'),
      MapEntry('LOCALE', locale),
    ];
  }
}

/// Reads device facts on demand. No streams; the gauge polls as needed.
class DeviceTelemetryService {
  static const _channel =
      MethodChannel('co.enspyr.recycledSound/device_telemetry');

  final _deviceInfo = DeviceInfoPlugin();
  final _battery = Battery();
  final _connectivity = Connectivity();

  Future<DeviceTelemetry> snapshot() async {
    // Fan out reads in parallel — each one is independent.
    final results = await Future.wait([
      _readNative(),
      PackageInfo.fromPlatform(),
      _battery.batteryLevel,
      _battery.batteryState,
      _connectivity.checkConnectivity(),
      _readDeviceInfo(),
    ]);

    final native = results[0] as Map<String, dynamic>;
    final pkg = results[1] as PackageInfo;
    final batteryLevel = results[2] as int;
    final batteryState = results[3] as BatteryState;
    final conn = results[4] as List<ConnectivityResult>;
    final deviceFields = results[5] as _DeviceFields;

    final thermalState = (native['thermalState'] as String?) ?? 'unknown';
    final thermalLoad = (native['thermalLoad'] as num?)?.toDouble() ?? 0.0;

    return DeviceTelemetry(
      make: deviceFields.make,
      modelId: deviceFields.modelId,
      modelName: deviceFields.modelName,
      osName: deviceFields.osName,
      osVersion: deviceFields.osVersion,
      appVersion: pkg.version,
      buildNumber: pkg.buildNumber,
      locale: Platform.localeName,
      processorCount: (native['processorCount'] as num?)?.toInt() ?? 0,
      physicalMemoryGb:
          (native['physicalMemoryGB'] as num?)?.toDouble() ?? 0.0,
      batteryPercent: batteryLevel,
      charging: batteryState == BatteryState.charging ||
          batteryState == BatteryState.full,
      lowPowerMode: (native['lowPowerMode'] as bool?) ?? false,
      networkType: _connNameOf(conn),
      thermalState: thermalState,
      thermalLoad: thermalLoad,
      thermalHeadroom: (native['thermalHeadroom'] as num?)?.toDouble(),
      thermalEstCelsius: _estimateCelsius(thermalState),
      coolDownNeeded:
          thermalState == 'serious' || thermalState == 'critical',
      hasLidar: (native['hasLidar'] as bool?) ?? false,
      hasNeuralEngine: (native['hasNeuralEngine'] as bool?) ?? false,
      socModel: native['socModel'] as String?,
    );
  }

  Future<Map<String, dynamic>> _readNative() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>('snapshot');
      if (raw == null) return const {};
      return raw.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return const {};
    }
  }

  Future<_DeviceFields> _readDeviceInfo() async {
    if (Platform.isIOS) {
      final ios = await _deviceInfo.iosInfo;
      return _DeviceFields(
        make: 'Apple',
        modelId: ios.utsname.machine,
        modelName: _iosMarketingName(ios.utsname.machine),
        osName: ios.systemName,
        osVersion: ios.systemVersion,
      );
    }
    final android = await _deviceInfo.androidInfo;
    return _DeviceFields(
      make: _capitalise(android.manufacturer),
      modelId: android.model,
      modelName: '${_capitalise(android.manufacturer)} ${android.model}',
      osName: 'Android',
      osVersion: android.version.release,
    );
  }

  /// Tiny, recent-ish lookup. Falls back to the identifier when unknown so
  /// users still see something meaningful (e.g. `iPhone20,1`).
  String _iosMarketingName(String id) {
    const map = <String, String>{
      'iPhone8,1': 'iPhone 6s',
      'iPhone8,2': 'iPhone 6s Plus',
      'iPhone8,4': 'iPhone SE (1st gen)',
      'iPhone9,1': 'iPhone 7',
      'iPhone9,3': 'iPhone 7',
      'iPhone9,2': 'iPhone 7 Plus',
      'iPhone9,4': 'iPhone 7 Plus',
      'iPhone10,1': 'iPhone 8',
      'iPhone10,4': 'iPhone 8',
      'iPhone10,2': 'iPhone 8 Plus',
      'iPhone10,5': 'iPhone 8 Plus',
      'iPhone10,3': 'iPhone X',
      'iPhone10,6': 'iPhone X',
      'iPhone11,2': 'iPhone XS',
      'iPhone11,4': 'iPhone XS Max',
      'iPhone11,6': 'iPhone XS Max',
      'iPhone11,8': 'iPhone XR',
      'iPhone12,1': 'iPhone 11',
      'iPhone12,3': 'iPhone 11 Pro',
      'iPhone12,5': 'iPhone 11 Pro Max',
      'iPhone12,8': 'iPhone SE (2nd gen)',
      'iPhone13,1': 'iPhone 12 mini',
      'iPhone13,2': 'iPhone 12',
      'iPhone13,3': 'iPhone 12 Pro',
      'iPhone13,4': 'iPhone 12 Pro Max',
      'iPhone14,2': 'iPhone 13 Pro',
      'iPhone14,3': 'iPhone 13 Pro Max',
      'iPhone14,4': 'iPhone 13 mini',
      'iPhone14,5': 'iPhone 13',
      'iPhone14,6': 'iPhone SE (3rd gen)',
      'iPhone14,7': 'iPhone 14',
      'iPhone14,8': 'iPhone 14 Plus',
      'iPhone15,2': 'iPhone 14 Pro',
      'iPhone15,3': 'iPhone 14 Pro Max',
      'iPhone15,4': 'iPhone 15',
      'iPhone15,5': 'iPhone 15 Plus',
      'iPhone16,1': 'iPhone 15 Pro',
      'iPhone16,2': 'iPhone 15 Pro Max',
      'iPhone17,1': 'iPhone 16 Pro',
      'iPhone17,2': 'iPhone 16 Pro Max',
      'iPhone17,3': 'iPhone 16',
      'iPhone17,4': 'iPhone 16 Plus',
      'i386': 'Simulator (x86)',
      'x86_64': 'Simulator (x86_64)',
      'arm64': 'Simulator (arm64)',
    };
    return map[id] ?? id;
  }

  /// Apple's published thermal-state ranges aren't exact, but the HIG
  /// roughly maps them to skin-temperature bands. Surfaced as a hint, not a
  /// reading — keeps the user honest about what's measured vs estimated.
  String _estimateCelsius(String state) => switch (state) {
        'nominal' => '< 35°C',
        'fair' => '35–38°C',
        'serious' => '38–42°C · cooldown soon',
        'critical' => '> 42°C · throttling',
        _ => 'unknown',
      };

  String _connNameOf(List<ConnectivityResult> r) {
    if (r.contains(ConnectivityResult.wifi)) return 'Wi-Fi';
    if (r.contains(ConnectivityResult.mobile)) return 'Cellular';
    if (r.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    if (r.contains(ConnectivityResult.vpn)) return 'VPN';
    if (r.contains(ConnectivityResult.bluetooth)) return 'Bluetooth';
    return 'offline';
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _DeviceFields {
  _DeviceFields({
    required this.make,
    required this.modelId,
    required this.modelName,
    required this.osName,
    required this.osVersion,
  });
  final String make;
  final String modelId;
  final String modelName;
  final String osName;
  final String osVersion;
}
