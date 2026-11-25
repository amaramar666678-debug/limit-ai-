import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../models/model_info.dart';
import '../services/opencode_api.dart';
import '../services/opencode_discovery.dart';

enum AppSection { chat, multiMouse }

class AppState extends ChangeNotifier {
  AppState({String endpoint = '127.0.0.1:4096', this.directory = ''})
      : _endpoint = endpoint,
        api = OpenCodeApi(baseUrl: endpoint);

  OpenCodeApi api;
  String _endpoint;
  String directory;
  String? _username;
  String? _password;
  bool connecting = false;
  bool connected = false;
  String? error;
  String? infoText;
  final List<SessionInfo> sessions = [];
  int activeIndex = -1;
  StreamSubscription<OpenCodeEvent>? _eventSub;
  bool _eventsRunning = false;

  AppSection section = AppSection.chat;
  List<ModelOption> models = List.of(ModelOption.fallback);
  ModelOption? selectedModel;
  String? selectedVariant;
  bool modelsLoaded = false;

  String get endpoint => _endpoint;
  String? get username => _username;

  String get modelLabel => selectedModel?.shortName ?? 'Auto model';
  String get modelSubLabel {
    final m = selectedModel;
    if (m == null) return 'Default';
    final v = selectedVariant;
    return v == null || v.isEmpty ? m.providerID : '${m.providerID} · $v';
  }

  void setSection(AppSection value) {
    if (section == value) return;
    section = value;
    notifyListeners();
  }

  SessionInfo? get current => (activeIndex >= 0 && activeIndex < sessions.length) ? sessions[activeIndex] : null;

  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<void> init() async {
    await autoConnect();
  }

  Future<void> autoConnect() async {
    final discovered = await OpenCodeDiscovery.discover();
    if (discovered != null) {
      await connect(endpoint: discovered.url, username: discovered.username, password: discovered.password);
      if (!connected) _scheduleAutoRetry();
      return;
    }
    await connect();
    if (!connected) _scheduleAutoRetry();
  }

  Timer? _retryTimer;
  void _scheduleAutoRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 5), () {
      if (!connected && !connecting) autoConnect();
    });
  }

  Future<void> connect({String? endpoint, String? directory, String? username, String? password}) async {
    if (endpoint != null && endpoint.trim().isNotEmpty) {
      _endpoint = endpoint.trim();
    }
    if (username != null) _username = username.trim().isEmpty ? null : username.trim();
    if (password != null) _password = password;
    if (directory != null) this.directory = directory.trim();
    api.dispose();
    api = OpenCodeApi(baseUrl: _endpoint, username: _username, password: _password);
    connecting = true;
    error = null;
    notifyListeners();
    try {
      final info = await api.info();
      infoText = info['data'] is Map ? (info['data']['name']?.toString() ?? 'OpenCode') : (info['name']?.toString() ?? 'OpenCode');
      connected = true;
      connecting = false;
      await loadModels();
      await refreshSessions();
      _startEvents();
      if (sessions.isEmpty) {
        await createSession();
      } else if (activeIndex < 0) {
        await selectSession(0);
      }
    } catch (e) {
      connected = false;
      connecting = false;
      error = _err(e);
    }
    notifyListeners();
  }

  String _err(Object e) {
    if (e is OpenCodeApiException) {
      final body = e.body != null && e.body!.isNotEmpty ? ' - ${e.body}' : '';
      return '${e.message}${e.statusCode != null ? ' (${e.statusCode})' : ''}$body';
    }
    return e.toString();
  }

  Future<void> loadModels() async {
    try {
      final raw = await api.listModels();
      final parsed = raw.map(ModelOption.fromJson).where((m) => m.id.isNotEmpty).toList();
      if (parsed.isNotEmpty) models = parsed;
      modelsLoaded = true;
      if (selectedModel == null) {
        try {
          final def = await api.getDefaultModel();
          if (def != null) {
            final id = (def['id'] ?? def['modelID'] ?? '').toString();
            final provider = (def['providerID'] ?? 'opencode').toString();
            final found = models.where((m) => m.id == id && m.providerID == provider);
            if (found.isNotEmpty) selectedModel = found.first;
          }
        } catch (_) {
          // Default model lookup is optional.
        }
      }
      selectedModel ??= models.first;
      final variants = selectedModel!.variants;
      if (variants.isNotEmpty && (selectedVariant == null || !variants.contains(selectedVariant))) {
        selectedVariant = variants.first;
      }
    } catch (_) {
      models = List.of(ModelOption.fallback);
      selectedModel ??= models.first;
      modelsLoaded = false;
    }
    notifyListeners();
  }

  Future<void> selectModel(ModelOption model, {String? variant}) async {
    selectedModel = model;
    final variants = model.variants;
    selectedVariant = (variant != null && variants.contains(variant))
        ? variant
        : (variants.isEmpty ? null : variants.first);
    notifyListeners();
    final s = current;
    if (s == null) return;
    try {
      await api.setSessionModel(
        s.id,
        modelID: model.id,
        providerID: model.providerID,
        variant: selectedVariant,
      );
    } catch (e) {
      error = _err(e);
    }
    notifyListeners();
  }

  Future<void> refreshSessions() async {
    try {
      final list = await api.listSessions(limit: 50);
      final mapped = list.map(_sessionFromJson).toList();
      final currentId = current?.id;
      sessions
        ..clear()
        ..addAll(mapped);
      if (currentId != null) {
        final idx = sessions.indexWhere((s) => s.id == currentId);
        activeIndex = idx >= 0 ? idx : (sessions.isEmpty ? -1 : 0);
      } else {
        activeIndex = sessions.isEmpty ? -1 : 0;
      }
      error = null;
    } catch (e) {
      error = _err(e);
    }
    notifyListeners();
  }

  SessionInfo _sessionFromJson(Map<String, dynamic> j) {
    final id = (j['id'] ?? j['sessionID'] ?? '').toString();
    final title = (j['title'] ?? 'Untitled session').toString();
    String dir = directory;
    final loc = j['location'];
    if (loc is Map && loc['directory'] != null) dir = loc['directory'].toString();
    if (j['directory'] != null) dir = j['directory'].toString();
    return SessionInfo(id: id, title: title.isEmpty ? 'Untitled session' : title, directory: dir);
  }

  Future<void> createSession() async {
    try {
      final j = await api.createSession(
        title: 'New session',
        directory: directory.isNotEmpty ? directory : null,
      );
      final s = _sessionFromJson(j);
      sessions.removeWhere((x) => x.id == s.id);
      sessions.insert(0, s);
      activeIndex = 0;
      s.loaded = true;
      error = null;
      notifyListeners();
      final m = selectedModel;
      if (m != null) {
        try {
          await api.setSessionModel(
            s.id,
            modelID: m.id,
            providerID: m.providerID,
            variant: selectedVariant,
          );
        } catch (_) {
          // Model switch is best-effort for a brand-new session.
        }
      }
    } catch (e) {
      error = _err(e);
      notifyListeners();
    }
  }

  Future<void> selectSession(int index) async {
    if (index < 0 || index >= sessions.length) return;
    activeIndex = index;
    notifyListeners();
    await loadMessages(sessions[index]);
  }

  Future<void> loadMessages(SessionInfo s) async {
    try {
      final raw = await api.getMessages(s.id);
      final msgs = <ChatMessage>[];
      for (final m in raw) {
        final msg = _messageFromJson(m);
        if (msg != null) msgs.add(msg);
      }
      s.messages
        ..clear()
        ..addAll(msgs);
      s.loaded = true;
      error = null;
    } catch (e) {
      error = _err(e);
    }
    notifyListeners();
  }

  ChatMessage? _messageFromJson(Map<String, dynamic> m) {
    final roleRaw = (m['role'] ?? m['type'] ?? '').toString().toLowerCase();
    ChatRole? role;
    if (roleRaw.contains('user')) role = ChatRole.user;
    if (roleRaw.contains('assistant') || roleRaw.contains('agent')) role = ChatRole.assistant;
    if (roleRaw.contains('system')) role = ChatRole.system;
    if (role == null && m['info'] is Map) {
      final info = m['info'] as Map;
      final r = (info['role'] ?? info['type'] ?? '').toString().toLowerCase();
      if (r.contains('user')) role = ChatRole.user;
      if (r.contains('assistant')) role = ChatRole.assistant;
      if (r.contains('system')) role = ChatRole.system;
    }
    role ??= ChatRole.assistant;

    final id = (m['id'] ?? m['messageID'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString();
    final text = _extractText(m);
    final tools = _extractTools(m);
    if (text.trim().isEmpty && tools.isEmpty && role != ChatRole.user) {
      return null;
    }
    return ChatMessage(id: id, role: role, text: text, tools: tools);
  }

  String _extractText(Map<String, dynamic> m) {
    for (final k in ['text', 'content', 'output']) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    final content = m['content'] ?? (m['info'] is Map ? (m['info'] as Map)['content'] : null);
    if (content is String) return content;
    if (content is List) {
      final buf = StringBuffer();
      for (final p in content) {
        if (p is String) {
          buf.writeln(p);
        } else if (p is Map) {
          final t = (p['text'] ?? p['content'] ?? p['value']);
          final type = (p['type'] ?? '').toString().toLowerCase();
          if (t is String && (type.isEmpty || type.contains('text'))) {
            if (type.contains('tool')) continue;
            buf.write(t);
          }
        }
      }
      final s = buf.toString().trim();
      if (s.isNotEmpty) return s;
    }
    final parts = m['parts'];
    if (parts is List) {
      final buf = StringBuffer();
      for (final p in parts) {
        if (p is Map) {
          final type = (p['type'] ?? '').toString().toLowerCase();
          if (type.contains('text')) {
            final t = p['text'];
            if (t is String) buf.write(t);
          }
        }
      }
      final s = buf.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  List<ToolEntry> _extractTools(Map<String, dynamic> m) {
    final out = <ToolEntry>[];
    void addPart(dynamic p) {
      if (p is! Map) return;
      final type = (p['type'] ?? '').toString().toLowerCase();
      if (!type.contains('tool')) return;
      final name = (p['tool'] ?? p['name'] ?? p['title'] ?? 'Tool').toString();
      final state = p['state'] is Map ? p['state'] as Map : p;
      final statusRaw = (state['status'] ?? p['status'] ?? '').toString().toLowerCase();
      var status = ToolStatus.running;
      if (statusRaw.contains('done') || statusRaw.contains('complete') || statusRaw.contains('success')) status = ToolStatus.done;
      if (statusRaw.contains('fail') || statusRaw.contains('error')) status = ToolStatus.failed;
      final input = state['input'] ?? p['input'];
      final output = state['output'] ?? p['output'];
      out.add(ToolEntry(
        id: (p['id'] ?? '${name}_${out.length}').toString(),
        kind: _toolKind(name),
        title: name,
        detail: input is String ? input : (input is Map ? (input['filePath'] ?? input['command'] ?? input['pattern'] ?? input.toString()).toString() : ''),
        output: output is String ? output : (output == null ? '' : output.toString()),
        status: status,
      ));
    }

    final content = m['content'];
    if (content is List) {
      for (final p in content) {
        addPart(p);
      }
    }
    final parts = m['parts'];
    if (parts is List) {
      for (final p in parts) {
        addPart(p);
      }
    }
    return out;
  }

  ToolKind _toolKind(String name) {
    final n = name.toLowerCase();
    if (n.contains('read')) return ToolKind.read;
    if (n.contains('edit') || n.contains('write') || n.contains('patch')) return ToolKind.edit;
    if (n.contains('bash') || n.contains('shell') || n.contains('cmd')) return ToolKind.bash;
    if (n.contains('search') || n.contains('grep') || n.contains('glob')) return ToolKind.search;
    return ToolKind.other;
  }

  Future<void> send(String text) async {
    final t = text.trim();
    final s = current;
    if (t.isEmpty || s == null || s.busy) return;
    final optimistic = ChatMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.user,
      text: t,
    );
    s.messages.add(optimistic);
    s.busy = true;
    if (s.title == 'New session' || s.title == 'Untitled session') {
      s.title = t.length > 40 ? '${t.substring(0, 40)}…' : t;
    }
    notifyListeners();
    try {
      await api.prompt(s.id, t);
      await loadMessages(s);
      error = null;
    } catch (e) {
      error = _err(e);
      s.busy = false;
    }
    notifyListeners();
  }

  Future<void> interruptCurrent() async {
    final s = current;
    if (s == null) return;
    try {
      await api.interrupt(s.id);
    } catch (e) {
      error = _err(e);
      notifyListeners();
    }
  }

  void _startEvents() {
    if (_eventsRunning) return;
    _eventsRunning = true;
    _eventSub?.cancel();
    _eventSub = api.subscribeEvents().listen((evt) {
      _handleEvent(evt);
    }, onError: (e) {
      _eventsRunning = false;
      connected = false;
      error = _err(e is Object ? e : Exception('Event stream error'));
      notifyListeners();
      Future.delayed(const Duration(seconds: 2), () {
        if (!_eventsRunning) connect();
      });
    }, onDone: () {
      _eventsRunning = false;
      connected = false;
      notifyListeners();
    });
  }

  void _handleEvent(OpenCodeEvent evt) {
    final type = evt.type.toLowerCase();
    final p = evt.payload ?? evt.raw;
    final sessionId = _findSessionId(p);
    final s = sessions.where((x) => x.id == sessionId).cast<SessionInfo?>().firstWhere((x) => true, orElse: () => null);

    if (type.contains('session.created') || type.contains('session.updated') || type.contains('session.renamed')) {
      refreshSessions();
      return;
    }
    if (s != null) {
      if (type.contains('session.execution.started') || type.contains('session.step.started')) {
        s.busy = true;
        notifyListeners();
      }
      if (type.contains('session.execution.succeeded') || type.contains('session.execution.failed') || type.contains('session.execution.interrupted') || type.contains('session.idle')) {
        s.busy = false;
        loadMessages(s);
        notifyListeners();
        return;
      }
      if (type.contains('session.text') || type.contains('session.tool') || type.contains('session.message') || type.contains('session.step')) {
        loadMessages(s);
      }
    }
  }

  String? _findSessionId(Map<String, dynamic> p) {
    for (final k in ['sessionID', 'sessionId', 'session_id', 'id']) {
      final v = p[k];
      if (v is String && v.startsWith('ses')) return v;
    }
    for (final v in p.values) {
      if (v is Map<String, dynamic>) {
        final found = _findSessionId(v);
        if (found != null) return found;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _eventSub?.cancel();
    api.dispose();
    super.dispose();
  }
}





