import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../models/engine_models.dart';

typedef StockfishProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      bool runInShell,
    });

class StockfishService {
  StockfishService({
    StockfishProcessStarter? processStarter,
    Future<int?> Function()? windowsMemoryDetector,
  }) : _processStarter = processStarter ?? Process.start,
       _windowsMemoryDetector =
           windowsMemoryDetector ?? _defaultDetectWindowsMemoryMb;

  final StockfishProcessStarter _processStarter;
  final Future<int?> Function() _windowsMemoryDetector;
  final Set<void Function()> _activeAnalysisCancels = <void Function()>{};
  bool _disposed = false;

  Future<EngineHardwareProfile> detectHardwareProfile() async {
    final cores = Platform.numberOfProcessors;
    final detectedMemoryMb = await _windowsMemoryDetector();
    final usableMemoryMb = detectedMemoryMb ?? 4096;
    // Keep auto-detected defaults conservative so desktop play does not
    // monopolize CPU or RAM unless the user explicitly opts in.
    final recommendedThreads = math.max(1, math.min(2, cores - 4));
    final recommendedHashMb = math.max(
      48,
      math.min(160, ((usableMemoryMb * 0.02) / 16).round() * 16),
    );

    return EngineHardwareProfile(
      cpuThreads: cores,
      memoryMb: detectedMemoryMb,
      recommendedThreads: recommendedThreads,
      recommendedHashMb: recommendedHashMb,
    );
  }

  Future<EngineAnalysis> analyze({
    required String fen,
    required EngineSettings settings,
  }) async {
    if (_disposed) {
      throw const StockfishCancelledException();
    }
    final startedAt = DateTime.now();
    final executable = await _resolveStockfishExecutable();
    final process = await _processStarter(
      executable,
      const [],
      runInShell: false,
    );
    if (_disposed) {
      process.kill();
      throw const StockfishCancelledException();
    }
    final completer = Completer<EngineAnalysis>();
    final lines = <int, EngineLine>{};
    var readyForSearch = false;
    var sawUciOk = false;
    var bestMove = '';
    var maxDepth = 0;
    late final void Function() cancelAnalysis;

    late final StreamSubscription<String> stdoutSubscription;
    late final StreamSubscription<String> stderrSubscription;
    Future<void> cleanup() async {
      _activeAnalysisCancels.remove(cancelAnalysis);
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
      process.kill();
    }

    Future<void> completeWithError(Object error) async {
      if (completer.isCompleted) {
        return;
      }
      completer.completeError(error);
      await cleanup();
    }

    Future<void> completeSuccessfully() async {
      if (completer.isCompleted) {
        return;
      }
      final orderedLines = lines.values.toList()
        ..sort((a, b) => a.multipv.compareTo(b.multipv));
      completer.complete(
        EngineAnalysis(
          bestMoveUci: bestMove,
          depth: maxDepth,
          lines: orderedLines,
          elapsedMs: DateTime.now().difference(startedAt).inMilliseconds,
        ),
      );
      await cleanup();
    }

    cancelAnalysis = () {
      unawaited(completeWithError(const StockfishCancelledException()));
    };
    _activeAnalysisCancels.add(cancelAnalysis);

    stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) {
            return;
          }

          if (trimmed == 'uciok') {
            sawUciOk = true;
            process.stdin.writeln(
              'setoption name Hash value ${settings.hashMb}',
            );
            process.stdin.writeln(
              'setoption name Threads value ${settings.threads}',
            );
            if (settings.skillLevel case final int skillLevel
                when skillLevel >= 0) {
              process.stdin.writeln(
                'setoption name Skill Level value $skillLevel',
              );
            }
            process.stdin.writeln(
              'setoption name LimitStrength value ${settings.limitStrength ? 'true' : 'false'}',
            );
            final elo = settings.elo;
            if (settings.limitStrength && elo != null && elo > 0) {
              process.stdin.writeln('setoption name UCI_Elo value $elo');
            }
            process.stdin.writeln(
              'setoption name MultiPV value ${settings.multiPv}',
            );
            process.stdin.writeln('isready');
            return;
          }

          if (trimmed == 'readyok' && sawUciOk && !readyForSearch) {
            readyForSearch = true;
            process.stdin.writeln('position fen $fen');
            final depth = settings.depth;
            if (depth != null && depth > 0) {
              process.stdin.writeln('go depth $depth');
            } else {
              process.stdin.writeln('go movetime ${settings.moveTimeMs}');
            }
            return;
          }

          if (trimmed.startsWith('info ')) {
            final parsedLine = _parseInfoLine(trimmed);
            if (parsedLine != null) {
              lines[parsedLine.multipv] = parsedLine;
              if (parsedLine.depth > maxDepth) {
                maxDepth = parsedLine.depth;
              }
            }
            return;
          }

          if (trimmed.startsWith('bestmove ')) {
            bestMove = trimmed.split(' ').elementAtOrNull(1) ?? '';
            completeSuccessfully();
          }
        });

    stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line.trim().isEmpty) {
            return;
          }
          completeWithError(Exception('Stockfish error: ${line.trim()}'));
        });

    process.stdin.writeln('uci');

    final timeout = Timer(const Duration(seconds: 20), () {
      completeWithError(
        TimeoutException('Stockfish analysis timed out for current position.'),
      );
    });

    try {
      final analysis = await completer.future;
      timeout.cancel();
      process.stdin.writeln('quit');
      return analysis;
    } catch (error) {
      timeout.cancel();
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final cancels = _activeAnalysisCancels.toList(growable: false);
    _activeAnalysisCancels.clear();
    for (final cancel in cancels) {
      cancel();
    }
  }

  Future<String> _resolveStockfishExecutable() async {
    if (!Platform.isWindows) {
      return 'stockfish';
    }

    final appDirectory = File(Platform.resolvedExecutable).parent.path;
    final bundledExecutable = File('$appDirectory\\stockfish.exe');
    if (await bundledExecutable.exists()) {
      return bundledExecutable.path;
    }

    return 'stockfish';
  }

  static Future<int?> _defaultDetectWindowsMemoryMb() async {
    if (!Platform.isWindows) {
      return null;
    }
    try {
      final result = await Process.run('powershell', const [
        '-NoProfile',
        '-Command',
        r'(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory',
      ]);
      final raw = result.stdout.toString().trim();
      final bytes = int.tryParse(raw);
      if (bytes == null || bytes <= 0) {
        return null;
      }
      return (bytes / (1024 * 1024)).round();
    } catch (_) {
      return null;
    }
  }

  EngineLine? _parseInfoLine(String line) {
    final pvMatch = RegExp(r'\bpv\s+(.+)$').firstMatch(line);
    if (pvMatch == null) {
      return null;
    }

    final depthMatch = RegExp(r'\bdepth\s+(\d+)').firstMatch(line);
    final multiPvMatch = RegExp(r'\bmultipv\s+(\d+)').firstMatch(line);
    final scoreMatch = RegExp(
      r'\bscore\s+(cp|mate)\s+(-?\d+)',
    ).firstMatch(line);
    final pv = pvMatch.group(1)!.trim().split(RegExp(r'\s+'));

    if (pv.isEmpty) {
      return null;
    }

    return EngineLine(
      multipv: int.tryParse(multiPvMatch?.group(1) ?? '1') ?? 1,
      moveUci: pv.first,
      pv: pv,
      depth: int.tryParse(depthMatch?.group(1) ?? '0') ?? 0,
      scoreType: scoreMatch?.group(1),
      score: int.tryParse(scoreMatch?.group(2) ?? ''),
    );
  }
}

class StockfishCancelledException implements Exception {
  const StockfishCancelledException();

  @override
  String toString() => 'Stockfish analysis cancelled.';
}
