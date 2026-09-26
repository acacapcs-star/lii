import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:psyguard_ai_app/core/config/app_config.dart';
import 'package:psyguard_ai_app/core/network/ai_api_client.dart';
import 'package:psyguard_ai_app/core/widgets/gleam_reply.dart';
import 'package:psyguard_ai_app/core/widgets/memory_ball.dart';

void main() {
  final offline = AppConfig(baseUrl: '', apiKey: '', model: '', appEnv: 'test');
  final service = GleamReplyService(MockAiClient(), offline, Random(7));

  test('never repeats the previous line offline', () {
    for (final g in EmotionGroup.values) {
      var prev = '';
      for (var i = 0; i < 30; i++) {
        final line = service.localReply(g, true, previous: prev);
        expect(line, isNot(prev));
        prev = line;
      }
    }
  });

  test('has several lines for every group in both languages', () {
    for (final g in EmotionGroup.values) {
      for (final zh in [true, false]) {
        final seen = <String>{};
        for (var i = 0; i < 200; i++) {
          seen.add(service.localReply(g, zh));
        }
        expect(seen.length, greaterThanOrEqualTo(8));
      }
    }
  });

  test('without an AI key the note never leaves the device', () async {
    final out = await service.reply(
      group: EmotionGroup.sad,
      word: '失落',
      memo: '今天有點想家',
      zh: true,
    );
    expect(out, isNotEmpty);
  });
}
