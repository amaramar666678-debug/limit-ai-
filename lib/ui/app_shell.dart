import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_models.dart';
import '../models/model_info.dart';
import '../state/app_state.dart';
import 'logo.dart';
import 'multi_mouse_page.dart';
import 'theme.dart';

TextDirection dirOf(String s) {
  for (final r in s.runes) {
    if ((r >= 0x0590 && r <= 0x08FF) || (r >= 0xFB50 && r <= 0xFEFF)) return TextDirection.rtl;
    if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) return TextDirection.ltr;
  }
  return TextDirection.ltr;
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (_, _) => Scaffold(
          body: Row(
            children: [
              SizedBox(width: 268, child: _Sidebar(state: state)),
              const VerticalDivider(width: 1, color: Palette.line),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.02, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: state.section == AppSection.chat
                      ? _Workspace(key: const ValueKey('chat'), state: state)
                      : MultiMousePage(
                          key: const ValueKey('multi'),
                          onAgentTask: (text) => state.send(text),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final inChat = state.section == AppSection.chat;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Palette.surface, Color(0xFF121B24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandLogo(size: 30, showGlow: true),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'multi mause',
                      style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                    ),
                    Text('AI workspace', style: TextStyle(fontSize: 10.5, color: Palette.muted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () => _showSettings(context, state),
                icon: const Icon(Icons.settings_outlined, size: 18, color: Palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _NavButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'المحادثة',
            selected: inChat,
            onTap: () => state.setSection(AppSection.chat),
          ),
          const SizedBox(height: 6),
          _NavButton(
            icon: Icons.mouse_rounded,
            label: 'Multi Mause',
            selected: !inChat,
            badge: '10',
            onTap: () => state.setSection(AppSection.multiMouse),
          ),
          const SizedBox(height: 16),
          if (inChat) ...[
            _ProjectCard(state: state),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.connected ? state.createSession : null,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New session'),
                style: FilledButton.styleFrom(
                  backgroundColor: Palette.raised,
                  foregroundColor: Palette.text,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                    side: const BorderSide(color: Palette.line),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'Sessions',
                style: TextStyle(fontSize: 11.5, color: Palette.muted, fontWeight: FontWeight.w700, letterSpacing: 0.6),
              ),
            ),
            Expanded(
              child: state.sessions.isEmpty
                  ? const Center(
                      child: Text('No sessions', style: TextStyle(color: Palette.muted, fontSize: 13)),
                    )
                  : ListView.builder(
                      itemCount: state.sessions.length,
                      itemBuilder: (_, i) => _SessionTile(
                        info: state.sessions[i],
                        selected: i == state.activeIndex,
                        onTap: () => state.selectSession(i),
                        onDelete: () => state.deleteSession(i),
                      ),
                    ),
            ),
            const Divider(color: Palette.line, height: 20),
            _StatusRow(state: state),
          ] else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Palette.raised,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Palette.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.bolt_rounded, size: 15, color: Palette.accent),
                            SizedBox(width: 8),
                            Text('10 cursors', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Win32',
                          style: monoStyle(size: 12, color: Palette.muted),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'اضغط Esc للإيقاف الفوري أثناء التنفيذ.',
                    style: TextStyle(fontSize: 11.5, color: Palette.muted, height: 1.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Palette.raised : null,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: selected ? const Color(0x5567C7B7) : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Palette.accent : Palette.muted,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Palette.text : Palette.muted,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x3367C7B7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(fontSize: 10.5, color: Palette.accent, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final dir = state.directory.isEmpty ? 'No project directory set' : state.directory;
    return Tooltip(
      message: dir,
      child: InkWell(
        onTap: () => _showSettings(context, state),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Palette.line),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, size: 16, color: Palette.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dir,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: state.directory.isEmpty ? Palette.muted : Palette.text,
                  ),
                ),
              ),
              const Icon(Icons.tune, size: 16, color: Palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ok = state.connected;
    final label = state.connecting ? 'Connecting...' : (ok ? 'Connected' : 'Disconnected');
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ok ? Palette.accent : (state.connecting ? Palette.warn : Palette.danger),
            boxShadow: [BoxShadow(color: (ok ? Palette.accent : Palette.danger).withValues(alpha: 0.4), blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12.5)),
              Text(
                state.endpoint,
                style: monoStyle(size: 11.5, color: Palette.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (!ok && !state.connecting)
          TextButton(onPressed: state.connect, child: const Text('Retry', style: TextStyle(fontSize: 12))),
      ],
    );
  }
}

class _SessionTile extends StatefulWidget {
  const _SessionTile({
    required this.info,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });
  final SessionInfo info;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  bool _hover = false;

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Palette.line),
        ),
        title: const Text('حذف المحادثة؟'),
        content: Text(
          'سيتم حذف «${widget.info.title}» من OpenCode. لا يمكن التراجع.',
          style: const TextStyle(fontSize: 13, color: Palette.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Palette.danger, foregroundColor: Palette.bg),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 40,
          decoration: BoxDecoration(
            color: widget.selected ? Palette.raised : (_hover ? const Color(0x151C2833) : null),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(width: 14, child: info.busy ? const _Pulse() : null),
              Expanded(
                child: InkWell(
                  onTap: widget.onTap,
                  child: SizedBox(
                    height: 40,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        info.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: widget.selected ? Palette.text : Palette.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _hover || widget.selected ? 1 : 0,
                child: IconButton(
                  tooltip: 'حذف المحادثة',
                  iconSize: 15,
                  padding: const EdgeInsets.only(right: 4),
                  color: Palette.danger,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: _confirmDelete,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse();
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .3, end: 1.0).animate(_c),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Palette.accent),
          ),
        ),
      );
}

class _Workspace extends StatefulWidget {
  const _Workspace({super.key, required this.state});
  final AppState state;
  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  String? _lastSession;
  int _lastMsgCount = 0;
  bool _lastBusy = false;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _submit(String t) {
    if (t.trim().isEmpty) return;
    widget.state.send(t);
    _input.clear();
    _focus.requestFocus();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    final s = st.current;
    if (s != null) {
      if (_lastSession != s.id || _lastMsgCount != s.messages.length || _lastBusy != s.busy) {
        _lastSession = s.id;
        _lastMsgCount = s.messages.length;
        _lastBusy = s.busy;
        _scrollToEnd();
      }
    }
    return Column(
      children: [
        _TopBar(state: st),
        const Divider(height: 1, color: Palette.line),
        if (st.error != null) _ErrorBanner(message: st.error!, onClose: st.clearError),
        Expanded(child: _body(st, s)),
        _Composer(
          controller: _input,
          focus: _focus,
          enabled: st.connected && s != null,
          running: s?.busy ?? false,
          onSubmit: _submit,
          onStop: st.interruptCurrent,
        ),
      ],
    );
  }

  Widget _body(AppState st, SessionInfo? s) {
    if (!st.connected && !st.connecting) {
      return _CenterMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Not connected to OpenCode',
        detail: 'Start OpenCode server (`opencode serve` or desktop) then connect. Configure endpoint and project directory in settings.',
        action: FilledButton(onPressed: () => _showSettings(context, st), child: const Text('Open settings')),
      );
    }
    if (st.connecting) return const Center(child: CircularProgressIndicator(color: Palette.accent));
    if (s == null) {
      return _CenterMessage(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No session',
        detail: 'Create a new session to start.',
        action: FilledButton(onPressed: st.createSession, child: const Text('New session')),
      );
    }
    if (s.messages.isEmpty) return _EmptyState(onPick: _submit, directory: st.directory);
    return LayoutBuilder(builder: (_, c) {
      final side = math.max(24.0, (c.maxWidth - 860) / 2);
      return ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(side, 24, side, 24),
        itemCount: s.messages.length + (s.busy ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= s.messages.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _BusyIndicator(activity: st.activity),
            );
          }
          return Padding(padding: const EdgeInsets.only(bottom: 14), child: _MessageBlock(s.messages[i]));
        },
      );
    });
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = state.current;
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s?.title ?? 'multi mause',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (s != null)
                  Text(
                    s.directory.isEmpty ? state.directory : s.directory,
                    overflow: TextOverflow.ellipsis,
                    style: monoStyle(size: 11, color: Palette.muted),
                  ),
              ],
            ),
          ),
          _ModelPicker(state: state),
          const SizedBox(width: 12),
          if (s?.busy ?? false)
            OutlinedButton.icon(
              onPressed: state.interruptCurrent,
              icon: const Icon(Icons.stop_rounded, size: 18),
              label: const Text('Stop'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Palette.danger,
                side: const BorderSide(color: Palette.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModelPicker extends StatelessWidget {
  const _ModelPicker({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final variants = state.selectedModel?.variants ?? const <String>[];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<ModelOption>(
          tooltip: 'اختر النموذج',
          color: Palette.surface,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Palette.line),
          ),
          onSelected: (m) => state.selectModel(m),
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              enabled: false,
              height: 36,
              child: Text('Models', style: TextStyle(fontSize: 11, color: Palette.muted, fontWeight: FontWeight.w700)),
            ),
            for (final m in state.models)
              PopupMenuItem<ModelOption>(
                value: m,
                child: _ModelMenuItem(model: m, selected: m.key == state.selectedModel?.key),
              ),
          ],
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Palette.raised,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Palette.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 15, color: Palette.accent),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.modelLabel, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    Text(state.modelSubLabel, style: monoStyle(size: 10, color: Palette.muted)),
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(Icons.expand_more, size: 16, color: Palette.muted),
              ],
            ),
          ),
        ),
        if (variants.isNotEmpty) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Palette.raised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Palette.line),
            ),
            child: DropdownButton<String>(
              value: state.selectedVariant ?? variants.first,
              icon: const Icon(Icons.expand_more, size: 14),
              dropdownColor: Palette.surface,
              underline: const SizedBox(),
              isDense: true,
              style: monoStyle(size: 11, color: Palette.accent),
              items: [
                for (final v in variants)
                  DropdownMenuItem(value: v, child: Text(v)),
              ],
              onChanged: (v) {
                final m = state.selectedModel;
                if (m != null && v != null) state.selectModel(m, variant: v);
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _ModelMenuItem extends StatelessWidget {
  const _ModelMenuItem({required this.model, required this.selected});
  final ModelOption model;
  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 260,
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 16,
              color: selected ? Palette.accent : Palette.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(model.shortName, style: const TextStyle(fontSize: 12.5)),
                  Text(
                    '${model.providerID}${model.context != null ? ' · ${model.context! ~/ 1000}k' : ''}',
                    style: monoStyle(size: 10.5, color: Palette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0x22EA8078),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Palette.danger, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: Palette.danger),
              ),
            ),
            IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 16, color: Palette.danger)),
          ],
        ),
      );
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({required this.icon, required this.title, required this.detail, this.action});
  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Palette.raised,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Color(0x2267C7B7), blurRadius: 24)],
                  ),
                  child: Icon(icon, size: 38, color: Palette.muted),
                ),
                const SizedBox(height: 18),
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Palette.muted, height: 1.5),
                ),
                if (action != null) ...[const SizedBox(height: 20), action!],
              ],
            ),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPick, required this.directory});
  final void Function(String) onPick;
  final String directory;
  static const _ideas = [
    'راجع المشروع واشرح هيكله',
    'Fix bugs and run tests',
    'نفّذ مهمة في المشروع الحالي',
  ];

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandLogo(size: 34),
                const SizedBox(height: 18),
                Text(
                  directory.isEmpty ? 'What should the agent do?' : 'What should the agent do in this project?',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25),
                ),
                const SizedBox(height: 8),
                Text(
                  directory.isEmpty ? 'Set a project directory in settings, then describe the task.' : directory,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Palette.muted,
                    height: 1.5,
                    fontFamily: directory.isEmpty ? sans : mono,
                  ),
                ),
                const SizedBox(height: 24),
                for (final idea in _ideas)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onPick(idea),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.line))),
                        child: Row(
                          children: [
                            Expanded(child: Text(idea, style: const TextStyle(fontSize: 14.5))),
                            const Icon(Icons.north_east_rounded, size: 16, color: Palette.muted),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _BusyIndicator extends StatefulWidget {
  const _BusyIndicator({this.activity});
  final String? activity;

  @override
  State<_BusyIndicator> createState() => _BusyIndicatorState();
}

class _BusyIndicatorState extends State<_BusyIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  IconData _icon(String label) {
    if (label.contains('Thinking')) return Icons.psychology_alt_rounded;
    if (label.contains('Writing')) return Icons.edit_note_rounded;
    if (label.contains('tool')) return Icons.build_rounded;
    return Icons.hourglass_top_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.activity ?? 'Waiting...';
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final active = (_c.value * 3).floor() % 3;
        final pulse = 0.82 + 0.18 * math.sin(_c.value * 2 * math.pi);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Palette.raised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x4467C7B7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: pulse,
                child: Icon(_icon(label), size: 16, color: Palette.accent),
              ),
              const SizedBox(width: 9),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                child: Text(
                  label,
                  key: ValueKey(label),
                  style: const TextStyle(fontSize: 12.5, color: Palette.text),
                ),
              ),
              const SizedBox(width: 8),
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.accent.withValues(alpha: i == active ? 1 : 0.3),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBlock extends StatelessWidget {
  const _MessageBlock(this.m);
  final ChatMessage m;
  @override
  Widget build(BuildContext context) {
    if (m.role == ChatRole.user) return _UserBlock(m);
    return _AgentBlock(m);
  }
}

class _UserBlock extends StatelessWidget {
  const _UserBlock(this.m);
  final ChatMessage m;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D2B36), Color(0xFF1A2631)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0x4467C7B7)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Directionality(
              textDirection: dirOf(m.text),
              child: SelectableText(m.text, style: const TextStyle(fontSize: 14.5, height: 1.5)),
            ),
          ),
        ),
      );
}

class _AgentBlock extends StatelessWidget {
  const _AgentBlock(this.m);
  final ChatMessage m;
  @override
  Widget build(BuildContext context) {
    final hasText = m.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (m.tools.isNotEmpty) ...[
          for (final t in m.tools)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ToolBlock(
                t,
                key: ValueKey('${t.id}${t.status.name}${t.output.length}'),
              ),
            ),
        ],
        if (hasText || m.streaming)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: Palette.accent, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: _RichMessage(text: m.text, streaming: m.streaming)),
            ],
          ),
      ],
    );
  }
}

class _RichMessage extends StatelessWidget {
  const _RichMessage({required this.text, required this.streaming});
  final String text;
  final bool streaming;
  static const _base = TextStyle(fontSize: 14.5, height: 1.65);

  List<InlineSpan> _inline(String t) {
    final p = t.split('`');
    return [
      for (var i = 0; i < p.length; i++)
        if (p[i].isNotEmpty)
          TextSpan(
            text: p[i],
            style: i.isOdd
                ? monoStyle(size: 13, color: Palette.accent).copyWith(backgroundColor: Palette.raised)
                : null,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final parts = text.split('```');
    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      final isLast = i == parts.length - 1;
      if (i.isOdd) {
        var code = parts[i];
        final nl = code.indexOf('\n');
        if (nl != -1 && nl < 20) code = code.substring(nl + 1);
        children.add(_CodeBlock(code.trimRight()));
      } else if (parts[i].trim().isNotEmpty || (isLast && streaming)) {
        final spans = _inline(parts[i].trim());
        if (isLast && streaming) {
          spans.add(const TextSpan(text: ' ▍', style: TextStyle(color: Palette.accent)));
        }
        children.add(
          Directionality(
            textDirection: dirOf(parts[i]),
            child: SelectableText.rich(TextSpan(style: _base, children: spans)),
          ),
        );
      }
    }
    if (children.isEmpty && streaming) {
      children.add(const Text('▍', style: TextStyle(color: Palette.accent, fontSize: 14.5)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock(this.code);
  final String code;
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Palette.surface,
            border: Border.all(color: Palette.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 12, 48, 12),
                child: SelectableText(code, style: monoStyle(size: 12.5, height: 1.55)),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  tooltip: 'Copy',
                  iconSize: 16,
                  color: Palette.muted,
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ToolBlock extends StatefulWidget {
  const _ToolBlock(this.e, {super.key});
  final ToolEntry e;
  @override
  State<_ToolBlock> createState() => _ToolBlockState();
}

class _ToolBlockState extends State<_ToolBlock> {
  bool _open = false;

  IconData _icon(ToolKind k) => switch (k) {
        ToolKind.read => Icons.description_outlined,
        ToolKind.edit => Icons.edit_outlined,
        ToolKind.bash => Icons.terminal_rounded,
        ToolKind.search => Icons.search_rounded,
        ToolKind.other => Icons.build_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final hasOut = e.output.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Palette.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: hasOut ? () => setState(() => _open = !_open) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  switch (e.status) {
                    ToolStatus.running => const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Palette.accent),
                      ),
                    ToolStatus.done => const Icon(Icons.check_circle_rounded, size: 16, color: Palette.accent),
                    ToolStatus.failed => const Icon(Icons.error_rounded, size: 16, color: Palette.danger),
                  },
                  const SizedBox(width: 10),
                  Icon(_icon(e.kind), size: 16, color: Palette.muted),
                  const SizedBox(width: 8),
                  Text(e.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: monoStyle(size: 12.5, color: Palette.muted),
                    ),
                  ),
                  if (hasOut) Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18, color: Palette.muted),
                ],
              ),
            ),
          ),
          if (_open && hasOut)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Palette.bg,
                border: Border(top: BorderSide(color: Palette.line)),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(e.output, style: monoStyle(size: 12.5, height: 1.5)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.enabled,
    required this.running,
    required this.onSubmit,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool enabled;
  final bool running;
  final void Function(String) onSubmit;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListenableBuilder(
              listenable: focus,
              builder: (_, _) => AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
                decoration: BoxDecoration(
                  color: Palette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: focus.hasFocus ? const Color(0x9967C7B7) : Palette.line,
                  ),
                  boxShadow: focus.hasFocus
                      ? const [BoxShadow(color: Color(0x2267C7B7), blurRadius: 18)]
                      : null,
                ),
                child: Column(
                  children: [
                    Focus(
                      onKeyEvent: (_, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter &&
                            !HardwareKeyboard.instance.isShiftPressed) {
                          onSubmit(controller.text);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: controller,
                        focusNode: focus,
                        enabled: enabled,
                        minLines: 1,
                        maxLines: 8,
                        cursorColor: Palette.accent,
                        style: const TextStyle(fontSize: 14.5, height: 1.5),
                        decoration: InputDecoration(
                          hintText: enabled ? 'Describe a task for the agent...' : 'Connect to OpenCode to start',
                          hintStyle: const TextStyle(color: Palette.muted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Enter sends. Shift+Enter adds a line.',
                            style: TextStyle(fontSize: 12, color: Palette.muted),
                          ),
                        ),
                        ListenableBuilder(
                          listenable: controller,
                          builder: (_, _) => _SendButton(
                            canSend: controller.text.trim().isNotEmpty && !running && enabled,
                            running: running,
                            onTap: running
                                ? onStop
                                : (controller.text.trim().isNotEmpty && enabled
                                    ? () => onSubmit(controller.text)
                                    : null),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.canSend,
    required this.running,
    required this.onTap,
  });

  final bool canSend;
  final bool running;
  final VoidCallback? onTap;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.canSend || widget.running;
    final base = widget.running
        ? Palette.raised
        : (widget.canSend ? Palette.accent : Palette.raised);
    final glow = _hover && active;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedBuilder(
        animation: _glow,
        builder: (_, _) {
          final wave = 0.5 + 0.5 * math.sin(_glow.value * 2 * math.pi);
          return AnimatedScale(
            scale: glow ? 1.07 : 1.0,
            duration: const Duration(milliseconds: 140),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              decoration: BoxDecoration(
                color: glow && widget.canSend
                    ? Color.lerp(Palette.accent, Colors.white, 0.14)
                    : base,
                borderRadius: BorderRadius.circular(10),
                boxShadow: glow
                    ? [
                        BoxShadow(
                          color: (widget.running ? Palette.danger : Palette.accent)
                              .withValues(alpha: 0.28 + 0.34 * wave),
                          blurRadius: 13 + 9 * wave,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: widget.onTap,
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      widget.running ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                      size: 20,
                      color: widget.running
                          ? Palette.danger
                          : (widget.canSend ? Palette.bg : Palette.muted),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<void> _showSettings(BuildContext context, AppState state) async {
  final endpointCtrl = TextEditingController(text: state.endpoint);
  final dirCtrl = TextEditingController(text: state.directory);
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: Palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Palette.line),
        ),
        title: const Text('Connection settings'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('OpenCode endpoint', style: TextStyle(fontSize: 12, color: Palette.muted)),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await state.autoConnect();
                    },
                    child: const Text('Auto-detect'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(controller: endpointCtrl, style: monoStyle(size: 13), decoration: _inputDeco('127.0.0.1:4096')),
              const SizedBox(height: 14),
              const Text('Project directory (where agent runs)', style: TextStyle(fontSize: 12, color: Palette.muted)),
              const SizedBox(height: 6),
              TextField(controller: dirCtrl, style: monoStyle(size: 13), decoration: _inputDeco(r'C:\path\to\project')),
              const SizedBox(height: 10),
              Text(
                state.username != null
                    ? 'Auto-detected credentials will be used for this endpoint.'
                    : 'The endpoint should point to a running OpenCode server. The directory is sent as session location.',
                style: const TextStyle(fontSize: 12, color: Palette.muted, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await state.connect(endpoint: endpointCtrl.text, directory: dirCtrl.text);
            },
            child: const Text('Connect'),
          ),
        ],
      );
    },
  );
}

InputDecoration _inputDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Palette.muted),
      filled: true,
      fillColor: Palette.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Palette.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Palette.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Palette.accent)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
