import 'dart:math';

enum SyncQueueStatus { pending, processing, failed, failedTerminal, completed }

class SyncQueueOperationType {
  static const String createOrder = 'create_order';
  static const String confirmShamCash = 'confirm_sham_cash';
}

class SyncQueueItem {
  final String id;
  final String operationType;
  final String idempotencyKey;
  final String correlationId;
  final String userScope;
  final Map<String, dynamic> payload;
  final SyncQueueStatus status;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? nextRetryAt;
  final String? lastError;

  const SyncQueueItem({
    required this.id,
    required this.operationType,
    required this.idempotencyKey,
    required this.correlationId,
    required this.userScope,
    required this.payload,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    required this.nextRetryAt,
    required this.lastError,
  });

  factory SyncQueueItem.create({
    required String operationType,
    required String idempotencyKey,
    String correlationId = '',
    required String userScope,
    required Map<String, dynamic> payload,
  }) {
    final now = DateTime.now().toUtc();
    return SyncQueueItem(
      id: _randomId(now),
      operationType: operationType,
      idempotencyKey: idempotencyKey,
      correlationId: correlationId,
      userScope: userScope,
      payload: payload,
      status: SyncQueueStatus.pending,
      attemptCount: 0,
      createdAt: now,
      updatedAt: now,
      nextRetryAt: null,
      lastError: null,
    );
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: (json['id'] ?? '').toString(),
      operationType: (json['operation_type'] ?? '').toString(),
      idempotencyKey: (json['idempotency_key'] ?? '').toString(),
      correlationId: (json['correlation_id'] ?? '').toString(),
      userScope: (json['user_scope'] ?? 'guest').toString(),
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : <String, dynamic>{},
      status: _statusFromString((json['status'] ?? 'pending').toString()),
      attemptCount: json['attempt_count'] is int
          ? json['attempt_count'] as int
          : int.tryParse('${json['attempt_count'] ?? '0'}') ?? 0,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      nextRetryAt: DateTime.tryParse((json['next_retry_at'] ?? '').toString()),
      lastError: (json['last_error'] ?? '').toString().trim().isEmpty
          ? null
          : (json['last_error'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'operation_type': operationType,
      'idempotency_key': idempotencyKey,
      'correlation_id': correlationId,
      'user_scope': userScope,
      'payload': payload,
      'status': _statusToString(status),
      'attempt_count': attemptCount,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'next_retry_at': nextRetryAt?.toUtc().toIso8601String(),
      'last_error': lastError,
    };
  }

  bool shouldRun(DateTime nowUtc) {
    if (status == SyncQueueStatus.completed ||
        status == SyncQueueStatus.failedTerminal) {
      return false;
    }
    if (nextRetryAt == null) {
      return true;
    }
    return !nextRetryAt!.isAfter(nowUtc);
  }

  SyncQueueItem markProcessing() {
    return copyWith(
      status: SyncQueueStatus.processing,
      updatedAt: DateTime.now().toUtc(),
      lastError: null,
      nextRetryAt: null,
    );
  }

  SyncQueueItem markCompleted() {
    return copyWith(
      status: SyncQueueStatus.completed,
      updatedAt: DateTime.now().toUtc(),
      lastError: null,
      nextRetryAt: null,
    );
  }

  SyncQueueItem markFailed(String error, {bool terminal = false}) {
    final now = DateTime.now().toUtc();
    if (terminal) {
      return copyWith(
        status: SyncQueueStatus.failedTerminal,
        attemptCount: attemptCount + 1,
        updatedAt: now,
        nextRetryAt: null,
        lastError: error,
      );
    }
    final attempts = attemptCount + 1;
    final nextRetry = now.add(backoffForAttempt(attempts));
    return copyWith(
      status: SyncQueueStatus.failed,
      attemptCount: attempts,
      updatedAt: now,
      nextRetryAt: nextRetry,
      lastError: error,
    );
  }

  SyncQueueItem markPendingRetry({bool resetAttempts = false}) {
    return copyWith(
      status: SyncQueueStatus.pending,
      attemptCount: resetAttempts ? 0 : attemptCount,
      updatedAt: DateTime.now().toUtc(),
      clearNextRetryAt: true,
      clearLastError: true,
    );
  }

  SyncQueueItem copyWith({
    String? id,
    String? operationType,
    String? idempotencyKey,
    String? correlationId,
    String? userScope,
    Map<String, dynamic>? payload,
    SyncQueueStatus? status,
    int? attemptCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? nextRetryAt,
    bool clearNextRetryAt = false,
    String? lastError,
    bool clearLastError = false,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      operationType: operationType ?? this.operationType,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      correlationId: correlationId ?? this.correlationId,
      userScope: userScope ?? this.userScope,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nextRetryAt: clearNextRetryAt ? null : (nextRetryAt ?? this.nextRetryAt),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  static Duration backoffForAttempt(int attempt) {
    final boundedAttempt = attempt < 1 ? 1 : attempt;
    final seconds = min(300, 5 * pow(2, boundedAttempt - 1).toInt());
    return Duration(seconds: seconds);
  }

  static SyncQueueStatus _statusFromString(String value) {
    switch (value) {
      case 'processing':
        return SyncQueueStatus.processing;
      case 'failed':
        return SyncQueueStatus.failed;
      case 'failed_terminal':
      case 'failedTerminal':
        return SyncQueueStatus.failedTerminal;
      case 'completed':
        return SyncQueueStatus.completed;
      case 'pending':
      default:
        return SyncQueueStatus.pending;
    }
  }

  static String _statusToString(SyncQueueStatus status) {
    switch (status) {
      case SyncQueueStatus.pending:
        return 'pending';
      case SyncQueueStatus.processing:
        return 'processing';
      case SyncQueueStatus.failed:
        return 'failed';
      case SyncQueueStatus.failedTerminal:
        return 'failed_terminal';
      case SyncQueueStatus.completed:
        return 'completed';
    }
  }

  static String _randomId(DateTime now) {
    Random random;
    try {
      random = Random.secure();
    } catch (_) {
      random = Random();
    }
    final suffix = List<int>.generate(
      8,
      (_) => random.nextInt(16),
    ).map((i) => i.toRadixString(16)).join();
    return 'sq_${now.microsecondsSinceEpoch}_$suffix';
  }
}
