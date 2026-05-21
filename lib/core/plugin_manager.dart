import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import '../models/plugin_manifest.dart';
import 'dev_log.dart';
import 'signature_verifier.dart';

class PluginManager {
  static final PluginManager _instance = PluginManager._internal();
  factory PluginManager() => _instance;
  PluginManager._internal();

  static const int maxZipSize = 50 * 1024 * 1024;
  static const int maxDecompressionRatio = 10;

  final List<PluginManifest> _plugins = [];
  String? _lastError;

  List<PluginManifest> get plugins => List.unmodifiable(_plugins);
  String? get lastError => _lastError;

  Future<Directory> get _pluginsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final pluginsDir = Directory('${appDir.path}/plugins');
    if (!await pluginsDir.exists()) {
      await pluginsDir.create(recursive: true);
    }
    return pluginsDir;
  }

  PluginManifest? getPluginById(String id) {
    for (final p in _plugins) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<PluginManifest> getPluginsByTag(String tag) {
    return _plugins.where((p) => p.tags.contains(tag)).toList();
  }

  List<PluginManifest> getPluginsProviding(String capability) {
    return _plugins.where((p) => p.provides.contains(capability)).toList();
  }

  List<String> get allTags {
    final tags = <String>{};
    for (final p in _plugins) {
      tags.addAll(p.tags);
    }
    return tags.toList()..sort();
  }

  List<PluginManifest> searchPlugins(String query) {
    final q = query.toLowerCase();
    return _plugins.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.author.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q) ||
          p.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  List<String> resolveDependencies(PluginManifest manifest) {
    final missing = <String>[];
    for (final dep in manifest.dependencies) {
      final installed = getPluginById(dep.id);
      if (installed == null) {
        missing.add(dep.id);
        continue;
      }
      if (dep.minVersion != null) {
        final installedVersion = _parseVersion(installed.version);
        final requiredVersion = _parseVersion(dep.minVersion!);
        if (installedVersion < requiredVersion) {
          missing.add('${dep.id} (需要 v${dep.minVersion}，已安装 v${installed.version})');
        }
      }
    }
    return missing;
  }

  List<String> getDependents(String pluginId) {
    final dependents = <String>[];
    for (final p in _plugins) {
      if (p.dependencies.any((d) => d.id == pluginId)) {
        dependents.add(p.id);
      }
    }
    return dependents;
  }

  int _parseVersion(String version) {
    final parts = version.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    var result = 0;
    for (var i = 0; i < parts.length && i < 3; i++) {
      result = result * 1000 + parts[i];
    }
    return result;
  }

  Future<void> scanPlugins() async {
    _plugins.clear();
    _lastError = null;
    try {
      final pluginsDir = await _pluginsDir;
      final entities = await pluginsDir.list().toList();

      for (final entity in entities) {
        if (entity is Directory) {
          final manifestFile = File('${entity.path}/manifest.json');
          if (await manifestFile.exists()) {
            try {
              final content = await manifestFile.readAsString();
              final json = jsonDecode(content) as Map<String, dynamic>;
              final manifest = PluginManifest.fromJson(json);
              if (manifest.isValid && manifest.isCompatible) {
                _plugins.add(manifest);
              } else {
                DevLog().warning('能力体无效或不兼容: ${entity.path}', source: 'PluginManager');
              }
            } catch (e) {
              DevLog().error('解析能力体清单失败: ${entity.path}', source: 'PluginManager');
            }
          }
        }
      }
      DevLog().info('扫描完成，共发现 ${_plugins.length} 个能力体', source: 'PluginManager');
    } catch (e) {
      _lastError = e.toString();
      DevLog().error('扫描能力体目录失败: $e', source: 'PluginManager');
    }
  }

  Future<bool> installPlugin(File zipFile) async {
    _lastError = null;
    try {
      final fileSize = await zipFile.length();
      if (fileSize > maxZipSize) {
        _lastError = '插件包过大（最大 50MB）';
        return false;
      }

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final totalUncompressed = archive.fold<int>(
        0,
        (sum, file) => sum + file.size,
      );
      if (totalUncompressed > fileSize * maxDecompressionRatio) {
        _lastError = '插件包可能存在安全风险';
        return false;
      }

      String? pluginId;
      PluginManifest? manifest;
      String? manifestRaw;
      String? signatureRaw;

      for (final file in archive) {
        if (file.name == 'manifest.json' ||
            file.name.endsWith('/manifest.json')) {
          manifestRaw = String.fromCharCodes(file.content as List<int>);
          final json = jsonDecode(manifestRaw) as Map<String, dynamic>;
          manifest = PluginManifest.fromJson(json);
          pluginId = manifest.id;
        }
        if (file.name == 'signature.json' ||
            file.name.endsWith('/signature.json')) {
          signatureRaw = String.fromCharCodes(file.content as List<int>);
        }
      }

      if (pluginId == null || manifest == null || !manifest.isValid) {
        _lastError = 'ZIP 包中未找到有效的 manifest.json';
        return false;
      }

      if (!manifest.isCompatible) {
        _lastError =
            '插件需要 SDK v${manifest.minSdkVersion}，当前 v${PluginManifest.currentSdkVersion}';
        return false;
      }

      if (manifestRaw != null) {
        final sigResult = await SignatureVerifier().verifyPlugin(
          manifestJson: manifest.toJson(),
          manifestRaw: manifestRaw,
          signatureData: signatureRaw,
        );
        DevLog().info(
          '签名验证: ${sigResult.displayText}',
          source: 'PluginManager',
          data: {'status': sigResult.status.name, 'signer': sigResult.signerId},
        );
        if (sigResult.status == SignatureStatus.tampered) {
          _lastError = '能力体签名验证失败：内容可能被篡改';
          return false;
        }
      }

      final missing = resolveDependencies(manifest);
      if (missing.isNotEmpty) {
        _lastError = '缺少依赖: ${missing.join(', ')}';
        DevLog().warning('缺少依赖: ${missing.join(', ')}', source: 'PluginManager');
      }

      final pluginsDir = await _pluginsDir;
      final targetDir = Directory('${pluginsDir.path}/$pluginId');

      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
      await targetDir.create(recursive: true);

      for (final file in archive) {
        if (!file.isFile) continue;
        final fileName = file.name;
        final relativePath = fileName.contains('/')
            ? fileName.substring(fileName.indexOf('/') + 1)
            : fileName;
        if (relativePath.isEmpty) continue;
        if (relativePath.contains('..')) continue;

        final outputFile = File('${targetDir.path}/$relativePath');
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsBytes(file.content as List<int>);
      }

      await scanPlugins();
      DevLog().info('能力体安装成功: ${manifest.name}', source: 'PluginManager');
      return true;
    } catch (e) {
      _lastError = e.toString();
      DevLog().error('安装能力体失败: $e', source: 'PluginManager');
      return false;
    }
  }

  Future<bool> uninstallPlugin(String id) async {
    _lastError = null;
    try {
      final dependents = getDependents(id);
      if (dependents.isNotEmpty) {
        _lastError = '其他能力体依赖此能力体: ${dependents.join(', ')}';
        return false;
      }

      final pluginsDir = await _pluginsDir;
      final targetDir = Directory('${pluginsDir.path}/$id');

      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
        await scanPlugins();
        DevLog().info('能力体已卸载: $id', source: 'PluginManager');
        return true;
      }
      _lastError = '能力体不存在: $id';
      return false;
    } catch (e) {
      _lastError = e.toString();
      DevLog().error('卸载能力体失败: $e', source: 'PluginManager');
      return false;
    }
  }

  Future<String> getPluginEntryPath(PluginManifest manifest) async {
    final pluginsDir = await _pluginsDir;
    return '${pluginsDir.path}/${manifest.id}/${manifest.entry}';
  }

  Future<String?> getPluginIconPath(PluginManifest manifest) async {
    if (manifest.icon.isEmpty) return null;
    final pluginsDir = await _pluginsDir;
    final iconPath = '${pluginsDir.path}/${manifest.id}/${manifest.icon}';
    if (await File(iconPath).exists()) return iconPath;
    return null;
  }

  Future<PluginManifest?> checkForUpdate(PluginManifest manifest) async {
    if (!manifest.hasUpdateUrl) return null;

    try {
      final response = await http
          .get(Uri.parse(manifest.updateUrl!))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteManifest = PluginManifest.fromJson(json);

      if (!remoteManifest.isValid) return null;

      final remoteVersion = _parseVersion(remoteManifest.version);
      final localVersion = _parseVersion(manifest.version);

      if (remoteVersion > localVersion) {
        return remoteManifest;
      }
      return null;
    } catch (e) {
      DevLog().error('检查更新失败: ${manifest.id}', source: 'PluginManager');
      return null;
    }
  }

  Future<Map<String, PluginManifest>> checkAllUpdates() async {
    final updates = <String, PluginManifest>{};
    for (final plugin in _plugins) {
      final update = await checkForUpdate(plugin);
      if (update != null) {
        updates[plugin.id] = update;
      }
    }
    return updates;
  }
}
