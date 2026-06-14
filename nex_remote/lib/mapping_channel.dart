import 'dart:convert';
import 'package:flutter/services.dart';
import 'models.dart';

class ExportResult {
  final String path;
  final String json;
  const ExportResult({required this.path, required this.json});
}

/// Bridge between Flutter and the Android native layer.
class MappingChannel {
  MappingChannel._();

  static const _method = MethodChannel('nex_remote/methods');
  static const _events = EventChannel('nex_remote/key_events');

  // ── Key event stream ──────────────────────────────────────────────────────

  /// Stream of keycodes from the accessibility service (ACTION_DOWN only).
  static Stream<int> get keyEvents =>
      _events.receiveBroadcastStream().map((e) => e as int);

  // ── Mappings ──────────────────────────────────────────────────────────────

  static Future<List<MappingEntry>> getMappings({String? profileId}) async {
    final args = profileId != null ? {'profileId': profileId} : null;
    final raw = await _method.invokeMethod<String>('getMappings', args);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => MappingEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> upsertMapping(MappingEntry entry,
      {String? profileId}) async {
    final args = <String, dynamic>{'mapping': jsonEncode(entry.toJson())};
    if (profileId != null) args['profileId'] = profileId;
    await _method.invokeMethod('upsertMapping', args);
  }

  static Future<void> removeMapping(String id, {String? profileId}) async {
    final args = <String, dynamic>{'id': id};
    if (profileId != null) args['profileId'] = profileId;
    await _method.invokeMethod('removeMapping', args);
  }

  static Future<void> clearMappings({String? profileId}) async {
    final args = profileId != null ? {'profileId': profileId} : null;
    await _method.invokeMethod('clearMappings', args);
  }

  // ── Profiles ──────────────────────────────────────────────────────────────

  static Future<List<AppProfile>> getProfiles() async {
    final raw = await _method.invokeMethod<String>('getProfiles');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => AppProfile.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<String> getCurrentProfile() async =>
      await _method.invokeMethod<String>('getCurrentProfile') ?? 'default';

  static Future<void> switchProfile(String id) =>
      _method.invokeMethod('switchProfile', {'id': id});

  static Future<String> createProfile(String name) async =>
      await _method.invokeMethod<String>('createProfile', {'name': name}) ?? '';

  static Future<void> deleteProfile(String id) =>
      _method.invokeMethod('deleteProfile', {'id': id});

  // ── Installed apps ────────────────────────────────────────────────────────

  static Future<List<AppInfo>> getInstalledApps() async {
    final raw = await _method.invokeMethod<String>('getInstalledApps');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => _appInfoFromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<List<AppInfo>> getAppDetails(List<String> packages) async {
    if (packages.isEmpty) return [];
    final raw = await _method
        .invokeMethod<String>('getAppDetails', {'packages': packages});
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => _appInfoFromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static AppInfo _appInfoFromMap(Map<String, dynamic> m) {
    List<int>? icon;
    final raw = m['icon'];
    if (raw is List) icon = raw.cast<int>();
    return AppInfo(
      name: m['name'] as String? ?? '',
      packageName: m['packageName'] as String? ?? '',
      iconBytes: icon,
    );
  }

  // ── Export / Import ───────────────────────────────────────────────────────

  static Future<ExportResult> exportMappings() async {
    final raw = await _method.invokeMethod<String>('exportMappings');
    final map = jsonDecode(raw!) as Map<String, dynamic>;
    return ExportResult(
        path: map['path'] as String, json: map['json'] as String);
  }

  static Future<int> importMappings() async {
    final raw = await _method.invokeMethod<String>('importMappings');
    return int.tryParse(raw ?? '0') ?? 0;
  }

  // ── Accessibility ─────────────────────────────────────────────────────────

  static Future<bool> isAccessibilityEnabled() async {
    final r = await _method.invokeMethod('isAccessibilityEnabled');
    return r == true || r == 'true';
  }

  static Future<void> openAccessibilitySettings() =>
      _method.invokeMethod('openAccessibilitySettings');

  // ── Key name utilities ────────────────────────────────────────────────────

  static String friendlyKeyName(int keycode) {
    const names = <int, String>{
      3: 'Home', 4: 'Back',
      19: 'D-Pad Up', 20: 'D-Pad Down', 21: 'D-Pad Left',
      22: 'D-Pad Right', 23: 'D-Pad Center / OK',
      24: 'Volume Up', 25: 'Volume Down', 26: 'Power',
      62: 'Space', 66: 'Enter', 67: 'Delete',
      79: 'A', 82: 'Menu', 84: 'Search',
      85: 'Play/Pause', 86: 'Stop', 87: 'Next', 88: 'Previous',
      126: 'Play', 127: 'Pause', 164: 'Mute',
      166: 'Page Up', 167: 'Page Down',
      187: 'App Switch', 195: 'Nex 1', 247: 'Nex 2',
      249: 'Nex 3', 265: 'Nex 4',
      402: 'CH+', 403: 'CH−',
      704: 'Red', 705: 'Green', 706: 'Yellow', 707: 'Blue',
    };
    return names[keycode] ?? 'Button $keycode';
  }
}
