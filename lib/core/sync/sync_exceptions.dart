class SyncRetryableException implements Exception {
  final String message;

  const SyncRetryableException(this.message);

  @override
  String toString() => 'SyncRetryableException: $message';
}

class SyncTerminalException implements Exception {
  final String message;
  final String code;

  const SyncTerminalException(
    this.message, {
    this.code = 'terminal_sync_error',
  });

  @override
  String toString() => 'SyncTerminalException($code): $message';
}

class SyncConflictException extends SyncTerminalException {
  final List<Map<String, dynamic>> conflicts;

  const SyncConflictException(
    super.message, {
    this.conflicts = const <Map<String, dynamic>>[],
  }) : super(code: 'stale_conflict');
}
