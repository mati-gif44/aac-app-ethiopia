import 'dart:convert';

import 'package:flutter/services.dart';

// Fitzgerald Key palette
const fitzgeraldColors = <String, Color>{
  'green': Color(0xFF4CAF50), // verbs
  'yellow': Color(0xFFFFD600), // pronouns
  'orange': Color(0xFFFF9800), // nouns / people / places
  'blue': Color(0xFF2196F3), // descriptive
  'red': Color(0xFFF44336), // negatives / quantity
  'pink': Color(0xFFE91E63), // social
};

class Word {
  final String id;
  final String english;
  final String amharic;
  final String category;
  final Color color;
  final String image;
  final String audio;
  final String page;
  final int position;
  final int level;
  final bool hasImage;
  final bool hasAudio;

  const Word({
    required this.id,
    required this.english,
    required this.amharic,
    required this.category,
    required this.color,
    required this.image,
    required this.audio,
    required this.page,
    required this.position,
    required this.level,
    required this.hasImage,
    required this.hasAudio,
  });

  factory Word.fromJson(Map<String, dynamic> json, Set<String> assets) {
    final image = json['image'] as String;
    final audio = json['audio'] as String;
    return Word(
      id: json['id'] as String,
      english: json['en'] as String,
      amharic: json['am'] as String? ?? '',
      category: json['category'] as String,
      color: fitzgeraldColors[json['color']] ?? fitzgeraldColors['orange']!,
      image: image,
      audio: audio,
      page: json['page'] as String,
      position: json['position'] as int,
      level: json['level'] as int? ?? 0,
      hasImage: assets.contains(image),
      hasAudio: assets.contains(audio),
    );
  }

  String label(bool isAmharic) =>
      isAmharic && amharic.isNotEmpty ? amharic : english;
}

class VocabPage {
  final String id;
  final String english;
  final String amharic;

  const VocabPage({
    required this.id,
    required this.english,
    required this.amharic,
  });

  factory VocabPage.fromJson(Map<String, dynamic> json) => VocabPage(
        id: json['id'] as String,
        english: json['en'] as String,
        amharic: json['am'] as String? ?? '',
      );

  String label(bool isAmharic) =>
      isAmharic && amharic.isNotEmpty ? amharic : english;
}

class Vocabulary {
  final List<VocabPage> pages;
  final List<Word> words;
  final Map<String, Word> _byId;
  final Map<String, Word> _bySlot;

  Vocabulary(this.pages, this.words)
      : _byId = {for (final w in words) w.id: w},
        _bySlot = {for (final w in words) '${w.page}#${w.position}': w};

  Word? byId(String id) => _byId[id];

  Word? wordAt(String page, int position) => _bySlot['$page#$position'];

  static Future<Vocabulary> load(AssetBundle bundle) async {
    final raw = await bundle.loadString('assets/data/words.json');
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final assets = {
      for (final a in manifest.listAssets()) ...[a, Uri.decodeFull(a)],
    };
    return parse(raw, assets);
  }

  static Vocabulary parse(String raw, Set<String> assets) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final pages = [
      for (final p in json['pages'] as List)
        VocabPage.fromJson(p as Map<String, dynamic>),
    ];
    final words = [
      for (final w in json['words'] as List)
        Word.fromJson(w as Map<String, dynamic>, assets),
    ];
    return Vocabulary(pages, words);
  }
}
