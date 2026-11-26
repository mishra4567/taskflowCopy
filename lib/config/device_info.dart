// lib/config/device_info.dart

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// Old IANA names some Android phones still report, mapped to the current
/// ones. Servers validating timezones (Laravel's `timezone` rule) accept
/// only the current names. Same map as notification_service.dart — extend
/// both if another one turns up.
const _legacyTimezoneAliases = {
  'Asia/Calcutta': 'Asia/Kolkata',
  'Asia/Saigon': 'Asia/Ho_Chi_Minh',
  'Asia/Rangoon': 'Asia/Yangon',
  'Asia/Katmandu': 'Asia/Kathmandu',
  'Europe/Kiev': 'Europe/Kyiv',
};

class DeviceInfoConfig {
  DeviceInfoConfig._();

  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  /// Collects this phone's details. Never throws: if the model can't be
  /// read, the platform name stands in, so sign-up and login still work.
  static Future<DeviceDetails> getDeviceInfo() async {
    final timezone = await _timezone();
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await _plugin.androidInfo;
          return DeviceDetails(
            deviceName: _joinName(info.manufacturer, info.model),
            platform: 'android',
            manufacturer: info.manufacturer,
            model: info.model,
            osVersion: info.version.release,
            isPhysicalDevice: info.isPhysicalDevice,
            timezone: timezone,
          );

        case TargetPlatform.iOS:
          final info = await _plugin.iosInfo;
          return DeviceDetails(
            deviceName: info.modelName.isNotEmpty ? info.modelName : info.name,
            platform: 'ios',
            manufacturer: 'Apple',
            model: info.model,
            osVersion: info.systemVersion,
            isPhysicalDevice: info.isPhysicalDevice,
            timezone: timezone,
          );

        default:
          return _fallback(timezone);
      }
    } catch (_) {
      return _fallback(timezone);
    }
  }

  static DeviceDetails _fallback(String timezone) => DeviceDetails(
    deviceName: defaultTargetPlatform.name,
    platform: defaultTargetPlatform.name,
    manufacturer: 'Unknown',
    model: 'Unknown',
    osVersion: 'Unknown',
    isPhysicalDevice: false,
    timezone: timezone,
  );

  /// "samsung" + "SM-A135F" -> "Samsung SM-A135F". Some models already
  /// start with the maker ("OnePlus 9"), which would otherwise repeat.
  static String _joinName(String manufacturer, String model) {
    final make = manufacturer.trim();
    final name = model.trim();
    if (name.isEmpty) return make;
    if (make.isEmpty) return name;
    if (name.toLowerCase().startsWith(make.toLowerCase())) return name;
    return '${make[0].toUpperCase()}${make.substring(1)} $name';
  }

  /// Read fresh each time, since the timezone changes when the person
  /// travels. UTC if it can't be read.
  static Future<String> _timezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return _legacyTimezoneAliases[info.identifier] ?? info.identifier;
    } catch (_) {
      return 'UTC';
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
    required this.timezone,
  });

  final String deviceName;
  final String platform;
  final String manufacturer;
  final String model;
  final String osVersion;
  final bool isPhysicalDevice;

  /// IANA name, e.g. "Asia/Kolkata".
  final String timezone;

  /// The same details with a different name — for when the person renames
  /// the phone before linking it.
  DeviceDetails copyWith({String? deviceName}) => DeviceDetails(
    deviceName: deviceName ?? this.deviceName,
    platform: platform,
    manufacturer: manufacturer,
    model: model,
    osVersion: osVersion,
    isPhysicalDevice: isPhysicalDevice,
    timezone: timezone,
  );

  /// camelCase, everything (the original shape, plus timezone).
  Map<String, dynamic> toJson() {
    return {
      'deviceName': deviceName,
      'platform': platform,
      'manufacturer': manufacturer,
      'model': model,
      'osVersion': osVersion,
      'isPhysicalDevice': isPhysicalDevice,
      'timezone': timezone,
    };
  }

  /// snake_case, only the fields register/login need — spread it into the
  /// request body: `{'email': ..., ...device.toAuthJson()}`. Confirm the
  /// key names against AuthController's validation before relying on it.
  Map<String, dynamic> toAuthJson() {
    return {
      'device_name': deviceName,
      'platform': platform,
      'timezone': timezone,
    };
  }
}
