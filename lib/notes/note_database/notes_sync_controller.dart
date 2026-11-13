import 'dart:async';

class NotesSyncController {
  NotesSyncController._();

  static final NotesSyncController instance =
  NotesSyncController._();

  bool _isPaused = false;
  int _activeOperations = 0;

  Completer<void>? _operationsFinished;

  bool get isPaused => _isPaused;

  Future<bool> runOperation(
      Future<void> Function() operation,
      ) async {
    if (_isPaused) return false;

    _activeOperations++;
    _operationsFinished ??= Completer<void>();

    try {
      if (_isPaused) return false;

      await operation();
      return true;
    } finally {
      _activeOperations--;

      if (_activeOperations == 0) {
        if (!(_operationsFinished?.isCompleted ?? true)) {
          _operationsFinished!.complete();
        }

        _operationsFinished = null;
      }
    }
  }

  Future<void> runSync(
      Future<void> Function() operation,
      ) async {
    await runOperation(operation);
  }

  Future<void> pauseAndWait() async {
    _isPaused = true;

    final activeOperations = _operationsFinished?.future;

    if (activeOperations != null) {
      await activeOperations;
    }
  }

  void resume() {
    _isPaused = false;
  }
}