import 'package:flutter/material.dart';

import '../../data/sections.dart' as data;

/// Mode 5 — Performance. Black screen, single keyword, swipe to advance.
///
/// This is what you'd glance at on stage. No scaffolding, no safety net.
/// The technology gets out of the way so the human can show up.
class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        itemCount: data.sections.length,
        itemBuilder: (context, index) {
          final section = data.sections[index];
          return SafeArea(
            child: Column(
              children: [
                // Minimal slide ref
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    section.slideRef,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const Spacer(),
                // The keyword — the only thing on screen
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    section.keyword,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w200,
                      letterSpacing: 3,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(),
                // Section dots
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(data.sections.length, (i) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: i == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == index
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
