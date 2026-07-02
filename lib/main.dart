import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  WordData(english: 'play',     amharic: 'መጫወት',    level: 3, color: _fkGreen,  icon: Icons.sports_esports),
  WordData(english: 'no',       amharic: 'አይ',       level: 1, color: _fkRed,    icon: Icons.cancel),
  // ── Row 1 ──────────────────────────────────────────────────────────────
  WordData(english: 'help',     amharic: 'እርዳታ',    level: 1, color: _fkGreen,  icon: Icons.pan_tool),
  WordData(english: 'you',      amharic: 'አንተ',      level: 2, color: _fkYellow, icon: Icons.person_outline),
  WordData(english: 'sleep',    amharic: 'መተኛት',    level: 3, color: _fkGreen,  icon: Icons.bedtime),
  WordData(english: 'yes',      amharic: 'አዎ',       level: 1, color: _fkPink,   icon: Icons.check_circle),
  // ── Row 2 ──────────────────────────────────────────────────────────────
  WordData(english: 'eat',      amharic: 'መብላት',    level: 1, color: _fkGreen,  icon: Icons.restaurant),
  WordData(english: 'go',       amharic: 'ሂድ',       level: 2, color: _fkGreen,  icon: Icons.directions_walk),
  WordData(english: 'pain',     amharic: 'ህመም',     level: 3, color: _fkBlue,   icon: Icons.healing),
  WordData(english: 'drink',    amharic: 'መጠጣት',    level: 1, color: _fkGreen,  icon: Icons.local_cafe),
  // ── Row 3 ──────────────────────────────────────────────────────────────
  WordData(english: 'finished', amharic: 'ጨርሻለሁ',   level: 2, color: _fkGreen,  icon: Icons.done_all, imageName: 'I have finished'),
  WordData(english: 'more',     amharic: 'ጨምር',     level: 1, color: _fkRed,    icon: Icons.add_circle),
  WordData(english: 'mom',      amharic: 'እናት',     level: 3, color: _fkOrange, icon: Icons.woman),
  WordData(english: 'water',    amharic: 'ውሃ',       level: 2, color: _fkOrange, icon: Icons.water_drop),
  // ── Row 4 ──────────────────────────────────────────────────────────────
  WordData(english: 'stop',     amharic: 'ቁም',      level: 1, color: _fkGreen,  icon: Icons.stop_circle),
  WordData(english: 'happy',    amharic: 'ደስታ',     level: 2, color: _fkBlue,   icon: Icons.sentiment_very_satisfied),
  WordData(english: 'dad',      amharic: 'አባት',     level: 3, color: _fkOrange, icon: Icons.man),
  WordData(english: 'toilet',   amharic: 'ሽንት ቤት', level: 2, color: _fkOrange, icon: Icons.wc),
  // ── Row 5 ──────────────────────────────────────────────────────────────
  WordData(english: 'sad',      amharic: 'ሐዘን',     level: 2, color: _fkBlue,   icon: Icons.sentiment_very_dissatisfied),
  WordData(english: 'hot',      amharic: 'ትኩስ',     level: 3, color: _fkBlue,   icon: Icons.wb_sunny),
  WordData(english: 'teacher',  amharic: 'መምህር',    level: 3, color: _fkOrange, icon: Icons.school),
  WordData(english: 'cold',     amharic: 'ቀዝቃዛ',   level: 3, color: _fkBlue,   icon: Icons.ac_unit),
];

class _SovRule {
  final List<String> pattern;
  final List<int> indices;
  const _SovRule(this.pattern, this.indices);

  bool matches(List<String> words) {
    if (words.length != pattern.length) return false;
    for (var i = 0; i < pattern.length; i++) {
      if (pattern[i] != '*' && pattern[i] != words[i]) return false;
    }
    return true;
  }

  List<String> apply(List<String> words) =>
      [for (final i in indices) words[i]];
}

const _sovRules = <_SovRule>[
  _SovRule(['more', '*'], [1, 0]),
  _SovRule(['I',   'want', '*'], [0, 2, 1]),
  _SovRule(['you', 'want', '*'], [0, 2, 1]),
  _SovRule(['I',   'go', '*'], [0, 2, 1]),
  _SovRule(['you', 'go', '*'], [0, 2, 1]),
  _SovRule(['I',   'want', '*', 'more'], [0, 2, 3, 1]),
  _SovRule(['you', 'want', '*', 'more'], [0, 2, 3, 1]),
];

List<String> amharicSOVOrder(List<String> words) {
  for (final rule in _sovRules) {
    if (rule.matches(words)) return rule.apply(words);
  }
  return words;
}

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
  List<List<String>> _history = [];
  late final FlutterTts _tts;
  late final AudioPlayer _audioPlayer;
  AppSettings _settings = const AppSettings();
  int _audioGen = 0;
  final Map<String, Uint8List> _amharicBytes = {};

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _audioPlayer = AudioPlayer();
    _initTts();
    _loadAndApplySettings();
    _loadHistory();
    _preloadAmharicAudio();
    WakelockPlus.enable();
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

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('sentence_history');
    if (raw != null && mounted) {
      setState(() {
        _history = raw
            .map((e) => e.split('\x1F').where((s) => s.isNotEmpty).toList())
            .where((e) => e.isNotEmpty)
            .toList();
      });
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'sentence_history',
      _history.map((s) => s.join('\x1F')).toList(),
    );
  }

  void _addToHistory(List<String> sentence) {
    final entry = List<String>.from(sentence);
    final key = entry.join('\x1F');
    setState(() {
      _history.removeWhere((h) => h.join('\x1F') == key);
      _history.insert(0, entry);
      if (_history.length > 5) _history = _history.sublist(0, 5);
    });
    _saveHistory();
  }

  Future<void> _preloadAmharicAudio() async {
    for (final word in kWords) {
      try {
        final data = await rootBundle.load('assets/audio/am/${word.english}.mp3');
        _amharicBytes[word.english] = data.buffer.asUint8List();
      } catch (_) {}
    }
  }

  Source _amharicSource(String key) {
    final bytes = _amharicBytes[key];
    return bytes != null ? BytesSource(bytes) : AssetSource('audio/am/$key.mp3');
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _tts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _stopAllAudio() async {
    _audioGen++;
    await Future.wait([_tts.stop(), _audioPlayer.stop()]);
  }

  void _onWordTapped(WordData word) {
    setState(() => _sentence.add(word.english));
    _speakWord(word.english);
  }

  Future<void> _speakWord(String key) async {
    await _stopAllAudio();
    if (_isAmharic) {
      try {
        await _audioPlayer.play(_amharicSource(key));
      } catch (_) {}
    } else {
      await _tts.speak(key);
    }
  }

  Future<void> _speakSentence() async {
    if (_sentence.isEmpty) return;
    _addToHistory(_sentence);
    await _stopAllAudio();
    final gen = _audioGen;
    if (_isAmharic) {
      final keys = amharicSOVOrder(List<String>.from(_sentence));
      for (final key in keys) {
        if (_audioGen != gen) return;
        final completer = Completer<void>();
        final sub = _audioPlayer.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        try {
          await _audioPlayer.play(_amharicSource(key));
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
      if (_audioGen != gen) return;
      await _tts.speak(_sentence.join(' '));
    }
  }

  void _backspace() {
    if (_sentence.isNotEmpty) setState(() => _sentence.removeLast());
  }

  void _clear() {
    _stopAllAudio();
    setState(() => _sentence.clear());
  }

  String _labelFor(String key) {
    final word = kWords.firstWhere((w) => w.english == key);
    return _isAmharic ? word.amharic : word.english;
  }

  // ── History ───────────────────────────────────────────────────────────────

  void _openHistory() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _HistorySheet(
        history: _history,
        isAmharic: _isAmharic,
        labelFor: _labelFor,
        onSelect: (sentence) {
          setState(() {
            _sentence
              ..clear()
              ..addAll(sentence);
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  // ── Settings / PIN ───────────────────────────────────────────────────────

  Future<void> _openSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('pin');
    if (!mounted) return;

    if (savedPin != null) {
      final unlockResult = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PinEntryDialog(correctPin: savedPin),
      );
      if (!mounted) return;
      if (unlockResult == false) return;
      if (unlockResult == null) {
        if (!await _createNewPin()) return;
      }
    } else {
      if (!await _createNewPin()) return;
    }
    if (!mounted) return;
    final result = await Navigator.push<AppSettings>(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen(initial: _settings)),
    );
    if (result != null && mounted) {
      setState(() => _settings = result);
      await _saveSettings(result);
    }
  }

  Future<bool> _createNewPin() async {
    final newPin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SetPinDialog(
        title: 'Create caregiver PIN',
        subtitle: 'Set a 4-digit PIN to protect settings.',
        confirmLabel: 'Create PIN',
      ),
    );
    if (newPin == null || !mounted) return false;
    final updated = _settings.copyWith(pin: newPin);
    setState(() => _settings = updated);
    await _saveSettings(updated);
    return mounted;
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
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _TopBarButton(
            label: _isAmharic ? 'EN' : 'አማ',
            active: false,
            onTap: () {
              _stopAllAudio();
              setState(() => _isAmharic = !_isAmharic);
            },
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
            onTap: _openHistory,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(Icons.history, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 4),
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
    final newPin = await showDialog<String>(
      context: context,
      builder: (_) => const _SetPinDialog(
        title: 'Change PIN',
        confirmLabel: 'Save',
      ),
    );
    if (newPin != null && mounted) {
      setState(() => _s = _s.copyWith(pin: newPin));
      // Save the PIN immediately so it persists even if the user
      // navigates back without tapping Save on the settings screen.
      await _saveSettings(_s);
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

// ── PIN dialog widgets ────────────────────────────────────────────────────────
//
// Using proper StatefulWidgets (not StatefulBuilder) avoids a Flutter assertion
// ("dependents is not empty") that fires when Navigator.pop is called from a
// context that is not part of the dialog's own widget subtree.  Inside a
// StatefulWidget, Navigator.of(context).pop() runs from within the tree and
// Flutter unwinds InheritedWidget dependencies in the correct order.

class _PinEntryDialog extends StatefulWidget {
  final String correctPin;
  const _PinEntryDialog({required this.correctPin});

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
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
class _SetPinDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String confirmLabel;

  const _SetPinDialog({
    required this.title,
    this.subtitle,
    required this.confirmLabel,
  });

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
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

// ── History sheet ─────────────────────────────────────────────────────────────

class _HistorySheet extends StatelessWidget {
  final List<List<String>> history;
  final bool isAmharic;
  final String Function(String) labelFor;
  final void Function(List<String>) onSelect;

  const _HistorySheet({
    required this.history,
    required this.isAmharic,
    required this.labelFor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.history, color: Color(0xFF1565C0), size: 22),
              const SizedBox(width: 8),
              Text(
                isAmharic ? 'የቅርብ ጊዜ ዓረፍተ ነገሮች' : 'Recent Sentences',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                isAmharic ? 'ታሪክ የለም' : 'No history yet',
                style: const TextStyle(color: Colors.black45, fontSize: 14),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final display =
                  history[i].map((k) => labelFor(k)).join('  ');
              return ListTile(
                leading:
                    const Icon(Icons.chat_bubble_outline, color: Color(0xFF1565C0)),
                title: Text(display,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                onTap: () => onSelect(history[i]),
              );
            },
          ),
        SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 8),
      ],
    );
  }
}

// ── AAC button ────────────────────────────────────────────────────────────────

class _AACButton extends StatefulWidget {
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
  State<_AACButton> createState() => _AACButtonState();
}

class _AACButtonState extends State<_AACButton>
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

  @override
  Widget build(BuildContext context) {
    final label = widget.isAmharic ? widget.word.amharic : widget.word.english;
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
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                  child: Opacity(
                    opacity: widget.enabled ? 1.0 : 0.25,
                    child: Image.asset(
                      'assets/images/${widget.word.imageName}.png',
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => Icon(
                        widget.word.icon,
                        size: 34,
                        color: widget.enabled
                            ? Colors.white
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
