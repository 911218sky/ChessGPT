import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_ai_desktop/src/models/session_config.dart';
import 'package:chess_ai_desktop/src/services/llm_commentary_service.dart';

void main() {
  test(
    'fetchModels sends authorization and returns sorted model ids',
    () async {
      final server = await _TestLlmServer.start((request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/v1/models');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer k',
        );
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'data': [
                {'id': 'z-model'},
                {'id': 'a-model'},
              ],
            }),
          );
        await request.response.close();
      });
      addTearDown(server.close);

      final service = LlmCommentaryService();
      addTearDown(service.dispose);

      final models = await service.fetchModels(_settings(server, apiKey: 'k'));

      expect(models, ['a-model', 'z-model']);
    },
  );

  test('complete streams OpenAI-compatible text and usage', () async {
    Map<String, Object?>? requestBody;
    final server = await _TestLlmServer.start((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/v1/chat/completions');
      expect(
        request.headers.value(HttpHeaders.acceptHeader),
        'text/event-stream',
      );
      requestBody =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, Object?>;
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: {"choices":[{"delta":{"content":"Hello "}}]}\n\n',
      );
      request.response.write(
        'data: {"choices":[{"delta":{"content":"world"}}],"usage":{"prompt_tokens":7,"completion_tokens":3,"total_tokens":10}}\n\n',
      );
      await request.response.close();
    });
    addTearDown(server.close);

    final service = LlmCommentaryService();
    addTearDown(service.dispose);
    final partials = <String>[];

    final result = await service.complete(
      settings: _settings(server, apiKey: 'k', model: 'model-a'),
      systemPrompt: 'system',
      userPrompt: 'user',
      onPartial: partials.add,
    );

    expect(requestBody?['model'], 'model-a');
    expect(requestBody?['stream'], isTrue);
    expect(result.text, 'Hello world');
    expect(partials, ['Hello ', 'world']);
    expect(result.usage?.promptTokens, 7);
    expect(result.usage?.completionTokens, 3);
    expect(result.usage?.totalTokens, 10);
  });

  test('complete ignores an unterminated trailing SSE event', () async {
    final server = await _TestLlmServer.start((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: {"choices":[{"delta":{"content":"kept"}}]}\n\n',
      );
      request.response.write(
        'data: {"choices":[{"delta":{"content":"ignored"}}]}',
      );
      await request.response.close();
    });
    addTearDown(server.close);

    final service = LlmCommentaryService();
    addTearDown(service.dispose);

    final result = await service.complete(
      settings: _settings(server),
      systemPrompt: 'system',
      userPrompt: 'user',
    );

    expect(result.text, 'kept');
  });

  test('complete includes endpoint and body in non-2xx errors', () async {
    final server = await _TestLlmServer.start((request) async {
      await request.drain<void>();
      request.response
        ..statusCode = 500
        ..write('bad gateway');
      await request.response.close();
    });
    addTearDown(server.close);

    final service = LlmCommentaryService();
    addTearDown(service.dispose);

    await expectLater(
      service.complete(
        settings: _settings(server),
        systemPrompt: 'system',
        userPrompt: 'user',
      ),
      throwsA(
        isA<LlmException>().having(
          (error) => error.message,
          'message',
          contains('completions request failed: 500 bad gateway'),
        ),
      ),
    );
  });
}

LlmSettings _settings(
  _TestLlmServer server, {
  String apiKey = '',
  String model = 'test-model',
}) {
  return LlmSettings(
    enabled: true,
    providerKind: LlmProviderKind.openAiCompatible,
    provider: 'Test',
    baseUrl: server.baseUrl,
    model: model,
    credentialMode: apiKey.isEmpty
        ? LlmCredentialMode.defaultProxy
        : LlmCredentialMode.customApiKey,
    apiKey: apiKey,
  );
}

class _TestLlmServer {
  const _TestLlmServer(this._server);

  final HttpServer _server;

  String get baseUrl => 'http://127.0.0.1:${_server.port}/v1';

  static Future<_TestLlmServer> start(
    Future<void> Function(HttpRequest request) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(handler);
    return _TestLlmServer(server);
  }

  Future<void> close() => _server.close(force: true);
}
