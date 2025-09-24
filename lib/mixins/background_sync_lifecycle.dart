import 'package:flutter/material.dart';
import '../services/background_sync_service.dart';

/// Mixin to handle app lifecycle changes for background sync optimization
mixin BackgroundSyncLifecycle<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App is active - use faster sync interval
        BackgroundSyncService.setAppActiveState(true);
        // Trigger immediate sync when app becomes active
        BackgroundSyncService.triggerSync();
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App is backgrounded - use slower sync interval
        BackgroundSyncService.setAppActiveState(false);
        break;

      case AppLifecycleState.detached:
        // App is being terminated - stop sync service
        BackgroundSyncService.stop();
        break;

      case AppLifecycleState.hidden:
        // App is hidden but still running - use slower sync
        BackgroundSyncService.setAppActiveState(false);
        break;
    }
  }
}
