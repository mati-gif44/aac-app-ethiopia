import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Using proper StatefulWidgets (not StatefulBuilder) avoids a Flutter assertion
// ("dependents is not empty") that fires when Navigator.pop is called from a
// context that is not part of the dialog's own widget subtree.  Inside a
// StatefulWidget, Navigator.of(context).pop() runs from within the tree and
// Flutter unwinds InheritedWidget dependencies in the correct order.

class PinEntryDialog extends StatefulWidget {
  final String correctPin;
  const PinEntryDialog({super.key, required this.correctPin});

  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog> {
  final _ctrl = TextEditingController();
  bool _hasError = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_ctrl.text == widget.correctPin) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _hasError = true;
        _ctrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Caregiver PIN'),
      content: TextField(
        controller: _ctrl,
        obscureText: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Enter PIN',
          errorText: _hasError ? 'Incorrect PIN' : null,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        // Leftmost — visually separated from Cancel/Unlock
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // null = forgot
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
          ),
          child: const Text('Forgot PIN?'),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}

/// Used for both "Create PIN" (first launch) and "Change PIN" (settings).
class SetPinDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String confirmLabel;

  const SetPinDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.confirmLabel,
  });

  @override
  State<SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<SetPinDialog> {
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    super.dispose();
  }

  void _submit() {
    if (_c1.text.length < 4) {
      setState(() => _error = 'PIN must be 4 digits');
    } else if (_c1.text != _c2.text) {
      setState(() => _error = 'PINs do not match');
    } else {
      Navigator.of(context).pop(_c1.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.subtitle != null) ...[
            Text(
              widget.subtitle!,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _c1,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            autofocus: true,
            decoration: const InputDecoration(labelText: 'New PIN (4 digits)'),
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _c2,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              labelText: 'Confirm PIN',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
