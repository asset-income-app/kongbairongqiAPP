import 'package:flutter/material.dart';
import '../core/dev_log.dart';

class DevConsolePage extends StatefulWidget {
  const DevConsolePage({super.key});

  @override
  State<DevConsolePage> createState() => _DevConsolePageState();
}

class _DevConsolePageState extends State<DevConsolePage> {
  LogLevel? _filterLevel;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    DevLog().addListener(_onLog);
  }

  @override
  void dispose() {
    DevLog().removeListener(_onLog);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onLog(LogEntry entry) {
    if (!_autoScroll || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stats = DevLog().stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('调试控制台'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              DevLog().clear();
              setState(() {});
            },
            tooltip: '清空日志',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsBar(stats, colorScheme),
          _buildFilterBar(colorScheme),
          Expanded(child: _buildLogList(colorScheme)),
        ],
      ),
    );
  }

  Widget _buildStatsBar(Map<String, int> stats, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatChip('Debug', stats['debug'] ?? 0, Colors.grey, colorScheme),
          _buildStatChip('Info', stats['info'] ?? 0, Colors.blue, colorScheme),
          _buildStatChip('Warn', stats['warning'] ?? 0, Colors.orange, colorScheme),
          _buildStatChip('Error', stats['error'] ?? 0, Colors.red, colorScheme),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索日志...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<LogLevel?>(
            value: _filterLevel,
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem(value: null, child: Text('全部')),
              ...LogLevel.values.map((level) => DropdownMenuItem(
                    value: level,
                    child: Text(level.name.toUpperCase()),
                  )),
            ],
            onChanged: (level) => setState(() => _filterLevel = level),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList(ColorScheme colorScheme) {
    final logs = DevLog().filter(
      level: _filterLevel,
      query: _searchController.text.isEmpty ? null : _searchController.text,
    );

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.terminal, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '暂无日志',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _buildLogItem(log, colorScheme);
      },
    );
  }

  Widget _buildLogItem(LogEntry log, ColorScheme colorScheme) {
    final levelColor = _getLevelColor(log.level);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: levelColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: levelColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                log.levelIcon,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 4),
              Text(
                log.source,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: levelColor,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(log.timestamp),
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            log.message,
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          if (log.data != null && log.data!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.data.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Colors.grey[700],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }
}
