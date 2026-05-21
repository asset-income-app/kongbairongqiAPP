import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'dev_log.dart';

enum SignatureStatus {
  valid,
  invalid,
  missing,
  unsigned,
  tampered,
}

class SignatureResult {
  final SignatureStatus status;
  final String? signerId;
  final String? algorithm;
  final String? error;

  const SignatureResult({
    required this.status,
    this.signerId,
    this.algorithm,
    this.error,
  });

  bool get isValid => status == SignatureStatus.valid;
  bool get isTrusted => status == SignatureStatus.valid || status == SignatureStatus.unsigned;

  String get displayText {
    switch (status) {
      case SignatureStatus.valid:
        return '签名有效 · $signerId';
      case SignatureStatus.invalid:
        return '签名无效';
      case SignatureStatus.missing:
        return '签名文件缺失';
      case SignatureStatus.unsigned:
        return '未签名';
      case SignatureStatus.tampered:
        return '内容已被篡改';
    }
  }
}

class TrustChain {
  static final TrustChain _instance = TrustChain._internal();
  factory TrustChain() => _instance;
  TrustChain._internal();

  final Map<String, String> _trustedPublicKeys = {};
  final Map<String, DateTime> _revokedKeys = {};

  void addTrustedKey(String signerId, String publicKey) {
    _trustedPublicKeys[signerId] = publicKey;
    DevLog().info('添加信任密钥: $signerId', source: 'TrustChain');
  }

  void revokeKey(String signerId) {
    _revokedKeys[signerId] = DateTime.now();
    DevLog().warning('撤销信任密钥: $signerId', source: 'TrustChain');
  }

  bool isKeyTrusted(String signerId) {
    if (_revokedKeys.containsKey(signerId)) return false;
    return _trustedPublicKeys.containsKey(signerId);
  }

  String? getPublicKey(String signerId) => _trustedPublicKeys[signerId];

  List<String> get trustedSigners => _trustedPublicKeys.keys.toList();
}

class SignatureVerifier {
  static final SignatureVerifier _instance = SignatureVerifier._internal();
  factory SignatureVerifier() => _instance;
  SignatureVerifier._internal();

  Future<SignatureResult> verifyPlugin({
    required Map<String, dynamic> manifestJson,
    required String manifestRaw,
    String? signatureData,
  }) async {
    if (signatureData == null || signatureData.isEmpty) {
      DevLog().info('能力体未签名', source: 'SignatureVerifier');
      return const SignatureResult(status: SignatureStatus.unsigned);
    }

    try {
      final sigJson = jsonDecode(signatureData) as Map<String, dynamic>;
      final signerId = sigJson['signer_id'] as String?;
      final algorithm = sigJson['algorithm'] as String? ?? 'hmac-sha256';
      final signature = sigJson['signature'] as String?;

      if (signerId == null || signature == null) {
        return const SignatureResult(
          status: SignatureStatus.invalid,
          error: '签名数据不完整',
        );
      }

      if (!TrustChain().isKeyTrusted(signerId)) {
        DevLog().warning('未知签名者: $signerId', source: 'SignatureVerifier');
      }

      final contentHash = _computeContentHash(manifestRaw);
      final expectedSig = _computeSignature(
        contentHash,
        TrustChain().getPublicKey(signerId) ?? _getDefaultKey(signerId),
        algorithm,
      );

      if (signature != expectedSig) {
        DevLog().error('签名验证失败: 内容可能被篡改', source: 'SignatureVerifier');
        return SignatureResult(
          status: SignatureStatus.tampered,
          signerId: signerId,
          algorithm: algorithm,
          error: '签名不匹配',
        );
      }

      DevLog().info('签名验证通过: $signerId', source: 'SignatureVerifier');
      return SignatureResult(
        status: SignatureStatus.valid,
        signerId: signerId,
        algorithm: algorithm,
      );
    } catch (e) {
      DevLog().error('签名解析失败: $e', source: 'SignatureVerifier');
      return SignatureResult(
        status: SignatureStatus.invalid,
        error: e.toString(),
      );
    }
  }

  String _computeContentHash(String content) {
    final bytes = utf8.encode(content);
    return sha256.convert(bytes).toString();
  }

  String _computeSignature(String contentHash, String key, String algorithm) {
    switch (algorithm) {
      case 'hmac-sha256':
        final hmacKey = utf8.encode(key);
        final bytes = utf8.encode(contentHash);
        final hmacSha256 = Hmac(sha256, hmacKey);
        final digest = hmacSha256.convert(bytes);
        return digest.toString();
      case 'sha256':
        final bytes = utf8.encode(contentHash + key);
        return sha256.convert(bytes).toString();
      default:
        final hmacKey = utf8.encode(key);
        final bytes = utf8.encode(contentHash);
        final hmacSha256 = Hmac(sha256, hmacKey);
        final digest = hmacSha256.convert(bytes);
        return digest.toString();
    }
  }

  String _getDefaultKey(String signerId) {
    return 'blankos_default_${signerId.hashCode.abs()}';
  }

  String generateSignature({
    required String manifestRaw,
    required String signerId,
    required String privateKey,
    String algorithm = 'hmac-sha256',
  }) {
    final contentHash = _computeContentHash(manifestRaw);
    final signature = _computeSignature(contentHash, privateKey, algorithm);

    return jsonEncode({
      'signer_id': signerId,
      'algorithm': algorithm,
      'signature': signature,
      'content_hash': contentHash,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<SignatureResult> verifyFileIntegrity({
    required Uint8List fileBytes,
    required String expectedHash,
  }) async {
    final actualHash = sha256.convert(fileBytes).toString();
    if (actualHash == expectedHash) {
      return const SignatureResult(status: SignatureStatus.valid);
    }
    return const SignatureResult(
      status: SignatureStatus.tampered,
      error: '文件哈希不匹配',
    );
  }
}
