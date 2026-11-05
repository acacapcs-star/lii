import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_language.dart';

const defaultTtsSpeechRate = 0.55;
const minTtsSpeechRate = 0.35;
const maxTtsSpeechRate = 1.0;

double normalizeTtsSpeechRate(double value) {
  final clamped = value.clamp(minTtsSpeechRate, maxTtsSpeechRate);
  return double.parse(clamped.toStringAsFixed(2));
}

final localSettingsServiceProvider = Provider<LocalSettingsService>((ref) {
  return LocalSettingsService(const FlutterSecureStorage());
});

final consentAcceptedProvider = FutureProvider<bool>((ref) async {
  return ref.read(localSettingsServiceProvider).getConsentAccepted();
});

final welcomeSeenProvider = FutureProvider<bool>((ref) async {
  return ref.read(localSettingsServiceProvider).getWelcomeSeen();
});

final ttsSpeechRateProvider = FutureProvider<double>((ref) async {
  return ref.read(localSettingsServiceProvider).getTtsSpeechRate();
});

final appLanguageControllerProvider =
    StateNotifierProvider<AppLanguageController, AppLanguage>((ref) {
      final controller = AppLanguageController(
        ref.read(localSettingsServiceProvider),
      );
      controller.load();
      return controller;
    });

class AppLanguageController extends StateNotifier<AppLanguage> {
  AppLanguageController(this._settings) : super(AppLanguage.zhTw);

  final LocalSettingsService _settings;

  Future<void> load() async {
    state = await _settings.getAppLanguage();
  }

  Future<void> setLanguage(AppLanguage language) async {
    await _settings.setAppLanguage(language);
    state = language;
  }
}

class LocalSettingsService {
  LocalSettingsService(this._storage);

  final FlutterSecureStorage _storage;

  static const _aiBaseUrlKey = 'ai_base_url';
  static const _aiApiKeyKey = 'ai_api_key';
  static const _aiModelKey = 'ai_model';
  static const _lastExportPathKey = 'last_export_path';
  static const _consentAcceptedKey = 'consent_accepted';
  static const _consentAcceptedAtKey = 'consent_accepted_at';
  static const _consentVersionKey = 'consent_version';
  static const _welcomeSeenKey = 'welcome_seen';
  static const _ttsSpeechRateKey = 'tts_speech_rate';
  static const _appLanguageKey = 'app_language';

  Future<void> saveAiSettings({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    await _storage.write(key: _aiBaseUrlKey, value: baseUrl);
    await _storage.write(key: _aiApiKeyKey, value: apiKey);
    await _storage.write(key: _aiModelKey, value: model);
  }

  Future<StoredAiSettings?> getAiSettings() async {
    final baseUrl = (await _storage.read(key: _aiBaseUrlKey))?.trim() ?? '';
    final apiKey = (await _storage.read(key: _aiApiKeyKey))?.trim() ?? '';
    final model = (await _storage.read(key: _aiModelKey))?.trim() ?? '';

    if (baseUrl.isEmpty && apiKey.isEmpty && model.isEmpty) {
      return null;
    }

    return StoredAiSettings(baseUrl: baseUrl, apiKey: apiKey, model: model);
  }

  Future<void> clearAiSettings() async {
    await _storage.delete(key: _aiBaseUrlKey);
    await _storage.delete(key: _aiApiKeyKey);
    await _storage.delete(key: _aiModelKey);
  }

  Future<void> setLastExportPath(String path) {
    return _storage.write(key: _lastExportPathKey, value: path);
  }

  Future<String?> getLastExportPath() {
    return _storage.read(key: _lastExportPathKey);
  }

  Future<void> setConsentAccepted({required int version}) async {
    await _storage.write(key: _consentAcceptedKey, value: 'true');
    await _storage.write(
      key: _consentAcceptedAtKey,
      value: DateTime.now().toIso8601String(),
    );
    await _storage.write(key: _consentVersionKey, value: version.toString());
  }

  Future<bool> getConsentAccepted() async {
    final value = await _storage.read(key: _consentAcceptedKey);
    return value == 'true';
  }

  Future<void> setWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeSeenKey, true);
  }

  Future<bool> getWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_welcomeSeenKey) ?? false;
  }

  Future<void> setTtsSpeechRate(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_ttsSpeechRateKey, normalizeTtsSpeechRate(value));
  }

  Future<double> getTtsSpeechRate() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getDouble(_ttsSpeechRateKey);
    return normalizeTtsSpeechRate(value ?? defaultTtsSpeechRate);
  }

  Future<void> setAppLanguage(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appLanguageKey, language.storageValue);
  }

  Future<AppLanguage> getAppLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return AppLanguage.fromStorageValue(prefs.getString(_appLanguageKey));
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_welcomeSeenKey);
    await prefs.remove(_ttsSpeechRateKey);
    await prefs.remove(_appLanguageKey);
  }
}

class StoredAiSettings {
  const StoredAiSettings({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  bool get isConfigured => baseUrl.isNotEmpty && apiKey.isNotEmpty;
}
