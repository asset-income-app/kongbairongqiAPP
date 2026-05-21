import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final String message;
  final LogLevel level;
  final String source;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  const LogEntry({
    required this.message,
    required this.level,
    required this.source,
    required this.timestamp,
    this.data,
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        'level': level.name,
        'source': source,
        'timestamp': timestamp.millisecondsSinceEpoch,
        if (data != null) 'data': data,
      };

  String get levelIcon {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
    }
  }
}

class DevLog {
  static final DevLog _instance = DevLog._internal();
  factory DevLog() => _instance;
  DevLog._internal();

  final List<LogEntry> _logs = [];
  static const int maxLogs = 500;
  final List<void Function(LogEntry)> _listeners = [];

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void addListener(void Function(LogEntry) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(LogEntry) listener) {
    _listeners.remove(listener);
  }

  void _add(LogEntry entry) {
    _logs.add(entry);
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
    for (final listener in List.from(_listeners)) {
      try {
        listener(entry);
      } catch (_) {}
    }
  }

  void debug(String message, {String source = 'App', Map<String, dynamic>? data}) {
    _add(LogEntry(
      message: message,
      level: LogLevel.debug,
      source: source,
      timestamp: DateTime.now(),
      data: data,
    ));
    developer.log(message, name: source, level: 500);
  }

  void info(String message, {String source = 'App', Map<String, dynamic>? data}) {
    _add(LogEntry(
      message: message,
      level: LogLevel.info,
      source: source,
      timestamp: DateTime.now(),
      data: data,
    ));
    developer.log(message, name: source, level: 800);
  }

  void warning(String message, {String source = 'App', Map<String, dynamic>? data}) {
    _add(LogEntry(
      message: message,
      level: LogLevel.warning,
      source: source,
      timestamp: DateTime.now(),
      data: data,
    ));
    developer.log(message, name: source, level: 900);
  }

  void error(String message, {String source = 'App', Map<String, dynamic>? data}) {
    _add(LogEntry(
      message: message,
      level: LogLevel.error,
      source: source,
      timestamp: DateTime.now(),
      data: data,
    ));
    developer.log(message, name: source, level: 1000);
  }

  List<LogEntry> filter({LogLevel? level, String? source, String? query}) {
    return _logs.where((log) {
      if (level != null && log.level != level) return false;
      if (source != null && log.source != source) return false;
      if (query != null &&
          !log.message.toLowerCase().contains(query.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  void clear() {
    _logs.clear();
  }

  Map<String, int> get stats {
    final result = <String, int>{};
    for (final level in LogLevel.values) {
      result[level.name] = _logs.where((l) => l.level == level).length;
    }
    return result;
  }
}
