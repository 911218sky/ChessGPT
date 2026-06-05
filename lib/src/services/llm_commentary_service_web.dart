import 'dart:convert';

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

import '../models/session_config.dart';

class LlmCommentaryService {
  LlmCommentaryService({Object? client})
    : _client = client is http.Client ? client : BrowserClient();

  static const _defaultProxyBaseUrl = String.fromEnvironment(
    'CHESS_AI_WEB_LLM_PROXY_BASE_URL',
  );
  static const _defaultProxyClientKey = String.fromEnvironment(
    'CHESS_AI_WEB_LLM_PROXY_CLIENT_KEY',
  );

  final http.Client _client;

  Future<List<String>> fetchModels(LlmSettings settings) async {
    final uri = _uri(settings, 'models');
    final response = await _send(
      'models',
      () => _client
          .get(uri, headers: _headers(settings, includeContentType: false))
          .timeout(const Duration(seconds: 20)),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException(
        _webFailureMessage(
          endpoint: 'models',
          statusCode: response.statusCode,
          body: _utf8Body(response),
        ),
      );
    }

    final payload = jsonDecode(_utf8Body(response));
    final data = payload is Map<String, Object?> ? payload['data'] : null;
    if (data is! List) {
      throw const LlmException('Models response did not include a data list.');
    }

    final models = <String>[];
    for (final item in data) {
      if (item is Map<String, Object?> && item['id'] is String) {
        models.add(item['id']! as String);
      }
    }
    models.sort();
    return models;
  }

  Future<void> testConnection(LlmSettings settings) async {
    final models = await fetchModels(settings);
    if (models.isEmpty) {
      throw const LlmException(
        'Connection worked, but no models were returned.',
      );
    }
  }

  Future<LlmCompletionResult> complete({
    required LlmSettings settings,
    required String systemPrompt,
    required String userPrompt,
    void Function(String partialText)? onPartial,
  }) async {
    final startedAt = DateTime.now();
    final uri = _uri(settings, 'chat/completions');
    final response = await _send(
      'chat completions',
      () => _client
          .post(
            uri,
            headers: _headers(
              settings,
              includeContentType: !_usesAnonymousDefaultProxy(settings),
            ),
            body: jsonEncode({
              'model': settings.model,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userPrompt},
              ],
              'temperature': 0.8,
              'max_tokens': 120,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 24)),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException(
        _webFailureMessage(
          endpoint: 'chat completions',
          statusCode: response.statusCode,
          body: _utf8Body(response),
        ),
      );
    }

    final payload = jsonDecode(_utf8Body(response));
    final text = _extractCompletionText(payload).trim();
    if (text.isEmpty) {
      throw const LlmException('Chat response was empty.');
    }
    onPartial?.call(text);
    return LlmCompletionResult(
      text: text,
      usage: payload is Map<String, Object?>
          ? LlmTokenUsage.fromJson(payload['usage'])
          : null,
      latencyMs: DateTime.now().difference(startedAt).inMilliseconds,
    );
  }

  Uri _uri(LlmSettings settings, String path) {
    final baseUrl = _effectiveBaseUrl(settings);
    if (baseUrl.isEmpty) {
      throw const LlmException(
        'Web LLM needs a backend proxy base URL. Configure CHESS_AI_WEB_LLM_PROXY_BASE_URL or set a proxy URL in the LLM panel.',
      );
    }
    if (_looksLikePublicProvider(baseUrl)) {
      throw const LlmException(
        'Web LLM must use a backend proxy, not a public provider API URL. This prevents exposing provider API keys in the browser.',
      );
    }
    final trimmed = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$trimmed/$path');
  }

  String _effectiveBaseUrl(LlmSettings settings) {
    final configured = settings.baseUrl.trim();
    final proxy = _defaultProxyBaseUrl.trim();
    if (proxy.isNotEmpty &&
        (configured.isEmpty || _looksLikePublicProvider(configured))) {
      return proxy;
    }
    return configured;
  }

  bool _usesAnonymousDefaultProxy(LlmSettings settings) {
    return settings.credentialMode == LlmCredentialMode.defaultProxy &&
        _defaultProxyClientKey.trim().isEmpty &&
        _normalizeBaseUrl(_effectiveBaseUrl(settings)) ==
            _normalizeBaseUrl(_defaultProxyBaseUrl);
  }

  String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  }

  Map<String, String> _headers(
    LlmSettings settings, {
    bool includeContentType = true,
  }) {
    final headers = <String, String>{'accept': 'application/json'};
    if (includeContentType) {
      headers['content-type'] = 'application/json';
    }
    final clientKey = switch (settings.credentialMode) {
      LlmCredentialMode.defaultProxy => _defaultProxyClientKey.trim(),
      LlmCredentialMode.customApiKey => settings.apiKey.trim(),
    };
    if (clientKey.isNotEmpty) {
      headers['authorization'] = 'Bearer $clientKey';
    }
    return headers;
  }

  Future<http.Response> _send(
    String endpoint,
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request();
    } on LlmException {
      rethrow;
    } catch (error) {
      throw LlmException(_webNetworkFailureMessage(endpoint, error));
    }
  }

  String _webFailureMessage({
    required String endpoint,
    required int statusCode,
    required String body,
  }) {
    final trimmedBody = body.trim();
    final bodyText = trimmedBody.isEmpty ? 'empty response body' : trimmedBody;
    final corsHint = statusCode == 401 || statusCode == 403
        ? ' On web this is often a backend proxy issue: the proxy must handle browser OPTIONS preflight, allow this Pages origin, and inject the real provider API key server-side. Do not put the provider key in the GitHub Pages build.'
        : '';
    return '$endpoint request failed: $statusCode $bodyText.$corsHint';
  }

  String _webNetworkFailureMessage(String endpoint, Object error) {
    return '$endpoint request failed in the browser: $error. If DevTools shows OPTIONS 403 or a CORS error, fix the backend proxy to answer OPTIONS for /v1/models and /v1/chat/completions, allow the GitHub Pages origin, allow Content-Type, and add the provider Authorization header on the server.';
  }

  String _utf8Body(http.Response response) {
    return utf8.decode(response.bodyBytes);
  }

  bool _looksLikePublicProvider(String baseUrl) {
    final host = Uri.tryParse(baseUrl.trim())?.host.toLowerCase();
    if (host == null) {
      return false;
    }
    return host == 'api.openai.com' ||
        host == 'api.anthropic.com' ||
        host == 'generativelanguage.googleapis.com' ||
        host == 'api.kimi.com' ||
        host.endsWith('.openai.com') ||
        host.endsWith('.anthropic.com');
  }

  String _extractCompletionText(Object? payload) {
    if (payload is! Map<String, Object?>) {
      return '';
    }
    final choices = payload['choices'];
    if (choices is! List || choices.isEmpty) {
      return '';
    }
    final first = choices.first;
    if (first is! Map<String, Object?>) {
      return '';
    }
    final message = first['message'];
    if (message is Map<String, Object?> && message['content'] is String) {
      return message['content']! as String;
    }
    final text = first['text'];
    return text is String ? text : '';
  }

  void dispose() {
    _client.close();
  }
}

class LlmCompletionResult {
  const LlmCompletionResult({
    required this.text,
    required this.usage,
    required this.latencyMs,
  });

  final String text;
  final LlmTokenUsage? usage;
  final int latencyMs;
}

class LlmTokenUsage {
  const LlmTokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  factory LlmTokenUsage.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return const LlmTokenUsage(
        promptTokens: 0,
        completionTokens: 0,
        totalTokens: 0,
      );
    }
    final prompt = _intValue(json['prompt_tokens']);
    final completion = _intValue(json['completion_tokens']);
    final total = json.containsKey('total_tokens')
        ? _intValue(json['total_tokens'])
        : prompt + completion;
    return LlmTokenUsage(
      promptTokens: prompt,
      completionTokens: completion,
      totalTokens: total,
    );
  }

  factory LlmTokenUsage.fromAnthropicJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return const LlmTokenUsage(
        promptTokens: 0,
        completionTokens: 0,
        totalTokens: 0,
      );
    }
    final prompt = _intValue(json['input_tokens']);
    final completion = _intValue(json['output_tokens']);
    return LlmTokenUsage(
      promptTokens: prompt,
      completionTokens: completion,
      totalTokens: prompt + completion,
    );
  }
}

int _intValue(Object? value) {
  return switch (value) {
    final int number => number,
    final num number => number.round(),
    final String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
}

class LlmException implements Exception {
  const LlmException(this.message);

  final String message;

  @override
  String toString() => message;
}
