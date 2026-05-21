import 'dart:developer' as developer;

typedef EventCallback = void Function(Map<String, dynamic> data);

class _OwnedCallback {
  final String ownerId;
  final EventCallback callback;

  const _OwnedCallback(this.ownerId, this.callback);

  void call(Map<String, dynamic> data) => callback(data);
}

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final Map<String, List<dynamic>> _listeners = {};
  final List<Map<String, dynamic>> _history = [];
  static const int maxHistory = 100;

  void on(String event, EventCallback callback) {
    _listeners.putIfAbsent(event, () => []);
    _listeners[event]!.add(callback);
  }

  void off(String event, EventCallback callback) {
    _listeners[event]?.remove(callback);
    if (_listeners[event]?.isEmpty ?? false) {
      _listeners.remove(event);
    }
  }

  void emit(String event, Map<String, dynamic> data) {
    _history.add({
      'event': event,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    if (_history.length > maxHistory) {
      _history.removeAt(0);
    }
    final listeners = _listeners[event];
    if (listeners != null) {
      for (final callback in List.from(listeners)) {
        try {
          if (callback is _OwnedCallback) {
            callback(data);
          } else if (callback is EventCallback) {
            callback(data);
          }
        } catch (e) {
          developer.log(
            'Event callback error: $event',
            name: 'EventBus',
            error: e,
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> getHistory({String? event, int? limit}) {
    var history = _history;
    if (event != null) {
      history = history.where((h) => h['event'] == event).toList();
    }
    if (limit != null && history.length > limit) {
      history = history.sublist(history.length - limit);
    }
    return List.unmodifiable(history);
  }

  void clearHistory() {
    _history.clear();
  }

  void removeAllListeners() {
    _listeners.clear();
  }

  void removeListenersForOwner(String ownerId) {
    _listeners.removeWhere((key, callbacks) {
      callbacks.removeWhere((cb) {
        if (cb is _OwnedCallback) {
          return cb.ownerId == ownerId;
        }
        return false;
      });
      return callbacks.isEmpty;
    });
  }

  void onOwned(String event, String ownerId, EventCallback callback) {
    final ownedCallback = _OwnedCallback(ownerId, callback);
    _listeners.putIfAbsent(event, () => []);
    _listeners[event]!.add(ownedCallback);
  }
}
