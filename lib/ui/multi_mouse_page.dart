import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mouse_controller.dart';
import 'logo.dart';
import 'theme.dart';

class MultiMousePage extends StatefulWidget {
  const MultiMousePage({super.key});

  @override
  State<MultiMousePage> createState() => _MultiMousePageState();
}

class _MultiMousePageState extends State<MultiMousePage> {
  MouseController? _controller;
  Offset? _origin;
  MousePattern _pattern = MousePattern.grid;
  double _spacing = 90;
  int _delayMs = 18;
  bool _doubleClick = false;
  bool _showPreview = true;
  bool _running = false;
  int _countdown = 0;
  int _activeIndex = -1;
  String? _error;

  @override
  void initState() {
    super.initState();
    try {
      _controller = MouseController();
      _controller!.currentPointer().then((p) {
        if (mounted) setState(() => _origin = p);
      }).catchError((Object e) {
        if (mounted) setState(() => _error = e.toString());
      });
    } catch (e) {
      _error = e.toString();
    }
  }

  @override
  void dispose() {
    _controller?.cancel();
    super.dispose();
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null) return;
    try {
      final p = await c.currentPointer();
      if (!mounted) return;
      setState(() {
        _origin = p;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _run() async {
    final c = _controller;
    final origin = _origin;
    if (c == null || origin == null || _running) return;

    c.reset();
    setState(() {
      _running = true;
      _error = null;
      _countdown = 3;
    });

    for (var n = 3; n >= 1; n--) {
      if (c.cancelled) break;
      setState(() => _countdown = n);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    if (c.cancelled) {
      setState(() {
        _running = false;
        _countdown = 0;
      });
      return;
    }

    final points = MouseController.positions(
      origin: origin,
      pattern: _pattern,
      spacing: _spacing,
    );

    setState(() => _countdown = 0);
    for (var i = 0; i < points.length; i++) {
      if (c.cancelled) break;
      setState(() => _activeIndex = i);
      try {
        await c.clickAt(
          points[i],
          doubleClick: _doubleClick,
          settleMs: 6,
        );
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
        break;
      }
      if (_delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: _delayMs));
      }
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _activeIndex = -1;
    });
  }

  void _stop() {
    _controller?.cancel();
    if (!mounted) return;
    setState(() {
      _running = false;
      _countdown = 0;
      _activeIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _stop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Palette.bg,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 980;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: 20),
                      if (_error != null) _errorBanner(),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _preview()),
                            const SizedBox(width: 18),
                            Expanded(flex: 2, child: _controls()),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _preview(),
                            const SizedBox(height: 18),
                            _controls(),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const BrandLogo(size: 40, showGlow: true),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Multi Mause',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                'عشرة مؤشرات تنفّذ النقرات في مواضع مختلفة بسرعة فائقة',
                style: TextStyle(fontSize: 13, color: Palette.muted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Palette.raised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Palette.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _controller == null ? Icons.block : Icons.check_circle_rounded,
                size: 14,
                color: _controller == null ? Palette.danger : Palette.accent,
              ),
              const SizedBox(width: 6),
              Text(
                _controller == null ? 'غير مدعوم' : 'Windows جاهز',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorBanner() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x22EA8078),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x55EA8078)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: Palette.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: Palette.danger),
              ),
            ),
          ],
        ),
      );

  Widget _preview() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location_rounded, size: 17, color: Palette.accent),
              const SizedBox(width: 8),
              const Text('المعاينة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              Switch(
                value: _showPreview,
                onChanged: (v) => setState(() => _showPreview = v),
                activeThumbColor: Palette.accent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Palette.line),
                gradient: const LinearGradient(
                  colors: [Color(0xFF111A23), Color(0xFF131E29)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _showPreview
                    ? CustomPaint(
                        painter: _MultiCursorPainter(
                          pattern: _pattern,
                          spacing: _spacing * 0.42,
                          active: _activeIndex,
                          running: _running,
                        ),
                        child: const SizedBox.expand(),
                      )
                    : Center(
                        child: Text(
                          'المعاينة متوقفة',
                          style: TextStyle(color: Palette.muted, fontSize: 13),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.stadium_rounded, size: 14, color: Palette.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _origin == null
                      ? 'جارٍ تحديد موضع المؤشر...'
                      : 'الموضع: ${_origin!.dx.round()} × ${_origin!.dy.round()}',
                  style: monoStyle(size: 12, color: Palette.muted),
                ),
              ),
              TextButton.icon(
                onPressed: _capture,
                icon: const Icon(Icons.center_focus_strong_rounded, size: 16),
                label: const Text('التقاط المؤشر'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, size: 17, color: Palette.accent),
              SizedBox(width: 8),
              Text('الإعدادات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('النمط', style: TextStyle(fontSize: 12.5, color: Palette.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in MousePattern.values)
                ChoiceChip(
                  label: Text(p.label),
                  selected: _pattern == p,
                  onSelected: _running
                      ? null
                      : (v) {
                          if (v) setState(() => _pattern = p);
                        },
                  selectedColor: Palette.accentSoft,
                  backgroundColor: Palette.raised,
                  side: BorderSide(color: Palette.line),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: _pattern == p ? Palette.accent : Palette.text,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text('المسافة', style: TextStyle(fontSize: 12.5, color: Palette.muted)),
              const Spacer(),
              Text('${_spacing.round()} px', style: monoStyle(size: 12, color: Palette.accent)),
            ],
          ),
          Slider(
            value: _spacing,
            min: 30,
            max: 240,
            divisions: 42,
            onChanged: _running
                ? null
                : (v) => setState(() => _spacing = v),
            activeColor: Palette.accent,
          ),
          Row(
            children: [
              const Text('الفاصل بين النقرات', style: TextStyle(fontSize: 12.5, color: Palette.muted)),
              const Spacer(),
              Text('$_delayMs ms', style: monoStyle(size: 12, color: Palette.accent)),
            ],
          ),
          Slider(
            value: _delayMs.toDouble(),
            min: 0,
            max: 120,
            divisions: 24,
            onChanged: _running
                ? null
                : (v) => setState(() => _delayMs = v.round()),
            activeColor: Palette.accent,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _doubleClick,
            onChanged: _running ? null : (v) => setState(() => _doubleClick = v),
            title: const Text('نقر مزدوج', style: TextStyle(fontSize: 13)),
            activeThumbColor: Palette.accent,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x223A6D63),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x4467C7B7)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Palette.accent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تنفّذ نقرات حقيقية على سطح المكتب. اضغط Esc أو زر الإيقاف في أي وقت.',
                    style: TextStyle(fontSize: 11.5, color: Palette.muted, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_running || _controller == null || _origin == null)
                      ? null
                      : _run,
                  icon: Icon(_running ? Icons.hourglass_top : Icons.bolt_rounded, size: 18),
                  label: Text(
                    _running
                        ? (_countdown > 0 ? 'البدء بعد $_countdown' : 'جارٍ التنفيذ...')
                        : 'تشغيل 10 نقرات',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.accent,
                    foregroundColor: Palette.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _running ? _stop : null,
                icon: const Icon(Icons.stop_rounded, size: 17),
                label: const Text('إيقاف'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.danger,
                  side: const BorderSide(color: Palette.line),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.line),
        ),
        child: child,
      );
}

class _MultiCursorPainter extends CustomPainter {
  const _MultiCursorPainter({
    required this.pattern,
    required this.spacing,
    required this.active,
    required this.running,
  });

  final MousePattern pattern;
  final double spacing;
  final int active;
  final bool running;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = size.center(Offset.zero);
    final points = MouseController.positions(
      origin: origin,
      pattern: pattern,
      spacing: spacing,
    );

    final gridPaint = Paint()
      ..color = const Color(0x113A4C5E)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final isActive = running && i == active;
      final color = isActive ? Palette.warn : Palette.accent;
      final halo = Paint()
        ..color = color.withValues(alpha: isActive ? 0.28 : 0.10)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p, isActive ? 15 : 11, halo);

      final arrow = Path()
        ..moveTo(p.dx, p.dy + 13)
        ..lineTo(p.dx, p.dy)
        ..lineTo(p.dx + 9, p.dy + 6)
        ..lineTo(p.dx + 4, p.dy + 7)
        ..lineTo(p.dx + 7, p.dy + 13)
        ..close();
      canvas.drawPath(
        arrow,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        arrow,
        Paint()
          ..color = Palette.bg
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      final num = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            fontSize: 9.5,
            color: isActive ? Palette.warn : Palette.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      num.paint(canvas, Offset(p.dx + 12, p.dy + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _MultiCursorPainter old) =>
      old.pattern != pattern ||
      old.spacing != spacing ||
      old.active != active ||
      old.running != running;
}
