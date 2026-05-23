import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:io';

import 'package:chess_ai_desktop/src/models/session_config.dart';
import 'package:chess_ai_desktop/src/services/local_settings_store.dart';

void main() {
  test(
    'serializes preference and LLM writes without dropping either payload',
    () async {
      Map<String, Object?> persisted = <String, Object?>{};

      final store = LocalSettingsStore(
        readSettingsJson: () async => Map<String, Object?>.from(persisted),
        writeSettingsJson: (json) async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
          persisted = Map<String, Object?>.from(json);
        },
      );

      final preferences = GameSessionConfig.defaults().copyWith(
        difficulty: DifficultyLevel.hard,
      );
      const llm = LlmSettings(enabled: true, model: 'model-b');

      await Future.wait([
        store.savePreferences(preferences),
        store.saveLlmSettings(llm),
      ]);

      expect(persisted['preferences'], isA<Map<String, Object?>>());
      expect(persisted['llm'], isA<Map<String, Object?>>());

      final savedPreferences =
          persisted['preferences']! as Map<String, Object?>;
      final savedLlm = persisted['llm']! as Map<String, Object?>;

      expect(savedPreferences['difficulty'], DifficultyLevel.hard.name);
      expect(savedLlm['enabled'], isTrue);
      expect(savedLlm['model'], 'model-b');
    },
  );

  test('stores settings.json inside the provided portable directory', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'chess-ai-settings-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final store = LocalSettingsStore(baseDirectory: tempDirectory);
    final preferences = GameSessionConfig.defaults().copyWith(
      difficulty: DifficultyLevel.hard,
    );

    await store.savePreferences(preferences);

    final settingsFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}settings.json',
    );
    expect(await settingsFile.exists(), isTrue);
    expect(settingsFile.parent.path, tempDirectory.path);

    final decoded = jsonDecode(await settingsFile.readAsString());
    expect(decoded, isA<Map<String, Object?>>());
    final persisted = decoded as Map<String, Object?>;
    expect(persisted['preferences'], isA<Map<String, Object?>>());

    final savedPreferences = persisted['preferences']! as Map<String, Object?>;
    expect(savedPreferences['difficulty'], DifficultyLevel.hard.name);
  });
}
