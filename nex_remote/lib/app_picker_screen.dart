import 'package:flutter/material.dart';

import 'mapping_channel.dart';
import 'tv_focusable.dart';

/// TV-friendly picker: lists every launchable app on the device so the
/// user can assign one to [keycode] using only the remote.
class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({super.key, required this.keycode});

  final int keycode;

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  late final Future<List<AppInfo>> _appsFuture;

  @override
  void initState() {
    super.initState();
    _appsFuture = MappingChannel.getInstalledApps();
  }

  Future<void> _select(AppInfo app) async {
    await MappingChannel.setMapping(widget.keycode, app.packageName);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _clear() async {
    await MappingChannel.removeMapping(widget.keycode);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Action for Button ${widget.keycode}'),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<AppInfo>>(
        future: _appsFuture,
        builder:
            (BuildContext context, AsyncSnapshot<List<AppInfo>> snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load apps: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<AppInfo> apps = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            itemCount: apps.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return TvListTile(
                  autofocus: true,
                  leading: const Icon(Icons.block, size: 36),
                  title: const Text('Not Configured'),
                  subtitle: const Text('Remove the mapping for this button'),
                  onTap: _clear,
                );
              }
              final AppInfo app = apps[index - 1];
              return TvListTile(
                leading: app.icon != null
                    ? Image.memory(app.icon!, width: 40, height: 40)
                    : const Icon(Icons.apps, size: 36),
                title: Text(app.name),
                subtitle: Text(app.packageName),
                onTap: () => _select(app),
              );
            },
          );
        },
      ),
    );
  }
}
