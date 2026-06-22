\# AAC App — Ethiopia (Project Brief for Claude Code)



\## What this is

An offline AAC (Augmentative and Alternative Communication) Flutter app for kids 

with autism in Ethiopia. Bilingual: English + Amharic.



\## Tech stack

\- Flutter/Dart

\- flutter\_tts → English TTS (Android system, offline)

\- audioplayers → Amharic playback (bundled .mp3 files, offline)

\- ARASAAC symbols (PNG files in assets/images/)



\## Asset structure

\- assets/images/{word}.png → symbol for each word (e.g. want.png)

\- assets/audio/am/{word}.mp3 → Amharic audio (e.g. want.mp3)



\## The 24 words (fixed positions, never reshuffle)

Level 1 (8): want, no, yes, help, eat, drink, more, stop

Level 2 (16): + I, you, go, finished, water, happy, sad, toilet

Level 3 (24): + play, sleep, pain, mom, dad, teacher, hot, cold



\## Level system

\- Option A: caregiver manually sets level 1/2/3

\- Grid is always 24 slots; hidden words show as greyed-out blank buttons

\- Positions NEVER change between levels



\## Core screens (MVP only)

1\. Home screen — 24-slot fixed grid of AAC buttons (image + text label)

2\. Sentence bar at top — tapped words accumulate here

3\. Tap sentence bar → speaks full sentence

4\. Backspace + Clear buttons

5\. Language toggle (EN / አማ)

6\. Level selector (caregiver sets 1, 2, or 3)



\## AAC design rules (non-negotiable)

\- Fixed button positions always — never reshuffle

\- Every button: ARASAAC image on top + text label below

\- Large buttons, high contrast

\- Works 100% offline



\## What we are NOT building in MVP

\- Custom vocabulary editing

\- User profiles

\- Cloud sync

\- Camera/photos

\- Search

\- Settings screen

\- Automatic level progression (that's Phase 2)



\## Device

Samsung S25, device ID: RFCY106KX4H

Run with: flutter run -d RFCY106KX4H

