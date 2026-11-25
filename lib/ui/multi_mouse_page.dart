import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mouse_controller.dart';
import '../services/mouse_task.dart';
import 'logo.dart';
import 'strings.dart';
import 'theme.dart';

class MultiMousePage extends StatefulWidget {
  const MultiMousePage({super.key, this.onAgentTask});

  /// Sends the same instruction to the OpenCode agent so it works on the task
  /// while the ten-cursor team performs the mouse actions.
  final Future<void> Function(String text)? onAgentTask;

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

  final _taskCtrl = TextEditingController();
  final _taskFocus = FocusNode();
  final _xCtrl = TextEditingController();
  final _yCtrl = TextEditingController();
  String? _taskLabel;
  bool _taskRunning = false;

  @override
  void initState() {
    super.initState();
    try {
      _controller = MouseController();
      _controller!.currentPointer().then((p) {
        if (!mounted) return;
        setState(() {
          _origin = p;
          _xCtrl.text = p.dx.round().toString();
          _yCtrl.text = p.dy.round().toString();
        });
      }).catchError((Object e) {
        if (mounted) setState(() => _error = e.toString());
      });
    } catch (e) {
      _error = e.toString();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _taskFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller?.cancel();
    _taskCtrl.dispose();
    _taskFocus.dispose();
    _xCtrl.dispose();
    _yCtrl.dispose();
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
        _xCtrl.text = p.dx.round().toString();
        _yCtrl.text = p.dy.round().toString();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Offset? _precisePoint() {
    final x = int.tryParse(_xCtrl.text.trim());
    final y = int.tryParse(_yCtrl.text.trim());
    if (x == null || y == null) {
      setState(() => _error = AppStrings.invalidCoords);
      return null;
    }
    return Offset(x.toDouble(), y.toDouble());
  }

  Future<void> _movePrecise() async {
    final c = _controller;
    final p = _precisePoint();
    if (c == null || p == null) return;
    try {
      await c.moveTo(p);
      if (!mounted) return;
      setState(() {
        _origin = p;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _clickPrecise() async {
    final c = _controller;
    final p = _precisePoint();
    if (c == null || p == null) return;
    try {
      await c.clickAt(p, doubleClick: _doubleClick);
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
      _taskRunning = false;
      _taskLabel = null;
    });
  }

  Future<void> _runTeamTask() async {
    final c = _controller;
    final origin = _origin;
    final prompt = _taskCtrl.text.trim();
    if (c == null || origin == null || prompt.isEmpty || _running) return;

    final task = MouseTaskPlanner.fromPrompt(
      prompt,
      origin: origin,
      pattern: _pattern,
      spacing: _spacing,
    );

    c.reset();
    setState(() {
      _running = true;
      _taskRunning = true;
      _error = null;
      _countdown = 3;
      _activeIndex = -1;
      _taskLabel = task.title;
    });

    for (var n = 3; n >= 1; n--) {
      if (c.cancelled) break;
      setState(() => _countdown = n);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    if (c.cancelled) {
      _stop();
      return;
    }

    setState(() => _countdown = 0);

    // The agent receives the same instruction and starts working in chat.
    final agentTask = widget.onAgentTask;
    if (agentTask != null) {
      agentTask(prompt).catchError((Object e) {
        if (mounted) setState(() => _error = 'Agent: ${e.toString()}');
      });
    }

    final runner = MouseTaskRunner(
      c,
      onStep: (_, action) {
        if (!mounted) return;
        setState(() {
          _activeIndex = action.cursor;
          _taskLabel = action.label;
        });
      },
    );

    try {
      await runner.run(task);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _taskRunning = false;
      _activeIndex = -1;
      _taskLabel = null;
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
                      const SizedBox(height: 18),
                      _aiTeamCard(),
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

  Widget _aiTeamCard() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_outlined, size: 18, color: Palette.accent),
              const SizedBox(width: 8),
              Text(
                AppStrings.aiTeamControl,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x3367C7B7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppStrings.teamOfTen,
                  style: const TextStyle(fontSize: 10.5, color: Palette.accent, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.aiTeamDescription,
            style: const TextStyle(fontSize: 12.5, color: Palette.muted, height: 1.5),
          ),
          const SizedBox(height: 12),
          Focus(
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter &&
                  !HardwareKeyboard.instance.isShiftPressed) {
                _runTeamTask();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _taskCtrl,
              focusNode: _taskFocus,
              enabled: !_running,
              minLines: 1,
              maxLines: 3,
              cursorColor: Palette.accent,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: AppStrings.aiTaskHint,
                hintStyle: const TextStyle(color: Palette.muted),
                filled: true,
                fillColor: Palette.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Palette.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Palette.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Palette.accent),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.pressEnterToStart,
            style: const TextStyle(fontSize: 11.5, color: Palette.muted),
          ),
          if (_taskLabel != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Palette.accent),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _taskLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: Palette.accent),
                  ),
                ),
                Text(
                  _activeIndex >= 0 ? AppStrings.cursorProgress(_activeIndex) : '',
                  style: monoStyle(size: 11, color: Palette.muted),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: _taskCtrl,
            builder: (_, _) => Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_running || _controller == null || _origin == null || _taskCtrl.text.trim().isEmpty)
                        ? null
                        : _runTeamTask,
                    icon: Icon(
                      _taskRunning ? Icons.hourglass_top : Icons.smart_toy_rounded,
                      size: 17,
                    ),
                    label: Text(
                      _running
                          ? (_countdown > 0 ? AppStrings.startingIn(_countdown) : AppStrings.teamWorking)
                          : AppStrings.runTeam,
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.accent,
                      foregroundColor: Palette.bg,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _running ? _stop : null,
                  icon: const Icon(Icons.stop_rounded, size: 16),
                  label: Text(AppStrings.stop),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.danger,
                    side: const BorderSide(color: Palette.line),
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                AppStrings.mouseSubtitle,
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
                _controller == null ? AppStrings.notSupported : AppStrings.windowsReady,
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
              Text(AppStrings.preview, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
                          AppStrings.previewPaused,
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
                      ? AppStrings.locatingPointer
                      : AppStrings.position(_origin!.dx, _origin!.dy),
                  style: monoStyle(size: 12, color: Palette.muted),
                ),
              ),
              TextButton.icon(
                onPressed: _capture,
                icon: const Icon(Icons.center_focus_strong_rounded, size: 16),
                label: Text(AppStrings.capturePointer),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.precision_manufacturing_outlined, size: 14, color: Palette.muted),
              const SizedBox(width: 6),
              Text(AppStrings.preciseControl, style: const TextStyle(fontSize: 12, color: Palette.muted)),
              const SizedBox(width: 8),
              SizedBox(
                width: 78,
                child: TextField(
                  controller: _xCtrl,
                  enabled: !_running,
                  keyboardType: TextInputType.number,
                  style: monoStyle(size: 12),
                  decoration: _coordDeco('X'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 78,
                child: TextField(
                  controller: _yCtrl,
                  enabled: !_running,
                  keyboardType: TextInputType.number,
                  style: monoStyle(size: 12),
                  decoration: _coordDeco('Y'),
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _running ? null : _movePrecise,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Palette.line),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(AppStrings.move, style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: _running ? null : _clickPrecise,
                style: FilledButton.styleFrom(
                  backgroundColor: Palette.accent,
                  foregroundColor: Palette.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(AppStrings.click, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _coordDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11, color: Palette.muted),
        filled: true,
        fillColor: Palette.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Palette.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Palette.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Palette.accent)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      );

  Widget _controls() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, size: 17, color: Palette.accent),
              SizedBox(width: 8),
              Text('Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Text(AppStrings.pattern, style: const TextStyle(fontSize: 12.5, color: Palette.muted)),
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
              Text(AppStrings.spacing, style: const TextStyle(fontSize: 12.5, color: Palette.muted)),
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
              Text(AppStrings.clickInterval, style: const TextStyle(fontSize: 12.5, color: Palette.muted)),
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
            title: Text(AppStrings.doubleClick, style: const TextStyle(fontSize: 13)),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Palette.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.realClicksNote,
                    style: const TextStyle(fontSize: 11.5, color: Palette.muted, height: 1.5),
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
                        ? (_countdown > 0 ? AppStrings.startingIn(_countdown) : AppStrings.executing)
                        : AppStrings.runTenClicks,
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
                label: Text(AppStrings.stop),
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
