import 'package:flutter/material.dart';

/// A styled card that wraps content with consistent padding and border radius.
class RsCard extends StatelessWidget {
  const RsCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
