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
  double get radius => math.sqrt(count * 9 / math.pi); // step = 3
}

/// Reads the actual game screen and plays agar.io by its rules.
class AgarVision {
  static Future<void> play(
    MouseController controller, {
    int durationMs = 30000,
  }) async {
    final stopwatch = Stopwatch()..start();
    final rng = math.Random(DateTime.now().microsecondsSinceEpoch);
    var current = controller.screenCenter();
    var lastSplit = DateTime.now().subtract(const Duration(seconds: 4));

    while (!controller.cancelled && stopwatch.elapsedMilliseconds < durationMs) {
      ScreenCapture cap;
      try {
        cap = ScreenCapture.capture();
      } catch (_) {
        await controller.glideTo(
          current,
          _randomPoint(controller.screenCenter(), 140, rng),
          steps: 8,
        );
        current = controller.screenCenter();
        continue;
      }

      try {
        final blobs = _blobs(cap);
        final arenaCenter = Offset(
          cap.left + cap.width / 2,
          cap.top + cap.height / 2,
        );
        final own = _ownCell(blobs, arenaCenter);
        if (own == null || blobs.length < 2) {
          await controller.glideTo(
            current,
            _randomPoint(arenaCenter, 130, rng),
            steps: 10,
          );
          current = arenaCenter;
          continue;
        }

        final others = blobs.where((b) => b != own).toList();
        final threats = <_Blob>[
          ...others.where((b) =>
              b.radius > own.radius * 1.18 && _distance(b.center, own.center) < 320),
        ]..sort((a, b) => _distance(a.center, own.center).compareTo(_distance(b.center, own.center)));

        final food = <_Blob>[
          ...others.where((b) =>
              b.radius < own.radius * 0.78 && _distance(b.center, own.center) < 560),
        ]..sort((a, b) => _distance(a.center, own.center).compareTo(_distance(b.center, own.center)));

        Offset target;
        if (threats.isNotEmpty) {
          final t = threats.first;
          final dx = own.x - t.x;
          final dy = own.y - t.y;
          final len = math.max(1.0, math.sqrt(dx * dx + dy * dy));
          target = Offset(own.x + dx / len * 230, own.y + dy / len * 230);
        } else if (food.isNotEmpty) {
          final f = food.first;
          target = f.center;
          final d = _distance(f.center, own.center);
          if (f.radius > own.radius * 0.42 &&
              d < 180 &&
              DateTime.now().difference(lastSplit) > const Duration(seconds: 2)) {
            await controller.pressSpace();
            lastSplit = DateTime.now();
          }
        } else {
          target = _randomPoint(arenaCenter, 170, rng);
        }

        final screen = controller.screenSize();
        target = Offset(
          target.dx.clamp(10.0, screen.width - 10).toDouble(),
          target.dy.clamp(10.0, screen.height - 10).toDouble(),
        );
        await controller.glideTo(current, target, steps: 12);
        current = target;
      } finally {
        cap.dispose();
      }
      await Future<void>.delayed(const Duration(milliseconds: 35));
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
        if (hi - lo > 42 && hi > 100 && lo < 235) {
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
          if ((n == idx - 1 && gx == 0) || (n == idx + 1 && gx == gw - 1)) continue;
          if (visited[n] == 0 && mask[n] == 1) {
            visited[n] = 1;
            queue.add(n);
          }
        }
      }
      if (count < 3 || count > 1800) continue;
      final radius = math.sqrt(count * step * step / math.pi);
      if (radius < 3.5 || radius > 150) continue;
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
    var bestScore = double.infinity;
    for (final b in blobs) {
      if (b.radius < 7 || b.radius > 130) continue;
      final d = _distance(b.center, center);
      // Camera follows the player, so our cell is near the arena center.
      final score = d - b.radius * 0.25;
      if (score < bestScore) {
        bestScore = score;
        best = b;
      }
    }
    return best;
  }

  static double _distance(Offset a, Offset b) =>
      math.sqrt(math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2));

  static Offset _randomPoint(Offset center, double radius, math.Random rng) {
    final a = rng.nextDouble() * math.pi * 2;
    final r = radius * (0.4 + rng.nextDouble() * 0.8);
    return Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
  }
}
