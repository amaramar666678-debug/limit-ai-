import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';

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
  }

  static final DynamicLibrary _user32 = Platform.isWindows
      ? DynamicLibrary.open('user32.dll')
      : DynamicLibrary.open('__unsupported__');

  late final int Function(Pointer<_Point>) _getCursorPos;
  late final int Function(int, int) _setCursorPos;
  late final void Function(int, int, int, int, int) _mouseEvent;

  bool _cancelled = false;
  bool get cancelled => _cancelled;

  void reset() => _cancelled = false;
  void cancel() => _cancelled = true;

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

  Future<void> moveTo(Offset point) async {
    if (_cancelled) return;
    _setCursorPos(point.dx.round(), point.dy.round());
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
        MousePattern.row => 'أفقي',
        MousePattern.column => 'عمودي',
        MousePattern.grid => 'شبكة 5×2',
        MousePattern.circle => 'دائرة',
        MousePattern.diagonal => 'قطري',
      };
}
