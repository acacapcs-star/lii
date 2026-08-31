import '../../l10n/app_language.dart';

const aiFallbackReply =
    '現在連不上伺服器，所以我沒辦法好好回你。你剛剛寫的東西還在，網路好一點再試一次就行。';

const aiFallbackReplyEn =
    'I cannot reach the server right now, so I cannot reply properly. What you wrote is still here — try again when the connection is better.';

/// 還沒設定 API 金鑰時的回覆——跟「連不上」是不同的情況
const aiNoKeyReply =
    '還沒設定 API 金鑰，所以現在是離線模式，我只能回幾句固定的話。'
    '到設定裡填了金鑰，我才能真的讀你寫的東西。';

const aiNoKeyReplyEn =
    'No API key is set, so this is offline mode and I can only give fixed replies. '
    'Add a key in Settings and I can actually read what you write.';

String aiNoKeyReplyFor(AppLanguage language) =>
    language == AppLanguage.zhTw ? aiNoKeyReply : aiNoKeyReplyEn;

const aiHighRiskSafetyReply =
    '我聽見你現在非常痛、也很危險。你不需要一個人撐著。\n\n'
    '請你先做 3 次慢呼吸：吸氣 4 秒、停 2 秒、吐氣 6 秒。\n'
    '如果你有立即危險，請立刻撥打 110 或 119；也可以撥打 1925 安心專線。\n\n'
    '我可以帶你進入安全流程，幫你把求助訊息整理好。';

const aiHighRiskSafetyReplyEn =
    'I hear that you are in a lot of pain and may not be safe right now. You do not have to hold this alone.\n\n'
    'Please take 3 slow breaths first: inhale for 4 seconds, hold for 2 seconds, and exhale for 6 seconds.\n'
    'If you are in immediate danger, call your local emergency number right away.\n\n'
    'I can guide you into the safety flow and help organize a message for support.';

String aiFallbackReplyFor(AppLanguage language) {
  return language == AppLanguage.zhTw ? aiFallbackReply : aiFallbackReplyEn;
}

String aiHighRiskSafetyReplyFor(AppLanguage language) {
  return language == AppLanguage.zhTw
      ? aiHighRiskSafetyReply
      : aiHighRiskSafetyReplyEn;
}

const localOnlyAssistantReplies = <String>{
  aiFallbackReply,
  aiFallbackReplyEn,
  aiHighRiskSafetyReply,
  aiHighRiskSafetyReplyEn,
};
