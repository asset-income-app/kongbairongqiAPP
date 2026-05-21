import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/plugin_manifest.dart';
import '../core/plugin_manager.dart';
import 'plugin_sandbox.dart';
import 'capability_detail_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onOpenSettings;

  const HomePage({super.key, this.onOpenSettings});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PluginManager _pluginManager = PluginManager();
  List<PluginManifest> _plugins = [];
  List<PluginManifest> _filteredPlugins = [];
  List<String> _recentPluginIds = [];
  String? _selectedTag;
  bool _isLoading = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _pluginManager.scanPlugins();
    await _loadRecentPlugins();
    setState(() {
      _plugins = _pluginManager.plugins;
      _applyFilters();
      _isLoading = false;
    });
  }

  Future<void> _loadRecentPlugins() async {
    final prefs = await SharedPreferences.getInstance();
    _recentPluginIds = prefs.getStringList('recent_plugins') ?? [];
  }

  Future<void> _saveRecentPlugin(String pluginId) async {
    _recentPluginIds.remove(pluginId);
    _recentPluginIds.insert(0, pluginId);
    if (_recentPluginIds.length > 5) {
      _recentPluginIds = _recentPluginIds.sublist(0, 5);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_plugins', _recentPluginIds);
    setState(() {});
  }

  void _applyFilters() {
    var result = _plugins;
    if (_selectedTag != null) {
      result = _pluginManager.getPluginsByTag(_selectedTag!);
    }
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      result = result
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.author.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q) ||
              p.id.toLowerCase().contains(q) ||
              p.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }
    _filteredPlugins = result;
  }

  void _filterPlugins(String query) {
    setState(() => _applyFilters());
  }

  void _selectTag(String? tag) {
    setState(() {
      _selectedTag = tag;
      _applyFilters();
    });
  }

  Future<void> _importPlugin() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final success = await _pluginManager.installPlugin(file);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? '能力体安装成功'
                  : (_pluginManager.lastError ?? '能力体安装失败')),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
          if (success) {
            setState(() {
              _plugins = _pluginManager.plugins;
              _applyFilters();
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openPlugin(PluginManifest plugin) {
    _saveRecentPlugin(plugin.id);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PluginSandbox(plugin: plugin)),
    );
  }

  void _openDetail(PluginManifest plugin) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CapabilityDetailPage(
          plugin: plugin,
          onOpen: () => _openPlugin(plugin),
          onUninstall: () async {
            await _uninstallPlugin(plugin);
          },
        ),
      ),
    );
  }

  Future<void> _uninstallPlugin(PluginManifest plugin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认卸载'),
        content: Text('确定要卸载 "${plugin.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('卸载', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _pluginManager.uninstallPlugin(plugin.id);
      setState(() {
        _plugins = _pluginManager.plugins;
        _applyFilters();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '能力体已卸载' : (_pluginManager.lastError ?? '卸载失败')),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allTags = _pluginManager.allTags;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索能力体...',
                  border: InputBorder.none,
                ),
                onChanged: _filterPlugins,
              )
            : const Text('BlankOS'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _applyFilters();
                }
              });
            },
            tooltip: '搜索',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: widget.onOpenSettings,
            tooltip: '设置',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plugins.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    if (allTags.isNotEmpty) _buildTagFilter(allTags, colorScheme),
                    Expanded(child: _buildPluginList()),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _importPlugin,
        tooltip: '导入能力体',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTagFilter(List<String> tags, ColorScheme colorScheme) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: const Text('全部'),
              selected: _selectedTag == null,
              onSelected: (_) => _selectTag(null),
            ),
          ),
          ...tags.map((tag) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(tag),
                  selected: _selectedTag == tag,
                  onSelected: (_) => _selectTag(tag),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 60,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '空空如也',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '点击右下角 + 开始添加能力体',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Text(
              '这里没有中间商，你创造的，全部归你。',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPluginList() {
    final recentPlugins = _plugins
        .where((p) => _recentPluginIds.contains(p.id))
        .toList();

    return Column(
      children: [
        if (recentPlugins.isNotEmpty && !_isSearching && _selectedTag == null)
          _buildRecentPlugins(recentPlugins),
        Expanded(
          child: _filteredPlugins.isEmpty
              ? Center(
                  child: Text(
                    '未找到匹配的能力体',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredPlugins.length,
                  itemBuilder: (context, index) {
                    final plugin = _filteredPlugins[index];
                    return _buildPluginCard(plugin);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecentPlugins(List<PluginManifest> recentPlugins) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '最近使用',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: recentPlugins.length,
              itemBuilder: (context, index) {
                final plugin = recentPlugins[index];
                return GestureDetector(
                  onTap: () => _openPlugin(plugin),
                  onLongPress: () => _openDetail(plugin),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.extension,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plugin.name,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPluginCard(PluginManifest plugin) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openPlugin(plugin),
        onLongPress: () => _openDetail(plugin),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.extension,
                  color: colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            plugin.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!plugin.isFree) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '¥${plugin.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (plugin.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          plugin.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'v${plugin.version} · ${plugin.author}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (plugin.tags.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          ...plugin.tags.take(2).map((tag) => Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              )),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                onPressed: () => _openDetail(plugin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
