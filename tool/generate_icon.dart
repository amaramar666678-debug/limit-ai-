// Generates the Windows runner icon from the branded WebP asset.
// Run with: dart run tool/generate_icon.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

Uint8List _u32(int v) => Uint8List.fromList([
      v & 0xFF,
      (v >> 8) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 24) & 0xFF,
    ]);

Future<void> main() async {
  final source = File('assets/logo_multi_mause.webp');
  if (!source.existsSync()) {
    stderr.writeln('Missing asset: ${source.path}');
    exitCode = 1;
    return;
  }

  final decoded = img.decodeImage(await source.readAsBytes());
  if (decoded == null) {
    stderr.writeln('Could not decode WebP logo');
    exitCode = 1;
    return;
  }

  const sizes = [16, 32, 48, 64, 128, 256];
  final pngs = <Uint8List>[];
  for (final size in sizes) {
    final resized = img.copyResize(
      decoded,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    pngs.add(Uint8List.fromList(img.encodePng(resized)));
  }

  final out = BytesBuilder();
  out.add([0x00, 0x00, 0x01, 0x00]); // ICONDIR: reserved, type = icon
  out.add([sizes.length, 0x00]); // image count

  var offset = 6 + 16 * sizes.length;
  for (var i = 0; i < sizes.length; i++) {
    final size = sizes[i];
    final byteSize = size == 256 ? 0 : size;
    out.add([byteSize, byteSize, 0x00, 0x00, 0x01, 0x00, 0x20, 0x00]);
    out.add(_u32(pngs[i].length));
    out.add(_u32(offset));
    offset += pngs[i].length;
  }
  for (final png in pngs) {
    out.add(png);
  }

  final target = File('windows/runner/resources/app_icon.ico');
  await target.writeAsBytes(out.takeBytes(), flush: true);
  stdout.writeln('Wrote ${target.path}');
}
