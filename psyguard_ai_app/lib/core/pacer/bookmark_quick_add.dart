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
      quote: "記得留時間給自己呼吸。",
      author: '導師',
      toneIndex: 4,
      colorIndex: 4,
    );
    await add(
      quote: "今天什麼都沒做也沒關係，你還在呼吸。",
      author: 'Luna',
      toneIndex: 2,
      colorIndex: 2,
    );
    await add(
      quote: "此刻什麼都沒有發生，你是安全的。",
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

  static const Map<BreathMood, List<List<String>>> _quotes = {
    BreathMood.anxious: [
      ['此刻什麼都沒有發生，你是安全的。', 'Luna'],
      ['心跳快不代表危險，它只是跑在你前面而已。', '導師'],
      ['不用把整天想完，先想接下來十分鐘就好。', '導師'],
      ['你剛剛讓自己的呼吸慢下來了，你比你想的更有能力。', 'Luna'],
    ],
    BreathMood.low: [
      ['今天什麼都沒做也沒關係，你還在呼吸。', 'Luna'],
      ['不用馬上好起來，慢慢來，我在這裡等你。', 'Luna'],
      ['能走到這裡的人是你，這不是小事。', '導師'],
      ['在黑暗裡不用假裝發光，我就陪著你。', 'Luna'],
    ],
    BreathMood.calm: [
      ['這樣就夠了，不用再多做什麼。', 'Luna'],
      ['今天你照顧了自己。', '導師'],
      ['安靜的日子也值得被記住。', 'Luna'],
      ['記得留時間給自己呼吸。', '導師'],
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
