import 'package:flutter/services.dart';

/// A launchable application reported by the native side.
class AppInfo {
  const AppInfo({required this.name, required this.packageName, this.icon});

  factory AppInfo.fromMap(Map<dynamic, dynamic> map) {
    return AppInfo(
      name: map['name'] as String? ?? map['packageName'] as String,
      packageName: map['packageName'] as String,
      icon: map['icon'] as Uint8List?,
    );
  }

  final String name;
  final String packageName;
  final Uint8List? icon;
}

/// Result of exporting the mappings to a JSON file on the device.
class ExportResult {
  const ExportResult({required this.path, required this.json});

  final String path;
  final String json;
}

/// Dart wrapper around the `nex_remote/methods` MethodChannel implemented
/// in MainActivity.kt.
class MappingChannel {
  MappingChannel._();

  static const MethodChannel _channel = MethodChannel('nex_remote/methods');

  /// Remote buttons that can be remapped.
  static const List<int> supportedKeycodes = <int>[195, 247, 249, 265];

  static Future<List<AppInfo>> getInstalledApps() async {
    final List<dynamic> apps =
        await _channel.invokeMethod('getInstalledApps') as List<dynamic>;
    return apps
        .map((dynamic app) => AppInfo.fromMap(app as Map<dynamic, dynamic>))
        .toList();
  }

  static Future<Map<int, String>> getMappings() async {
    final Map<dynamic, dynamic> raw =
        await _channel.invokeMethod('getMappings') as Map<dynamic, dynamic>;
    return raw.map(
      (dynamic key, dynamic value) =>
          MapEntry<int, String>(int.parse(key as String), value as String),
    );
  }

  static Future<void> setMapping(int keycode, String packageName) {
    return _channel.invokeMethod('setMapping', <String, dynamic>{
      'keycode': keycode,
      'packageName': packageName,
    });
  }

  static Future<void> removeMapping(int keycode) {
    return _channel
        .invokeMethod('removeMapping', <String, dynamic>{'keycode': keycode});
  }

  static Future<void> clearMappings() {
    return _channel.invokeMethod('clearMappings');
  }

  /// Resolves name and icon for the given packages. Packages that are no
  /// longer installed are absent from the result.
  static Future<Map<String, AppInfo>> getAppDetails(
    List<String> packages,
  ) async {
    if (packages.isEmpty) {
      return <String, AppInfo>{};
    }
    final Map<dynamic, dynamic> raw = await _channel.invokeMethod(
      'getAppDetails',
      <String, dynamic>{'packages': packages},
    ) as Map<dynamic, dynamic>;
    return raw.map(
      (dynamic key, dynamic value) => MapEntry<String, AppInfo>(
        key as String,
        AppInfo.fromMap(value as Map<dynamic, dynamic>),
      ),
    );
  }

  static Future<ExportResult> exportMappings() async {
    final Map<dynamic, dynamic> raw =
        await _channel.invokeMethod('exportMappings') as Map<dynamic, dynamic>;
    return ExportResult(
      path: raw['path'] as String,
      json: raw['json'] as String,
    );
  }

  static Future<Map<int, String>> importMappings() async {
    final Map<dynamic, dynamic> raw =
        await _channel.invokeMethod('importMappings') as Map<dynamic, dynamic>;
    return raw.map(
      (dynamic key, dynamic value) =>
          MapEntry<int, String>(int.parse(key as String), value as String),
    );
  }

  static Future<bool> isAccessibilityServiceEnabled() async {
    final bool? enabled =
        await _channel.invokeMethod('isAccessibilityServiceEnabled') as bool?;
    return enabled ?? false;
  }

  static Future<void> openAccessibilitySettings() {
    return _channel.invokeMethod('openAccessibilitySettings');
  }
}
