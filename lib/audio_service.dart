import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'models/word.dart';
import 'sov.dart';

class AudioService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  int _gen = 0;
  final Map<String, Uint8List> _amharicBytes = {};

  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> preload(Iterable<Word> words) async {
    for (final word in words) {
      await _bytesFor(word);
    }
  }

  Future<Uint8List?> _bytesFor(Word word) async {
    if (!word.hasAudio) return null;
    final cached = _amharicBytes[word.id];
    if (cached != null) return cached;
    try {
      final data = await rootBundle.load(word.audio);
      return _amharicBytes[word.id] = data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _tts.stop();
    _player.dispose();
  }

  Future<void> stopAll() async {
    _gen++;
    await Future.wait([_tts.stop(), _player.stop()]);
  }

  Future<void> speakWord(Word word, bool isAmharic) async {
    await stopAll();
    if (isAmharic) {
      final gen = _gen;
      final bytes = await _bytesFor(word);
      if (bytes == null || _gen != gen) return;
      try {
        await _player.play(BytesSource(bytes));
      } catch (_) {}
    } else {
      await _tts.speak(word.english);
    }
  }

  Future<void> speakSentence(
    List<String> ids,
    Word? Function(String) lookup,
    bool isAmharic,
  ) async {
    await stopAll();
    final gen = _gen;
    if (isAmharic) {
      for (final id in amharicSOVOrder(List<String>.from(ids))) {
        if (_gen != gen) return;
        final word = lookup(id);
        final bytes = word == null ? null : await _bytesFor(word);
        if (bytes == null || _gen != gen) continue;
        final completer = Completer<void>();
        final sub = _player.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        try {
          await _player.play(BytesSource(bytes));
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
      if (_gen != gen) return;
      final text = ids.map((id) => lookup(id)?.english ?? id).join(' ');
      await _tts.speak(text);
    }
  }
}
