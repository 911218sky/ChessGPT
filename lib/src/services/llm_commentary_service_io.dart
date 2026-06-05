import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/session_config.dart';

class LlmCommentaryService {
  LlmCommentaryService({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<List<String>> fetchModels(LlmSettings settings) async {
    return switch (settings.providerKind) {
      LlmProviderKind.anthropicClaude => _fetchAnthropicModels(settings),
      _ => _fetchOpenAiCompatibleModels(settings),
    };
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
    return switch (settings.providerKind) {
      LlmProviderKind.anthropicClaude => _completeAnthropic(
        settings: settings,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        onPartial: onPartial,
      ),
      _ => _completeOpenAiCompatible(
        settings: settings,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        onPartial: onPartial,
      ),
    };
  }

  Future<List<String>> _fetchOpenAiCompatibleModels(
    LlmSettings settings,
  ) async {
    final payload = await _sendJson(
      method: 'GET',
      uri: _uri(settings.baseUrl, 'models'),
      settings: settings,
      timeout: const Duration(seconds: 20),
    );

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

  Future<List<String>> _fetchAnthropicModels(LlmSettings settings) async {
    final payload = await _sendJson(
      method: 'GET',
      uri: _uri(settings.baseUrl, 'models'),
      settings: settings,
      timeout: const Duration(seconds: 20),
    );

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

  Future<LlmCompletionResult> _completeOpenAiCompatible({
    required LlmSettings settings,
    required String systemPrompt,
    required String userPrompt,
    void Function(String partialText)? onPartial,
  }) async {
    final startedAt = DateTime.now();
    final streamResult = await _sendSse(
      method: 'POST',
      uri: _uri(settings.baseUrl, 'chat/completions'),
      settings: settings,
      timeout: const Duration(seconds: 24),
      body: {
        'model': settings.model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.8,
        'max_tokens': 90,
        'stream': true,
        'stream_options': {'include_usage': true},
      },
      onEvent: (payload) {
        final choices = payload is Map<String, Object?>
            ? payload['choices']
            : null;
        if (choices is! List || choices.isEmpty) {
          return;
        }
        final first = choices.first;
        if (first is! Map<String, Object?>) {
          return;
        }
        final delta = first['delta'];
        if (delta is! Map<String, Object?>) {
          return;
        }
        final content = delta['content'];
        if (content is String && content.isNotEmpty) {
          onPartial?.call(content);
        }
      },
    );

    final payload = streamResult.finalPayload;
    final text = streamResult.text.trim();
    if (text.isEmpty) {
      throw const LlmException('Chat response was empty.');
    }
    final latencyMs = DateTime.now().difference(startedAt).inMilliseconds;
    final usage = payload is! Map<String, Object?>
        ? null
        : LlmTokenUsage.fromJson(payload['usage']);
    return LlmCompletionResult(text: text, usage: usage, latencyMs: latencyMs);
  }

  Future<LlmCompletionResult> _completeAnthropic({
    required LlmSettings settings,
    required String systemPrompt,
    required String userPrompt,
    void Function(String partialText)? onPartial,
  }) async {
    final startedAt = DateTime.now();
    final streamResult = await _sendSse(
      method: 'POST',
      uri: _uri(settings.baseUrl, 'messages'),
      settings: settings,
      timeout: const Duration(seconds: 24),
      body: {
        'model': settings.model,
        'system': systemPrompt,
        'max_tokens': 90,
        'temperature': 0.8,
        'messages': [
          {'role': 'user', 'content': userPrompt},
        ],
        'stream': true,
      },
      onEvent: (payload) {
        if (payload is! Map<String, Object?>) {
          return;
        }
        if (payload['type'] == 'content_block_delta') {
          final delta = payload['delta'];
          if (delta is Map<String, Object?>) {
            final text = delta['text'];
            if (text is String && text.isNotEmpty) {
              onPartial?.call(text);
            }
          }
        }
      },
    );

    final payload = streamResult.finalPayload;
    final latencyMs = DateTime.now().difference(startedAt).inMilliseconds;
    final usage = payload is! Map<String, Object?>
        ? null
        : LlmTokenUsage.fromAnthropicJson(payload['usage']);
    final text = streamResult.text.trim();
    if (text.isEmpty) {
      throw const LlmException('Claude response was empty.');
    }
    return LlmCompletionResult(text: text, usage: usage, latencyMs: latencyMs);
  }

  Future<Object?> _sendJson({
    required String method,
    required Uri uri,
    required LlmSettings settings,
    required Duration timeout,
    Map<String, Object?>? body,
  }) async {
    final request = await _client.openUrl(method, uri).timeout(timeout);
    request.headers.contentType = ContentType.json;
    final apiKey = _effectiveApiKey(settings);
    if (settings.providerKind.usesAnthropicApi) {
      if (apiKey.isNotEmpty) {
        request.headers.set('x-api-key', apiKey);
      }
      request.headers.set('anthropic-version', '2023-06-01');
    } else if (apiKey.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    }
    if (body != null) {
      request.write(jsonEncode(body));
    }

    final response = await request.close().timeout(timeout);
    final responseBody = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final endpoint = uri.pathSegments.isEmpty
          ? uri.path
          : uri.pathSegments.last;
      throw LlmException(
        '$endpoint request failed: ${response.statusCode} $responseBody',
      );
    }
    return jsonDecode(responseBody);
  }

  Future<_LlmSseResult> _sendSse({
    required String method,
    required Uri uri,
    required LlmSettings settings,
    required Duration timeout,
    required void Function(Object? payload) onEvent,
    Map<String, Object?>? body,
  }) async {
    final request = await _client.openUrl(method, uri).timeout(timeout);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    final apiKey = _effectiveApiKey(settings);
    if (settings.providerKind.usesAnthropicApi) {
      if (apiKey.isNotEmpty) {
        request.headers.set('x-api-key', apiKey);
      }
      request.headers.set('anthropic-version', '2023-06-01');
    } else if (apiKey.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    }
    if (body != null) {
      request.write(jsonEncode(body));
    }

    final response = await request.close().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final responseBody = await response.transform(utf8.decoder).join();
      final endpoint = uri.pathSegments.isEmpty
          ? uri.path
          : uri.pathSegments.last;
      throw LlmException(
        '$endpoint request failed: ${response.statusCode} $responseBody',
      );
    }

    final textBuffer = StringBuffer();
    Object? finalPayload;
    final eventBuffer = StringBuffer();

    await for (final chunk in response.transform(utf8.decoder)) {
      eventBuffer.write(chunk);
      final buffered = eventBuffer.toString();
      final events = buffered.split('\n\n');
      eventBuffer
        ..clear()
        ..write(events.removeLast());
      for (final event in events) {
        final parsed = _parseSseData(event);
        if (parsed == null) {
          continue;
        }
        if (parsed == '[DONE]') {
          continue;
        }
        final payload = jsonDecode(parsed);
        onEvent(payload);
        final deltaText = _extractStreamText(
          payload,
          usesAnthropicApi: settings.providerKind.usesAnthropicApi,
        );
        if (deltaText.isNotEmpty) {
          textBuffer.write(deltaText);
        }
        final payloadUsage = _extractUsagePayload(
          payload,
          usesAnthropicApi: settings.providerKind.usesAnthropicApi,
        );
        if (payloadUsage != null) {
          finalPayload = payloadUsage;
        }
      }
    }

    return _LlmSseResult(
      text: textBuffer.toString(),
      finalPayload: finalPayload,
    );
  }

  String? _parseSseData(String rawEvent) {
    final dataLines = rawEvent
        .split('\n')
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5).trimLeft())
        .toList(growable: false);
    if (dataLines.isEmpty) {
      return null;
    }
    return dataLines.join('\n').trim();
  }

  String _extractStreamText(Object? payload, {required bool usesAnthropicApi}) {
    if (payload is! Map<String, Object?>) {
      return '';
    }
    if (usesAnthropicApi) {
      if (payload['type'] == 'content_block_delta') {
        final delta = payload['delta'];
        if (delta is Map<String, Object?> && delta['text'] is String) {
          return delta['text']! as String;
        }
      }
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
    final delta = first['delta'];
    if (delta is Map<String, Object?> && delta['content'] is String) {
      return delta['content']! as String;
    }
    return '';
  }

  Object? _extractUsagePayload(
    Object? payload, {
    required bool usesAnthropicApi,
  }) {
    if (payload is! Map<String, Object?>) {
      return null;
    }
    if (usesAnthropicApi) {
      if (payload['type'] == 'message_delta') {
        final usage = payload['usage'];
        if (usage is Map<String, Object?>) {
          return {'usage': usage};
        }
      }
      if (payload['type'] == 'message_stop') {
        final message = payload['message'];
        if (message is Map<String, Object?>) {
          return message;
        }
      }
      return null;
    }

    final usage = payload['usage'];
    if (usage is Map<String, Object?>) {
      return {'usage': usage};
    }
    return null;
  }

  Uri _uri(String baseUrl, String path) {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$trimmed/$path');
  }

  String _effectiveApiKey(LlmSettings settings) {
    if (settings.credentialMode == LlmCredentialMode.customApiKey) {
      return settings.apiKey.trim();
    }
    final appKey = Platform.environment['CHESS_AI_LLM_API_KEY']?.trim();
    if (appKey != null && appKey.isNotEmpty) {
      return appKey;
    }
    return (Platform.environment[settings.providerKind.apiKeyHint] ?? '')
        .trim();
  }

  void dispose() {
    _client.close(force: true);
  }
}

class _LlmSseResult {
  const _LlmSseResult({required this.text, required this.finalPayload});

  final String text;
  final Object? finalPayload;
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
