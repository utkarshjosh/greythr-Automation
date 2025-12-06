enum LogStatus {
  pending,
  done,
  skip,
  error,
  unknown;

  static LogStatus fromString(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return LogStatus.pending;
      case 'DONE':
        return LogStatus.done;
      case 'SKIP':
        return LogStatus.skip;
      case 'ERROR':
        return LogStatus.error;
      default:
        return LogStatus.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case LogStatus.pending:
        return 'Pending';
      case LogStatus.done:
        return 'Done';
      case LogStatus.skip:
        return 'Skipped';
      case LogStatus.error:
        return 'Error';
      case LogStatus.unknown:
        return 'Unknown';
    }
  }
}

class DailyLog {
  final String date; // YYYY-MM-DD format
  final LogStatus status;
  final String? timestamp;
  final String? empId;
  final String? swipeTime;
  final String? message; // Optional message (e.g., for pending logs before initial date)
  final String? workLocation;

  DailyLog({
    required this.date,
    required this.status,
    this.timestamp,
    this.empId,
    this.swipeTime,
    this.message,
    this.workLocation,
  });

  factory DailyLog.fromMap(String date, Map<String, dynamic>? map) {
    if (map == null) {
      return DailyLog(
        date: date,
        status: LogStatus.pending,
      );
    }

    final status = LogStatus.fromString(map['status']);
    // Default to pending if status is unknown or missing
    final finalStatus = status == LogStatus.unknown 
        ? LogStatus.pending 
        : status;

    return DailyLog(
      date: date,
      status: finalStatus,
      timestamp: map['timestamp'],
      empId: map['empId'],
      swipeTime: map['swipeTime'],
      message: map['message'],
      workLocation: map['workLocation'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.name.toUpperCase(),
      'timestamp': timestamp,
      'empId': empId,
      'swipeTime': swipeTime,
      if (message != null) 'message': message,
      if (workLocation != null) 'workLocation': workLocation,
    };
  }

  DailyLog copyWith({
    String? date,
    LogStatus? status,
    String? timestamp,
    String? empId,
    String? swipeTime,
    String? message,
    String? workLocation,
  }) {
    return DailyLog(
      date: date ?? this.date,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      empId: empId ?? this.empId,
      swipeTime: swipeTime ?? this.swipeTime,
      message: message ?? this.message,
      workLocation: workLocation ?? this.workLocation,
    );
  }
}

