import 'package:flutter/material.dart';

import '../models/word.dart';

class AACButton extends StatefulWidget {
  final Word word;
  final bool isAmharic;
  final bool enabled;
  final VoidCallback? onTap;

  const AACButton({
    super.key,
    required this.word,
    required this.isAmharic,
    required this.enabled,
    this.onTap,
  });

  @override
  State<AACButton> createState() => _AACButtonState();
}

class _AACButtonState extends State<AACButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      // Shrink phase: quick
      duration: const Duration(milliseconds: 80),
      // Expand phase: slightly slower with an overshoot for the bounce feel
      reverseDuration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.91).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap?.call();
    // Shrink → bounce back regardless of whether tap produced an action,
    // so disabled buttons never animate.
    _ctrl.forward().then((_) {
      if (mounted) _ctrl.reverse();
    });
  }

  Widget _labelText(String label, Color textColor, double fontSize) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _imageWithLabel(String label, Color textColor) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
            child: Opacity(
              opacity: widget.enabled ? 1.0 : 0.25,
              child: Image.asset(
                widget.word.image,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Center(child: _labelText(label, textColor, 11)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.word.label(widget.isAmharic);
    final textColor = widget.enabled
        ? (widget.word.color.computeLuminance() > 0.4
            ? Colors.black87
            : Colors.white)
        : Colors.grey.shade400;

    return GestureDetector(
      onTap: widget.enabled ? _handleTap : null,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: widget.enabled ? widget.word.color : const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.black
                  .withValues(alpha: widget.enabled ? 0.30 : 0.12),
              width: 1.2,
            ),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 4,
                      offset: const Offset(1, 2),
                    ),
                  ]
                : null,
          ),
          child: widget.word.hasImage
              ? _imageWithLabel(label, textColor)
              : Padding(
                  padding: const EdgeInsets.all(6),
                  child: Center(child: _labelText(label, textColor, 22)),
                ),
        ),
      ),
    );
  }
}

class EmptySlot extends StatelessWidget {
  const EmptySlot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.12),
          width: 1.2,
        ),
      ),
    );
  }
}
