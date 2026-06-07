import 'dart:async';
import 'dart:convert';

import 'package:web/web.dart' as web;

import '../models/session_config.dart';

class LocalSettingsStore {
  LocalSettingsStore({
    Object? baseDirectory,
    Future<Map<String, Object?>?> Function()? readSettingsJson,
    Future<void> Function(Map<String, Object?> json)? writeSettingsJson,
  }) : _readSettingsJsonOverride = readSettingsJson,
       _writeSettingsJsonOverride = writeSettingsJson;

  static const _storageKey = 'chess_ai_desktop.settings';
  static const _webDefaultLlmAppliedKey = 'webDefaultLlmApplied';
  static const _defaultLlmEnabled = bool.fromEnvironment(
    'CHESS_AI_DEFAULT_LLM_ENABLED',
  );
  static const _defaultProxyBaseUrl = String.fromEnvironment(
    'CHESS_AI_WEB_LLM_PROXY_BASE_URL',
  );
  static const _defaultLlmModel = String.fromEnvironment(
    'CHESS_AI_DEFAULT_LLM_MODEL',
    defaultValue: 'GPT-5.4',
  );

  final Future<Map<String, Object?>?> Function()? _readSettingsJsonOverride;
  final Future<void> Function(Map<String, Object?> json)?
  _writeSettingsJsonOverride;
  Future<void> _writeQueue = Future<void>.value();

  Future<GameSessionConfig?> loadPreferences({required LlmSettings llm}) async {
    final json = await _readSettingsJson();
    final preferences = json?['preferences'];
    if (preferences is! Map<String, Object?>) {
      return null;
    }
    return GameSessionConfig.fromPreferencesJson(preferences, llm: llm);
  }

  Future<LlmSettings?> loadLlmSettings() async {
    final json = await _readSettingsJson();
    final llm = json?['llm'];
    if (llm is! Map<String, Object?>) {
      return null;
    }
    final settings = LlmSettings.fromJson(llm);
    if (json != null && _shouldApplyWebDefaultLlm(json, settings)) {
      final migrated = settings.copyWith(
        providerKind: LlmProviderKind.openAiCompatible,
        enabled: true,
        provider: 'OpenAI Compatible',
        baseUrl: _defaultProxyBaseUrl.trim(),
        model: _defaultLlmModel.trim().isNotEmpty
            ? _defaultLlmModel.trim()
            : settings.model,
        credentialMode: LlmCredentialMode.defaultProxy,
        apiKey: '',
      );
      await _saveWebDefaultLlmMigration(json, migrated);
      return migrated;
    }
    return settings;
  }

  Future<void> savePreferences(GameSessionConfig config) async {
    await _enqueueWrite(() async {
      final json = await _readSettingsJson() ?? <String, Object?>{};
      json['preferences'] = config.toPreferencesJson();
      await _writeSettingsJson(json);
    });
  }

  Future<void> saveLlmSettings(LlmSettings settings) async {
    await _enqueueWrite(() async {
      final json = await _readSettingsJson() ?? <String, Object?>{};
      json['llm'] = settings.toJson();
      await _writeSettingsJson(json);
    });
  }

  Future<void> resetPreferences() async {
    await savePreferences(GameSessionConfig.defaults());
  }

  Future<void> resetLlmSettings() async {
    await saveLlmSettings(const LlmSettings());
  }

  bool _shouldApplyWebDefaultLlm(
    Map<String, Object?> json,
    LlmSettings settings,
  ) {
    if (!_defaultLlmEnabled || _defaultProxyBaseUrl.trim().isEmpty) {
      return false;
    }
    if (json[_webDefaultLlmAppliedKey] == true) {
      return false;
    }
    if (settings.credentialMode != LlmCredentialMode.defaultProxy ||
        settings.apiKey.trim().isNotEmpty) {
      return false;
    }
    return !settings.enabled || _looksLikePublicProvider(settings.baseUrl);
  }

  Future<void> _saveWebDefaultLlmMigration(
    Map<String, Object?> json,
    LlmSettings settings,
  ) async {
    await _enqueueWrite(() async {
      final latest = await _readSettingsJson() ?? json;
      latest['llm'] = settings.toJson();
      latest[_webDefaultLlmAppliedKey] = true;
      await _writeSettingsJson(latest);
    });
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

  Future<Map<String, Object?>?> _readSettingsJson() async {
    final override = _readSettingsJsonOverride;
    if (override != null) {
      return override();
    }
    final encoded = web.window.localStorage.getItem(_storageKey);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(encoded);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    return null;
  }

  Future<void> _writeSettingsJson(Map<String, Object?> json) async {
    final override = _writeSettingsJsonOverride;
    if (override != null) {
      await override(json);
      return;
    }
    web.window.localStorage.setItem(_storageKey, jsonEncode(json));
  }

  Future<void> _enqueueWrite(Future<void> Function() action) async {
    final previous = _writeQueue;
    final completer = Completer<void>();
    _writeQueue = previous.catchError((_, _) {}).then((_) => action());
    _writeQueue
        .then((_) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        });
    await completer.future;
  }
}
