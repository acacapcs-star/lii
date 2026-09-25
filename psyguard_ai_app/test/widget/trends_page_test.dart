import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psyguard_ai_app/core/storage/app_database.dart';
import 'package:psyguard_ai_app/core/storage/database_provider.dart';
import 'package:psyguard_ai_app/features/trends/presentation/trends_page.dart';

void main() {
  testWidgets('trends page range slider changes the day range', (tester) async {
    final db = AppDatabase.memory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: TrendsPage()),
      ),
    );

    await tester.pumpAndSettle();

    // 舊的 7 / 14 / 30 / 90 天按鈕已經換成 3 到 30 天的拉桿
    final container =
        ProviderScope.containerOf(tester.element(find.byType(TrendsPage)));
    expect(container.read(trendRangeProvider), 30);

    await tester.drag(find.byType(Slider), const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(container.read(trendRangeProvider), 3);

    await db.close();
  });
}
