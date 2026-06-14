/// Data models shared across the app.

enum EventType {
  single,
  doublePress,
  long,
  hold;

  String get value => switch (this) {
        EventType.single => 'single',
        EventType.doublePress => 'double',
        EventType.long => 'long',
        EventType.hold => 'hold',
      };

  static EventType fromString(String s) => switch (s) {
        'double' => EventType.doublePress,
        'long' => EventType.long,
        'hold' => EventType.hold,
        _ => EventType.single,
      };

  String get label => switch (this) {
        EventType.single => 'Single Press',
        EventType.doublePress => 'Double Press',
        EventType.long => 'Long Press',
        EventType.hold => 'Hold (repeat)',
      };

  String get description => switch (this) {
        EventType.single => 'Normal tap',
        EventType.doublePress => 'Two taps within 300 ms',
        EventType.long => 'Hold 500 ms then release',
        EventType.hold => 'Repeats every 200 ms while held',
      };
}

// ── Actions ──────────────────────────────────────────────────────────────────

sealed class NexAction {
  const NexAction();

  Map<String, dynamic> toJson();
  String get displayName;
  String get typeKey;

  factory NexAction.fromJson(Map<String, dynamic> j) => switch (j['type'] as String? ?? '') {
        'open_app' => OpenAppAction(
            packageName: j['packageName'] as String? ?? '',
            appName: j['appName'] as String? ?? '',
          ),
        'system' => SystemAction(systemAction: j['systemAction'] as String? ?? 'home'),
        'scroll' => ScrollAction(
            direction: j['direction'] as String? ?? 'down',
            steps: j['steps'] as int? ?? 3,
          ),
        'click' => const ClickAction(),
        'toggle_mouse' => const ToggleMouseAction(),
        'toggle_scroll' => const ToggleScrollAction(),
        _ => SystemAction(systemAction: 'home'),
      };
}

class OpenAppAction extends NexAction {
  final String packageName;
  final String appName;
  const OpenAppAction({required this.packageName, this.appName = ''});

  @override
  String get typeKey => 'open_app';

  @override
  Map<String, dynamic> toJson() => {
        'type': 'open_app',
        'packageName': packageName,
        if (appName.isNotEmpty) 'appName': appName,
      };

  @override
  String get displayName => appName.isNotEmpty ? appName : packageName;
}

class SystemAction extends NexAction {
  final String systemAction; // back | home | recents | screenshot
  const SystemAction({required this.systemAction});

  @override
  String get typeKey => 'system';

  @override
  Map<String, dynamic> toJson() => {'type': 'system', 'systemAction': systemAction};

  @override
  String get displayName => switch (systemAction) {
        'back' => 'Back',
        'home' => 'Home',
        'recents' => 'Recent Apps',
        'screenshot' => 'Screenshot',
        _ => systemAction,
      };
}

class ScrollAction extends NexAction {
  final String direction; // up | down
  final int steps;
  const ScrollAction({required this.direction, this.steps = 3});

  @override
  String get typeKey => 'scroll';

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'scroll', 'direction': direction, 'steps': steps};

  @override
  String get displayName => direction == 'up' ? 'Scroll Up' : 'Scroll Down';
}

class ClickAction extends NexAction {
  const ClickAction();
  @override
  String get typeKey => 'click';
  @override
  Map<String, dynamic> toJson() => {'type': 'click'};
  @override
  String get displayName => 'Click';
}

class ToggleMouseAction extends NexAction {
  const ToggleMouseAction();
  @override
  String get typeKey => 'toggle_mouse';
  @override
  Map<String, dynamic> toJson() => {'type': 'toggle_mouse'};
  @override
  String get displayName => 'Toggle Air Mouse';
}

class ToggleScrollAction extends NexAction {
  const ToggleScrollAction();
  @override
  String get typeKey => 'toggle_scroll';
  @override
  Map<String, dynamic> toJson() => {'type': 'toggle_scroll'};
  @override
  String get displayName => 'Toggle Scroll Mode';
}

// ── MappingEntry ──────────────────────────────────────────────────────────────

class MappingEntry {
  final String id;
  final int keycode;
  final EventType eventType;
  final NexAction action;

  const MappingEntry({
    required this.id,
    required this.keycode,
    required this.eventType,
    required this.action,
  });

  factory MappingEntry.fromJson(Map<String, dynamic> j) => MappingEntry(
        id: j['id'] as String? ?? '',
        keycode: j['keycode'] as int,
        eventType: EventType.fromString(j['eventType'] as String? ?? 'single'),
        action: NexAction.fromJson(Map<String, dynamic>.from(j['action'] as Map)),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'keycode': keycode,
        'eventType': eventType.value,
        'action': action.toJson(),
      };
}

// ── AppProfile ────────────────────────────────────────────────────────────────

class AppProfile {
  final String id;
  final String name;

  const AppProfile({required this.id, required this.name});

  factory AppProfile.fromJson(Map<String, dynamic> j) =>
      AppProfile(id: j['id'] as String, name: j['name'] as String);
}

// ── AppInfo ───────────────────────────────────────────────────────────────────

class AppInfo {
  final String name;
  final String packageName;
  final List<int>? iconBytes;

  const AppInfo({required this.name, required this.packageName, this.iconBytes});
}
