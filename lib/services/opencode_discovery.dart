import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class OpenCodeEndpoint {
  OpenCodeEndpoint({required this.url, this.username, this.password});
  final String url;
  final String? username;
  final String? password;
}

class OpenCodeDiscovery {
  static Future<OpenCodeEndpoint?> discover() async {
    final candidates = <OpenCodeEndpoint>[];

    // 1) Environment variables
    final envUrl = Platform.environment['OPENCODE_URL'] ?? Platform.environment['OPENCODE_SERVER'];
    if (envUrl != null && envUrl.trim().isNotEmpty) {
      candidates.add(OpenCodeEndpoint(
        url: envUrl.trim(),
        username: Platform.environment['OPENCODE_USER'] ?? Platform.environment['OPENCODE_USERNAME'],
        password: Platform.environment['OPENCODE_PASSWORD'],
      ));
    }

    // 2) Running OpenCode service file (most reliable when `opencode serve --service` is active)
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      final serviceFile = File('$home\\.local\\state\\opencode\\service.json');
      if (await serviceFile.exists()) {
        try {
          final j = jsonDecode(await serviceFile.readAsString());
          if (j is Map && j['url'] is String) {
            candidates.add(OpenCodeEndpoint(
              url: (j['url'] as String).trim(),
              username: 'opencode',
              password: j['password']?.toString(),
            ));
          }
        } catch (_) {}
      }
    }

    // 3) Warden server file from OpenCode desktop
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      final f = File('$appData\\ai.opencode.desktop\\warden-server.json');
      if (await f.exists()) {
        try {
          final j = jsonDecode(await f.readAsString());
          if (j is Map && j['url'] is String) {
            candidates.add(OpenCodeEndpoint(
              url: (j['url'] as String).trim(),
              username: j['username']?.toString(),
              password: j['password']?.toString(),
            ));
          }
        } catch (_) {}
      }
    }

    // 4) Common local default
    candidates.add(OpenCodeEndpoint(url: 'http://127.0.0.1:4096'));

    for (final c in candidates) {
      if (await _probe(c)) return c;
    }
    // Fallback: try common local ports if nothing responded.
    for (final port in [4096, 4097, 4222, 8080, 3000]) {
      final c = OpenCodeEndpoint(url: 'http://127.0.0.1:$port');
      if (candidates.any((x) => x.url.contains(':$port'))) continue;
      if (await _probe(c)) return c;
    }
    return candidates.isNotEmpty ? candidates.first : OpenCodeEndpoint(url: 'http://127.0.0.1:4096');
  }

  static Future<bool> _probe(OpenCodeEndpoint c) async {
    try {
      final uri = Uri.parse(c.url.endsWith('/') ? '${c.url}api/info' : '${c.url}/api/info');
      final headers = <String, String>{'Accept': 'application/json'};
      if (c.username != null && c.username!.isNotEmpty) {
        headers['Authorization'] = 'Basic ${base64Encode(utf8.encode('${c.username}:${c.password ?? ''}'))}';
      }
      final r = await http.get(uri, headers: headers).timeout(const Duration(seconds: 2));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
