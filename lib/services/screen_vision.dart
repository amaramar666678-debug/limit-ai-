import 'dart:ffi';
import 'package:ffi/ffi.dart';

final class _BitmapInfoHeader extends Struct {
  @Uint32()
  external int biSize;
  @Int32()
  external int biWidth;
  @Int32()
  external int biHeight;
  @Uint16()
  external int biPlanes;
  @Uint16()
  external int biBitCount;
  @Uint32()
  external int biCompression;
  @Uint32()
  external int biSizeImage;
  @Int32()
  external int biXPelsPerMeter;
  @Int32()
  external int biYPelsPerMeter;
  @Uint32()
  external int biClrUsed;
  @Uint32()
  external int biClrImportant;
}

final class _BitmapInfo extends Struct {
  external _BitmapInfoHeader bmiHeader;
}

final class _Rect extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

/// A raw top-down BGRA snapshot of the desktop or of the foreground window.
class ScreenCapture {
  ScreenCapture(this.left, this.top, this.width, this.height, this._pixels);

  final int left;
  final int top;
  final int width;
  final int height;
  final Pointer<Uint8> _pixels;

  int offsetAt(int x, int y) => (y * width + x) * 4;
  int redAt(int x, int y) => _pixels[offsetAt(x, y) + 2];
  int greenAt(int x, int y) => _pixels[offsetAt(x, y) + 1];
  int blueAt(int x, int y) => _pixels[offsetAt(x, y)];
  int screenX(int x) => left + x;
  int screenY(int y) => top + y;

  void dispose() => calloc.free(_pixels);

  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
  static final DynamicLibrary _gdi32 = DynamicLibrary.open('gdi32.dll');

  static ScreenCapture capture() {
    final desktop = _captureDesktop();
    if (_usable(desktop)) return desktop;
    desktop.dispose();

    final hwnd = _user32
        .lookupFunction<IntPtr Function(), int Function()>('GetForegroundWindow')();
    if (hwnd == 0) throw StateError('No foreground window to capture');
    final rect = calloc<_Rect>();
    try {
      final getWindowRect = _user32.lookupFunction<
          Int32 Function(IntPtr, Pointer<_Rect>),
          int Function(int, Pointer<_Rect>)>('GetWindowRect');
      if (getWindowRect(hwnd, rect) == 0) {
        throw StateError('GetWindowRect failed');
      }
      final w = rect.ref.right - rect.ref.left;
      final h = rect.ref.bottom - rect.ref.top;
      if (w < 200 || h < 200) throw StateError('Foreground window too small');
      try {
        return _captureWindow(hwnd, rect.ref.left, rect.ref.top, w, h, 2);
      } catch (_) {
        return _captureWindow(hwnd, rect.ref.left, rect.ref.top, w, h, 0);
      }
    } finally {
      calloc.free(rect);
    }
  }

  static bool _usable(ScreenCapture c) {
    var sum = 0;
    var min = 255;
    var max = 0;
    var n = 0;
    for (var y = 0; y < c.height; y += 17) {
      for (var x = 0; x < c.width; x += 17) {
        final lum = (c.redAt(x, y) * 0.299 +
                c.greenAt(x, y) * 0.587 +
                c.blueAt(x, y) * 0.114)
            .round();
        sum += lum;
        if (lum < min) min = lum;
        if (lum > max) max = lum;
        n++;
      }
    }
    if (n == 0) return false;
    final avg = sum ~/ n;
    return avg > 8 && avg < 247 && (max - min) > 12;
  }

  static ScreenCapture _captureDesktop() {
    final getSystemMetrics = _user32.lookupFunction<
        Int32 Function(Int32), int Function(int)>('GetSystemMetrics');
    final w = getSystemMetrics(0);
    final h = getSystemMetrics(1);
    final hdc = _user32
        .lookupFunction<IntPtr Function(IntPtr), int Function(int)>('GetDC')(0);
    if (hdc == 0 || w <= 0 || h <= 0) throw StateError('GetDC failed');
    try {
      return _grab(
        sourceHdc: hdc,
        width: w,
        height: h,
        srcX: 0,
        srcY: 0,
        left: 0,
        top: 0,
        bitblt: true,
      );
    } finally {
      _user32
          .lookupFunction<Int32 Function(IntPtr, IntPtr), int Function(int, int)>(
              'ReleaseDC')(0, hdc);
    }
  }

  static ScreenCapture _captureWindow(
    int hwnd,
    int left,
    int top,
    int w,
    int h,
    int flags,
  ) {
    return _grab(
      sourceHdc: 0,
      width: w,
      height: h,
      srcX: 0,
      srcY: 0,
      left: left,
      top: top,
      bitblt: false,
      printWindowHwnd: hwnd,
      printFlags: flags,
    );
  }

  static ScreenCapture _grab({
    required int sourceHdc,
    required int width,
    required int height,
    required int srcX,
    required int srcY,
    required int left,
    required int top,
    required bool bitblt,
    int? printWindowHwnd,
    int printFlags = 0,
  }) {
    final createCompatibleDc = _gdi32.lookupFunction<
        IntPtr Function(IntPtr), int Function(int)>('CreateCompatibleDC');
    final createCompatibleBitmap = _gdi32.lookupFunction<
        IntPtr Function(IntPtr, Int32, Int32), int Function(int, int, int)>(
        'CreateCompatibleBitmap');
    final selectObject = _gdi32.lookupFunction<
        IntPtr Function(IntPtr, IntPtr), int Function(int, int)>('SelectObject');
    final bitBlt = _gdi32.lookupFunction<
        Int32 Function(IntPtr, Int32, Int32, Int32, Int32, IntPtr, Int32, Int32, Uint32),
        int Function(int, int, int, int, int, int, int, int, int)>('BitBlt');
    final getDibits = _gdi32.lookupFunction<
        Int32 Function(IntPtr, IntPtr, Uint32, Uint32, Pointer<Void>,
            Pointer<_BitmapInfo>, Uint32),
        int Function(int, int, int, int, Pointer<Void>, Pointer<_BitmapInfo>, int)>(
        'GetDIBits');
    final deleteObject = _gdi32.lookupFunction<
        Int32 Function(IntPtr), int Function(int)>('DeleteObject');
    final deleteDc = _gdi32.lookupFunction<
        Int32 Function(IntPtr), int Function(int)>('DeleteDC');

    final memDc = createCompatibleDc(sourceHdc);
    final bitmap = createCompatibleBitmap(sourceHdc, width, height);
    if (memDc == 0 || bitmap == 0) {
      if (bitmap != 0) deleteObject(bitmap);
      if (memDc != 0) deleteDc(memDc);
      throw StateError('Could not create bitmap');
    }
    final old = selectObject(memDc, bitmap);
    final info = calloc<_BitmapInfo>();
    final pixels = calloc<Uint8>(width * height * 4);
    try {
      if (printWindowHwnd != null) {
        final printed = _gdi32.lookupFunction<
            Int32 Function(IntPtr, IntPtr, Uint32),
            int Function(int, int, int)>('PrintWindow')(
            printWindowHwnd, memDc, printFlags);
        if (printed == 0) throw StateError('PrintWindow failed');
      } else if (bitblt) {
        if (bitBlt(memDc, 0, 0, width, height, sourceHdc, srcX, srcY,
                0x00CC0020) == 0) {
          throw StateError('BitBlt failed');
        }
      }
      info.ref.bmiHeader
        ..biSize = 40
        ..biWidth = width
        ..biHeight = -height
        ..biPlanes = 1
        ..biBitCount = 32
        ..biCompression = 0;
      if (getDibits(memDc, bitmap, 0, height, pixels.cast<Void>(), info, 0) == 0) {
        throw StateError('GetDIBits failed');
      }
      return ScreenCapture(left, top, width, height, pixels);
    } catch (_) {
      calloc.free(pixels);
      rethrow;
    } finally {
      calloc.free(info);
      if (old != 0) selectObject(memDc, old);
      deleteObject(bitmap);
      deleteDc(memDc);
    }
  }
}
