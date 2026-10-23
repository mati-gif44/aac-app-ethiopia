import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio_service.dart';
import 'models/word.dart';
import 'pin_dialogs.dart';
import 'settings.dart';
import 'tutorial.dart';
import 'widgets/aac_button.dart';
import 'widgets/bar_widgets.dart';
import 'widgets/history_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _level = 1;
  int _pageIndex = 0;
  bool _isAmharic = false;
  bool _flashSentenceBar = false;
  final List<String> _sentence = [];
  List<List<String>> _history = [];
  final AudioService _audio = AudioService();
  AppSettings _settings = const AppSettings();
  Vocabulary? _vocab;

  @override
  void initState() {
    super.initState();
    _audio.init();
    _loadAndApplySettings();
    _loadHistory();
    _loadVocabulary();
    WakelockPlus.enable();
  }

  Future<void> _loadVocabulary() async {
    final vocab = await Vocabulary.load(rootBundle);
    if (!mounted) return;
    setState(() => _vocab = vocab);
    _audio.preload(vocab.words);
  }

  Future<void> _loadAndApplySettings() async {
    final s = await loadSettings();
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

  @override
  void dispose() {
    WakelockPlus.disable();
    _audio.dispose();
    super.dispose();
  }

  Word? _lookup(String id) => _vocab?.byId(id);

  void _onWordTapped(Word word) {
    setState(() => _sentence.add(word.id));
    _audio.speakWord(word, _isAmharic);
  }

  Future<void> _speakSentence() async {
    if (_sentence.isEmpty) return;
    _addToHistory(_sentence);
    setState(() => _flashSentenceBar = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _flashSentenceBar = false);
    });
    await _audio.speakSentence(
        List<String>.from(_sentence), _lookup, _isAmharic);
  }

  void _backspace() {
    if (_sentence.isNotEmpty) setState(() => _sentence.removeLast());
  }

  void _removeWordAt(int index) {
    setState(() => _sentence.removeAt(index));
  }

  void _clear() {
    _audio.stopAll();
    setState(() => _sentence.clear());
  }

  String _labelFor(String id) => _lookup(id)?.label(_isAmharic) ?? id;

  // ── History ───────────────────────────────────────────────────────────────

  void _openHistory() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (ctx) => HistorySheet(
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
        builder: (_) => PinEntryDialog(correctPin: savedPin),
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
      await saveSettings(result);
    }
  }

  Future<bool> _createNewPin() async {
    final newPin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SetPinDialog(
        title: 'Create caregiver PIN',
        subtitle: 'Set a 4-digit PIN to protect settings.',
        confirmLabel: 'Create PIN',
      ),
    );
    if (newPin == null || !mounted) return false;
    final updated = _settings.copyWith(pin: newPin);
    setState(() => _settings = updated);
    await saveSettings(updated);
    return mounted;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vocab = _vocab;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildSentenceBar(),
            _buildActionRow(),
            Expanded(
              child: vocab == null ? const SizedBox.shrink() : _buildGrid(vocab),
            ),
            if (vocab != null)
              PageTabs(
                pages: vocab.pages,
                selected: _pageIndex,
                isAmharic: _isAmharic,
                onSelect: (i) => setState(() => _pageIndex = i),
              ),
          ],
        ),
      ),
    );
  }

  void _openTutorial() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TutorialScreen()),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: const Color(0xFF1565C0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: _openTutorial,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(Icons.help_outline, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 4),
          TopBarButton(
            label: _isAmharic ? 'EN' : 'አማ',
            active: false,
            onTap: () {
              _audio.stopAll();
              setState(() => _isAmharic = !_isAmharic);
            },
          ),
          const SizedBox(width: 8),
          Row(
            children: [1, 2, 3]
                .map(
                  (l) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: TopBarButton(
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

    return GestureDetector(
      onTap: _speakSentence,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 60),
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _flashSentenceBar ? const Color(0xFFC8E6C9) : Colors.white,
          border: Border.all(
            color: _flashSentenceBar
                ? const Color(0xFF2E7D32)
                : const Color(0xFF1565C0),
            width: 2.5,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isEmpty
            ? Text(
                _isAmharic ? 'ቃላት ይምረጡ...' : 'Tap words to build a sentence...',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade400),
              )
            : Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < _sentence.length; i++)
                          WordChip(
                            label: _labelFor(_sentence[i]),
                            onRemove: () => _removeWordAt(i),
                          ),
                      ],
                    ),
                  ),
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
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: ActionButton(
              icon: Icons.backspace,
              label: _isAmharic ? 'ሰርዝ' : 'Back',
              color: const Color(0xFFE65100),
              onTap: _backspace,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ActionButton(
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

  Widget _buildGrid(Vocabulary vocab) {
    final pageId = vocab.pages[_pageIndex].id;
    final isCompact = _pageIndex == 0 && _settings.gridMode == GridMode.compact;
    final cols = isCompact ? 3 : 4;
    final rows = isCompact ? 4 : 6;
    final count = cols * rows;
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
            final word = vocab.wordAt(pageId, index);
            if (word == null) return const EmptySlot();
            final enabled = word.level <= _level;
            return AACButton(
              key: ValueKey(word.id),
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
