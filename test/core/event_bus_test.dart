import 'package:flutter_test/flutter_test.dart';
import 'package:blankos/core/event_bus.dart';

void main() {
  group('EventBus', () {
    late EventBus eventBus;

    setUp(() {
      eventBus = EventBus();
      eventBus.removeAllListeners();
      eventBus.clearHistory();
    });

    test('emit should trigger registered callbacks', () {
      var received = <Map<String, dynamic>>[];
      eventBus.on('test', (data) => received.add(data));

      eventBus.emit('test', {'value': 1});
      eventBus.emit('test', {'value': 2});

      expect(received.length, 2);
      expect(received[0]['value'], 1);
      expect(received[1]['value'], 2);
    });

    test('off should remove callback', () {
      var count = 0;
      void callback(Map<String, dynamic> data) => count++;

      eventBus.on('test', callback);
      eventBus.emit('test', {});
      expect(count, 1);

      eventBus.off('test', callback);
      eventBus.emit('test', {});
      expect(count, 1);
    });

    test('emit should not trigger callbacks for different events', () {
      var count = 0;
      eventBus.on('event_a', (data) => count++);

      eventBus.emit('event_b', {});
      expect(count, 0);

      eventBus.emit('event_a', {});
      expect(count, 1);
    });

    test('getHistory should return emitted events', () {
      eventBus.emit('test', {'a': 1});
      eventBus.emit('test', {'b': 2});
      eventBus.emit('other', {'c': 3});

      final allHistory = eventBus.getHistory();
      expect(allHistory.length, 3);

      final filteredHistory = eventBus.getHistory(event: 'test');
      expect(filteredHistory.length, 2);

      final limitedHistory = eventBus.getHistory(limit: 1);
      expect(limitedHistory.length, 1);
      expect(limitedHistory[0]['data']['c'], 3);
    });

    test('onOwned should register owned callbacks', () {
      var count = 0;
      eventBus.onOwned('test', 'owner1', (data) => count++);

      eventBus.emit('test', {});
      expect(count, 1);
    });

    test('removeListenersForOwner should remove owned callbacks', () {
      var count = 0;
      eventBus.onOwned('test', 'owner1', (data) => count++);

      eventBus.emit('test', {});
      expect(count, 1);

      eventBus.removeListenersForOwner('owner1');
      eventBus.emit('test', {});
      expect(count, 1);
    });

    test('callback error should not crash other callbacks', () {
      var count = 0;
      eventBus.on('test', (data) => throw Exception('test error'));
      eventBus.on('test', (data) => count++);

      eventBus.emit('test', {});
      expect(count, 1);
    });

    test('history should be limited to maxHistory', () {
      for (var i = 0; i < 150; i++) {
        eventBus.emit('test', {'i': i});
      }
      final history = eventBus.getHistory();
      expect(history.length, 100);
    });
  });
}
