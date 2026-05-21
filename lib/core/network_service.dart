import 'dart:convert';
import 'package:http/http.dart' as http;

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  static const int maxResponseSize = 5 * 1024 * 1024;
  static const Duration defaultTimeout = Duration(seconds: 30);

  Future<Map<String, dynamic>> request({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? defaultTimeout;

    try {
      final uri = Uri.parse(url);
      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(uri, headers: headers)
              .timeout(effectiveTimeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: _encodeBody(body))
              .timeout(effectiveTimeout);
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: _encodeBody(body))
              .timeout(effectiveTimeout);
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers)
              .timeout(effectiveTimeout);
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: _encodeBody(body))
              .timeout(effectiveTimeout);
          break;
        default:
          return {
            'success': false,
            'error': 'Unsupported method: $method',
          };
      }

      if (response.bodyBytes.length > maxResponseSize) {
        return {
          'success': false,
          'error': 'Response too large (max 5MB)',
        };
      }

      final responseBody = _parseResponseBody(response.body);

      return {
        'success': response.statusCode >= 200 && response.statusCode < 300,
        'statusCode': response.statusCode,
        'body': responseBody,
        'headers': response.headers,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  String? _encodeBody(dynamic body) {
    if (body == null) return null;
    if (body is String) return body;
    return jsonEncode(body);
  }

  dynamic _parseResponseBody(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }
}
