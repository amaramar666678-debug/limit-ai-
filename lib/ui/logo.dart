import 'package:flutter/material.dart';
import 'theme.dart';

/// App brand mark using the real "multi mause" logo asset.
///
/// The custom painter remains as a fallback in case the asset cannot be
/// decoded on a platform.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 28, this.showGlow = false});

  static const asset = 'assets/logo_multi_mause.webp';

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: showGlow
            ? const [BoxShadow(color: Color(0x6667C7B7), blurRadius: 16, spreadRadius: 1)]
            : const [BoxShadow(color: Color(0x223A6D63), blurRadius: 8)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => const _FallbackLogo(),
        ),
      ),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo();

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Palette.accent, Color(0xFF4AA7D8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(Icons.mouse_rounded, color: Palette.bg, size: 18),
      );
}
