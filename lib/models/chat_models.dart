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

/// A local file sent to OpenCode as a prompt attachment.
class ChatAttachment {
  ChatAttachment(this.path, {String? name, this.size})
      : name = name ?? _fileName(path);

  final String path;
  final String name;
  final int? size;

  static String _fileName(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    return parts.isEmpty ? path : parts.last;
  }

  bool get isImage {
    final lower = name.toLowerCase();
    return ['.png', '.jpg', '.jpeg', '.gif', '.webp']
        .any((ext) => lower.endsWith(ext));
  }

  Map<String, dynamic> toJson() => {
        'uri': Uri.file(path).toString(),
        'name': name,
      };
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.streaming = false,
    List<ToolEntry>? tools,
    List<ChatAttachment>? attachments,
  })  : tools = tools ?? [],
        attachments = attachments ?? [];

  final String id;
  final ChatRole role;
  String text;
  bool streaming;
  final List<ToolEntry> tools;
  final List<ChatAttachment> attachments;
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
