import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../models/engine_models.dart';

const _stockfishScriptPath = 'stockfish/stockfish-17.1-lite-single-03e3232.js';

class StockfishService {
  StockfishService();

  final Set<void Function()> _activeAnalysisCancels = <void Function()>{};
  bool _disposed = false;

  Future<EngineHardwareProfile> detectHardwareProfile() async {
    final cores = web.window.navigator.hardwareConcurrency;
    return EngineHardwareProfile(
      runtime: EngineRuntime.browserWorkerWasm,
      cpuThreads: cores,
      memoryMb: null,
      recommendedThreads: 1,
      recommendedHashMb: 64,
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
    final worker = _startWorker();
    final completer = Completer<EngineAnalysis>();
    final lines = <int, EngineLine>{};
    var readyForSearch = false;
    var sawUciOk = false;
    var bestMove = '';
    var maxDepth = 0;
    late final void Function() cancelAnalysis;

    late final StreamSubscription<web.MessageEvent> messageSubscription;
    late final StreamSubscription<web.Event> errorSubscription;

    void send(String command) {
      worker.postMessage(command.toJS);
    }

    final hashMb = _clamp(settings.hashMb, min: 16, max: 64);
    final multiPv = _clamp(settings.multiPv, min: 1, max: 3);
    final moveTimeMs = _clamp(settings.moveTimeMs, min: 100, max: 3000);
    final depth = settings.depth == null
        ? null
        : _clamp(settings.depth!, min: 1, max: 18);

    Future<void> cleanup() async {
      _activeAnalysisCancels.remove(cancelAnalysis);
      await messageSubscription.cancel();
      await errorSubscription.cancel();
      worker.terminate();
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

    messageSubscription = web.EventStreamProviders.messageEvent
        .forTarget(worker)
        .listen((event) {
          final trimmed = event.data.dartify()?.toString().trim() ?? '';
          if (trimmed.isEmpty) {
            return;
          }

          if (trimmed == 'uciok') {
            sawUciOk = true;
            send('setoption name Hash value $hashMb');
            send('setoption name Threads value 1');
            if (settings.skillLevel case final int skillLevel
                when skillLevel >= 0) {
              send('setoption name Skill Level value $skillLevel');
            }
            send(
              'setoption name LimitStrength value ${settings.limitStrength ? 'true' : 'false'}',
            );
            final elo = settings.elo;
            if (settings.limitStrength && elo != null && elo > 0) {
              send('setoption name UCI_Elo value $elo');
            }
            send('setoption name MultiPV value $multiPv');
            send('isready');
            return;
          }

          if (trimmed == 'readyok' && sawUciOk && !readyForSearch) {
            readyForSearch = true;
            send('position fen $fen');
            if (depth != null && depth > 0) {
              send('go depth $depth');
            } else {
              send('go movetime $moveTimeMs');
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
            final reportedMove = trimmed.split(' ').elementAtOrNull(1) ?? '';
            bestMove = reportedMove == '(none)' ? '' : reportedMove;
            if (bestMove.isEmpty) {
              unawaited(
                completeWithError(
                  Exception(
                    'Stockfish did not return a legal best move for this position.',
                  ),
                ),
              );
              return;
            }
            unawaited(completeSuccessfully());
          }
        });

    errorSubscription = web.EventStreamProviders.errorWorkerEvent
        .forTarget(worker)
        .listen((event) {
          unawaited(
            completeWithError(Exception('Stockfish worker error: $event')),
          );
        });

    send('uci');

    final timeout = Timer(const Duration(seconds: 20), () {
      unawaited(
        completeWithError(
          TimeoutException(
            'Stockfish analysis timed out for current position.',
          ),
        ),
      );
    });

    try {
      final analysis = await completer.future;
      timeout.cancel();
      return analysis;
    } catch (_) {
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

  web.Worker _startWorker() {
    try {
      return web.Worker(_stockfishScriptPath.toJS);
    } catch (error) {
      throw Exception(
        'Stockfish Web Worker could not start. The browser must support Web Workers and WebAssembly, and the stockfish assets must be served from web/stockfish/. Error: $error',
      );
    }
  }

  int _clamp(int value, {required int min, required int max}) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
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
