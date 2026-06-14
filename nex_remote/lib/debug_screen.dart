import 'dart:async';
import 'package:flutter/material.dart';
import 'models.dart';
import 'mapping_channel.dart';

/// Live keycode monitor and mapping inspector for troubleshooting.
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  StreamSubscription<int>? _sub;
  int? _lastKc;
  final List<int> _history = [];
  List<MappingEntry> _mappings = [];

  static const _maxHistory = 100;

  @override
  void initState() {
    super.initState();
    _loadMappings();
    _sub = MappingChannel.keyEvents.listen((kc) {
      if (!mounted) return;
      setState(() {
        _lastKc = kc;
        _history.add(kc);
        if (_history.length > _maxHistory) _history.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadMappings() async {
    final m = await MappingChannel.getMappings();
    if (mounted) setState(() => _mappings = m);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Debug', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadMappings,
            tooltip: 'Refresh mappings',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.white70),
            onPressed: () => setState(() { _history.clear(); _lastKc = null; }),
            tooltip: 'Clear history',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Last keycode
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LAST KEY',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text(
                    _lastKc != null
                        ? '${MappingChannel.friendlyKeyName(_lastKc!)}  ($_lastKc)'
                        : '—  press a button',
                    style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // History
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('HISTORY',
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _history.isEmpty
                              ? const Text(
                                  'Waiting for key events…\n\nEnable Nex Remote in Settings → Accessibility.',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 13))
                              : SingleChildScrollView(
                                  reverse: true,
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: _history.reversed.take(50).map((kc) =>
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('$kc',
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                                fontFamily: 'monospace')),
                                      )).toList(),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Mappings
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MAPPINGS',
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _mappings.isEmpty
                              ? const Text('No mappings.',
                                  style: TextStyle(color: Colors.white38))
                              : ListView.builder(
                                  itemCount: _mappings.length,
                                  itemBuilder: (_, i) {
                                    final m = _mappings[i];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${MappingChannel.friendlyKeyName(m.keycode)} [${m.eventType.label}]',
                                            style: const TextStyle(
                                                color: Colors.tealAccent,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          Text(m.action.displayName,
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
