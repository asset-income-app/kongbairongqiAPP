import 'dart:io';
import 'package:flutter/material.dart';
import '../models/plugin_manifest.dart';
import '../core/plugin_manager.dart';
import '../core/signature_verifier.dart';

class CapabilityDetailPage extends StatelessWidget {
  final PluginManifest plugin;
  final VoidCallback onOpen;
  final VoidCallback onUninstall;

  const CapabilityDetailPage({
    super.key,
    required this.plugin,
    required this.onOpen,
    required this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dependents = PluginManager().getDependents(plugin.id);
    final missingDeps = PluginManager().resolveDependencies(plugin);

    return Scaffold(
      appBar: AppBar(
        title: Text(plugin.name),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(colorScheme),
            const SizedBox(height: 24),
            _buildInfoSection(),
            if (plugin.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDescription(),
            ],
            if (plugin.permissions.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPermissions(colorScheme),
            ],
            if (plugin.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildTags(colorScheme),
            ],
            if (plugin.hasDependencies) ...[
              const SizedBox(height: 16),
              _buildDependencies(colorScheme, missingDeps),
            ],
            if (dependents.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDependents(colorScheme, dependents),
            ],
            if (plugin.provides.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildProvides(colorScheme),
            ],
            const SizedBox(height: 32),
            _buildActions(context, colorScheme),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.extension,
              color: colorScheme.primary,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            plugin.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'v${plugin.version} · ${plugin.author}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          if (!plugin.isFree) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '¥${plugin.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _buildTrustBadge(colorScheme),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(ColorScheme colorScheme) {
    return FutureBuilder<SignatureResult>(
      future: _checkSignature(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final result = snapshot.data!;
        Color badgeColor;
        IconData badgeIcon;
        String badgeText;

        switch (result.status) {
          case SignatureStatus.valid:
            badgeColor = Colors.green;
            badgeIcon = Icons.verified_user;
            badgeText = '已验证 · ${result.signerId ?? "可信"}';
            break;
          case SignatureStatus.unsigned:
            badgeColor = Colors.grey;
            badgeIcon = Icons.info_outline;
            badgeText = '未签名';
            break;
          case SignatureStatus.tampered:
            badgeColor = Colors.red;
            badgeIcon = Icons.warning;
            badgeText = '已篡改';
            break;
          default:
            badgeColor = Colors.orange;
            badgeIcon = Icons.help_outline;
            badgeText = '签名异常';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, size: 14, color: badgeColor),
              const SizedBox(width: 4),
              Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11,
                  color: badgeColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<SignatureResult> _checkSignature() async {
    try {
      final entryPath = await PluginManager().getPluginEntryPath(plugin);
      final pluginDir = entryPath.substring(0, entryPath.lastIndexOf('/'));
      final manifestFile = File('$pluginDir/manifest.json');
      final sigFile = File('$pluginDir/signature.json');

      if (!await manifestFile.exists()) {
        return const SignatureResult(status: SignatureStatus.missing);
      }

      final manifestRaw = await manifestFile.readAsString();
      final sigRaw = await sigFile.exists() ? await sigFile.readAsString() : null;

      return SignatureVerifier().verifyPlugin(
        manifestJson: plugin.toJson(),
        manifestRaw: manifestRaw,
        signatureData: sigRaw,
      );
    } catch (e) {
      return SignatureResult(
        status: SignatureStatus.invalid,
        error: e.toString(),
      );
    }
  }

  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow('ID', plugin.id),
            _buildInfoRow('版本', 'v${plugin.version}'),
            _buildInfoRow('作者', plugin.author),
            _buildInfoRow('SDK', 'v${plugin.minSdkVersion}'),
            if (plugin.hasUpdateUrl)
              _buildInfoRow('更新源', plugin.updateUrl!),
            if (plugin.hasPayment)
              _buildInfoRow('支付地址', plugin.paymentAddress!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '描述',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              plugin.description,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissions(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '权限',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: plugin.permissions.map((p) {
                final icon = _getPermissionIcon(p);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        p.value,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPermissionIcon(PluginPermission permission) {
    switch (permission) {
      case PluginPermission.clipboard:
        return Icons.content_copy;
      case PluginPermission.vibration:
        return Icons.vibration;
      case PluginPermission.camera:
        return Icons.camera_alt;
      case PluginPermission.storage:
        return Icons.storage;
      case PluginPermission.network:
        return Icons.wifi;
      case PluginPermission.notification:
        return Icons.notifications;
      case PluginPermission.events:
        return Icons.hub;
    }
  }

  Widget _buildTags(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '标签',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: plugin.tags.map((tag) => Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDependencies(ColorScheme colorScheme, List<String> missing) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '依赖',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            ...plugin.dependencies.map((dep) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        missing.contains(dep.id) ? Icons.error : Icons.check_circle,
                        size: 16,
                        color: missing.contains(dep.id)
                            ? Colors.red
                            : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dep.id,
                        style: TextStyle(
                          fontSize: 13,
                          color: missing.contains(dep.id) ? Colors.red : null,
                        ),
                      ),
                      if (dep.minVersion != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '>= v${dep.minVersion}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDependents(ColorScheme colorScheme, List<String> dependents) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '被依赖',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '卸载前需先移除这些能力体',
                  style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...dependents.map((id) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 14, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(id, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildProvides(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '提供能力',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: plugin.provides.map((cap) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cap,
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, ColorScheme colorScheme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.play_arrow),
            label: const Text('启动能力体'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onUninstall();
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('卸载', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }
}
