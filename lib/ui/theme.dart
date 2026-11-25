import 'package:flutter/material.dart';

class Palette {
  static const bg = Color(0xFF0E141B);
  static const surface = Color(0xFF151E27);
  static const raised = Color(0xFF1C2833);
  static const line = Color(0xFF273849);
  static const text = Color(0xFFEAF1F7);
  static const muted = Color(0xFF8CA0B3);
  static const accent = Color(0xFF67C7B7);
  static const accentSoft = Color(0x225CC8B8);
  static const danger = Color(0xFFEA8078);
  static const warn = Color(0xFFF0B35A);
}

const sans = 'Segoe UI';
const sansFallback = ['Tahoma', 'Noto Sans Arabic', 'Arial'];
const mono = 'Cascadia Mono';
const monoFallback = ['Consolas', 'Courier New'];

TextStyle monoStyle({double size = 12.5, Color? color, double? height, FontWeight? weight}) =>
    TextStyle(
      fontFamily: mono,
      fontFamilyFallback: monoFallback,
      fontSize: size,
      color: color,
      height: height,
      fontWeight: weight,
    );

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Palette.bg,
      fontFamily: sans,
      fontFamilyFallback: sansFallback,
      colorScheme: const ColorScheme.dark(
        primary: Palette.accent,
        surface: Palette.surface,
        onSurface: Palette.text,
        error: Palette.danger,
      ),
      dividerColor: Palette.line,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Palette.accent,
        selectionColor: Color(0x5567C7B7),
      ),
    );
