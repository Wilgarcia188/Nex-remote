import 'package:flutter/material.dart';
import 'mapping_channel.dart';
import 'tv_focusable.dart';

/// Export, import and reset all mappings (all profiles).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _alert(BuildContext ctx, String title, String body) =>
      showDialog<void>(
        context: ctx,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
              child: Text(body,
                  style: const TextStyle(color: Colors.white70, fontSize: 13))),
          actions: [
            TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: Colors.tealAccent))),
          ],
        ),
      );

  Future<void> _export(BuildContext ctx) async {
    try {
      final r = await MappingChannel.exportMappings();
      if (ctx.mounted) await _alert(ctx, 'Export complete', 'Saved to:\n${r.path}\n\n${r.json}');
    } catch (e) {
      if (ctx.mounted) await _alert(ctx, 'Export failed', '$e');
    }
  }

  Future<void> _import(BuildContext ctx) async {
    try {
      final count = await MappingChannel.importMappings();
      if (ctx.mounted) {
        await _alert(ctx, 'Import complete', 'Imported $count mapping(s).');
      }
    } catch (e) {
      if (ctx.mounted) await _alert(ctx, 'Import failed', '$e');
    }
  }

  Future<void> _reset(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Reset mappings?', style: TextStyle(color: Colors.white)),
        content: const Text(
            'All mappings in the current profile will be deleted.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    await MappingChannel.clearMappings();
    if (ctx.mounted) await _alert(ctx, 'Done', 'All mappings removed from current profile.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Backup'),
          TvListTile(
            autofocus: true,
            leading: const Icon(Icons.upload, color: Colors.tealAccent),
            title: 'Export all profiles',
            subtitle: 'Save every profile as JSON to device storage',
            onTap: () => _export(context),
          ),
          TvListTile(
            leading: const Icon(Icons.download, color: Colors.tealAccent),
            title: 'Import profiles',
            subtitle: 'Load from the last exported JSON file',
            onTap: () => _import(context),
          ),
          const SizedBox(height: 16),
          _section('Danger Zone'),
          TvListTile(
            accentColor: Colors.redAccent,
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: 'Reset current profile',
            subtitle: 'Remove all mappings from the active profile',
            onTap: () => _reset(context),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
        child: Text(title,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
      );
}
