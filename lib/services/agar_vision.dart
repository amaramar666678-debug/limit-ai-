import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'mouse_controller.dart';
import 'screen_vision.dart';

class _Blob {
  _Blob(this.x, this.y, this.r, this.g, this.b, this.count);

  final double x;
  final double y;
  final int r;
  final int g;
  final int b;
  final int count;

  Offset get center => Offset(x, y);
  double get radius => math.sqrt(count * 9 / math.pi); // grid step = 3
}

/// Outcome of one play session, used by the UI so it never claims the task
/// finished when the game was never actually detected.
class AgarPlayResult {
  const AgarPlayResult({
    required this.detectedGame,
    required this.moves,
    required this.captures,
  });

  final bool detectedGame;
  final int moves;
  final int captures;
}

/// Reads the actual game screen and plays agar.io by its rules.
class AgarVision {
  static Future<AgarPlayResult> play(
    MouseController controller, {
    int durationMs = 30000,
  }) async {
    final stopwatch = Stopwatch()..start();
    final rng = math.Random(DateTime.now().microsecondsSinceEpoch);
    final screen = controller.screenSize();
    var current = controller.screenCenter();
    var lastSplit = DateTime.now().subtract(const Duration(seconds: 4));
    var captures = 0;
    var moves = 0;
    var detectedGame = false;

    Offset clampPoint(Offset p) => Offset(
          p.dx.clamp(8.0, screen.width - 8).toDouble(),
          p.dy.clamp(110, screen.height - 20).toDouble(),
        );

    Future<void> wander(Offset center) async {
      final target = clampPoint(_randomPoint(center, 160, rng));
      await controller.glideTo(current, target, steps: 12);
      current = target;
      moves++;
    }

    while (!controller.cancelled && stopwatch.elapsedMilliseconds < durationMs) {
      ScreenCapture cap;
      try {
        cap = ScreenCapture.capture();
      } catch (_) {
        // Capture can fail briefly while Chrome paints a new page. Keep playing
        // instead of ending the task.
        await wander(controller.screenCenter());
        continue;
      }

      captures++;
      try {
        final blobs = _blobs(cap);
        final arenaCenter = Offset(
          cap.left + cap.width / 2,
          cap.top + cap.height / 2,
        );
        final own = _ownCell(blobs, arenaCenter);

        if (own == null || blobs.length < 2) {
          // The game canvas was not recognised yet. Move like a player and wait
          // for the next frame rather than reporting completion.
          await wander(arenaCenter);
          continue;
        }

        detectedGame = true;
        final others = blobs.where((b) => b != own).toList();
        final threats = <_Blob>[
          ...others.where((b) =>
              b.radius > own.radius * 1.18 &&
              _distance(b.center, own.center) < 340),
        ]..sort((a, b) => _distance(a.center, own.center).compareTo(
              _distance(b.center, own.center)));

        final food = <_Blob>[
          ...others.where((b) =>
              b.radius < own.radius * 0.78 &&
              _distance(b.center, own.center) < 620),
        ]..sort((a, b) => _distance(a.center, own.center).compareTo(
              _distance(b.center, own.center)));

        Offset target;
        if (threats.isNotEmpty) {
          // Flee the nearest bigger cell.
          final t = threats.first;
          final dx = own.x - t.x;
          final dy = own.y - t.y;
          final len = math.max(1.0, math.sqrt(dx * dx + dy * dy));
          target = clampPoint(
            Offset(own.x + dx / len * 260, own.y + dy / len * 260),
          );
        } else if (food.isNotEmpty) {
          // Eat the nearest smaller cell / pellet.
          final f = food.first;
          target = clampPoint(f.center);
          final d = _distance(f.center, own.center);
          if (f.radius > own.radius * 0.40 &&
              d < 190 &&
              DateTime.now().difference(lastSplit) > const Duration(seconds: 2)) {
            await controller.pressSpace();
            lastSplit = DateTime.now();
          }
        } else {
          target = clampPoint(_randomPoint(arenaCenter, 180, rng));
        }

        await controller.glideTo(current, target, steps: 12);
        current = target;
        moves++;
      } finally {
        cap.dispose();
      }
      await Future<void>.delayed(const Duration(milliseconds: 35));
    }

    return AgarPlayResult(
      detectedGame: detectedGame,
      moves: moves,
      captures: captures,
    );
  }

  /// One-shot diagnostic used by `tool/run_agar_once.dart`.
  static Future<String> debugInspect() async {
    try {
      final cap = ScreenCapture.capture();
      try {
        final blobs = _blobs(cap);
        final center = Offset(
          cap.left + cap.width / 2,
          cap.top + cap.height / 2,
        );
        final own = _ownCell(blobs, center);
        final radii = blobs.map((b) => b.radius).toList()
          ..sort((a, b) => b.compareTo(a));
        return 'capture=${cap.width}x${cap.height}@(${cap.left},${cap.top}) '
            'blobs=${blobs.length} '
            'own=${own == null ? 'none' : 'r${own.radius.toStringAsFixed(1)}@(${own.x.round()},${own.y.round()})'} '
            'topRadii=${radii.take(6).map((r) => r.toStringAsFixed(1)).join(',')}';
      } finally {
        cap.dispose();
      }
    } catch (e) {
      return 'capture failed: $e';
    }
  }

  static List<_Blob> _blobs(ScreenCapture cap) {
    const step = 3;
    final gw = cap.width ~/ step;
    final gh = cap.height ~/ step;
    final mask = Uint8List(gw * gh);
    final minY = 110 - cap.top;
    final maxY = cap.top + cap.height - 55;

    for (var gy = 0; gy < gh; gy++) {
      final screenY = cap.top + gy * step;
      if (screenY < minY || screenY > maxY) continue;
      for (var gx = 0; gx < gw; gx++) {
        final x = gx * step;
        final y = gy * step;
        final r = cap.redAt(x, y);
        final g = cap.greenAt(x, y);
        final b = cap.blueAt(x, y);
        final hi = math.max(r, math.max(g, b));
        final lo = math.min(r, math.min(g, b));
        // Lower threshold than before: agar.io cells are often pastel, not
        // fully saturated.
        if (hi - lo > 26 && hi > 115 && lo < 244) {
          mask[gy * gw + gx] = 1;
        }
      }
    }

    final visited = Uint8List(mask.length);
    final blobs = <_Blob>[];
    for (var i = 0; i < mask.length; i++) {
      if (mask[i] == 0 || visited[i] == 1) continue;
      final queue = <int>[i];
      visited[i] = 1;
      var sx = 0.0;
      var sy = 0.0;
      var sr = 0;
      var sg = 0;
      var sb = 0;
      var count = 0;
      while (queue.isNotEmpty) {
        final idx = queue.removeLast();
        final gx = idx % gw;
        final gy = idx ~/ gw;
        sx += gx;
        sy += gy;
        final r = cap.redAt(gx * step, gy * step);
        final g = cap.greenAt(gx * step, gy * step);
        final b = cap.blueAt(gx * step, gy * step);
        sr += r;
        sg += g;
        sb += b;
        count++;
        for (final n in [idx - 1, idx + 1, idx - gw, idx + gw]) {
          if (n < 0 || n >= mask.length) continue;
          if ((n == idx - 1 && gx == 0) || (n == idx + 1 && gx == gw - 1)) {
            continue;
          }
          if (visited[n] == 0 && mask[n] == 1) {
            visited[n] = 1;
            queue.add(n);
          }
        }
      }
      if (count < 3 || count > 2400) continue;
      final radius = math.sqrt(count * step * step / math.pi);
      if (radius < 3.0 || radius > 170) continue;
      blobs.add(_Blob(
        cap.left + (sx / count) * step,
        cap.top + (sy / count) * step,
        sr ~/ count,
        sg ~/ count,
        sb ~/ count,
        count,
      ));
    }
    return blobs;
  }

  static _Blob? _ownCell(List<_Blob> blobs, Offset center) {
    _Blob? best;
    for (final b in blobs) {
      if (b.radius < 8 || b.radius > 140) continue;
      // The camera follows the player: our cell is the largest cell close to
      // the arena centre. Nearby pellets must not be mistaken for it.
      if (_distance(b.center, center) > 110) continue;
      if (best == null || b.radius > best.radius) best = b;
    }
    return best;
  }

  static double _distance(Offset a, Offset b) =>
      math.sqrt(math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2));

  static Offset _randomPoint(Offset center, double radius, math.Random rng) {
    final a = rng.nextDouble() * math.pi * 2;
    const r = 0.4;
    final distance = radius * (r + rng.nextDouble() * 0.8);
    return Offset(
      center.dx + math.cos(a) * distance,
      center.dy + math.sin(a) * distance,
    );
  }
}
