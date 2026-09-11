// ./extensions/extension_manifest.dart
import 'package:flutter/material.dart';

/// Declared inside every extension zip's manifest.json. An extension can
/// carry plain JSON data (via dataFile), real Dart logic + screens
/// compiled and run at runtime via flutter_eval (via codeFile), or both.
/// `icon` is a name looked up against a fixed whitelist here, never an
/// arbitrary asset or class, so a manifest alone can't inject UI.
class ExtensionManifest {
  const ExtensionManifest({
    required this.id,
    required this.type,
    required this.name,
    required this.version,
    required this.icon,
    this.description = '',
    this.dataFile,
    this.codeFile,
  });

  final String id;
  final String type;
  final String name;
  final String version;
  final String icon;
  final String description;

  /// Optional JSON data file inside the zip (e.g. contacts.json).
  final String? dataFile;

  /// Optional .dart source file inside the zip. If present, the extension
  /// carries its own logic and screen — compiled and run at runtime via
  /// flutter_eval — instead of (or alongside) plain JSON data.
  final String? codeFile;

  factory ExtensionManifest.fromJson(Map<String, dynamic> json) {
    return ExtensionManifest(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      version: json['version'] as String? ?? '1.0.0',
      icon: json['icon'] as String? ?? 'extension',
      description: json['description'] as String? ?? '',
      dataFile: json['dataFile'] as String?,
      codeFile: json['codeFile'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'version': version,
    'icon': icon,
    'description': description,
    if (dataFile != null) 'dataFile': dataFile,
    if (codeFile != null) 'codeFile': codeFile,
  };

  /// Whitelisted icon lookup — extensions declare a name, never a widget
  /// or asset path, so a malformed/malicious manifest can't inject
  /// arbitrary UI.
  IconData get iconData {
    switch (icon) {
      case 'people_outline':
        return Icons.people_outline;
      case 'calendar_month_outlined':
        return Icons.calendar_month_outlined;
      case 'wb_sunny_outlined':
        return Icons.wb_sunny_outlined;
      case 'account_balance_wallet_outlined':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.extension_outlined;
    }
  }
}

class InstalledExtension {
  const InstalledExtension({required this.manifest, required this.storageId});

  final ExtensionManifest manifest;
  

  /// Stable id used to locate stored extension files (same as [manifest.id]).
  final String storageId;
}
