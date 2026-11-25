import 'package:shared_preferences/shared_preferences.dart';

/// persisted, user-editable application settings.
class StoredSettings {
  const StoredSettings({
    this.endpoint = '127.0.0.1:4096',
    this.directory = '',
    this.language = 'en',
    this.modelId,
    this.providerId,
    this.variant,
  });

  final String endpoint;
  final String directory;
  final String language;
  final String? modelId;
  final String? providerId;
  final String? variant;
}

class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _endpoint = 'endpoint';
  static const _directory = 'directory';
  static const _language = 'language';
  static const _modelId = 'modelId';
  static const _providerId = 'providerId';
  static const _variant = 'variant';

  static Future<SettingsStore> create() async =>
      SettingsStore(await SharedPreferences.getInstance());

  StoredSettings load() => StoredSettings(
        endpoint: _prefs.getString(_endpoint) ?? '127.0.0.1:4096',
        directory: _prefs.getString(_directory) ?? '',
        language: _prefs.getString(_language) ?? 'en',
        modelId: _prefs.getString(_modelId),
        providerId: _prefs.getString(_providerId),
        variant: _prefs.getString(_variant),
      );

  Future<void> save({
    String? endpoint,
    String? directory,
    String? language,
    String? modelId,
    String? providerId,
    String? variant,
  }) async {
    if (endpoint != null) await _prefs.setString(_endpoint, endpoint);
    if (directory != null) await _prefs.setString(_directory, directory);
    if (language != null) await _prefs.setString(_language, language);
    if (modelId != null) {
      await _prefs.setString(_modelId, modelId);
    } else {
      await _prefs.remove(_modelId);
    }
    if (providerId != null) {
      await _prefs.setString(_providerId, providerId);
    } else {
      await _prefs.remove(_providerId);
    }
    if (variant != null) {
      await _prefs.setString(_variant, variant);
    } else {
      await _prefs.remove(_variant);
    }
  }
}
