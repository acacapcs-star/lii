import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:psyguard_ai_app/core/widgets/luna_orb.dart' show GlassTone;
import 'package:psyguard_ai_app/core/widgets/memory_ball.dart';
import 'package:shared_preferences/shared_preferences.dart';

MemoryBall ball(int id, DateTime at) => MemoryBall(
      id: id,
      createdAt: at,
      source: BallSource.emotionDict,
      tone: GlassTone.amber,
      group: EmotionGroup.tired,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MemoryBall JSON', () {
    test('reads balls saved before memo and reply existed', () {
      final b = MemoryBall.fromJson({
        'id': 1,
        'created_at': '2026-09-20T10:00:00.000',
        'source': 'emotion_dict',
        'tone': GlassTone.dawn.index,
        'group': 'angry',
      });
      expect(b.memo, '');
      expect(b.reply, '');
    });

    test('round-trips memo and reply', () {
      final b = MemoryBall(
        id: 2,
        createdAt: DateTime(2026, 9, 20),
        source: BallSource.emotionDict,
        tone: GlassTone.ice,
        memo: '今天有點想家',
        reply: '這個感覺可以先放在這裡。',
      );
      final back = MemoryBall.fromJson(
          jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>);
      expect(back.memo, '今天有點想家');
      expect(back.reply, '這個感覺可以先放在這裡。');
    });

    test('linking a card keeps memo and reply', () async {
      final b = await MemoryBallStore.addFromEmotion(
          group: EmotionGroup.sad, word: '', memo: '寫下來了');
      await MemoryBallStore.setReply(b.id, 'Luna 有看到');
      await MemoryBallStore.linkPacer(b.id, 'card-1');
      final after = (await MemoryBallStore.load()).single;
      expect(after.pacerId, 'card-1');
      expect(after.memo, '寫下來了');
      expect(after.reply, 'Luna 有看到');
    });
  });

  group('how long the jar keeps balls', () {
    final now = DateTime.now();

    test('keeps everything by default', () async {
      expect(await MemoryBallStore.loadKeep(), JarKeep.forever);
      await MemoryBallStore.restoreAll([
        ball(1, now),
        ball(2, now.subtract(const Duration(days: 400))),
      ]);
      await MemoryBallStore.applyKeepRule();
      expect(await MemoryBallStore.load(), hasLength(2));
    });

    test('one month removes only balls older than 30 days', () async {
      await MemoryBallStore.restoreAll([
        ball(1, now),
        ball(2, now.subtract(const Duration(days: 29))),
        ball(3, now.subtract(const Duration(days: 31))),
      ]);
      await MemoryBallStore.saveKeep(JarKeep.month);
      await MemoryBallStore.applyKeepRule();
      final left = await MemoryBallStore.load();
      expect(left.map((b) => b.id), containsAll([1, 2]));
      expect(left.map((b) => b.id), isNot(contains(3)));
    });

    test('counts what a shorter setting would remove before switching', () {
      final all = [
        ball(1, now),
        ball(2, now.subtract(const Duration(days: 60))),
        ball(3, now.subtract(const Duration(days: 200))),
      ];
      expect(MemoryBallStore.countExpired(all, JarKeep.forever), 0);
      expect(MemoryBallStore.countExpired(all, JarKeep.semester), 1);
      expect(MemoryBallStore.countExpired(all, JarKeep.month), 2);
    });

    test('warns before the cap', () {
      expect(MemoryBallStore.nearFull, lessThan(MemoryBallStore.maxBalls));
    });
  });
}
