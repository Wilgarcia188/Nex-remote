import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mapping_channel.dart';

/// Receives keycodes captured by the Kotlin AccessibilityService and shows
/// the last keycode, the full history of keycodes received this session and
/// the currently configured mappings.
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  static const EventChannel _keyEventChannel =
      EventChannel('nex_remote/key_events');

  StreamSubscription<dynamic>? _subscription;
  int? _lastKeycode;
  final List<int> _history = <int>[];
  Map<int, String> _mappings = <int, String>{};
  Map<String, AppInfo> _appDetails = <String, AppInfo>{};

  @override
  void initState() {
    super.initState();
    _loadMappings();
    _subscription = _keyEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final int keycode = event as int;
        setState(() {
          _lastKeycode = keycode;
          _history.add(keycode);
        });
      },
    );
  }

  Future<void> _loadMappings() async {
    final Map<int, String> mappings = await MappingChannel.getMappings();
    final Map<String, AppInfo> details =
        await MappingChannel.getAppDetails(mappings.values.toSet().toList());
    if (!mounted) {
      return;
    }
    setState(() {
      _mappings = mappings;
      _appDetails = details;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Widget _mappingsPanel(TextTheme textTheme) {
    final List<int> keycodes = _mappings.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Current Mappings:', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        if (keycodes.isEmpty)
          Text('No mappings configured.', style: textTheme.bodyLarge)
        else
          for (final int keycode in keycodes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '$keycode → '
                '${_appDetails[_mappings[keycode]]?.name ?? _mappings[keycode]}',
                style: textTheme.titleMedium,
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Nex Remote — Debug', style: textTheme.headlineMedium),
              const SizedBox(height: 32),
              Text(
                'Last Keycode: ${_lastKeycode ?? '—'}',
                style: textTheme.displaySmall?.copyWith(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('History:', style: textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _history.isEmpty
                                ? Text(
                                    'Waiting for key events…\n\n'
                                    'If nothing appears, enable "Nex Remote" '
                                    'in Settings → Accessibility on this '
                                    'device.',
                                    style: textTheme.bodyLarge,
                                  )
                                : SingleChildScrollView(
                                    reverse: true,
                                    child: Text(
                                      _history.join(' '),
                                      style: textTheme.headlineSmall,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(child: _mappingsPanel(textTheme)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
