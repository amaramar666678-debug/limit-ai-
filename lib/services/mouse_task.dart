import 'package:flutter/material.dart';
import '../ui/strings.dart';
import 'agar_vision.dart';
import 'mouse_controller.dart';

enum TeamActionKind {
  launch,
  paste,
  enter,
  click,
  doubleClick,
  move,
  steer,
  play,
  visionPlay,
  escape,
  scroll,
  delay
}

/// One atomic step carried out by a member of the ten-cursor team.
class TeamAction {
  const TeamAction(
    this.kind, {
    this.text,
    this.point,
    this.durationMs,
    this.radius,
    this.cursor = 0,
    required this.label,
  });

  final TeamActionKind kind;
  final String? text;
  final Offset? point;
  final int? durationMs;
  final double? radius;
  final int cursor;
  final String label;
}

class MouseTask {
  const MouseTask({
    required this.title,
    required this.description,
    required this.actions,
  });

  final String title;
  final String description;
  final List<TeamAction> actions;
}

/// Truthful outcome of a run, so the UI does not say "finished" when the game
/// was never detected or the user cancelled.
class MouseTaskResult {
  const MouseTaskResult({required this.cancelled, this.detail});

  final bool cancelled;
  final String? detail;
}

/// Turns a natural-language instruction into a concrete, reviewable team plan.
class MouseTaskPlanner {
  static final _strip = RegExp(
    r'افتح|فتح|ابحث|بحث|دور|search|find|open|launch|chrome|كروم|متصفح|browser|'
    r'صورة|صور|image|images|picture|photos?|عن|about|for|في|من|关于|搜索|打开',
    caseSensitive: false,
  );

  static String _query(String prompt) {
    var q = prompt.replaceAll(_strip, ' ');
    q = q.replaceAll(RegExp(r'[؟?،,.!]+'), ' ');
    q = q.replaceAll(RegExp(r'\s+'), ' ').trim();
    return q.isEmpty ? prompt.trim() : q;
  }

  static MouseTask fromPrompt(
    String prompt, {
    required Offset origin,
    required MousePattern pattern,
    required double spacing,
    Offset? screenCenter,
    Size? screenSize,
  }) {
    final lower = prompt.toLowerCase();
    final isAgar = lower.contains('agar.io') ||
        (lower.contains('agar') &&
            (lower.contains('game') ||
                lower.contains('لعبة') ||
                lower.contains('لعب')));
    if (isAgar) {
      return agarGame(
        screenCenter: screenCenter ?? origin,
        screenSize: screenSize ?? Size(origin.dx * 2, origin.dy * 2),
        spacing: spacing,
      );
    }
    final wantsImage = lower.contains('صورة') ||
        lower.contains('صور') ||
        lower.contains('image') ||
        lower.contains('picture') ||
        lower.contains('photo');
    final wantsBrowser = lower.contains('كروم') ||
        lower.contains('chrome') ||
        lower.contains('متصفح') ||
        lower.contains('browser') ||
        wantsImage ||
        lower.contains('بحث') ||
        lower.contains('ابحث') ||
        lower.contains('search') ||
        lower.contains('info') ||
        lower.contains('معلومات');

    if (!wantsBrowser) {
      return tenClicks(origin: origin, pattern: pattern, spacing: spacing);
    }

    final q = _query(prompt);
    final url = wantsImage
        ? 'https://www.google.com/search?tbm=isch&q=${Uri.encodeComponent(q)}'
        : 'https://www.google.com/search?q=${Uri.encodeComponent(q)}';
    final command = 'chrome "$url"';

    final actions = <TeamAction>[
      TeamAction(
        TeamActionKind.launch,
        text: command,
        cursor: 0,
        label: AppStrings.launchChrome,
      ),
      TeamAction(
        TeamActionKind.delay,
        durationMs: 2600,
        cursor: 1,
        label: AppStrings.waitResults,
      ),
    ];

    // The ten cursors then sweep the result area as one team.
    final points = MouseController.positions(
      origin: origin,
      pattern: pattern,
      spacing: spacing,
    );
    for (var i = 0; i < points.length; i++) {
      actions.add(TeamAction(
        TeamActionKind.click,
        point: points[i],
        cursor: i,
        label: wantsImage ? AppStrings.checkImage(i + 1) : AppStrings.checkResult(i + 1),
      ));
    }

    return MouseTask(
      title: wantsImage ? AppStrings.imageSearch : AppStrings.infoSearch,
      description: wantsImage ? AppStrings.imagesLabel(q) : AppStrings.infoLabel(q),
      actions: actions,
    );
  }

  /// Opens agar.io, starts a round, then continuously steers the cell with the
  /// pointer. Agar.io follows mouse direction; clicks are only needed to start.
  static MouseTask agarGame({
    required Offset screenCenter,
    required Size screenSize,
    required double spacing,
  }) {
    // Measured on the live agar.io page: the Play button sits at ~44.4% of the
    // window height, and the nickname field at ~38.4%. Using proportions keeps
    // this correct with Windows DPI scaling (100%, 125%, 150%...).
    final nickPoint = Offset(
      screenSize.width / 2,
      screenSize.height * 0.384,
    );
    final playPoint = Offset(
      screenSize.width / 2,
      screenSize.height * 0.444,
    );
    return MouseTask(
      title: AppStrings.agarGame,
      description: AppStrings.agarDescription,
      actions: [
        TeamAction(
          TeamActionKind.launch,
          text: 'chrome "https://agar.io"',
          cursor: 0,
          label: AppStrings.launchAgar,
        ),
        TeamAction(
          TeamActionKind.delay,
          durationMs: 6000,
          cursor: 1,
          label: AppStrings.waitResults,
        ),
        // No synthetic Esc and no blind ad click: both can hijack the page.
        // Real ad overlays must be dismissed by their own Skip button.
        TeamAction(
          TeamActionKind.click,
          point: nickPoint,
          cursor: 3,
          label: AppStrings.focusGame,
        ),
        TeamAction(
          TeamActionKind.click,
          point: playPoint,
          cursor: 4,
          label: AppStrings.clickPlay,
        ),
        TeamAction(
          TeamActionKind.delay,
          durationMs: 1200,
          cursor: 5,
          label: AppStrings.waitResults,
        ),
        TeamAction(
          TeamActionKind.click,
          point: playPoint,
          cursor: 6,
          label: AppStrings.clickPlay,
        ),
        TeamAction(
          TeamActionKind.delay,
          durationMs: 1200,
          cursor: 7,
          label: AppStrings.waitResults,
        ),
        TeamAction(
          TeamActionKind.click,
          point: screenCenter,
          cursor: 8,
          label: AppStrings.focusGame,
        ),
        TeamAction(
          TeamActionKind.visionPlay,
          durationMs: 45000,
          cursor: 9,
          label: AppStrings.playingVision,
        ),
      ],
    );
  }

  static MouseTask tenClicks({
    required Offset origin,
    required MousePattern pattern,
    required double spacing,
    bool doubleClick = false,
  }) {
    final points = MouseController.positions(
      origin: origin,
      pattern: pattern,
      spacing: spacing,
    );
    return MouseTask(
      title: AppStrings.teamClicks,
      description: AppStrings.clickDescription(doubleClick),
      actions: [
        for (var i = 0; i < points.length; i++)
          TeamAction(
            doubleClick ? TeamActionKind.doubleClick : TeamActionKind.click,
            point: points[i],
            cursor: i,
            label: AppStrings.cursorLabel(i + 1),
          ),
      ],
    );
  }
}

/// Executes a [MouseTask] step by step and reports progress to the UI.
class MouseTaskRunner {
  MouseTaskRunner(this.controller, {this.onStep});

  final MouseController controller;
  final void Function(int index, TeamAction action)? onStep;

  Future<MouseTaskResult> run(MouseTask task) async {
    controller.reset();
    AgarPlayResult? playResult;
    for (var i = 0; i < task.actions.length; i++) {
      if (controller.cancelled) break;
      final a = task.actions[i];
      onStep?.call(i, a);
      switch (a.kind) {
        case TeamActionKind.launch:
          await controller.runCommand(a.text ?? '');
          break;
        case TeamActionKind.paste:
          await controller.pasteText(a.text ?? '');
          break;
        case TeamActionKind.enter:
          await controller.pressEnter();
          break;
        case TeamActionKind.click:
          if (a.point != null) await controller.clickAt(a.point!);
          break;
        case TeamActionKind.doubleClick:
          if (a.point != null) {
            await controller.clickAt(a.point!, doubleClick: true);
          }
          break;
        case TeamActionKind.move:
          if (a.point != null) await controller.moveTo(a.point!);
          break;
        case TeamActionKind.steer:
          if (a.point != null) {
            await controller.steer(
              a.point!,
              a.radius ?? 90,
              durationMs: a.durationMs ?? 8000,
            );
          }
          break;
        case TeamActionKind.play:
          if (a.point != null) {
            await controller.playLikeHuman(
              a.point!,
              a.radius ?? 90,
              durationMs: a.durationMs ?? 15000,
            );
          }
          break;
        case TeamActionKind.visionPlay:
          playResult = await AgarVision.play(
            controller,
            durationMs: a.durationMs ?? 30000,
          );
          break;
        case TeamActionKind.escape:
          await controller.pressEscape();
          break;
        case TeamActionKind.scroll:
          if (a.point != null) {
            await controller.scrollAt(a.point!, a.durationMs ?? -120);
          }
          break;
        case TeamActionKind.delay:
          await Future<void>.delayed(
            Duration(milliseconds: a.durationMs ?? 100),
          );
          break;
      }
      if (a.kind != TeamActionKind.delay && !controller.cancelled) {
        await Future<void>.delayed(const Duration(milliseconds: 24));
      }
    }
    return MouseTaskResult(
      cancelled: controller.cancelled,
      detail: playResult == null
          ? null
          : (playResult.detectedGame
              ? AppStrings.agarDetected
              : AppStrings.agarFallback),
    );
  }
}
