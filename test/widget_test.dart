import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:selam_aac/models/word.dart';
import 'package:selam_aac/sov.dart';

const _green = Color(0xFF4CAF50);
const _yellow = Color(0xFFFFD600);
const _orange = Color(0xFFFF9800);
const _blue = Color(0xFF2196F3);
const _red = Color(0xFFF44336);
const _pink = Color(0xFFE91E63);

const _corePage = [
  ('want', 'ፈልጋለሁ', 1, _green),
  ('I', 'እኔ', 2, _yellow),
  ('play', 'መጫወት', 3, _green),
  ('no', 'አይ', 1, _red),
  ('help', 'እርዳታ', 1, _green),
  ('you', 'አንተ', 2, _yellow),
  ('sleep', 'መተኛት', 3, _green),
  ('yes', 'አዎ', 1, _pink),
  ('eat', 'መብላት', 1, _green),
  ('go', 'ሂድ', 2, _green),
  ('pain', 'ህመም', 3, _blue),
  ('drink', 'መጠጣት', 1, _green),
  ('finished', 'ጨርሻለሁ', 2, _green),
  ('more', 'ጨምር', 1, _red),
  ('mom', 'እናት', 3, _orange),
  ('water', 'ውሃ', 2, _orange),
  ('stop', 'ቁም', 1, _green),
  ('happy', 'ደስታ', 2, _blue),
  ('dad', 'አባት', 3, _orange),
  ('toilet', 'ሽንት ቤት', 2, _orange),
  ('sad', 'ሐዘን', 2, _blue),
  ('hot', 'ትኩስ', 3, _blue),
  ('teacher', 'መምህር', 3, _orange),
  ('cold', 'ቀዝቃዛ', 3, _blue),
];

void main() {
  final raw = File('assets/data/words.json').readAsStringSync();
  final assets = {
    for (final f in Directory('assets').listSync(recursive: true))
      if (f is File) f.path.replaceAll('\\', '/'),
  };
  final vocab = Vocabulary.parse(raw, assets);

  test('core page matches the original fixed layout', () {
    for (var i = 0; i < _corePage.length; i++) {
      final (id, am, level, color) = _corePage[i];
      final w = vocab.wordAt('core', i)!;
      expect(w.id, id);
      expect(w.english, id);
      expect(w.amharic, am);
      expect(w.level, level);
      expect(w.color, color);
      expect(w.hasImage, isTrue, reason: w.image);
      expect(w.hasAudio, isTrue, reason: w.audio);
    }
    expect(vocab.words.where((w) => w.page == 'core').length, 24);
  });

  test('ids and slots are unique and positions fit the 4x6 grid', () {
    expect(vocab.words.map((w) => w.id).toSet().length, vocab.words.length);
    expect(
      vocab.words.map((w) => '${w.page}#${w.position}').toSet().length,
      vocab.words.length,
    );
    final pageIds = vocab.pages.map((p) => p.id).toSet();
    for (final w in vocab.words) {
      expect(pageIds, contains(w.page));
      expect(w.position, inInclusiveRange(0, 23));
      if (w.page != 'core') expect(w.level, 0);
    }
    expect(vocab.words.length, 24 + 43);
  });

  test('labels fall back to English when Amharic is missing', () {
    final w = vocab.byId('beef_stew')!;
    expect(w.label(true), 'beef stew');
    expect(vocab.byId('want')!.label(true), 'ፈልጋለሁ');
  });

  test('SOV reordering unchanged', () {
    expect(amharicSOVOrder(['I', 'want', 'water']), ['I', 'water', 'want']);
    expect(amharicSOVOrder(['more', 'water']), ['water', 'more']);
  });
}
