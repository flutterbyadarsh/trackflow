import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_file/theme_file/theme_mode_provider.dart';

class ThemeDemoScreen extends ConsumerWidget {
  const ThemeDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider); // var theme mode
    final textTheme = Theme.of(context).textTheme; // var text theme
    return Scaffold(
      appBar: AppBar(title: const Text('TrackFlow Design System')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Plan Better. Do More.', style: textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text('One consistent system for Light and Dark themes.', style: textTheme.bodyMedium),
          const SizedBox(height: 24),
          Text('Choose appearance', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.phone_android)),
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
            ],
            selected: {themeMode},
            // riverpod provider
            onSelectionChanged: (selection) => ref.read(themeModeProvider.notifier).setThemeMode(selection.first),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Example task card', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Revise Flutter state management', style: textTheme.bodyLarge),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text('Study • Medium priority', style: textTheme.bodySmall),
                ]),
                const SizedBox(height: 16),
                const LinearProgressIndicator(value: 0.6),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Add task (demo)')),
        ],
      ),
    );
  }
}

/*
import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_spacing.dart';

Container(
  padding: const EdgeInsets.all(AppSpacing.lg),
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(
      AppSpacing.radiusLg,
    ),
  ),
  child: Text(
    'Today’s Tasks',
    style: Theme.of(context).textTheme.titleLarge,
  ),
)
 */
