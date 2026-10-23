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
