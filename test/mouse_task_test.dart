import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:limit_ai/services/mouse_controller.dart';
import 'package:limit_ai/services/mouse_task.dart';

void main() {
  test('agar prompt plans real vision play and never self-cancels', () {
    final task = MouseTaskPlanner.fromPrompt(
      'العب لعبة agar.io واطعم الخلية',
      origin: const Offset(100, 100),
      pattern: MousePattern.grid,
      spacing: 60,
      screenCenter: const Offset(640, 400),
    );

    expect(
      task.actions.any((a) => a.kind == TeamActionKind.visionPlay),
      isTrue,
      reason: 'Agar prompts must reach the screen-reading play loop',
    );
    expect(
      task.actions.any((a) => a.kind == TeamActionKind.escape),
      isFalse,
      reason: 'A synthetic Esc would trigger the global user-stop watcher',
    );
  });

  test('browser prompt still opens Chrome then sweeps results', () {
    final task = MouseTaskPlanner.fromPrompt(
      'open chrome and search for cat images',
      origin: const Offset(100, 100),
      pattern: MousePattern.grid,
      spacing: 60,
    );

    expect(task.actions.first.kind, TeamActionKind.launch);
    expect(task.actions.first.text, contains('chrome'));
    expect(
      task.actions.where((a) => a.kind == TeamActionKind.click).length,
      10,
    );
  });
}
