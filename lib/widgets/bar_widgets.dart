import 'package:flutter/material.dart';

import '../models/word.dart';

class TopBarButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const TopBarButton({
    super.key,
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

class WordChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const WordChip({super.key, required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.close, color: Colors.white70, size: 15),
          ],
        ),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const ActionButton({
    super.key,
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
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PageTabs extends StatelessWidget {
  final List<VocabPage> pages;
  final int selected;
  final bool isAmharic;
  final ValueChanged<int> onSelect;

  const PageTabs({
    super.key,
    required this.pages,
    required this.selected,
    required this.isAmharic,
    required this.onSelect,
  });

  static const _icons = <String, IconData>{
    'core': Icons.grid_view,
    'body': Icons.accessibility_new,
    'clothes': Icons.checkroom,
    'food': Icons.restaurant,
    'feelings': Icons.emoji_emotions,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            for (var i = 0; i < pages.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _tab(i)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final active = i == selected;
    final fg = active ? Colors.white : const Color(0xFF1565C0);
    return GestureDetector(
      onTap: () => onSelect(i),
      child: Container(
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1565C0), width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icons[pages[i].id] ?? Icons.grid_view, color: fg, size: 24),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                pages[i].label(isAmharic),
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
