import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dev_console_page.dart';
import '../models/plugin_manifest.dart';
import '../core/plugin_manager.dart';

enum AppThemeMode { light, dark, system }

class SettingsPage extends StatefulWidget {
  final Function(AppThemeMode) onThemeChanged;
  final AppThemeMode currentTheme;

  const SettingsPage({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _developerMode = false;
  final String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _developerMode = prefs.getBool('developer_mode') ?? false;
    });
  }

  Future<void> _setDeveloperMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('developer_mode', value);
    setState(() => _developerMode = value);
  }

  Future<void> _checkAllUpdates() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在检查更新...'),
          ],
        ),
      ),
    );

    try {
      final updates = await PluginManager().checkAllUpdates();
      if (!mounted) return;
      Navigator.pop(context);

      if (updates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所有能力体均为最新版本')),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('发现更新'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: updates.entries.map((e) => ListTile(
                title: Text(e.value.name),
                subtitle: Text('v${e.key} → v${e.value.version}'),
                dense: true,
              )).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('外观'),
          _buildThemeSelector(),
          const Divider(),

          _buildSectionHeader('高级'),
          SwitchListTile(
            title: const Text('开发者模式'),
            subtitle: Text(
              _developerMode ? '已启用调试功能' : '启用后可查看调试信息',
              style: TextStyle(
                fontSize: 12,
                color: _developerMode ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
            value: _developerMode,
            onChanged: _setDeveloperMode,
            secondary: Icon(
              Icons.code,
              color: _developerMode ? colorScheme.primary : null,
            ),
          ),
          if (_developerMode) ...[
            ListTile(
              leading: Icon(Icons.terminal, color: colorScheme.primary),
              title: const Text('调试控制台'),
              subtitle: const Text('查看运行时日志', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DevConsolePage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.system_update, color: colorScheme.primary),
              title: const Text('检查全部更新'),
              subtitle: const Text('检测所有能力体的新版本', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _checkAllUpdates(),
            ),
          ],
          const Divider(),

          _buildSectionHeader('关于'),
          _buildAboutTile('版本', 'v$_appVersion'),
          _buildAboutTile('应用', 'BlankOS'),
          _buildAboutTile('理念', '零抽成 · 能力体生态'),
          _buildAboutTile('SDK', 'v${PluginManifest.currentSdkVersion}'),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '这里没有中间商，你创造的，全部归你。',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    return ListTile(
      leading: Icon(
        widget.currentTheme == AppThemeMode.dark
            ? Icons.dark_mode
            : widget.currentTheme == AppThemeMode.light
                ? Icons.light_mode
                : Icons.brightness_auto,
      ),
      title: const Text('主题'),
      subtitle: Text(_getThemeLabel(widget.currentTheme)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeDialog(),
    );
  }

  String _getThemeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return '浅色模式';
      case AppThemeMode.dark:
        return '深色模式';
      case AppThemeMode.system:
        return '跟随系统';
    }
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择主题'),
        children: AppThemeMode.values.map((mode) {
          return SimpleDialogOption(
            onPressed: () {
              widget.onThemeChanged(mode);
              Navigator.pop(context);
            },
            child: Row(
              children: [
                Icon(
                  mode == AppThemeMode.dark
                      ? Icons.dark_mode
                      : mode == AppThemeMode.light
                          ? Icons.light_mode
                          : Icons.brightness_auto,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(_getThemeLabel(mode)),
                const Spacer(),
                if (mode == widget.currentTheme)
                  Icon(Icons.check, color: Theme.of(context).colorScheme.primary, size: 20),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAboutTile(String label, String value) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
