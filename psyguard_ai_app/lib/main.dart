import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/security/local_settings_service.dart';
import 'core/pacer/bookmark_quick_add.dart';
import 'l10n/app_language.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    try {
      await dotenv.load(fileName: '.env.example');
    } catch (_) {
      // Allow running with --dart-define when env files are unavailable.
    }
  }
  final container = ProviderContainer();
  await container.read(appLanguageControllerProvider.notifier).load();
  final lang = container.read(appLanguageControllerProvider);
  // SEED_PACERS 第一次開 app 時放三張預設 pacer，Pacer Lift 才不會是空的
  await BookmarkQuickAdd.seedIfEmpty(isZh: lang == AppLanguage.zhTw);
  runApp(UncontrolledProviderScope(container: container, child: const LumiApp()));
}
