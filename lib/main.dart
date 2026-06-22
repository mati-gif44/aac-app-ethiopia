import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const AACApp());
}

// ── Word data ────────────────────────────────────────────────────────────────

class WordData {
  final String english;
  final String amharic;
  final int level;
  final Color color;
  final IconData icon;
  final String imageName; // filename (no extension) — defaults to english key

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
  final List<String> _sentence = []; // stores english word keys
  late final FlutterTts _tts;
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _audioPlayer = AudioPlayer();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  @override
  void dispose() {
    _tts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Speech ────────────────────────────────────────────────────────────────

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

  // ── Sentence bar actions ──────────────────────────────────────────────────

  void _backspace() {
    if (_sentence.isNotEmpty) setState(() => _sentence.removeLast());
  }

  void _clear() => setState(() => _sentence.clear());

  String _labelFor(String key) {
    final word = kWords.firstWhere((w) => w.english == key);
    return _isAmharic ? word.amharic : word.english;
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
          // Language toggle
          _TopBarButton(
            label: _isAmharic ? 'EN' : 'አማ',
            active: false,
            onTap: () => setState(() => _isAmharic = !_isAmharic),
          ),
          const SizedBox(width: 12),
          // Level selector
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const cols = 4;
        const rows = 6;
        const hGap = 6.0;
        const vGap = 6.0;
        const pad = 8.0;
        final cellW = (constraints.maxWidth - (cols - 1) * hGap - pad * 2) / cols;
        final cellH = (constraints.maxHeight - (rows - 1) * vGap - pad * 2) / rows;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(pad),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: vGap,
            crossAxisSpacing: hGap,
            childAspectRatio: cellW / cellH,
          ),
          itemCount: kWords.length,
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

// ── Reusable widgets ──────────────────────────────────────────────────────────

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
