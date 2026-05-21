import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/plugin_manifest.dart';
import '../core/plugin_manager.dart';
import '../core/event_bus.dart';
import '../core/capability_storage.dart';
import '../core/network_service.dart';
import '../core/notification_service.dart';
import '../core/dev_log.dart';

class PluginSandbox extends StatefulWidget {
  final PluginManifest plugin;

  const PluginSandbox({super.key, required this.plugin});

  @override
  State<PluginSandbox> createState() => _PluginSandboxState();
}

class _PluginSandboxState extends State<PluginSandbox> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  String _appBarTitle = '';

  @override
  void initState() {
    super.initState();
    _appBarTitle = widget.plugin.name;
    _initWebView();
  }

  @override
  void dispose() {
    EventBus().removeListenersForOwner(widget.plugin.id);
    super.dispose();
  }

  Future<void> _initWebView() async {
    try {
      final entryPath =
          await PluginManager().getPluginEntryPath(widget.plugin);

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            },
            onPageFinished: (String url) {
              setState(() => _isLoading = false);
            },
            onWebResourceError: (WebResourceError error) {
              setState(() {
                _isLoading = false;
                _errorMessage = '加载失败: ${error.description}';
              });
            },
          ),
        )
        ..addJavaScriptChannel(
          'Bridge',
          onMessageReceived: (JavaScriptMessage message) {
            _handleBridgeMessage(message.message);
          },
        );

      final uri = Uri.parse(entryPath);
      await _controller.loadFile(uri.path);

      setState(() {});
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '初始化失败: $e';
      });
    }
  }

  void _handleBridgeMessage(String message) {
    final source = 'PluginSandbox[${widget.plugin.id}]';
    DevLog().debug('Neural: $message', source: source);

    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final action = data['action'] as String?;
      final params = data['params'];
      final callbackId = data['callbackId'] as String?;

      DevLog().info('Action: $action', source: source, data: params is Map ? Map<String, dynamic>.from(params) : null);

      switch (action) {
        case 'vibrate':
          _handleVibrate(params, callbackId);
          break;
        case 'copyToClipboard':
          _handleCopyToClipboard(params, callbackId);
          break;
        case 'getClipboardText':
          _handleGetClipboardText(callbackId);
          break;
        case 'getDeviceInfo':
          _handleGetDeviceInfo(callbackId);
          break;
        case 'showToast':
          _handleShowToast(params);
          break;
        case 'setAppBarTitle':
          _handleSetAppBarTitle(params);
          break;
        case 'storeData':
          _handleStoreData(params, callbackId);
          break;
        case 'retrieveData':
          _handleRetrieveData(params, callbackId);
          break;
        case 'removeData':
          _handleRemoveData(params, callbackId);
          break;
        case 'clearData':
          _handleClearData(callbackId);
          break;
        case 'emitEvent':
          _handleEmitEvent(params, callbackId);
          break;
        case 'onEvent':
          _handleOnEvent(params, callbackId);
          break;
        case 'offEvent':
          _handleOffEvent(params, callbackId);
          break;
        case 'getEventHistory':
          _handleGetEventHistory(params, callbackId);
          break;
        case 'httpRequest':
          _handleHttpRequest(params, callbackId);
          break;
        case 'showNotification':
          _handleShowNotification(params, callbackId);
          break;
        default:
          DevLog().warning('Unknown neural action: $action', source: 'PluginSandbox');
          _sendCallback(callbackId, {'error': 'Unknown action: $action'});
      }
    } catch (e) {
      DevLog().error('Neural parse error: $e', source: 'PluginSandbox');
    }
  }

  void _sendCallback(String? callbackId, Map<String, dynamic> data) {
    if (callbackId == null) return;
    final jsonStr = jsonEncode(data);
    _controller.runJavaScript(
      "window.BridgeCallbacks?.['$callbackId']?.($jsonStr); delete window.BridgeCallbacks?.['$callbackId']",
    );
  }

  void _sendEventToWebView(String eventName, Map<String, dynamic> eventData) {
    final jsonStr = jsonEncode({'event': eventName, 'data': eventData});
    _controller.runJavaScript(
      "window.Neural?.onEvent($jsonStr)",
    );
  }

  Future<void> _handleVibrate(dynamic params, String? callbackId) async {
    if (!widget.plugin.hasPermission(PluginPermission.vibration)) {
      _sendCallback(callbackId, {'error': 'Permission denied: vibration'});
      return;
    }
    await HapticFeedback.mediumImpact();
    _sendCallback(callbackId, {'success': true});
  }

  Future<void> _handleCopyToClipboard(
      dynamic params, String? callbackId) async {
    if (!widget.plugin.hasPermission(PluginPermission.clipboard)) {
      _sendCallback(callbackId, {'error': 'Permission denied: clipboard'});
      return;
    }
    final text = params is Map ? params['text'] : params?.toString() ?? '';
    await Clipboard.setData(ClipboardData(text: text));
    _sendCallback(callbackId, {'success': true});
  }

  Future<void> _handleGetClipboardText(String? callbackId) async {
    if (!widget.plugin.hasPermission(PluginPermission.clipboard)) {
      _sendCallback(callbackId, {'error': 'Permission denied: clipboard'});
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    _sendCallback(callbackId, {'text': data?.text ?? ''});
  }

  Future<void> _handleGetDeviceInfo(String? callbackId) async {
    _sendCallback(callbackId, {
      'platform': 'android',
      'appId': 'com.blankos.blankos',
      'sdkVersion': PluginManifest.currentSdkVersion,
    });
  }

  void _handleShowToast(dynamic params) {
    final msg = params is Map ? params['message'] : params?.toString() ?? '';
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }

  void _handleSetAppBarTitle(dynamic params) {
    final title = params is Map ? params['title'] : params?.toString() ?? '';
    if (mounted && title.isNotEmpty) {
      setState(() => _appBarTitle = title);
    }
  }

  Future<void> _handleStoreData(dynamic params, String? callbackId) async {
    if (!widget.plugin.hasPermission(PluginPermission.storage)) {
      _sendCallback(callbackId, {'error': 'Permission denied: storage'});
      return;
    }
    try {
      final key = params is Map ? params['key'] as String? : null;
      final value = params is Map ? params['value'] : null;
      if (key == null) {
        _sendCallback(callbackId, {'error': 'key is required'});
        return;
      }
      await CapabilityStorage()
          .storeData(widget.plugin.id, key, value);
      _sendCallback(callbackId, {'success': true});
    } catch (e) {
      _sendCallback(callbackId, {'error': e.toString()});
    }
  }

  Future<void> _handleRetrieveData(dynamic params, String? callbackId) async {
    if (!widget.plugin.hasPermission(PluginPermission.storage)) {
      _sendCallback(callbackId, {'error': 'Permission denied: storage'});
      return;
    }
    try {
      final key = params is Map ? params['key'] as String? : null;
      if (key == null) {
        final allData =
            await CapabilityStorage().retrieveAllData(widget.plugin.id);
        _sendCallback(callbackId, {'success': true, 'data': allData});
        return;
      }
      final value =
          await CapabilityStorage().retrieveData(widget.plugin.id, key);
      _sendCallback(callbackId, {'success': true, 'value': value});
    } catch (e) {
      _sendCallback(callbackId, {'error': e.toString()});
    }
  }

  Future<void> _handleRemoveData(dynamic params, String? callbackId) async {
    if (!widget.plugin.hasPermission(PluginPermission.storage)) {
      _sendCallback(callbackId, {'error': 'Permission denied: storage'});
      return;
    }
    try {
      final key = params is Map ? params['key'] as String? : null;
      if (key == null) {
        _sendCallback(callbackId, {'error': 'key is required'});
        return;
      }
      final removed =
          await CapabilityStorage().removeData(widget.plugin.id, key);
      _sendCallback(callbackId, {'success': removed});
    } catch (e) {
      _sendCallback(callbackId, {'error': e.toString()});
    }
  }

  Future<void> _handleClearData(String? callbackId) async {
    if (!widget.plugin.hasPermission(PluginPermission.storage)) {
      _sendCallback(callbackId, {'error': 'Permission denied: storage'});
      return;
    }
    try {
      await CapabilityStorage().clearData(widget.plugin.id);
      _sendCallback(callbackId, {'success': true});
    } catch (e) {
      _sendCallback(callbackId, {'error': e.toString()});
    }
  }

  void _handleEmitEvent(dynamic params, String? callbackId) {
    final eventName = params is Map ? params['event'] as String? : null;
    final eventData =
        params is Map ? params['data'] as Map<String, dynamic>? : null;
    if (eventName == null) {
      _sendCallback(callbackId, {'error': 'event name is required'});
      return;
    }
    EventBus().emit(eventName, eventData ?? {});
    _sendCallback(callbackId, {'success': true});
  }

  void _handleOnEvent(dynamic params, String? callbackId) {
    final eventName = params is Map ? params['event'] as String? : null;
    if (eventName == null) {
      _sendCallback(callbackId, {'error': 'event name is required'});
      return;
    }
    EventBus().onOwned(eventName, widget.plugin.id, (data) {
      _sendEventToWebView(eventName, data);
    });
    _sendCallback(callbackId, {'success': true});
  }

  void _handleOffEvent(dynamic params, String? callbackId) {
    final eventName = params is Map ? params['event'] as String? : null;
    if (eventName == null) {
      _sendCallback(callbackId, {'error': 'event name is required'});
      return;
    }
    EventBus().removeListenersForOwner(widget.plugin.id);
    _sendCallback(callbackId, {'success': true});
  }

  void _handleGetEventHistory(dynamic params, String? callbackId) {
    final eventName = params is Map ? params['event'] as String? : null;
    final limit = params is Map ? params['limit'] as int? : null;
    final history = EventBus().getHistory(event: eventName, limit: limit);
    _sendCallback(callbackId, {'success': true, 'history': history});
  }

  Future<void> _handleHttpRequest(dynamic params, String? callbackId) async {
    if (!widget.plugin.hasPermission(PluginPermission.network)) {
      _sendCallback(callbackId, {'error': 'Permission denied: network'});
      return;
    }
    try {
      final method = params is Map ? params['method'] as String? : null;
      final url = params is Map ? params['url'] as String? : null;
      final headers = params is Map
          ? (params['headers'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()))
          : null;
      final body = params is Map ? params['body'] : null;
      final timeout = params is Map ? params['timeout'] as int? : null;

      if (method == null || url == null) {
        _sendCallback(callbackId, {'error': 'method and url are required'});
        return;
      }

      final result = await NetworkService().request(
        method: method,
        url: url,
        headers: headers,
        body: body,
        timeout: timeout != null ? Duration(seconds: timeout) : null,
      );
      _sendCallback(callbackId, result);
    } catch (e) {
      _sendCallback(callbackId, {'success': false, 'error': e.toString()});
    }
  }

  Future<void> _handleShowNotification(
      dynamic params, String? callbackId) async {
    if (!widget.plugin.hasPermission(PluginPermission.notification)) {
      _sendCallback(callbackId, {'error': 'Permission denied: notification'});
      return;
    }
    try {
      final title = params is Map ? params['title'] as String? : null;
      final body = params is Map ? params['body'] as String? : null;
      final id = params is Map ? params['id'] as int? : null;

      if (title == null || body == null) {
        _sendCallback(callbackId, {'error': 'title and body are required'});
        return;
      }

      final success = await NotificationService().show(
        title: title,
        body: body,
        id: id ?? 0,
      );
      _sendCallback(callbackId, {'success': success});
    } catch (e) {
      _sendCallback(callbackId, {'success': false, 'error': e.toString()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Stack(
        children: [
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _initWebView,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_isLoading && _errorMessage == null)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
