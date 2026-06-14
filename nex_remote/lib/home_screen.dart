import 'package:flutter/material.dart';
import 'models.dart';
import 'mapping_channel.dart';
import 'button_mapper_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'debug_screen.dart';
import 'tv_focusable.dart';

/// Main hub: lists all button mappings grouped by keycode, shows profile name,
/// accessibility warning, and lets users add / edit / delete mappings.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<MappingEntry> _mappings = [];
  bool _accessibilityOk = false;
  String _profileName = 'Default';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final mappings = await MappingChannel.getMappings();
    final accessible = await MappingChannel.isAccessibilityEnabled();
    final profiles = await MappingChannel.getProfiles();
    final currentId = await MappingChannel.getCurrentProfile();
    final profile = profiles.where((p) => p.id == currentId).firstOrNull ??
        const AppProfile(id: 'default', name: 'Default');
    if (!mounted) return;
    setState(() {
      _mappings = mappings;
      _accessibilityOk = accessible;
      _profileName = profile.name;
      _loading = false;
    });
  }

  Map<int, List<MappingEntry>> get _grouped {
    final m = <int, List<MappingEntry>>{};
    for (final e in _mappings) {
      m.putIfAbsent(e.keycode, () => []).add(e);
    }
    return Map.fromEntries(m.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nex Remote',
                style: TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(_profileName,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.white70),
            tooltip: 'Profiles',
            onPressed: () async {
              await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined, color: Colors.white70),
            tooltip: 'Debug',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const DebugScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : Column(
              children: [
                if (!_accessibilityOk) _accessibilityBanner(),
                Expanded(child: _body()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Add Mapping'),
        onPressed: _addMapping,
      ),
    );
  }

  Widget _accessibilityBanner() => Material(
        color: Colors.orange.shade800,
        child: InkWell(
          onTap: MappingChannel.openAccessibilitySettings,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                  child: Text('Accessibility service disabled — tap to enable',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w500))),
              Icon(Icons.chevron_right, color: Colors.white),
            ]),
          ),
        ),
      );

  Widget _body() {
    if (_mappings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.gamepad_outlined, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('No mappings yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
            SizedBox(height: 8),
            Text('Tap + to capture a button and assign an action',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    final grouped = _grouped;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: grouped.length,
      itemBuilder: (_, i) {
        final kc = grouped.keys.elementAt(i);
        final entries = grouped[kc]!;
        return _KeycodeCard(
          keycode: kc,
          entries: entries,
          onAddEvent: () => _addEventToKey(kc),
          onEdit: _editEntry,
          onDelete: _deleteEntry,
        );
      },
    );
  }

  Future<void> _addMapping() async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const ButtonMapperScreen()));
    if (ok == true) _load();
  }

  Future<void> _addEventToKey(int keycode) async {
    final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => ButtonMapperScreen(preselectedKeycode: keycode)));
    if (ok == true) _load();
  }

  Future<void> _editEntry(MappingEntry entry) async {
    final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => ButtonMapperScreen(editEntry: entry)));
    if (ok == true) _load();
  }

  Future<void> _deleteEntry(MappingEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Delete mapping?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove ${entry.eventType.label} → ${entry.action.displayName} '
          'for ${MappingChannel.friendlyKeyName(entry.keycode)}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await MappingChannel.removeMapping(entry.id);
      _load();
    }
  }
}

// ── Keycode card ───────────────────────────────────────────────────────────────

class _KeycodeCard extends StatelessWidget {
  final int keycode;
  final List<MappingEntry> entries;
  final VoidCallback onAddEvent;
  final void Function(MappingEntry) onEdit;
  final void Function(MappingEntry) onDelete;

  const _KeycodeCard({
    required this.keycode,
    required this.entries,
    required this.onAddEvent,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 8),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    MappingChannel.friendlyKeyName(keycode),
                    style: const TextStyle(
                        color: Colors.tealAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.tealAccent, size: 20),
                  tooltip: 'Add event type',
                  onPressed: onAddEvent,
                ),
              ]),
            ),
            const Divider(height: 1, color: Colors.white12),
            ...entries.map((e) => _EntryRow(entry: e, onEdit: onEdit, onDelete: onDelete)),
          ],
        ),
      );
}

class _EntryRow extends StatelessWidget {
  final MappingEntry entry;
  final void Function(MappingEntry) onEdit;
  final void Function(MappingEntry) onDelete;

  const _EntryRow(
      {required this.entry, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: Colors.white10, borderRadius: BorderRadius.circular(4)),
          child: Text(entry.eventType.label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ),
        title: Text(entry.action.displayName,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white54),
            onPressed: () => onEdit(entry),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            onPressed: () => onDelete(entry),
          ),
        ]),
      );
}
