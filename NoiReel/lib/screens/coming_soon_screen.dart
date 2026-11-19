import 'package:flutter/material.dart';

import '../widgets/fade_slide_in.dart';

/// Placeholder for a tab that isn't built yet
class ComingSoonScreen extends StatelessWidget {
  /// Creates a placeholder for the [title] tab
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
  });

  final String title;        // Tab name, e.g. "Search"
  final IconData icon;       // The tab's icon
  final String description;  // What the tab will do

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('NOIREEL')),
      body: Center(
        child: FadeSlideIn(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: text.bodyMedium?.color),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(description, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text('Coming soon', style: text.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
