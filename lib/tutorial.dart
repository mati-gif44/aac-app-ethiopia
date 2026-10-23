import 'package:flutter/material.dart';

class _TutorialPageData {
  final IconData icon;
  final String title;
  final List<String> steps;
  const _TutorialPageData({
    required this.icon,
    required this.title,
    required this.steps,
  });
}

const _tutorialPages = [
  _TutorialPageData(
    icon: Icons.touch_app,
    title: 'Building a Sentence',
    steps: [
      'Tap symbols to add words to the sentence bar',
      'Tap the sentence bar to speak it aloud',
      'Tap backspace to remove the last word',
    ],
  ),
  _TutorialPageData(
    icon: Icons.translate,
    title: 'Switching Languages',
    steps: [
      'Tap the EN / አማ toggle to switch between English and Amharic',
    ],
  ),
  _TutorialPageData(
    icon: Icons.tab,
    title: 'Word Pages',
    steps: [
      'Tap the tabs at the bottom to switch between word pages',
      'Core has the main words; Body, Clothes, Food and Feelings have more',
      'Your sentence stays when you switch pages',
    ],
  ),
  _TutorialPageData(
    icon: Icons.lock_outline,
    title: 'Caregiver Settings',
    steps: [
      'Tap the settings icon',
      'Enter the PIN (default 1234) to access level settings and change the PIN',
      'Level 1 shows basic words, Level 3 shows all 24 Core words',
    ],
  ),
];

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _tutorialPages.length - 1) {
      Navigator.pop(context);
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _tutorialPages.length - 1;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: isLast
                  ? null
                  : Align(
                      alignment: Alignment.topRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Skip'),
                      ),
                    ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _tutorialPages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _TutorialPage(data: _tutorialPages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _tutorialPages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? const Color(0xFF1565C0)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _next,
                  child: Text(
                    isLast ? 'Done' : 'Next',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
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

class _TutorialPage extends StatelessWidget {
  final _TutorialPageData data;
  const _TutorialPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 48, color: const Color(0xFF1565C0)),
          ),
          const SizedBox(height: 32),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          ...data.steps.map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, size: 6, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                          fontSize: 16, color: Colors.black87, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
