import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:psyguard_ai_app/core/storage/app_database.dart';
import 'package:psyguard_ai_app/core/storage/database_provider.dart';
import 'package:psyguard_ai_app/features/home/presentation/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'home status follows ERS and keeps explore cards',
    (tester) async {
      // 首頁狀態讀的是最近一次的 ERS（ERS_UNIFIED），85 分屬於紅燈
      SharedPreferences.setMockInitialValues({'last_ers_score': 85.0});
      // 測試預設的畫面很矮，下面的卡片不會被畫出來；拉高到整頁都看得到
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = AppDatabase.memory();
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Needs support'), findsOneWidget);
      expect(find.text('Talk it out'), findsWidgets);
      expect(find.text('Emergency Support'), findsOneWidget);

      router.dispose();
      await db.close();
    },
  );
}
