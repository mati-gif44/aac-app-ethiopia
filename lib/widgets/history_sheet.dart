import 'package:flutter/material.dart';

class HistorySheet extends StatelessWidget {
  final List<List<String>> history;
  final bool isAmharic;
  final String Function(String) labelFor;
  final void Function(List<String>) onSelect;

  const HistorySheet({
    super.key,
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
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: history.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final display =
                    history[i].map((k) => labelFor(k)).join('  ');
                return ListTile(
                  leading: const Icon(Icons.chat_bubble_outline,
                      color: Color(0xFF1565C0)),
                  title: Text(display,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  onTap: () => onSelect(history[i]),
                );
              },
            ),
          ),
        SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 8),
      ],
    );
  }
}
