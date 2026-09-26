// AI安全介入邏輯
// 設計者：藍宥欣
// 三級介入系統

enum InterventionLevel {
  green,   // 第一級：自動推送心靈雞湯
  yellow,  // 第二級：AI主動發起關懷對話
  red,     // 第三級：系統提示聯絡輔導室
}

class InterventionConfig {
  final InterventionLevel level;
  final String message;
  final String? actionLabel;
  final String? actionRoute;
  final bool notifyCounselor;

  const InterventionConfig({
    required this.level,
    required this.message,
    this.actionLabel,
    this.actionRoute,
    this.notifyCounselor = false,
  });
}

class AISafetyEngine {
  // 根據ERS分數決定介入等級
  InterventionConfig evaluate(double ersScore, int consecutiveRedDays,
      {bool isZh = true}) {
    // 第三級：紅區（ERS>=70 且連續3天）
    if (ersScore >= 70 && consecutiveRedDays >= 3) {
      return InterventionConfig(
        level: InterventionLevel.red,
        message: isZh
            ? 'lii 注意到你最近很不容易，輔導老師已收到通知，要不要今天和老師聊聊？'
            : 'lii noticed things have been really hard lately. A counselor has been notified. Would you like to talk with them today?',
        actionLabel: isZh ? '好的，我想聊聊' : "Okay, I'd like to talk",
        actionRoute: '/safety',
        notifyCounselor: true,
      );
    }

    // 第三級：ERS>=70 單次
    if (ersScore >= 70) {
      return InterventionConfig(
        level: InterventionLevel.red,
        message: isZh
            ? '你今天承受了很多，lii 在這裡陪你。需要我幫你聯絡輔導室嗎？'
            : 'You have carried a lot today, and lii is here with you. Would you like help contacting the counseling office?',
        actionLabel: isZh ? '查看支援資源' : 'See support resources',
        actionRoute: '/safety',
        notifyCounselor: false,
      );
    }

    // 第二級：黃區（ERS 40~70）
    if (ersScore >= 40) {
      return InterventionConfig(
        level: InterventionLevel.yellow,
        message: isZh
            ? '最近感覺如何？lii 想和你說說話 💙'
            : 'How have you been lately? lii is here if you want to talk 💙',
        actionLabel: isZh ? '和AI聊聊' : 'Chat with AI',
        actionRoute: '/chat',
        notifyCounselor: false,
      );
    }

    // 第一級：綠區
    return InterventionConfig(
      level: InterventionLevel.green,
      message: isZh
          ? '今天狀態不錯！繼續保持 ✨'
          : 'You are doing well today. Keep it up ✨',
      notifyCounselor: false,
    );
  }

  // 高風險語言偵測
  bool detectHighRiskLanguage(String text) {
    const highRiskKeywordsZh = [
      '不想活', '死', '消失', '沒有意義', '放棄',
      '撐不下去', '太累了', '不想了', '結束',
    ];
    // 英文用片語而不是單字，避免 'die' 誤中 'diet'、'died down' 之類
    const highRiskKeywordsEn = [
      'want to die', 'wanna die', 'kill myself', 'end my life',
      'suicide', 'suicidal', 'self harm', 'self-harm',
      'hurt myself', 'better off dead', 'end it all',
      'no reason to live', 'give up on everything',
      'disappear forever', 'nothing matters anymore',
      "can't go on", 'cannot go on', 'so tired of everything',
    ];
    final lowered = text.toLowerCase();
    return highRiskKeywordsZh.any((kw) => text.contains(kw)) ||
        highRiskKeywordsEn.any((kw) => lowered.contains(kw));
  }
}
