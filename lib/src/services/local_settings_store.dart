import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/session_config.dart';

class LocalSettingsStore {
  LocalSettingsStore({
    Directory? baseDirectory,
    Future<Map<String, Object?>?> Function()? readSettingsJson,
    Future<void> Function(Map<String, Object?> json)? writeSettingsJson,
  }) : _baseDirectory = baseDirectory,
       _readSettingsJsonOverride = readSettingsJson,
       _writeSettingsJsonOverride = writeSettingsJson;

  final Directory? _baseDirectory;
  final Future<Map<String, Object?>?> Function()? _readSettingsJsonOverride;
  final Future<void> Function(Map<String, Object?> json)?
  _writeSettingsJsonOverride;
  Future<void> _writeQueue = Future<void>.value();

  Future<GameSessionConfig?> loadPreferences({required LlmSettings llm}) async {
    final json = await _readSettingsJson();
    if (json == null) {
      return null;
    }

    final preferences = json['preferences'];
    if (preferences is! Map<String, Object?>) {
      return null;
    }
    return GameSessionConfig.fromPreferencesJson(preferences, llm: llm);
  }

  Future<LlmSettings?> loadLlmSettings() async {
    final json = await _readSettingsJson();
    if (json == null) {
      return null;
    }

    final llm = json['llm'];
    if (llm is! Map<String, Object?>) {
      return null;
    }
    return LlmSettings.fromJson(llm);
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

  Future<Map<String, Object?>?> _readSettingsJson() async {
    final override = _readSettingsJsonOverride;
    if (override != null) {
      return override();
    }

    final file = await _settingsFile();
    if (!await file.exists()) {
      return null;
    }

    final jsonText = await file.readAsString();
    final decoded = jsonDecode(jsonText);
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

    final file = await _settingsFile();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(json));
  }

  Future<File> _settingsFile() async {
    final directory =
        _baseDirectory?.path ?? File(Platform.resolvedExecutable).parent.path;
    return File('$directory${Platform.pathSeparator}settings.json');
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
