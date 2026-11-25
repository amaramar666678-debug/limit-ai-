import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenCodeApiException implements Exception {
  OpenCodeApiException(this.message, {this.statusCode, this.body});
  final String message;
  final int? statusCode;
  final String? body;
  @override
  String toString() => 'OpenCodeApiException($statusCode): $message';
}

class OpenCodeEvent {
  OpenCodeEvent({required this.type, required this.raw, this.payload});
  final String type;
  final Map<String, dynamic> raw;
  final Map<String, dynamic>? payload;
}

class OpenCodeApi {
  OpenCodeApi({required String baseUrl, this.username, this.password}) : baseUrl = _normalize(baseUrl);

  String baseUrl;
  String? username;
  String? password;
  final http.Client _client = http.Client();

  static String _normalize(String input) {
    var v = input.trim();
    if (v.isEmpty) v = '127.0.0.1:4096';
    if (!v.startsWith('http://') && !v.startsWith('https://')) {
      v = 'http://$v';
    }
    return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return u;
    return u.replace(queryParameters: {...u.queryParameters, ...query});
  }

  Map<String, String> get _headers {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final u = username;
    final p = password;
    if (u != null && u.isNotEmpty) {
      h['Authorization'] = 'Basic ${base64Encode(utf8.encode('$u:${p ?? ''}'))}';
    }
    return h;
  }

  dynamic _decode(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw OpenCodeApiException(
        'Request failed',
        statusCode: r.statusCode,
        body: r.body,
      );
    }
    if (r.body.isEmpty) return null;
    return jsonDecode(r.body);
  }

  Future<Map<String, dynamic>> getJson(String path, [Map<String, String>? query]) async {
    final r = await _client.get(_uri(path, query), headers: _headers);
    final data = _decode(r);
    if (data is Map<String, dynamic>) return data;
    throw OpenCodeApiException('Unexpected response', body: r.body);
  }

  Future<Map<String, dynamic>?> postJson(String path, [Object? body]) async {
    final r = await _client.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {}));
    final data = _decode(r);
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    throw OpenCodeApiException('Unexpected response', body: r.body);
  }

  Future<Map<String, dynamic>?> patchJson(String path, [Object? body]) async {
    final r = await _client.patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {}));
    final data = _decode(r);
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    throw OpenCodeApiException('Unexpected response', body: r.body);
  }

  Future<void> delete(String path) async {
    final r = await _client.delete(_uri(path), headers: _headers);
    _decode(r);
  }

  Future<Map<String, dynamic>> info() => getJson('/api/info');

  Future<List<Map<String, dynamic>>> listSessions({int limit = 50}) async {
    final res = await getJson('/api/session', {'limit': '$limit', 'order': 'desc'});
    final data = res['data'];
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    // fallback if API shape differs
    final items = res['items'] ?? res['sessions'];
    if (items is List) return items.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  Future<Map<String, dynamic>> createSession({String? title, String? directory}) async {
    final body = <String, dynamic>{};
    if (title != null && title.isNotEmpty) body['title'] = title;
    if (directory != null && directory.isNotEmpty) {
      body['location'] = {'directory': directory};
    }
    final res = await postJson('/api/session', body);
    final data = res?['data'];
    if (data is Map<String, dynamic>) return data;
    if (res != null && res.containsKey('id')) return res;
    throw OpenCodeApiException('Could not create session', body: res?.toString());
  }

  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final res = await getJson('/api/session/$sessionId');
    final data = res['data'];
    if (data is Map<String, dynamic>) return data;
    return res;
  }

  Future<List<Map<String, dynamic>>> getMessages(String sessionId) async {
    final res = await getJson('/api/session/$sessionId/message');
    final data = res['data'] ?? res['messages'] ?? res['items'];
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  Future<Map<String, dynamic>> prompt(String sessionId, String text) async {
    final res = await postJson('/api/session/$sessionId/prompt', {
      'text': text,
    });
    final data = res?['data'];
    if (data is Map<String, dynamic>) return data;
    return res ?? {};
  }

  Future<void> interrupt(String sessionId) async {
    await postJson('/api/session/$sessionId/interrupt', {});
  }

  Stream<OpenCodeEvent> subscribeEvents() async* {
    final req = http.Request('GET', _uri('/api/event'));
    req.headers.addAll(_headers);
    req.headers['Accept'] = 'text/event-stream';
    req.headers['Cache-Control'] = 'no-cache';
    final res = await _client.send(req);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw OpenCodeApiException('Event stream failed', statusCode: res.statusCode);
    }
    String? eventName;
    final dataLines = <String>[];
    await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          final rawData = dataLines.join('\n');
          dataLines.clear();
          final evt = _parseEvent(eventName, rawData);
          eventName = null;
          if (evt != null) yield evt;
        } else {
          eventName = null;
        }
        continue;
      }
      if (line.startsWith(':')) continue;
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
        continue;
      }
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
  }

  OpenCodeEvent? _parseEvent(String? eventName, String rawData) {
    dynamic decoded;
    try {
      decoded = jsonDecode(rawData);
    } catch (_) {
      return OpenCodeEvent(type: eventName ?? 'message', raw: {'data': rawData});
    }
    if (decoded is! Map<String, dynamic>) {
      return OpenCodeEvent(type: eventName ?? 'message', raw: {'data': decoded});
    }
    final type = (decoded['type'] ?? eventName ?? 'message').toString();
    final payload = decoded['properties'] is Map<String, dynamic>
        ? decoded['properties'] as Map<String, dynamic>
        : decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;
    return OpenCodeEvent(type: type, raw: decoded, payload: payload);
  }

  void dispose() {
    _client.close();
  }
}
