import 'package:flutter_test/flutter_test.dart';
import 'package:blankos/core/plugin_manager.dart';

void main() {
  group('PluginManager', () {
    test('should be a singleton', () {
      final instance1 = PluginManager();
      final instance2 = PluginManager();

      expect(identical(instance1, instance2), true);
    });

    test('plugins should return empty list initially', () {
      final manager = PluginManager();
      expect(manager.plugins, isEmpty);
    });
  });
}
