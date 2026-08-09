import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/pacer/bookmark_quick_add.dart';

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
  // SEED_PACERS 第一次開 app 時放三張預設 pacer，Pacer Lift 才不會是空的
  await BookmarkQuickAdd.seedIfEmpty();

  runApp(const ProviderScope(child: LumiApp()));
}
