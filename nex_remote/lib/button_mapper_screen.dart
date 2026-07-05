import 'dart:async';
import 'package:flutter/material.dart';
import 'models.dart';
import 'mapping_channel.dart';
import 'action_picker_screen.dart';
import 'tv_focusable.dart';

/// Three-step wizard: capture button → choose event type → choose action → save.
class ButtonMapperScreen extends StatefulWidget {
  /// If set, skip capture and go directly to event-type selection.
  final int? preselectedKeycode;
  /// If set, start in edit mode with existing data pre-filled.
  final MappingEntry? editEntry;

  const ButtonMapperScreen({super.key, this.preselectedKeycode, this.editEntry});

  @override
  State<ButtonMapperScreen> createState() => _ButtonMapperScreenState();
}

class _ButtonMapperScreenState extends State<ButtonMapperScreen> {
  int? _keycode;
  EventType _eventType = EventType.single;
  NexAction? _action;
  bool _capturing = false;
  bool _saving = false;
  StreamSubscription<int>? _keySub;

  @override
  void initState() {
    super.initState();
    if (widget.editEntry != null) {
      final e = widget.editEntry!;
      _keycode = e.keycode;
      _eventType = e.eventType;
      _action = e.action;
    } else if (widget.preselectedKeycode != null) {
      _keycode = widget.preselectedKeycode;
    } else {
      // Auto-enter capture for new mappings so the user never has to tap a
      // button to start capture.  Setting _capturing directly (no setState)
      // is safe here because the first build hasn't happened yet.
      _capturing = true;
      _enterCapture();
    }
  }

  @override
  void dispose() {
    _keySub?.cancel();
    // Always release capture isolation on exit, even if the user backs out
    // mid-capture.
    MappingChannel.setCaptureMode(false);
    super.dispose();
  }

  /// Called by the "Tap to change button" tile after a keycode has already
  /// been captured.  Re-enters capture mode so the user can pick a new button.
  void _startCapture() {
    setState(() => _capturing = true);
    _enterCapture();
  }

  /// Enables native capture-mode isolation and subscribes to the key-event
  /// stream.  The first keycode received is accepted unconditionally — Back (4)
  /// and D-Pad Center (23) are fully capturable because the native side
  /// consumes all events during capture and does not execute any mapped action.
  void _enterCapture() {
    MappingChannel.setCaptureMode(true);
    _keySub?.cancel();
    _keySub = MappingChannel.keyEvents.listen((kc) {
      _keySub?.cancel();
      MappingChannel.setCaptureMode(false);
      if (mounted) setState(() { _keycode = kc; _capturing = false; });
    });
  }

  Future<void> _pickAction() async {
    final action = await Navigator.push<NexAction>(
      context,
      MaterialPageRoute(builder: (_) => ActionPickerScreen(current: _action)),
    );
    if (action != null && mounted) setState(() => _action = action);
  }

  Future<void> _save() async {
    if (_keycode == null || _action == null) return;
    setState(() => _saving = true);
    try {
      await MappingChannel.upsertMapping(MappingEntry(
        id: widget.editEntry?.id ?? '',
        keycode: _keycode!,
        eventType: _eventType,
        action: _action!,
      ));
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _canSave => _keycode != null && _action != null && !_saving;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          widget.editEntry != null ? 'Edit Mapping' : 'New Mapping',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_canSave)
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _label('1. BUTTON'),
          const SizedBox(height: 8),
          _keycodeCard(),
          const SizedBox(height: 24),
          _label('2. EVENT TYPE'),
          const SizedBox(height: 8),
          _eventTypeCard(),
          const SizedBox(height: 24),
          _label('3. ACTION'),
          const SizedBox(height: 8),
          _actionCard(),
          const SizedBox(height: 32),
          if (_canSave)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Mapping',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2));

  Widget _keycodeCard() => _Card(
        highlighted: _capturing,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_keycode != null) ...[
              Text(MappingChannel.friendlyKeyName(_keycode!),
                  style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text('Keycode: $_keycode',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 12),
            ],
            if (_capturing)
              const Row(children: [
                SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.tealAccent, strokeWidth: 2)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                      'Press any button on your remote…\n(Back is captured too — press it only to map it)',
                      style: TextStyle(color: Colors.white70)),
                ),
              ])
            else
              TvListTile(
                leading: const Icon(Icons.ads_click, color: Colors.tealAccent),
                title: _keycode == null ? 'Tap to capture button' : 'Tap to change button',
                onTap: _startCapture,
              ),
          ],
        ),
      );

  Widget _eventTypeCard() => _Card(
        child: Column(
          children: EventType.values.map((et) {
            final sel = _eventType == et;
            return TvListTile(
              onTap: () => setState(() => _eventType = et),
              leading: Icon(
                sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: sel ? Colors.tealAccent : Colors.white38,
                size: 20,
              ),
              title: et.label,
              subtitle: et.description,
            );
          }).toList(),
        ),
      );

  Widget _actionCard() => TvFocusable(
        onSelect: _pickAction,
        borderRadius: 12,
        child: _Card(
          highlighted: _action != null,
          child: Row(
            children: [
              Icon(
                _action != null ? Icons.check_circle : Icons.touch_app,
                color: _action != null ? Colors.tealAccent : Colors.white38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _action?.displayName ?? 'Tap to choose an action',
                  style: TextStyle(
                      color: _action != null ? Colors.white : Colors.white38,
                      fontSize: 15),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  final bool highlighted;
  const _Card({required this.child, this.highlighted = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: highlighted
                  ? Colors.tealAccent.withValues(alpha: 0.7)
                  : Colors.white12),
        ),
        child: child,
      );
}
