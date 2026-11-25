// lib/config/device_info.dart

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceInfoConfig {
  DeviceInfoConfig._();

  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  /// Collect device information.
  static Future<DeviceDetails> getDeviceInfo() async {
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await _plugin.androidInfo;

          return DeviceDetails(
            deviceName: '${info.manufacturer} ${info.model}'.trim(),
            platform: 'android',
            manufacturer: info.manufacturer,
            model: info.model,
            osVersion: info.version.release,
            isPhysicalDevice: info.isPhysicalDevice,
          );

        case TargetPlatform.iOS:
          final info = await _plugin.iosInfo;

          return DeviceDetails(
            deviceName: info.modelName,
            platform: 'ios',
            manufacturer: 'Apple',
            model: info.model,
            osVersion: info.systemVersion,
            isPhysicalDevice: info.isPhysicalDevice,
          );

        default:
          return DeviceDetails(
            deviceName: defaultTargetPlatform.name,
            platform: defaultTargetPlatform.name,
            manufacturer: 'Unknown',
            model: 'Unknown',
            osVersion: 'Unknown',
            isPhysicalDevice: false,
          );
      }
    } catch (e) {
      throw Exception('Unable to retrieve device information: $e');
    }
  }
}

/// Standardized device information for TaskFlow.
class DeviceDetails {
  const DeviceDetails({
    required this.deviceName,
    required this.platform,
    required this.manufacturer,
    required this.model,
    required this.osVersion,
    required this.isPhysicalDevice,
  });

  final String deviceName;
  final String platform;
  final String manufacturer;
  final String model;
  final String osVersion;
  final bool isPhysicalDevice;

  Map<String, dynamic> toJson() {
    return {
      'deviceName': deviceName,
      'platform': platform,
      'manufacturer': manufacturer,
      'model': model,
      'osVersion': osVersion,
      'isPhysicalDevice': isPhysicalDevice,
    };
  }
}
