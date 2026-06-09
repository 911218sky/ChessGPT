import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chessgpt/src/models/engine_models.dart';
import 'package:chessgpt/src/services/stockfish_service.dart';

void main() {
  test('detectHardwareProfile prefers fewer default threads', () async {
    final service = StockfishService(windowsMemoryDetector: () async => 8192);

    final profile = await service.detectHardwareProfile();

    expect(
      profile.recommendedThreads,
      equals(math.max(1, math.min(2, Platform.numberOfProcessors - 4))),
    );
    expect(profile.recommendedHashMb, equals(160));
  });

  test('analyze sends UCI options and parses best move lines', () async {
    late _FakeProcess process;
    final service = StockfishService(
      processStarter: (_, _, {runInShell = false}) async {
        process = _FakeProcess(
          onCommand: (command, process) {
            switch (command) {
              case 'uci':
                process.emitStdout('uciok');
                return;
              case 'isready':
                process.emitStdout('readyok');
                return;
              case 'go depth 12':
                process
                  ..emitStdout(
                    'info depth 10 multipv 2 score mate -3 pv g1f3 g8f6',
                  )
                  ..emitStdout(
                    'info depth 12 multipv 1 score cp 34 pv e2e4 e7e5',
                  )
                  ..emitStdout('bestmove e2e4');
                return;
            }
          },
        );
        return process;
      },
    );

    final analysis = await service.analyze(
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      settings: const EngineSettings(
        moveTimeMs: 500,
        depth: 12,
        skillLevel: 8,
        limitStrength: true,
        elo: 1400,
        multiPv: 2,
        hashMb: 128,
        threads: 3,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(analysis.bestMoveUci, 'e2e4');
    expect(analysis.depth, 12);
    expect(analysis.lines, hasLength(2));
    expect(analysis.lines[0].multipv, 1);
    expect(analysis.lines[0].moveUci, 'e2e4');
    expect(analysis.lines[0].scoreType, 'cp');
    expect(analysis.lines[0].score, 34);
    expect(analysis.lines[1].multipv, 2);
    expect(analysis.lines[1].moveUci, 'g1f3');
    expect(analysis.lines[1].scoreType, 'mate');
    expect(analysis.lines[1].score, -3);
    expect(
      process.commands,
      containsAllInOrder([
        'uci',
        'setoption name Hash value 128',
        'setoption name Threads value 3',
        'setoption name Skill Level value 8',
        'setoption name LimitStrength value true',
        'setoption name UCI_Elo value 1400',
        'setoption name MultiPV value 2',
        'isready',
        'position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'go depth 12',
        'quit',
      ]),
    );
    await Future<void>.delayed(Duration.zero);
    expect(process.killed, isTrue);
  });

  test(
    'dispose cancels in-flight analysis and prevents new processes',
    () async {
      late _FakeProcess process;
      var startCount = 0;
      final service = StockfishService(
        processStarter: (_, _, {runInShell = false}) async {
          startCount += 1;
          process = _FakeProcess();
          return process;
        },
      );

      final analysisFuture = service.analyze(
        fen: 'startpos',
        settings: const EngineSettings(
          moveTimeMs: 10,
          multiPv: 1,
          hashMb: 64,
          threads: 1,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final cancellationExpectation = expectLater(
        analysisFuture,
        throwsA(isA<StockfishCancelledException>()),
      );
      await service.dispose();
      await cancellationExpectation;
      await Future<void>.delayed(Duration.zero);
      expect(process.killed, isTrue);

      await expectLater(
        service.analyze(
          fen: 'startpos',
          settings: const EngineSettings(
            moveTimeMs: 10,
            multiPv: 1,
            hashMb: 64,
            threads: 1,
          ),
        ),
        throwsA(isA<StockfishCancelledException>()),
      );
      expect(startCount, 1);
    },
  );
}

class _FakeProcess implements Process {
  _FakeProcess({void Function(String command, _FakeProcess process)? onCommand})
    : commands = <String>[] {
    _stdinConsumer = _CommandStreamConsumer();
    stdin = IOSink(_stdinConsumer);
    stdin.encoding = utf8;
    _stdinConsumer.onCommand = (command) {
      commands.add(command);
      onCommand?.call(command, this);
    };
  }

  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>();
  final Completer<int> _exitCode = Completer<int>();
  final List<String> commands;
  late final _CommandStreamConsumer _stdinConsumer;
  bool killed = false;

  @override
  late final IOSink stdin;

  @override
  int get pid => 1;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  void emitStdout(String line) {
    if (!_stdoutController.isClosed) {
      _stdoutController.add(utf8.encode('$line\n'));
    }
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!_exitCode.isCompleted) {
      _exitCode.complete(0);
    }
    unawaited(_stdoutController.close());
    unawaited(_stderrController.close());
    return true;
  }
}

class _CommandStreamConsumer implements StreamConsumer<List<int>> {
  void Function(String command)? onCommand;
  String _pending = '';

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _pending += utf8.decode(chunk);
      final parts = _pending.split(RegExp(r'\r?\n'));
      _pending = parts.removeLast();
      for (final command in parts) {
        final trimmed = command.trim();
        if (trimmed.isNotEmpty) {
          onCommand?.call(trimmed);
        }
      }
    }
  }

  @override
  Future<void> close() async {
    final trimmed = _pending.trim();
    if (trimmed.isNotEmpty) {
      onCommand?.call(trimmed);
    }
    _pending = '';
  }
}
