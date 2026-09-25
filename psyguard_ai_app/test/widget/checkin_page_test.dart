import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psyguard_ai_app/core/storage/app_database.dart';
import 'package:psyguard_ai_app/core/storage/database_provider.dart';
import 'package:psyguard_ai_app/features/checkin/presentation/checkin_page.dart';

void main() {
  testWidgets('check-in note section opens the diary', (tester) async {
    final db = AppDatabase.memory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: CheckinPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Today\'s Note'),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    // 今日筆記已經改成一個入口，點了到筆記頁寫，不再是頁面上的輸入框
    expect(find.text('Today\'s Note'), findsOneWidget);
    expect(find.text('Open Today Diary'), findsOneWidget);
    await db.close();
  });
}
