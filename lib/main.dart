import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AACApp());
}

// ── Settings model ────────────────────────────────────────────────────────────

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

Future<AppSettings> _loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  return AppSettings(
    gridMode: prefs.getString('grid_mode') == 'compact'
        ? GridMode.compact
        : GridMode.wide,
    spacing: prefs.getDouble('spacing') ?? 6.0,
    pin: prefs.getString('pin'), // null when never saved
  );
}

Future<void> _saveSettings(AppSettings s) async {
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

// ── Word data ─────────────────────────────────────────────────────────────────

class WordData {
  final String english;
  final String amharic;
  final int level;
  final Color color;
  final IconData icon;
  final String imageName;

  const WordData({
    required this.english,
    required this.amharic,
    required this.level,
    required this.color,
    required this.icon,
    String? imageName,
  }) : imageName = imageName ?? english;
}

// Fitzgerald Key palette
const _fkGreen  = Color(0xFF4CAF50); // verbs
const _fkYellow = Color(0xFFFFD600); // pronouns
const _fkOrange = Color(0xFFFF9800); // nouns / people / places
const _fkBlue   = Color(0xFF2196F3); // descriptive
const _fkRed    = Color(0xFFF44336); // negatives / quantity
const _fkPink   = Color(0xFFE91E63); // social

// Fixed grid positions (4 cols × 6 rows = 24 slots).
// Level 1 words are intentionally scattered across rows 0–4.
const List<WordData> kWords = [
  // ── Row 0 ──────────────────────────────────────────────────────────────
  WordData(english: 'want',     amharic: 'ፈልጋለሁ',  level: 1, color: _fkGreen,  icon: Icons.favorite),
  WordData(english: 'I',        amharic: 'እኔ',       level: 2, color: _fkYellow, icon: Icons.person),
  WordData(english: 'play',     amharic: 'ጫወት',     level: 3, color: _fkGreen,  icon: Icons.sports_esports),
  WordData(english: 'no',       amharic: 'አይ',       level: 1, color: _fkRed,    icon: Icons.cancel),
  // ── Row 1 ──────────────────────────────────────────────────────────────
  WordData(english: 'help',     amharic: 'እርዳታ',    level: 1, color: _fkGreen,  icon: Icons.pan_tool),
  WordData(english: 'you',      amharic: 'አንተ',      level: 2, color: _fkYellow, icon: Icons.person_outline),
  WordData(english: 'sleep',    amharic: 'ተኛ',      level: 3, color: _fkGreen,  icon: Icons.bedtime),
  WordData(english: 'yes',      amharic: 'አዎ',       level: 1, color: _fkPink,   icon: Icons.check_circle),
  // ── Row 2 ──────────────────────────────────────────────────────────────
  WordData(english: 'eat',      amharic: 'ምግብ',     level: 1, color: _fkGreen,  icon: Icons.restaurant),
  WordData(english: 'go',       amharic: 'ሂድ',       level: 2, color: _fkGreen,  icon: Icons.directions_walk),
  WordData(english: 'pain',     amharic: 'ህመም',     level: 3, color: _fkBlue,   icon: Icons.healing),
  WordData(english: 'drink',    amharic: 'ጠጣ',      level: 1, color: _fkGreen,  icon: Icons.local_cafe),
  // ── Row 3 ──────────────────────────────────────────────────────────────
  WordData(english: 'finished', amharic: 'ጨርሻለሁ',   level: 2, color: _fkGreen,  icon: Icons.done_all, imageName: 'I have finished'),
  WordData(english: 'more',     amharic: 'ተጨማሪ',   level: 1, color: _fkRed,    icon: Icons.add_circle),
  WordData(english: 'mom',      amharic: 'እናቴ',     level: 3, color: _fkOrange, icon: Icons.woman),
  WordData(english: 'water',    amharic: 'ውሃ',       level: 2, color: _fkOrange, icon: Icons.water_drop),
  // ── Row 4 ──────────────────────────────────────────────────────────────
  WordData(english: 'stop',     amharic: 'ቁም',      level: 1, color: _fkGreen,  icon: Icons.stop_circle),
  WordData(english: 'happy',    amharic: 'ደስተኛ',    level: 2, color: _fkBlue,   icon: Icons.sentiment_very_satisfied),
  WordData(english: 'dad',      amharic: 'አባቴ',     level: 3, color: _fkOrange, icon: Icons.man),
  WordData(english: 'toilet',   amharic: 'መጸዳጃ',   level: 2, color: _fkOrange, icon: Icons.wc),
  // ── Row 5 ──────────────────────────────────────────────────────────────
  WordData(english: 'sad',      amharic: 'ሐዘን',     level: 2, color: _fkBlue,   icon: Icons.sentiment_very_dissatisfied),
  WordData(english: 'hot',      amharic: 'ሞቃት',     level: 3, color: _fkBlue,   icon: Icons.wb_sunny),
  WordData(english: 'teacher',  amharic: 'አስተማሪ',   level: 3, color: _fkOrange, icon: Icons.school),
  WordData(english: 'cold',     amharic: 'ቀዝቃዛ',   level: 3, color: _fkBlue,   icon: Icons.ac_unit),
];

// ── App root ─────────────────────────────────────────────────────────────────

class AACApp extends StatelessWidget {
  const AACApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AAC Ethiopia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ── Home screen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _level = 1;
  bool _isAmharic = false;
  final List<String> _sentence = [];
  late final FlutterTts _tts;
  late final AudioPlayer _audioPlayer;
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _audioPlayer = AudioPlayer();
    _initTts();
    _loadAndApplySettings();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> _loadAndApplySettings() async {
    final s = await _loadSettings();
    if (mounted) setState(() => _settings = s);
  }

  @override
  void dispose() {
    _tts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Speech ──────────────────────────────────────────────────────────────

  void _onWordTapped(WordData word) {
    setState(() => _sentence.add(word.english));
    _speakWord(word.english);
  }

  Future<void> _speakWord(String key) async {
    if (_isAmharic) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource('audio/am/$key.mp3'));
      } catch (_) {}
    } else {
      await _tts.stop();
      await _tts.speak(key);
    }
  }

  Future<void> _speakSentence() async {
    if (_sentence.isEmpty) return;
    if (_isAmharic) {
      await _audioPlayer.stop();
      for (final key in _sentence) {
        final completer = Completer<void>();
        final sub = _audioPlayer.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        try {
          await _audioPlayer.play(AssetSource('audio/am/$key.mp3'));
          await completer.future.timeout(
            const Duration(seconds: 6),
            onTimeout: () {},
          );
        } catch (_) {
          if (!completer.isCompleted) completer.complete();
        } finally {
          await sub.cancel();
        }
      }
    } else {
      await _tts.stop();
      await _tts.speak(_sentence.join(' '));
    }
  }

  // ── Sentence bar actions ─────────────────────────────────────────────────

  void _backspace() {
    if (_sentence.isNotEmpty) setState(() => _sentence.removeLast());
  }

  void _clear() => setState(() => _sentence.clear());

  String _labelFor(String key) {
    final word = kWords.firstWhere((w) => w.english == key);
    return _isAmharic ? word.amharic : word.english;
  }

  // ── Settings / PIN ───────────────────────────────────────────────────────

  Future<void> _openSettings() async {
    if (_settings.pin == null) {
      // First time: create a PIN before entering settings.
      final newPin = await _showCreatePinDialog();
      if (newPin == null || !mounted) return;
      final updated = _settings.copyWith(pin: newPin);
      setState(() => _settings = updated);
      await _saveSettings(updated);
      if (!mounted) return;
    } else {
      final unlocked = await _showPinDialog();
      if (!unlocked || !mounted) return;
    }
    final result = await Navigator.push<AppSettings>(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen(initial: _settings)),
    );
    if (result != null && mounted) {
      setState(() => _settings = result);
      await _saveSettings(result);
    }
  }

  // Shown when no PIN exists yet.
  Future<String?> _showCreatePinDialog() async {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    String? error;
    final newPin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Create caregiver PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Set a 4-digit PIN to protect settings.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: c1,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                autofocus: true,
                decoration: const InputDecoration(labelText: 'New PIN (4 digits)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c2,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                  labelText: 'Confirm PIN',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (c1.text.length < 4) {
                  setS(() => error = 'PIN must be 4 digits');
                } else if (c1.text != c2.text) {
                  setS(() => error = 'PINs do not match');
                } else {
                  Navigator.pop(ctx, c1.text);
                }
              },
              child: const Text('Create PIN'),
            ),
          ],
        ),
      ),
    );
    c1.dispose();
    c2.dispose();
    return newPin;
  }

  // Shown on subsequent taps when a PIN is already set.
  Future<bool> _showPinDialog() async {
    final controller = TextEditingController();
    bool hasError = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Caregiver PIN'),
          content: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Enter PIN',
              errorText: hasError ? 'Incorrect PIN' : null,
            ),
            onSubmitted: (_) {
              if (controller.text == _settings.pin) {
                Navigator.pop(ctx, true);
              } else {
                setS(() {
                  hasError = true;
                  controller.clear();
                });
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text == _settings.pin) {
                  Navigator.pop(ctx, true);
                } else {
                  setS(() {
                    hasError = true;
                    controller.clear();
                  });
                }
              },
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result ?? false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildSentenceBar(),
            _buildActionRow(),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: const Color(0xFF1565C0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Text(
            'AAC Ethiopia',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          _TopBarButton(
            label: _isAmharic ? 'EN' : 'አማ',
            active: false,
            onTap: () => setState(() => _isAmharic = !_isAmharic),
          ),
          const SizedBox(width: 8),
          Row(
            children: [1, 2, 3]
                .map(
                  (l) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _TopBarButton(
                      label: 'L$l',
                      active: _level == l,
                      onTap: () => setState(() => _level = l),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openSettings,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(Icons.settings, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceBar() {
    final isEmpty = _sentence.isEmpty;
    final display = isEmpty
        ? (_isAmharic ? 'ቃላት ይምረጡ...' : 'Tap words to build a sentence...')
        : _sentence.map(_labelFor).join('   ');

    return GestureDetector(
      onTap: _speakSentence,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 60),
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF1565C0), width: 2.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                display,
                style: TextStyle(
                  fontSize: 18,
                  color: isEmpty ? Colors.grey.shade400 : Colors.black87,
                  fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
                ),
              ),
            ),
            if (!isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.volume_up, color: Color(0xFF1565C0), size: 26),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.backspace,
              label: _isAmharic ? 'ሰርዝ' : 'Back',
              color: const Color(0xFFE65100),
              onTap: _backspace,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              icon: Icons.clear_all,
              label: _isAmharic ? 'አጽዳ' : 'Clear',
              color: const Color(0xFFC62828),
              onTap: _clear,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final isCompact = _settings.gridMode == GridMode.compact;
    final cols = isCompact ? 3 : 4;
    final rows = isCompact ? 4 : 6;
    final count = isCompact ? 12 : kWords.length;
    final gap = _settings.spacing;

    return LayoutBuilder(
      builder: (context, constraints) {
        const pad = 8.0;
        final cellW =
            (constraints.maxWidth - (cols - 1) * gap - pad * 2) / cols;
        final cellH =
            (constraints.maxHeight - (rows - 1) * gap - pad * 2) / rows;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(pad),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: cellW / cellH,
          ),
          itemCount: count,
          itemBuilder: (context, index) {
            final word = kWords[index];
            final enabled = word.level <= _level;
            return _AACButton(
              word: word,
              isAmharic: _isAmharic,
              enabled: enabled,
              onTap: enabled ? () => _onWordTapped(word) : null,
            );
          },
        );
      },
    );
  }
}

// ── Settings screen ───────────────────────────────────────────────────────────

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
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    String? error;

    final newPin = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Change PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c1,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                autofocus: true,
                decoration: const InputDecoration(labelText: 'New PIN (4 digits)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c2,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                  labelText: 'Confirm PIN',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (c1.text.length < 4) {
                  setS(() => error = 'PIN must be 4 digits');
                } else if (c1.text != c2.text) {
                  setS(() => error = 'PINs do not match');
                } else {
                  Navigator.pop(ctx, c1.text);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    c1.dispose();
    c2.dispose();
    if (newPin != null && mounted) {
      setState(() => _s = _s.copyWith(pin: newPin));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated')),
      );
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
                      '3×4 shows the first 12 word positions. '
                      'Raise the level to unlock more of them.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Settings sub-widgets ──────────────────────────────────────────────────────

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

// ── Shared top-bar / action widgets ──────────────────────────────────────────

class _TopBarButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TopBarButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF1565C0) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── AAC button ────────────────────────────────────────────────────────────────

class _AACButton extends StatelessWidget {
  final WordData word;
  final bool isAmharic;
  final bool enabled;
  final VoidCallback? onTap;

  const _AACButton({
    required this.word,
    required this.isAmharic,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = isAmharic ? word.amharic : word.english;
    // Pick text colour that contrasts against the Fitzgerald Key background.
    final textColor = enabled
        ? (word.color.computeLuminance() > 0.4 ? Colors.black87 : Colors.white)
        : Colors.grey.shade400;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: enabled ? word.color : const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(8),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 4,
                    offset: const Offset(1, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // Image sits on top of the category-colour background.
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                child: Opacity(
                  opacity: enabled ? 1.0 : 0.25,
                  child: Image.asset(
                    'assets/images/${word.imageName}.png',
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => Icon(
                      word.icon,
                      size: 34,
                      color: enabled ? Colors.white : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ),
            // Text label
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
