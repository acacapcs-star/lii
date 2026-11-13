import 'package:flutter/widgets.dart';

enum AppLanguage {
  english('en', Locale('en')),
  zhTw('zh_TW', Locale('zh', 'TW'));

  const AppLanguage(this.storageValue, this.locale);

  final String storageValue;
  final Locale locale;

  static AppLanguage fromStorageValue(String? value) {
    return switch (value) {
      'zh_TW' => AppLanguage.zhTw,
      _ => AppLanguage.zhTw,
    };
  }
}
