import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import '../ui/strings.dart';

final class _Point extends Struct {
  @Int32()
  external int x;

  @Int32()
  external int y;
}

/// Low-level Windows mouse control used by the Multi Mause feature.
///
/// A single physical cursor is moved between the ten target points and a real
/// left click is sent at each one. The points are executed in rapid sequence;
/// Windows does not expose ten independent system cursors.
class MouseController {
  MouseController() {
    if (!Platform.isWindows) {
      throw UnsupportedError('Multi Mause requires Windows');
    }
    final lib = _user32;
    _getCursorPos = lib.lookupFunction<
        Int32 Function(Pointer<_Point>),
        int Function(Pointer<_Point>)>('GetCursorPos');
    _setCursorPos = lib.lookupFunction<
        Int32 Function(Int32, Int32),
        int Function(int, int)>('SetCursorPos');
    _mouseEvent = lib.lookupFunction<
        Void Function(Uint32, Uint32, Uint32, Uint32, UintPtr),
        void Function(int, int, int, int, int)>('mouse_event');
    _keyEvent = lib.lookupFunction<
        Void Function(Uint32, Uint32, Uint32, UintPtr),
        void Function(int, int, int, int)>('keybd_event');
    _getSystemMetrics = lib.lookupFunction<
        Int32 Function(Int32),
        int Function(int)>('GetSystemMetrics');
    _getAsyncKeyState = lib.lookupFunction<
        Int16 Function(Int32),
        int Function(int)>('GetAsyncKeyState');
  }

  static final DynamicLibrary _user32 = Platform.isWindows
      ? DynamicLibrary.open('user32.dll')
      : DynamicLibrary.open('__unsupported__');

  late final int Function(Pointer<_Point>) _getCursorPos;
  late final int Function(int, int) _setCursorPos;
  late final void Function(int, int, int, int, int) _mouseEvent;
  late final void Function(int, int, int, int) _keyEvent;
  late final int Function(int) _getSystemMetrics;
  late final int Function(int) _getAsyncKeyState;

  static const _vkEscape = 0x1B;
  static const _vkSpace = 0x20;
  static const _vkWin = 0x5B;
  static const _vkCtrl = 0x11;
  static const _vkR = 0x52;
  static const _vkA = 0x41;
  static const _vkV = 0x56;
  static const _vkEnter = 0x0D;
  static const _keyUp = 0x0002;
  static const _wheel = 0x0800;

  bool _cancelled = false;
  bool get cancelled => _cancelled;

  Timer? _escWatcher;
  bool _escWasDown = false;

  void reset() => _cancelled = false;
  void cancel() => _cancelled = true;

  /// Watches Esc globally, even while Chrome or another window has focus.
  void startEscWatcher(void Function() onEscape) {
    _escWatcher?.cancel();
    _escWasDown = false;
    _escWatcher = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final down = (_getAsyncKeyState(_vkEscape) & 0x8000) != 0;
      if (down && !_escWasDown) onEscape();
      _escWasDown = down;
    });
  }

  void stopEscWatcher() {
    _escWatcher?.cancel();
    _escWatcher = null;
    _escWasDown = false;
  }

  void dispose() => stopEscWatcher();

  Future<Offset> currentPointer() async {
    final p = calloc<_Point>();
    try {
      final ok = _getCursorPos(p);
      if (ok == 0) throw StateError('GetCursorPos failed');
      return Offset(p.ref.x.toDouble(), p.ref.y.toDouble());
    } finally {
      calloc.free(p);
    }
  }

  /// Physical screen size in pixels.
  Size screenSize() => Size(
        _getSystemMetrics(0).toDouble(),
        _getSystemMetrics(1).toDouble(),
      );

  Offset screenCenter() {
    final s = screenSize();
    return Offset(s.width / 2, s.height / 2);
  }

  Future<void> moveTo(Offset point) async {
    if (_cancelled) return;
    _setCursorPos(point.dx.round(), point.dy.round());
  }

  /// Continuously guides a game cursor (e.g. an agar.io cell) in a smooth
  /// orbit. Games such as agar.io follow the pointer direction without clicks.
  Future<void> steer(
    Offset center,
    double radius, {
    int durationMs = 8000,
  }) async {
    final screen = screenSize();
    final stopwatch = Stopwatch()..start();
    var step = 0;
    while (!_cancelled && stopwatch.elapsedMilliseconds < durationMs) {
      final angle = step * 0.15;
      final r = radius * (0.82 + 0.18 * math.sin(step * 0.06));
      final x = (center.dx + r * math.cos(angle)).clamp(0.0, screen.width).toDouble();
      final y = (center.dy + r * math.sin(angle)).clamp(0.0, screen.height).toDouble();
      _setCursorPos(x.round(), y.round());
      await Future<void>.delayed(const Duration(milliseconds: 26));
      step++;
    }
  }

  /// Human-like pointer play for games such as agar.io: short smooth darts,
  /// small pauses and occasional clicks, instead of a mechanical orbit.
  Future<void> playLikeHuman(
    Offset center,
    double radius, {
    int durationMs = 15000,
  }) async {
    final screen = screenSize();
    final rng = math.Random(DateTime.now().microsecondsSinceEpoch);
    final stopwatch = Stopwatch()..start();
    var current = center;

    Offset clampPoint(Offset p) => Offset(
          p.dx.clamp(0.0, screen.width).toDouble(),
          p.dy.clamp(0.0, screen.height).toDouble(),
        );

    while (!_cancelled && stopwatch.elapsedMilliseconds < durationMs) {
      final angle = rng.nextDouble() * math.pi * 2;
      final distance = radius * (0.45 + rng.nextDouble() * 0.75);
      final target = clampPoint(Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      ));

      final steps = 7 + rng.nextInt(9);
      for (var s = 1; s <= steps && !_cancelled; s++) {
        final t = s / steps;
        final eased = t * t * (3 - 2 * t); // smooth in/out
        final p = clampPoint(Offset(
          current.dx + (target.dx - current.dx) * eased,
          current.dy + (target.dy - current.dy) * eased,
        ));
        _setCursorPos(p.dx.round(), p.dy.round());
        await Future<void>.delayed(
          Duration(milliseconds: 22 + rng.nextInt(16)),
        );
      }
      if (_cancelled) break;
      current = target;

      // Occasional click to eject mass / interact with the game.
      if (rng.nextInt(4) == 0) {
        _press(0x0002, 0x0004);
      }
      // Brief human pause before the next move.
      if (rng.nextInt(5) == 0) {
        await Future<void>.delayed(
          Duration(milliseconds: 110 + rng.nextInt(180)),
        );
      }
    }
  }

  Future<void> clickAt(
    Offset point, {
    bool doubleClick = false,
    int settleMs = 8,
  }) async {
    if (_cancelled) return;
    _setCursorPos(point.dx.round(), point.dy.round());
    if (settleMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: settleMs));
    }
    if (_cancelled) return;
    _press(0x0002, 0x0004); // LEFTDOWN / LEFTUP
    if (doubleClick && !_cancelled) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (_cancelled) return;
      _press(0x0002, 0x0004);
    }
  }

  void _press(int downFlag, int upFlag) {
    _mouseEvent(downFlag, 0, 0, 0, 0);
    _mouseEvent(upFlag, 0, 0, 0, 0);
  }

  Future<void> scrollAt(Offset point, int delta) async {
    if (_cancelled) return;
    _setCursorPos(point.dx.round(), point.dy.round());
    await Future<void>.delayed(const Duration(milliseconds: 6));
    if (_cancelled) return;
    _mouseEvent(_wheel, 0, delta, 0, 0);
  }

  void _key(int vk, {bool up = false}) {
    _keyEvent(vk, 0, up ? _keyUp : 0, 0);
  }

  void _tap(int vk) {
    _key(vk);
    _key(vk, up: true);
  }

  Future<void> pressEnter() async {
    if (_cancelled) return;
    _tap(_vkEnter);
  }

  Future<void> pressSpace() async {
    if (_cancelled) return;
    _tap(_vkSpace);
  }

  Future<void> pressEscape() async {
    if (_cancelled) return;
    _tap(_vkEscape);
  }

  Future<void> click() async {
    if (_cancelled) return;
    _press(0x0002, 0x0004);
  }

  /// Smoothly moves the pointer from [from] to [to] in human-like steps.
  Future<void> glideTo(
    Offset from,
    Offset to, {
    int steps = 10,
    int minMs = 22,
    int maxMs = 38,
  }) async {
    for (var s = 1; s <= steps && !_cancelled; s++) {
      final t = s / steps;
      final eased = t * t * (3 - 2 * t);
      _setCursorPos(
        (from.dx + (to.dx - from.dx) * eased).round(),
        (from.dy + (to.dy - from.dy) * eased).round(),
      );
      await Future<void>.delayed(
        Duration(milliseconds: minMs + (s % 4) * ((maxMs - minMs) ~/ 4)),
      );
    }
  }

  /// Pastes [text] at the current focus using the clipboard. The previous
  /// clipboard content is restored afterwards.
  Future<void> pasteText(String text) async {
    if (_cancelled || text.isEmpty) return;
    ClipboardData? previous;
    try {
      previous = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      previous = null;
    }
    await Clipboard.setData(ClipboardData(text: text));
    // Give the clipboard a moment to settle before sending Ctrl+V.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (_cancelled) return;
    _key(_vkCtrl);
    _key(_vkV);
    _key(_vkV, up: true);
    _key(_vkCtrl, up: true);
    // Do not restore the old clipboard until the paste is fully processed.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (previous?.text != null) {
      try {
        await Clipboard.setData(ClipboardData(text: previous!.text!));
      } catch (_) {
        // Clipboard restore is best-effort.
      }
    }
  }

  /// Opens the Windows Run dialog and launches [command], e.g. `chrome`.
  Future<void> runCommand(String command) async {
    if (_cancelled) return;
    _key(_vkWin);
    _key(_vkR);
    _key(_vkR, up: true);
    _key(_vkWin, up: true);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (_cancelled) return;
    // Clear any previous Run dialog text before pasting the command.
    _key(_vkCtrl);
    _key(_vkA);
    _key(_vkA, up: true);
    _key(_vkCtrl, up: true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await pasteText(command);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    await pressEnter();
  }

  static List<Offset> positions({
    required Offset origin,
    required MousePattern pattern,
    required double spacing,
    double radiusScale = 1.6,
  }) {
    final pts = <Offset>[];
    for (var i = 0; i < 10; i++) {
      switch (pattern) {
        case MousePattern.row:
          pts.add(Offset(origin.dx + (i - 4.5) * spacing, origin.dy));
          break;
        case MousePattern.column:
          pts.add(Offset(origin.dx, origin.dy + (i - 4.5) * spacing));
          break;
        case MousePattern.grid:
          final col = i % 5;
          final row = i ~/ 5;
          pts.add(Offset(
            origin.dx + (col - 2) * spacing,
            origin.dy + (row - 0.5) * spacing,
          ));
          break;
        case MousePattern.circle:
          final a = -math.pi / 2 + (i * 2 * math.pi / 10);
          final r = spacing * radiusScale;
          pts.add(Offset(origin.dx + r * math.cos(a), origin.dy + r * math.sin(a)));
          break;
        case MousePattern.diagonal:
          pts.add(Offset(
            origin.dx + (i - 4.5) * spacing,
            origin.dy + (i - 4.5) * spacing * 0.45,
          ));
          break;
      }
    }
    return pts;
  }

}

enum MousePattern { row, column, grid, circle, diagonal }

extension MousePatternLabel on MousePattern {
  String get label => switch (this) {
        MousePattern.row => AppStrings.patternRow,
        MousePattern.column => AppStrings.patternColumn,
        MousePattern.grid => AppStrings.patternGrid,
        MousePattern.circle => AppStrings.patternCircle,
        MousePattern.diagonal => AppStrings.patternDiagonal,
      };
}
