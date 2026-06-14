import 'package:flutter/material.dart';

import 'mapping_channel.dart';
import 'tv_focusable.dart';

/// Settings: export, import and reset all mappings. The export file lives
/// in the app's external files directory so it can be pulled or pushed
/// with adb — no text input is ever required on the TV.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showMessage(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: <Widget>[
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      final ExportResult result = await MappingChannel.exportMappings();
      if (context.mounted) {
        await _showMessage(
          context,
          'Mappings exported',
          'Saved to:\n${result.path}\n\n${result.json}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        await _showMessage(context, 'Export failed', '$e');
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final Map<int, String> imported = await MappingChannel.importMappings();
      final String summary = imported.isEmpty
          ? 'The file contained no valid mappings.'
          : imported.entries
              .map((MapEntry<int, String> e) => '${e.key} → ${e.value}')
              .join('\n');
      if (context.mounted) {
        await _showMessage(
          context,
          'Imported ${imported.length} mapping(s)',
          summary,
        );
      }
    } catch (e) {
      if (context.mounted) {
        await _showMessage(context, 'Import failed', '$e');
      }
    }
  }

  Future<void> _reset(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Reset all mappings?'),
        content: const Text(
          'Every configured button will go back to Not Configured.',
        ),
        actions: <Widget>[
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await MappingChannel.clearMappings();
    if (context.mounted) {
      await _showMessage(context, 'Mappings reset', 'All mappings removed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        children: <Widget>[
          TvListTile(
            autofocus: true,
            leading: const Icon(Icons.upload),
            title: const Text('Export mappings'),
            subtitle: const Text(
              'Save all mappings as JSON to the app files folder',
            ),
            onTap: () => _export(context),
          ),
          TvListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import mappings'),
            subtitle: const Text(
              'Load mappings from a previously exported JSON file',
            ),
            onTap: () => _import(context),
          ),
          TvListTile(
            accentColor: Colors.redAccent,
            leading: const Icon(Icons.delete_forever),
            title: const Text('Reset all mappings'),
            subtitle: const Text('Set every button back to Not Configured'),
            onTap: () => _reset(context),
          ),
        ],
      ),
    );
  }
}
