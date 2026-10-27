import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_dialogs.dart';

enum GridMode { wide, compact } // 4×6 (24 words) | 3×4 (12 words, larger buttons)

class AppSettings {
  final GridMode gridMode;
  final double spacing; // gap between buttons in dp
  final String? pin; // null = never set; non-null = PIN active

  const AppSettings({
    this.gridMode = GridMode.wide,
    this.spacing = 6.0,
    this.pin, // null by default
  });

  AppSettings copyWith({GridMode? gridMode, double? spacing, String? pin}) =>
      AppSettings(
        gridMode: gridMode ?? this.gridMode,
        spacing: spacing ?? this.spacing,
        pin: pin ?? this.pin,
      );
}

Future<AppSettings> loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  return AppSettings(
    gridMode: prefs.getString('grid_mode') == 'compact'
        ? GridMode.compact
        : GridMode.wide,
    spacing: prefs.getDouble('spacing') ?? 6.0,
    pin: prefs.getString('pin'), // null when never saved
  );
}

Future<void> saveSettings(AppSettings s) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      'grid_mode', s.gridMode == GridMode.compact ? 'compact' : 'wide');
  await prefs.setDouble('spacing', s.spacing);
  if (s.pin != null) {
    await prefs.setString('pin', s.pin!);
  } else {
    await prefs.remove('pin');
  }
}

class SettingsScreen extends StatefulWidget {
  final AppSettings initial;
  const SettingsScreen({super.key, required this.initial});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _s;

  static const _spacingValues = [4.0, 6.0, 10.0];
  static const _spacingLabels = ['Compact', 'Normal', 'Spacious'];

  @override
  void initState() {
    super.initState();
    _s = widget.initial;
  }

  int get _spacingIndex {
    final i = _spacingValues.indexOf(_s.spacing);
    return i < 0 ? 1 : i;
  }

  Future<void> _changePin() async {
    final newPin = await showDialog<String>(
      context: context,
      builder: (_) => const SetPinDialog(
        title: 'Change PIN',
        confirmLabel: 'Save',
      ),
    );
    if (newPin != null && mounted) {
      setState(() => _s = _s.copyWith(pin: newPin));
      // Save the PIN immediately so it persists even if the user
      // navigates back without tapping Save on the settings screen.
      await saveSettings(_s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN updated')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Settings'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _s),
            child: const Text(
              'Save',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Grid size ────────────────────────────────────────────────
          _SettingsCard(
            title: 'Grid Size',
            child: Row(
              children: [
                Expanded(
                  child: _GridModeButton(
                    label: '4×6',
                    sublabel: '24 words\n(default)',
                    selected: _s.gridMode == GridMode.wide,
                    onTap: () =>
                        setState(() => _s = _s.copyWith(gridMode: GridMode.wide)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GridModeButton(
                    label: '3×4',
                    sublabel: '12 words\n(larger buttons)',
                    selected: _s.gridMode == GridMode.compact,
                    onTap: () =>
                        setState(() => _s = _s.copyWith(gridMode: GridMode.compact)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Button spacing ───────────────────────────────────────────
          _SettingsCard(
            title: 'Button Spacing',
            child: Column(
              children: [
                Slider(
                  value: _spacingIndex.toDouble(),
                  min: 0,
                  max: 2,
                  divisions: 2,
                  activeColor: const Color(0xFF1565C0),
                  onChanged: (v) => setState(
                    () => _s =
                        _s.copyWith(spacing: _spacingValues[v.round()]),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _spacingLabels
                      .map((l) => Text(l,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── PIN ──────────────────────────────────────────────────────
          _SettingsCard(
            title: 'Caregiver PIN',
            child: Row(
              children: [
                Text(
                  '• • • •',
                  style: TextStyle(
                    fontSize: 22,
                    letterSpacing: 4,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Change PIN'),
                  onPressed: _changePin,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1565C0),
                    side: const BorderSide(color: Color(0xFF1565C0)),
                  ),
                ),
              ],
            ),
          ),

          // ── 3×4 info tip ─────────────────────────────────────────────
          if (_s.gridMode == GridMode.compact) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '3×4 shows the first 12 word positions of the Core page. '
                      'Raise the level to unlock more of them. Other pages always use 4×6.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Pictographic symbols: Sergio Palao. Origin: ARASAAC (arasaac.org). '
            'License: CC BY-NC-SA. Owner: Government of Aragón (Spain).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SettingsCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _GridModeButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _GridModeButton({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1565C0) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF1565C0) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sublabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: selected ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
