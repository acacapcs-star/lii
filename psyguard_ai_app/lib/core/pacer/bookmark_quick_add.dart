// 從任何地方掛一台纜車到 Pacer Lift。
// ⚠️ key 必須跟 bookmark_page.dart 的 _kBookmarksKey 一致。
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'breath_plan.dart';

class BookmarkQuickAdd {
  static const String _key = 'bookmarks_v2';

  // SEED_PACERS 首次啟動放三張，之後就不再塞。
  // 只有在一張卡片都沒有的時候才會動作。
  static Future<void> seedIfEmpty() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        if (list.isNotEmpty) return; // 已經有卡片就不動
      } catch (_) {
        // 資料壞掉就當作空的，照樣塞
      }
    }

    // 倒著加，因為 add() 是 insert(0)，最後一句會排在最上面
    await add(
      quote: "Remember to take time to breathe.",
      author: 'Homeroom teacher',
      toneIndex: 4,
      colorIndex: 4,
    );
    await add(
      quote: "It's okay if you did nothing today. You were breathing.",
      author: 'Luna',
      toneIndex: 2,
      colorIndex: 2,
    );
    await add(
      quote: "Right now, nothing is happening. You are safe.",
      author: 'Luna',
      toneIndex: 0,
      colorIndex: 0,
    );
  }

  static Future<void> add({
    required String quote,
    String author = 'Luna',
    int colorIndex = 0,
    int imageIndex = -1,
    int toneIndex = 0,
  }) async {
    if (quote.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    List<dynamic> list = [];
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        list = jsonDecode(raw) as List;
      } catch (_) {
        list = [];
      }
    }

    list.insert(0, <String, dynamic>{
      'quote': quote,
      'author': author,
      'colorIndex': colorIndex,
      'imageIndex': imageIndex,
      'frameIndex': 0,
      'darkY': 0.72,
      'darkRange': 0.35,
      'customImagePath': '',
      'tone': toneIndex,
    });

    await prefs.setString(_key, jsonEncode(list));
  }

  // EN_SEED demo 走英文，這 12 句預設 pacer 一併換成英文
  static const Map<BreathMood, List<List<String>>> _quotes = {
    BreathMood.anxious: [
      ["Right now, nothing is happening. You are safe.", 'Luna'],
      [
        "A fast heartbeat doesn't mean danger. It's just running ahead of you.",
        'Homeroom teacher'
      ],
      [
        "You don't have to think through the whole day. Just the next ten minutes.",
        'Homeroom teacher'
      ],
      [
        "You just slowed your breathing down. You can do more than you think.",
        'Luna'
      ],
    ],
    BreathMood.low: [
      ["It's okay if you did nothing today. You were breathing.", 'Luna'],
      [
        "You don't have to feel better right away. Take your time, I'll wait.",
        'Luna'
      ],
      [
        "You're the one who made it this far. That's not a small thing.",
        'Homeroom teacher'
      ],
      [
        "You don't have to pretend to be bright in the dark. I'll just stay.",
        'Luna'
      ],
    ],
    BreathMood.calm: [
      ["This is enough. You don't have to do more.", 'Luna'],
      ["You took care of yourself today.", 'Homeroom teacher'],
      ["Quiet days are worth remembering too.", 'Luna'],
      ["Remember to take time to breathe.", 'Homeroom teacher'],
    ],
  };

  static final math.Random _rng = math.Random();

  static Future<String> addFromBreath(BreathMood mood) async {
    final list = _quotes[mood]!;
    final pick = list[_rng.nextInt(list.length)];
    await add(quote: pick[0], author: pick[1]);
    return pick[0];
  }
}
