import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'models.dart';
import 'mapping_channel.dart';
import 'tv_focusable.dart';

/// Screen for picking the action assigned to a button event.
class ActionPickerScreen extends StatefulWidget {
  final NexAction? current;
  const ActionPickerScreen({super.key, this.current});

  @override
  State<ActionPickerScreen> createState() => _ActionPickerScreenState();
}

class _ActionPickerScreenState extends State<ActionPickerScreen> {
  _Tab _tab = _Tab.system;
  List<AppInfo> _apps = [];
  bool _loadingApps = false;

  @override
  void initState() {
    super.initState();
    if (widget.current is OpenAppAction) {
      _tab = _Tab.app;
      _loadApps();
    }
  }

  Future<void> _loadApps() async {
    setState(() => _loadingApps = true);
    final apps = await MappingChannel.getInstalledApps();
    if (mounted) setState(() { _apps = apps; _loadingApps = false; });
  }

  void _pick(NexAction action) => Navigator.pop(context, action);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Choose Action', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _TabBar(
            current: _tab,
            onChanged: (t) {
              setState(() => _tab = t);
              if (t == _Tab.app && _apps.isEmpty) _loadApps();
            },
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    return switch (_tab) {
      _Tab.system => _systemList(),
      _Tab.scroll  => _scrollList(),
      _Tab.app     => _appList(),
      _Tab.mouse   => _mouseList(),
    };
  }

  Widget _systemList() {
    final items = [
      _ActionItem(Icons.arrow_back,   'Back',         SystemAction(systemAction: 'back')),
      _ActionItem(Icons.home,          'Home',         SystemAction(systemAction: 'home')),
      _ActionItem(Icons.apps,          'Recent Apps',  SystemAction(systemAction: 'recents')),
      _ActionItem(Icons.screenshot,    'Screenshot',   SystemAction(systemAction: 'screenshot')),
      _ActionItem(Icons.touch_app,     'Click',        const ClickAction()),
    ];
    return _tileList(items);
  }

  Widget _scrollList() {
    final items = [
      _ActionItem(Icons.keyboard_arrow_up,   'Scroll Up',   ScrollAction(direction: 'up')),
      _ActionItem(Icons.keyboard_arrow_down, 'Scroll Down', ScrollAction(direction: 'down')),
      _ActionItem(Icons.swap_vert,           'Toggle Scroll Mode', const ToggleScrollAction()),
    ];
    return _tileList(items);
  }

  Widget _mouseList() {
    final items = [
      _ActionItem(Icons.mouse, 'Toggle Air Mouse', const ToggleMouseAction()),
    ];
    return _tileList(items);
  }

  Widget _tileList(List<_ActionItem> items) => ListView(
        padding: const EdgeInsets.all(12),
        children: items.map((item) => TvListTile(
          leading: Icon(item.icon, color: Colors.tealAccent),
          title: item.label,
          onTap: () => _pick(item.action),
        )).toList(),
      );

  Widget _appList() {
    if (_loadingApps) {
      return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
    }
    if (_apps.isEmpty) {
      return const Center(child: Text('No apps found', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _apps.length,
      itemBuilder: (ctx, i) {
        final app = _apps[i];
        Widget? leadingWidget;
        if (app.iconBytes != null) {
          leadingWidget = Image.memory(
            Uint8List.fromList(app.iconBytes!),
            width: 32, height: 32, fit: BoxFit.contain,
          );
        }
        return TvListTile(
          leading: leadingWidget ?? const Icon(Icons.android, color: Colors.white38, size: 28),
          title: app.name,
          subtitle: app.packageName,
          onTap: () => _pick(OpenAppAction(packageName: app.packageName, appName: app.name)),
        );
      },
    );
  }
}

class _TabBar extends StatelessWidget {
  final _Tab current;
  final ValueChanged<_Tab> onChanged;
  const _TabBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: _Tab.values.map((t) {
            final sel = t == current;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? Colors.tealAccent : Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(t.label,
                      style: TextStyle(
                        color: sel ? Colors.black : Colors.white70,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      )),
                ),
              ),
            );
          }).toList(),
        ),
      );
}

enum _Tab {
  system, scroll, app, mouse;
  String get label => switch (this) {
        _Tab.system => 'System',
        _Tab.scroll => 'Scroll',
        _Tab.app    => 'Open App',
        _Tab.mouse  => 'Air Mouse',
      };
}

class _ActionItem {
  final IconData icon;
  final String label;
  final NexAction action;
  const _ActionItem(this.icon, this.label, this.action);
}
