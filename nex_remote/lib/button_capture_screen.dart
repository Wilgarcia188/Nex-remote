import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_picker_screen.dart';
import 'tv_focusable.dart';

/// Friendly keycode name lookup. Covers the four confirmed Nex Remote
/// keycodes plus common Android key constants.
String _friendlyName(int keycode) {
  const Map<int, String> names = <int, String>{
    // Confirmed Nex Remote keycodes
    195: 'Custom Button A (195)',
    247: 'Custom Button B (247)',
    249: 'Custom Button C (249)',
    265: 'Custom Button D (265)',
    // D-pad
    19: 'D-Pad Up',
    20: 'D-Pad Down',
    21: 'D-Pad Left',
    22: 'D-Pad Right',
    23: 'D-Pad Center (OK)',
    // Media controls
    24: 'Volume Up',
    25: 'Volume Down',
    164: 'Volume Mute',
    85: 'Play / Pause',
    86: 'Stop',
    87: 'Next Track',
    88: 'Previous Track',
    126: 'Play',
    127: 'Pause',
    // Navigation
    3: 'Home',
    4: 'Back',
    82: 'Menu',
    187: 'Recent Apps',
    // TV specific
    166: 'TV Power',
    167: 'TV Input',
    172: 'Guide / EPG',
    228: 'DVR',
    // Color buttons
    183: 'Red Button',
    184: 'Green Button',
    185: 'Yellow Button',
    186: 'Blue Button',
    // Number buttons
    8: 'Key 0',
    9: 'Key 1',
    10: 'Key 2',
    11: 'Key 3',
    12: 'Key 4',
    13: 'Key 5',
    14: 'Key 6',
    15: 'Key 7',
    16: 'Key 8',
    17: 'Key 9',
  };
  return names[keycode] ?? 'Unknown Button ($keycode)';
}

/// Three-step flow:
///   1. [_CaptureStep]  — "Press the button you want to map"
///   2. [_ConfirmStep]  — shows keycode + friendly name, asks to continue
///   3. AppPickerScreen — existing screen for choosing the target app
class ButtonCaptureScreen extends StatefulWidget {
  const ButtonCaptureScreen({super.key});

  @override
  State<ButtonCaptureScreen> createState() => _ButtonCaptureScreenState();
}

class _ButtonCaptureScreenState extends State<ButtonCaptureScreen> {
  int? _capturedKeycode;

  void _onCaptured(int keycode) {
    setState(() => _capturedKeycode = keycode);
  }

  void _onRetry() {
    setState(() => _capturedKeycode = null);
  }

  Future<void> _onConfirmed(int keycode) async {
    final bool saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (BuildContext context) =>
                AppPickerScreen(keycode: keycode),
          ),
        ) ??
        false;
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      // User pressed BACK in the picker without choosing — stay in capture
      setState(() => _capturedKeycode = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _capturedKeycode == null
              ? _CaptureStep(key: const ValueKey<String>('capture'), onCaptured: _onCaptured)
              : _ConfirmStep(
                  key: ValueKey<int>(_capturedKeycode!),
                  keycode: _capturedKeycode!,
                  onConfirmed: _onConfirmed,
                  onRetry: _onRetry,
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — Waiting for a button press
// ---------------------------------------------------------------------------

class _CaptureStep extends StatefulWidget {
  const _CaptureStep({super.key, required this.onCaptured});

  final ValueChanged<int> onCaptured;

  @override
  State<_CaptureStep> createState() => _CaptureStepState();
}

class _CaptureStepState extends State<_CaptureStep>
    with SingleTickerProviderStateMixin {
  StreamSubscription<dynamic>? _sub;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    const EventChannel keyEventChannel = EventChannel('nex_remote/key_events');
    _sub = keyEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final int keycode = event as int;
        // Ignore navigation keys that would break TV UX:
        // BACK(4), DPAD center/up/down/left/right (19-23)
        if (keycode == 4 || (keycode >= 19 && keycode <= 23)) {
          return;
        }
        widget.onCaptured(keycode);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          FadeTransition(
            opacity: _pulse,
            child: Icon(
              Icons.radio_button_on,
              size: 80,
              color: Colors.tealAccent,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Press the button you want to map',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Press any button on the remote.\nNavigation keys (Back, D-Pad) are ignored during capture.',
            style: textTheme.bodyLarge?.copyWith(color: Colors.white60),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          TvFocusable(
            autofocus: true,
            onSelect: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text('Cancel', style: textTheme.titleMedium),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — Confirm detected keycode
// ---------------------------------------------------------------------------

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    super.key,
    required this.keycode,
    required this.onConfirmed,
    required this.onRetry,
  });

  final int keycode;
  final ValueChanged<int> onConfirmed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String name = _friendlyName(keycode);

    return Padding(
      padding: const EdgeInsets.all(64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.check_circle_outline, size: 72, color: Colors.tealAccent),
          const SizedBox(height: 32),
          Text('Button detected!', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.tealAccent, width: 2),
              color: Colors.tealAccent.withValues(alpha: 0.1),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  'Keycode: $keycode',
                  style: textTheme.displaySmall?.copyWith(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(name, style: textTheme.titleLarge),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TvFocusable(
                autofocus: true,
                onSelect: () => onConfirmed(keycode),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.arrow_forward),
                      const SizedBox(width: 8),
                      Text('Choose App', style: textTheme.titleMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              TvFocusable(
                onSelect: onRetry,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.refresh),
                      const SizedBox(width: 8),
                      Text('Try Again', style: textTheme.titleMedium),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
