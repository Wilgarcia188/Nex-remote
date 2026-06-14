import 'dart:typed_data';
import 'package:flutter/material.dart' hide ScrollAction;
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
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.current is OpenAppAction) {
      _tab = _Tab.app;
      _loadApps();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() => _loadingApps = true);
    final apps = await MappingChannel.getInstalledApps();
    if (mounted) setState(() { _apps = apps; _loadingApps = false; });
  }

  void _pick(NexAction action) => Navigator.pop(context, action);

  void _switchTab(_Tab t) {
    setState(() {
      _tab = t;
      _searchQuery = '';
      _searchCtrl.clear();
    });
    if (t == _Tab.app && _apps.isEmpty) _loadApps();
  }

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
          _TabBar(current: _tab, onChanged: _switchTab),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() => switch (_tab) {
    _Tab.system => _systemList(),
    _Tab.scroll  => _scrollList(),
    _Tab.app     => _appList(),
    _Tab.mouse   => _mouseList(),
  };

  Widget _systemList() => _tileList([
    _ActionItem(Icons.arrow_back,    'Back',        const SystemAction(systemAction: 'back')),
    _ActionItem(Icons.home,          'Home',        const SystemAction(systemAction: 'home')),
    _ActionItem(Icons.apps,          'Recent Apps', const SystemAction(systemAction: 'recents')),
    _ActionItem(Icons.crop_free,     'Screenshot',  const SystemAction(systemAction: 'screenshot')),
    _ActionItem(Icons.touch_app,     'Click',       const ClickAction()),
  ]);

  Widget _scrollList() => _tileList([
    _ActionItem(Icons.keyboard_arrow_up,   'Scroll Up',         const ScrollAction(direction: 'up')),
    _ActionItem(Icons.keyboard_arrow_down, 'Scroll Down',       const ScrollAction(direction: 'down')),
    _ActionItem(Icons.swap_vert,           'Toggle Scroll Mode', const ToggleScrollAction()),
  ]);

  Widget _mouseList() => _tileList([
    _ActionItem(Icons.mouse, 'Toggle Air Mouse', const ToggleMouseAction()),
  ]);

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

    final filtered = _searchQuery.isEmpty
        ? _apps
        : _apps.where((a) =>
            a.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            a.packageName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search apps…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38),
                      onPressed: () => setState(() {
                        _searchQuery = '';
                        _searchCtrl.clear();
                      }),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF2C2C2C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _apps.isEmpty
                        ? 'No apps found'
                        : 'No apps match "$_searchQuery"',
                    style: const TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final app = filtered[i];
                    Widget? icon;
                    if (app.iconBytes != null) {
                      icon = ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          Uint8List.fromList(app.iconBytes!),
                          width: 36, height: 36, fit: BoxFit.contain,
                        ),
                      );
                    }
                    return TvListTile(
                      leading: icon ?? const Icon(Icons.android, color: Colors.white38, size: 28),
                      title: app.name,
                      subtitle: app.packageName,
                      onTap: () => _pick(OpenAppAction(
                        packageName: app.packageName,
                        appName: app.name,
                      )),
                    );
                  },
                ),
        ),
      ],
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.icon,
                      size: 16,
                      color: sel ? Colors.black : Colors.white70),
                  const SizedBox(width: 6),
                  Text(t.label,
                      style: TextStyle(
                        color: sel ? Colors.black : Colors.white70,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      )),
                ],
              ),
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

  IconData get icon => switch (this) {
    _Tab.system => Icons.settings_remote,
    _Tab.scroll => Icons.swap_vert,
    _Tab.app    => Icons.launch,
    _Tab.mouse  => Icons.mouse,
  };
}

class _ActionItem {
  final IconData icon;
  final String label;
  final NexAction action;
  const _ActionItem(this.icon, this.label, this.action);
}
