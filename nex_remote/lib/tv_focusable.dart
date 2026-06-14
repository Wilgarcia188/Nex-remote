import 'package:flutter/material.dart';

/// Wraps any widget with a TV-friendly focus treatment:
///   • teal accent border (2 dp → 3 dp on focus)
///   • background highlight on focus
///   • subtle scale-up animation (1.0 → 1.03) when focus is gained
///
/// Usage:
///   TvFocusable(
///     onSelect: () { … },
///     child: Padding(…),
///   )
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.child,
    required this.onSelect,
    this.autofocus = false,
    this.borderRadius = 8,
  });

  final Widget child;
  final VoidCallback onSelect;
  final bool autofocus;
  final double borderRadius;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable>
    with SingleTickerProviderStateMixin {
  bool _focused = false;

  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onFocusChange(bool gained) {
    setState(() => _focused = gained);
    if (gained) {
      _scaleCtrl.forward();
    } else {
      _scaleCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: _onFocusChange,
      child: GestureDetector(
        onTap: widget.onSelect,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _focused
                    ? Colors.tealAccent
                    : Colors.tealAccent.withValues(alpha: 0.0),
                width: _focused ? 3 : 2,
              ),
              color: _focused
                  ? Colors.tealAccent.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Drop-in replacement for [ListTile] with TV focus treatment applied.
/// Supports leading widget, title, subtitle and an optional trailing widget.
class TvListTile extends StatelessWidget {
  const TvListTile({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.autofocus = false,
    this.accentColor,
  });

  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool autofocus;

  /// Override the focus border/highlight colour (defaults to tealAccent).
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return _TvListTileCore(
      autofocus: autofocus,
      accentColor: accentColor ?? Colors.tealAccent,
      onTap: onTap,
      child: ListTile(
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        leading: leading,
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: trailing,
      ),
    );
  }
}

/// Internal Focus + animation shell used by [TvListTile].
class _TvListTileCore extends StatefulWidget {
  const _TvListTileCore({
    required this.child,
    required this.onTap,
    required this.autofocus,
    required this.accentColor,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool autofocus;
  final Color accentColor;

  @override
  State<_TvListTileCore> createState() => _TvListTileCoreState();
}

class _TvListTileCoreState extends State<_TvListTileCore>
    with SingleTickerProviderStateMixin {
  bool _focused = false;

  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onFocusChange(bool gained) {
    setState(() => _focused = gained);
    if (gained) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: _onFocusChange,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused
                    ? widget.accentColor
                    : widget.accentColor.withValues(alpha: 0.0),
                width: 3,
              ),
              color: _focused
                  ? widget.accentColor.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.04),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
