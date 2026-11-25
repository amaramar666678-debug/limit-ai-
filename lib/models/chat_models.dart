enum ToolStatus { running, done, failed }

enum ToolKind { read, edit, bash, search, other }

enum ChatRole { user, assistant, system }

class ToolEntry {
  ToolEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    this.output = '',
    this.status = ToolStatus.running,
  });

  final String id;
  final ToolKind kind;
  final String title;
  final String detail;
  String output;
  ToolStatus status;
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.streaming = false,
    List<ToolEntry>? tools,
  }) : tools = tools ?? [];

  final String id;
  final ChatRole role;
  String text;
  bool streaming;
  final List<ToolEntry> tools;
}

class SessionInfo {
  SessionInfo({
    required this.id,
    required this.title,
    required this.directory,
  });

  final String id;
  String title;
  String directory;
  bool busy = false;
  bool loaded = false;
  final List<ChatMessage> messages = [];
}
