import 'package:flutter/material.dart';

import 'app_picker_screen.dart';
import 'button_capture_screen.dart';
import 'debug_screen.dart';
import 'mapping_channel.dart';
import 'settings_screen.dart';
import 'tv_focusable.dart';

/// TV-friendly home screen: shows every configurable button with its
/// assigned app, plus entries for the debug screen and settings.
/// Fully navigable with UP/DOWN/LEFT/RIGHT/OK/BACK.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Map<int, String> _mappings = <int, String>{};
  Map<String, AppInfo> _appDetails = <String, AppInfo>{};
  bool _serviceEnabled = true;
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
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    final Map<int, String> mappings = await MappingChannel.getMappings();
    final Map<String, AppInfo> details =
        await MappingChannel.getAppDetails(mappings.values.toSet().toList());
    final bool serviceEnabled =
        await MappingChannel.isAccessibilityServiceEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _mappings = mappings;
      _appDetails = details;
      _serviceEnabled = serviceEnabled;
      _loading = false;
    });
  }

  Future<void> _configureButton(int keycode) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AppPickerScreen(keycode: keycode),
      ),
    );
    await _load();
  }

  Future<void> _openCaptureMode() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => const ButtonCaptureScreen(),
      ),
    );
    await _load();
  }

  Widget _buttonTile(int keycode, {required bool autofocus}) {
    final String? packageName = _mappings[keycode];
    final AppInfo? app =
        packageName == null ? null : _appDetails[packageName];
    final String label = packageName == null
        ? 'Not Configured'
        : (app?.name ?? packageName);

    return TvListTile(
      autofocus: autofocus,
      leading: app?.icon != null
          ? Image.memory(app!.icon!, width: 40, height: 40)
          : Icon(
              packageName == null ? Icons.radio_button_unchecked : Icons.apps,
              size: 36,
            ),
      title: Text('$keycode  →  $label'),
      subtitle: packageName == null ? null : Text(packageName),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _configureButton(keycode),
    );
  }

  Widget _serviceWarning() {
    return TvListTile(
      accentColor: Colors.orange,
      leading: const Icon(Icons.warning_amber_rounded),
      title: const Text('Accessibility service is OFF'),
      subtitle: const Text(
        'Button remapping needs the Nex Remote accessibility service. '
        'Press OK to open Accessibility settings and enable it.',
      ),
      onTap: MappingChannel.openAccessibilitySettings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: <Widget>[
                    // ── Header ──────────────────────────────────────────────
                    Text(
                      'NEX REMOTE',
                      style: textTheme.headlineLarge?.copyWith(
                        color: Colors.tealAccent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Configured Buttons', style: textTheme.titleLarge),
                    if (!_serviceEnabled) _serviceWarning(),
                    const SizedBox(height: 8),

                    // ── Configured button rows ───────────────────────────────
                    for (int i = 0;
                        i < MappingChannel.supportedKeycodes.length;
                        i++)
                      _buttonTile(
                        MappingChannel.supportedKeycodes[i],
                        autofocus: i == 0,
                      ),

                    // ── Add Mapping via capture ──────────────────────────────
                    const SizedBox(height: 8),
                    TvListTile(
                      accentColor: Colors.tealAccent,
                      leading: const Icon(Icons.add_circle_outline, size: 36),
                      title: const Text('Add Mapping'),
                      subtitle: const Text(
                        'Press a button on the remote to detect its keycode, '
                        'then choose an app to launch',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _openCaptureMode,
                    ),

                    const Divider(height: 32),

                    // ── Debug & Settings ─────────────────────────────────────
                    TvListTile(
                      leading: const Icon(Icons.bug_report),
                      title: const Text('Debug Screen'),
                      subtitle:
                          const Text('Live keycodes and current mappings'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const DebugScreen(),
                          ),
                        );
                      },
                    ),
                    TvListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Settings'),
                      subtitle: const Text(
                        'Export, import or reset all mappings',
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const SettingsScreen(),
                          ),
                        );
                        await _load();
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
