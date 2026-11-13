import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trackflow/AuthFile/authWrapper.dart';

import 'package:trackflow/app_file/theme_file/app_theme.dart';

import 'Statemanage_riverpod/provider/theme_provider.dart';
import 'Statemanage_riverpod/provider/task_provider.dart';

class TrackFlow extends ConsumerStatefulWidget {
  const TrackFlow({super.key});

  @override
  ConsumerState<TrackFlow> createState() => _TrackFlowState();
}

class _TrackFlowState extends ConsumerState<TrackFlow>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncNotifications();
    }
  }

  Future<void> _syncNotifications() async {
    try {
      await ref
          .read(taskProvider.notifier)
          .syncDueInAppNotifications();
    } catch (error) {
      debugPrint('App resume notification sync error: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'TrackFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const AuthWrapper(),
    );
  }
}