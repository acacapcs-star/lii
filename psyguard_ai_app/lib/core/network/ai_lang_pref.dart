/// AI 回覆語言的偏好設定。
///
/// 預設 auto：模型依使用者這則訊息的語言回覆，
/// 打日文回日文、中英夾雜就夾雜著回。
/// 另外兩個選項是強制覆蓋。
///
/// 需要 API 金鑰才有作用；離線模式的回覆是固定的。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiReplyLang { auto, zhTw, en }

extension AiReplyLangX on AiReplyLang {
  String get key => switch (this) {
        AiReplyLang.auto => 'auto',
        AiReplyLang.zhTw => 'zhTw',
        AiReplyLang.en => 'en',
      };

  String label(bool zh) => switch (this) {
        AiReplyLang.auto => zh ? '跟著我打的語言' : 'Follow what I type',
        AiReplyLang.zhTw => zh ? '一律用繁體中文' : 'Always Traditional Chinese',
        AiReplyLang.en => zh ? '一律用英文' : 'Always English',
      };

  String hint(bool zh) => switch (this) {
        AiReplyLang.auto => zh
            ? '打中文回中文，打日文回日文，中英夾雜也會夾雜著回。'
            : 'Chinese gets Chinese, Japanese gets Japanese, mixed stays mixed.',
        AiReplyLang.zhTw =>
          zh ? '不管你打什麼語言，都用繁體中文回。' : 'Always replies in Traditional Chinese.',
        AiReplyLang.en =>
          zh ? '不管你打什麼語言，都用英文回。' : 'Always replies in English.',
      };

  /// 接在系統提示後面的一行
  String directive() => switch (this) {
        AiReplyLang.auto =>
          '\n\n[Language] Reply in the same language the user just wrote in. '
              'If their message mixes languages, you may mix too. '
              'Do not switch to a different language than they used.',
        AiReplyLang.zhTw =>
          '\n\n【語言】不論使用者用什麼語言，一律以繁體中文回覆。',
        AiReplyLang.en =>
          '\n\n[Language] Reply in English only, regardless of what the user wrote.',
      };
}

class AiReplyLangController extends StateNotifier<AiReplyLang> {
  AiReplyLangController() : super(AiReplyLang.auto) {
    _load();
  }

  static const _prefsKey = 'ai_reply_lang';

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_prefsKey);
      state = switch (raw) {
        'zhTw' => AiReplyLang.zhTw,
        'en' => AiReplyLang.en,
        _ => AiReplyLang.auto,
      };
    } catch (_) {
      // 讀不到就維持 auto
    }
  }

  Future<void> set(AiReplyLang v) async {
    state = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, v.key);
    } catch (_) {}
  }
}

final aiReplyLangProvider =
    StateNotifierProvider<AiReplyLangController, AiReplyLang>(
  (ref) => AiReplyLangController(),
);

/// 提示只跳一次
class AiLangNoticeSeen {
  static const key = 'ai_lang_notice_seen';

  static Future<bool> get() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(key) ?? false;
    } catch (_) {
      return true; // 讀不到就當看過，不要重複打擾
    }
  }

  static Future<void> mark() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(key, true);
    } catch (_) {}
  }
}
