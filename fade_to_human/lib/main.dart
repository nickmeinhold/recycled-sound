import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'modes/bones/bones_screen.dart';
import 'modes/karaoke/karaoke_screen.dart';
import 'modes/performance/performance_screen.dart';
import 'modes/swiss_cheese/swiss_cheese_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const FadeToHumanApp());
}

class FadeToHumanApp extends StatelessWidget {
  const FadeToHumanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fade to Human',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const ModeSelectorScreen(),
    );
  }
}

/// Home screen — pick your practice mode.
///
/// Modes are ordered as a journey: full support → no support.
/// The app literally teaches you to not need it.
class ModeSelectorScreen extends StatelessWidget {
  const ModeSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Title
              const Text(
                'FADE TO HUMAN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The technology gets out of the way\nso you can show up for people.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Mode cards
              Expanded(
                child: ListView(
                  children: [
                    _ModeCard(
                      title: 'KARAOKE',
                      subtitle: 'Full text, word by word',
                      description: 'Words illuminate at speaking pace. '
                          'Build the muscle memory.',
                      icon: Icons.music_note,
                      color: const Color(0xFF004D40),
                      onTap: () => _push(context, const KaraokeScreen()),
                    ),
                    _ModeCard(
                      title: 'SWISS CHEESE',
                      subtitle: 'Progressive erasure',
                      description: 'Each pass erases more words. '
                          'Tap gaps to peek. Fill the holes from memory.',
                      icon: Icons.auto_fix_high,
                      color: const Color(0xFF1A237E),
                      onTap: () => _push(context, const SwissCheeseScreen()),
                    ),
                    _ModeCard(
                      title: 'BONES',
                      subtitle: 'Emoji + keyword',
                      description: 'The absolute minimum. '
                          'Reconstruct everything from anchors.',
                      icon: Icons.emoji_emotions_outlined,
                      color: const Color(0xFF4A148C),
                      onTap: () => _push(context, const BonesScreen()),
                    ),
                    _ModeCard(
                      title: 'PERFORMANCE',
                      subtitle: 'Black screen, one word',
                      description: 'You either know it or you don\'t. '
                          'The app disappears. You remain.',
                      icon: Icons.visibility_off,
                      color: const Color(0xFFBF360C),
                      onTap: () => _push(context, const PerformanceScreen()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 36),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
