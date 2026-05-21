import 'package:flutter_test/flutter_test.dart';
import 'package:blankos/models/plugin_manifest.dart';

void main() {
  group('PluginManifest', () {
    test('fromJson should parse valid JSON correctly', () {
      final json = {
        'id': 'com.test.plugin',
        'name': 'Test Plugin',
        'description': 'A test plugin',
        'version': '1.0.0',
        'entry': 'index.html',
        'icon': 'icon.png',
        'permissions': ['camera', 'storage'],
        'author': 'Test Author',
        'price': 9.99,
        'payment_address': '0x123abc',
        'min_sdk_version': 1,
        'dependencies': [
          {'id': 'com.test.dep', 'min_version': '1.0.0'}
        ],
        'provides': ['image-capture'],
        'tags': ['工具', '相机'],
      };

      final manifest = PluginManifest.fromJson(json);

      expect(manifest.id, 'com.test.plugin');
      expect(manifest.name, 'Test Plugin');
      expect(manifest.description, 'A test plugin');
      expect(manifest.version, '1.0.0');
      expect(manifest.entry, 'index.html');
      expect(manifest.icon, 'icon.png');
      expect(manifest.permissions.length, 2);
      expect(manifest.permissions[0], PluginPermission.camera);
      expect(manifest.permissions[1], PluginPermission.storage);
      expect(manifest.author, 'Test Author');
      expect(manifest.price, 9.99);
      expect(manifest.paymentAddress, '0x123abc');
      expect(manifest.minSdkVersion, 1);
      expect(manifest.dependencies.length, 1);
      expect(manifest.dependencies[0].id, 'com.test.dep');
      expect(manifest.dependencies[0].minVersion, '1.0.0');
      expect(manifest.provides, ['image-capture']);
      expect(manifest.tags, ['工具', '相机']);
    });

    test('fromJson should handle missing optional fields', () {
      final json = {
        'id': 'com.test.plugin',
        'name': 'Test Plugin',
        'version': '1.0.0',
        'entry': 'index.html',
        'author': 'Test Author',
      };

      final manifest = PluginManifest.fromJson(json);

      expect(manifest.description, '');
      expect(manifest.icon, '');
      expect(manifest.permissions, []);
      expect(manifest.price, 0.0);
      expect(manifest.paymentAddress, isNull);
      expect(manifest.minSdkVersion, 1);
      expect(manifest.dependencies, []);
      expect(manifest.provides, []);
      expect(manifest.tags, []);
    });

    test('fromJson should handle null values gracefully', () {
      final json = <String, dynamic>{};

      final manifest = PluginManifest.fromJson(json);

      expect(manifest.id, '');
      expect(manifest.name, 'Unknown');
      expect(manifest.version, '1.0.0');
      expect(manifest.entry, 'index.html');
      expect(manifest.author, 'Unknown');
    });

    test('toJson should serialize correctly', () {
      final manifest = PluginManifest(
        id: 'com.test.plugin',
        name: 'Test Plugin',
        description: 'A test plugin',
        version: '1.0.0',
        entry: 'index.html',
        icon: 'icon.png',
        permissions: [PluginPermission.camera],
        author: 'Test Author',
        price: 9.99,
        paymentAddress: '0x123abc',
        dependencies: [CapabilityDependency(id: 'com.test.dep', minVersion: '1.0.0')],
        provides: ['image-capture'],
        tags: ['工具'],
      );

      final json = manifest.toJson();

      expect(json['id'], 'com.test.plugin');
      expect(json['name'], 'Test Plugin');
      expect(json['description'], 'A test plugin');
      expect(json['version'], '1.0.0');
      expect(json['permissions'], ['camera']);
      expect(json['author'], 'Test Author');
      expect(json['price'], 9.99);
      expect(json['payment_address'], '0x123abc');
      expect(json['min_sdk_version'], 1);
      expect(json['dependencies'].length, 1);
      expect(json['dependencies'][0]['id'], 'com.test.dep');
      expect(json['provides'], ['image-capture']);
      expect(json['tags'], ['工具']);
    });

    test('isValid should validate required fields', () {
      final valid = PluginManifest(
        id: 'com.test.plugin',
        name: 'Test',
        version: '1.0.0',
        author: 'Author',
      );
      expect(valid.isValid, true);

      final invalidId = PluginManifest(
        id: '',
        name: 'Test',
        version: '1.0.0',
        author: 'Author',
      );
      expect(invalidId.isValid, false);

      final invalidName = PluginManifest(
        id: 'com.test',
        name: '',
        version: '1.0.0',
        author: 'Author',
      );
      expect(invalidName.isValid, false);
    });

    test('isFree should check price', () {
      final free = PluginManifest(
        id: 'com.test',
        name: 'Free',
        version: '1.0.0',
        author: 'Author',
        price: 0.0,
      );
      expect(free.isFree, true);

      final paid = PluginManifest(
        id: 'com.test',
        name: 'Paid',
        version: '1.0.0',
        author: 'Author',
        price: 9.99,
      );
      expect(paid.isFree, false);
    });

    test('hasPermission should check permissions', () {
      final manifest = PluginManifest(
        id: 'com.test',
        name: 'Test',
        version: '1.0.0',
        author: 'Author',
        permissions: [PluginPermission.camera, PluginPermission.storage, PluginPermission.events],
      );

      expect(manifest.hasPermission(PluginPermission.camera), true);
      expect(manifest.hasPermission(PluginPermission.vibration), false);
      expect(manifest.hasPermission(PluginPermission.events), true);
    });

    test('isCompatible should check SDK version', () {
      final compatible = PluginManifest(
        id: 'com.test',
        name: 'Test',
        version: '1.0.0',
        author: 'Author',
        minSdkVersion: 1,
      );
      expect(compatible.isCompatible, true);

      final incompatible = PluginManifest(
        id: 'com.test',
        name: 'Test',
        version: '1.0.0',
        author: 'Author',
        minSdkVersion: 99,
      );
      expect(incompatible.isCompatible, false);
    });

    test('hasDependencies and hasEvents should work correctly', () {
      final withDeps = PluginManifest(
        id: 'com.test',
        name: 'Test',
        version: '1.0.0',
        author: 'Author',
        dependencies: [CapabilityDependency(id: 'com.test.dep')],
        permissions: [PluginPermission.events],
      );
      expect(withDeps.hasDependencies, true);
      expect(withDeps.hasEvents, true);

      final noDeps = PluginManifest(
        id: 'com.test',
        name: 'Test',
        version: '1.0.0',
        author: 'Author',
      );
      expect(noDeps.hasDependencies, false);
      expect(noDeps.hasEvents, false);
    });

    test('PluginPermission.fromString should parse correctly', () {
      expect(PluginPermission.fromString('camera'), PluginPermission.camera);
      expect(PluginPermission.fromString('events'), PluginPermission.events);
      expect(PluginPermission.fromString('invalid'), isNull);
    });

    test('CapabilityDependency should serialize and deserialize', () {
      final dep = CapabilityDependency(id: 'com.test.dep', minVersion: '2.0.0');
      final json = dep.toJson();
      expect(json['id'], 'com.test.dep');
      expect(json['min_version'], '2.0.0');

      final fromJson = CapabilityDependency.fromJson(json);
      expect(fromJson.id, 'com.test.dep');
      expect(fromJson.minVersion, '2.0.0');
    });
  });
}
