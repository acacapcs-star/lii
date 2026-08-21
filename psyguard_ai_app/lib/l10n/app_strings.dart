import 'app_language.dart';

class AppStrings {
  const AppStrings._(this.language);

  final AppLanguage language;

  static AppStrings of(AppLanguage language) => AppStrings._(language);

  bool get isZhTw => language == AppLanguage.zhTw;

  String get appName => 'Luna';

  String get todayMentalStateAnalysis => isZhTw ? '今日心理狀態分析' : "Today's Mental State Analysis";

  String get welcomeTagline =>
      isZhTw ? '你的心理健康\n陪伴夥伴' : 'Your mental health\nsupport companion';

  String get disclaimerTitle => isZhTw ? '重要聲明' : 'Important Notice';

  String get disclaimerBody => isZhTw
      ? '本應用提供心理健康支持與自我覺察工具，非醫療診斷或治療。若有立即危險，請立刻撥打 110 或 119。'
      : 'This app provides mental health support and self-awareness tools. It is not medical diagnosis or treatment. If you are in immediate danger, call your local emergency number right away.';

  String get getStarted => isZhTw ? '開始使用' : 'Get Started';

  String get consentTitle => isZhTw ? '開始前確認' : 'Before You Start';

  String get consentPrivacyBody => isZhTw
      ? '隱私與資料：第一版資料只儲存在你的手機本機（可在設定中清除）。\nAI：若你之後自行設定 API Key，聊天內容可能會送到第三方 AI 服務進行生成回覆。'
      : 'Privacy and data: In this first version, data is stored only on your device and can be cleared in Settings.\nAI: If you later configure your own API key, chat content may be sent to a third-party AI service to generate replies.';

  String get consentCheckbox => isZhTw
      ? '我了解本應用不是醫療工具；若有立即危險我會優先尋求真人協助（110/119/1925）。'
      : 'I understand this app is not a medical tool. If I am in immediate danger, I will seek real-person help first.';

  String get consentAgree => isZhTw ? '同意並開始' : 'Agree and Start';

  String get needImmediateHelp =>
      isZhTw ? '我現在需要立即求助' : 'I need urgent help now';

  String get loading => isZhTw ? '載入中...' : 'Loading...';
  String loadFailed(Object error) =>
      isZhTw ? '載入失敗：$error' : 'Failed to load: $error';
  String saveFailed(Object error) =>
      isZhTw ? '儲存失敗：$error' : 'Failed to save: $error';
  String sendFailed(Object error) =>
      isZhTw ? '傳送失敗：$error' : 'Failed to send: $error';
  String operationFailed(Object error) =>
      isZhTw ? '操作失敗：$error' : 'Operation failed: $error';
  String get cancel => isZhTw ? '取消' : 'Cancel';
  String get reset => isZhTw ? '重置' : 'Reset';
  String get clear => isZhTw ? '清除' : 'Clear';
  String get copy => isZhTw ? '複製' : 'Copy';
  String get copied => isZhTw ? '已複製' : 'Copied';

  String get navHome => isZhTw ? '首頁' : 'Home';
  String get navChat => isZhTw ? '說出來' : 'Talk it out';
  String get navCheckin => isZhTw ? '筆記紀錄' : 'Check-in';
  String get navSleep => isZhTw ? '睡眠紀錄' : 'Sleep Log';
  String get navTrends => isZhTw ? '趨勢圖' : 'Trends';
  String get navTools => isZhTw ? '心理工具箱' : 'Toolbox';
  String get navSafety => isZhTw ? '安全流程' : 'Safety Flow';
  String get navExport => isZhTw ? '匯出報告' : 'Export Report';
  String get navSettings => isZhTw ? '設定' : 'Settings';

  String get goodMorning => isZhTw ? '早安' : 'Good morning';
  String get goodAfternoon => isZhTw ? '午安' : 'Good afternoon';
  String get goodEvening => isZhTw ? '晚安' : 'Good evening';
  String get peacefulDay => isZhTw ? '願你擁有平靜的一天' : 'May you have a calm day';
  String get statusNeedsAttention => isZhTw ? '需要被關注' : 'Needs attention';
  String get statusWatchful => isZhTw ? '留意中' : 'Keep an eye on it';
  String get statusGood => isZhTw ? '狀態良好' : 'Doing okay';
  // ERS_LABEL 跟首頁的表情顏色同一組門檻（<=40 / 41-70 / >70）
  String get statusCare => isZhTw ? '需要留意' : 'Take care';
  String get statusSupport => isZhTw ? '需要支持' : 'Needs support';
  String get todayStatus => isZhTw ? '今日身心狀態' : 'Today\'s well-being';
  String get exploreSelf => isZhTw ? '探索自己' : 'Explore Yourself';
  String get moreFeatures => isZhTw ? '工具' : 'Tools';
  String get emergencyCase => isZhTw ? '案號 115-E018647' : 'Case 115-E018647';
  String get emotionalRelease => isZhTw ? '情緒抒發' : 'Emotional release';
  String get healthDataTrends => isZhTw ? '健康數據趨勢' : 'Health data trends';
  String get supportiveChat => isZhTw ? '想說什麼都行' : "Say what's going on";
  String get sleepStatus => isZhTw ? '記錄睡眠狀況' : 'Track sleep';
  String get moodFirstAid => isZhTw ? '心情急救' : 'Mood first aid';
  String get sevenDaySummary =>
      isZhTw ? '近七天的摘要' : 'A 7-day summary';

  String get chatTitle => navChat;
  String get chatEmptyTitle =>
      isZhTw ? '今天有什麼想聊聊的嗎？' : 'What would you like to talk about today?';
  String get chatEmptySubtitle => isZhTw ? '我在這裡傾聽你' : 'I am here to listen';
  String get chatHint => isZhTw ? '輸入你的感受...' : 'Type how you feel...';
  String get voiceUnavailable => isZhTw
      ? '語音功能無法使用，請確認權限設定'
      : 'Voice is unavailable. Please check permission settings.';
  String get ttsResume => isZhTw ? '繼續播放' : 'Resume';
  String get ttsPause => isZhTw ? '暫停' : 'Pause';
  String get ttsStop => isZhTw ? '終止' : 'Stop';
  String get ttsRead => isZhTw ? '朗讀' : 'Read aloud';
  String get highRiskDetected =>
      isZhTw ? '偵測到高風險訊號' : 'High-risk signal detected';
  String get highRiskSheetBody => isZhTw
      ? '如果你有立即危險，請立刻撥打 110 / 119。你也可以先進入安全流程，取得求助資源與一鍵複製訊息。'
      : 'If you are in immediate danger, call your local emergency number now. You can also enter the safety flow for support resources and a prepared message.';
  String get goToSafety => isZhTw ? '前往安全流程' : 'Go to Safety Flow';
  String get keepChatting => isZhTw ? '我想再聊一下' : 'Keep chatting';
  String riskContext(String level, String reasons) =>
      isZhTw ? '風險:$level，原因:$reasons' : 'Risk: $level. Reasons: $reasons';

  String get checkinTitle => navCheckin;
  String get mood => isZhTw ? '情緒穩定度' : 'Emotional Stability';
  String get stress => isZhTw ? '情緒輕鬆度' : 'Emotional Ease';
  String get energy => isZhTw ? '情緒韌性值' : 'Emotional Resilience';
  String get todayNote => isZhTw ? '今日筆記' : 'Today\'s Note';
  String get noteHint =>
      isZhTw ? '想記下什麼嗎？（選填）' : 'Anything to write down? (optional)';
  String get completeCheckin => isZhTw ? '完成紀錄' : 'Complete Check-in';
  String get noteTooLong =>
      isZhTw ? '補充文字請控制在 200 字內' : 'Please keep the note under 200 characters.';
  String savedRisk(String level) =>
      isZhTw ? '已記錄！風險等級：$level' : 'Saved. Risk level: $level';
  String get veryBad => isZhTw ? '很差' : 'Very low';
  String get bad => isZhTw ? '不好' : 'Low';
  String get okay => isZhTw ? '普通' : 'Okay';
  String get good => isZhTw ? '不錯' : 'Good';
  String get veryGood => isZhTw ? '很好' : 'Very good';

  String get sleepTitle => navSleep;
  String get sleepDuration => isZhTw ? '睡眠時長' : 'Sleep Duration';
  String hours(double value) => isZhTw
      ? '${value.toStringAsFixed(1)} 小時'
      : '${value.toStringAsFixed(1)} hr';
  String get sleepDifficulty => isZhTw ? '入睡困難度' : 'Difficulty Falling Asleep';
  List<String> get sleepDifficultyLabels => isZhTw
      ? const ['沒有困難', '輕微', '中度', '嚴重']
      : const ['None', 'Mild', 'Moderate', 'Severe'];
  String get bedtime => isZhTw ? '就寢時間' : 'Bedtime';
  String get waketime => isZhTw ? '起床時間' : 'Wake Time';
  String get saveSleep => isZhTw ? '儲存睡眠紀錄' : 'Save Sleep Log';
  String savedSleepRisk(String level) =>
      isZhTw ? '已儲存！風險：$level' : 'Saved. Risk: $level';

  String get toolsTitle => navTools;
  String get toolHistory => isZhTw ? '練習紀錄' : 'Practice History';
  String get todayGuidance => isZhTw ? '今日指引' : 'Today\'s Guidance';
  String get acceptThisLine => isZhTw ? '收下這句話' : 'Keep this line';
  String get startExperience => isZhTw ? '開始體驗' : 'Start';
  String get completePractice =>
      isZhTw ? '完成今日練習' : 'Complete Today\'s Practice';
  String toolSavedRisk(String level) =>
      isZhTw ? '已記錄練習！風險：$level' : 'Practice saved. Risk: $level';
  String toolRecordFailed(Object error) =>
      isZhTw ? '記錄失敗：$error' : 'Failed to record: $error';
  String get selfDialogueCard => isZhTw ? '自我對話卡' : 'Self-dialogue Card';
  String get selfDialogueDesc => isZhTw
      ? '抽出一張指引卡片，轉化自我責備的念頭。'
      : 'Draw a guidance card and reframe self-blaming thoughts.';
  String get breathing478 => isZhTw ? '4-7-8 呼吸' : '4-7-8 Breathing';
  String get breathing478Desc => isZhTw
      ? '吸氣 4 秒、閉氣 7 秒、吐氣 8 秒，做 3 回合。'
      : 'Inhale for 4 seconds, hold for 7, exhale for 8. Repeat 3 rounds.';
  String get grounding54321 => isZhTw ? '5-4-3-2-1 著地' : '5-4-3-2-1 Grounding';
  String get grounding54321Desc => isZhTw
      ? '說出你看見 5 樣、摸到 4 樣、聽到 3 樣、聞到 2 樣、感受 1 樣。'
      : 'Name 5 things you see, 4 you touch, 3 you hear, 2 you smell, and 1 you feel.';
  String get emotionDictionary => isZhTw ? '情緒詞彙庫' : 'Emotion Dictionary';
  String get emotionDictionaryDesc => isZhTw
      ? '除了「不開心」，試著精準描述你的感受。'
      : 'Go beyond "not okay" and describe your feelings more precisely.';

  String get safetyTitle => navSafety;
  String get safetyFirst => isZhTw ? '先確保安全' : 'Safety First';
  String get needHelpQuestion => isZhTw ? '需要協助嗎？' : 'Need help?';
  String get immediateDangerCall => isZhTw
      ? '若有立即危險請先撥打 110 / 119。'
      : 'If you are in immediate danger, call your local emergency number first.';
  String get supportResources => isZhTw ? '求助資源' : 'Support Resources';
  String get safetySteps => isZhTw ? '安全步驟' : 'Safety Steps';
  String get copyHelpMessage => isZhTw ? '一鍵複製求助訊息' : 'Copy Support Message';
  String get helpMessageCopied => isZhTw ? '已複製求助訊息' : 'Support message copied';

  // ── Safety Flow 的三個選項與守護精靈訊息 ──
  String get safetyOptionChat =>
      isZhTw ? 'A. 繼續跟 LUNA 說話' : 'A. Keep talking with LUNA';
  String get safetyOptionCounselor =>
      isZhTw ? 'B. 聯繫輔導老師' : 'B. Contact a school counselor';
  String get safetyCounselorBody => isZhTw
      ? '請前往校內輔導室，或請導師協助聯繫輔導老師。'
      : 'Go to your school counseling office, or ask your homeroom teacher to help you reach a counselor.';
  String get gotIt => isZhTw ? '了解' : 'Got it';
  String get safetyOptionResources =>
      isZhTw ? 'C. 查看求助資源 (1925) ↓' : 'C. See support resources ↓';
  String get guardianHigh => isZhTw
      ? 'lii 一直都在你身邊，不管你選哪條路，我都陪著你 🤍'
      : 'lii is here with you. Whichever path you choose, I am here 🤍';
  String get guardianMedium => isZhTw
      ? '最近感覺如何？lii 想陪你說說話 💙'
      : 'How have you been feeling? lii is here if you want to talk 💙';
  String get guardianLow =>
      isZhTw ? '今天狀態不錯！繼續保持 ✨' : 'You are doing well today. Keep it up ✨';
  String get liiIsHere => isZhTw ? 'lii 在這裡陪你' : 'lii is here with you';

  String get trendsTitle => isZhTw ? '最近的起伏' : 'Trends';
  String get analysisHistory => isZhTw ? '分析歷史' : 'Analysis History';
  String get aiTrendAnalysis => isZhTw ? 'AI 趨勢分析' : 'AI Trend Analysis';
  String days(int value) => isZhTw ? '$value 天' : '$value days';
  String get threeMonths => isZhTw ? '3 個月' : '3 months';
  String get noTrendData => isZhTw ? '還沒有趨勢資料' : 'No trend data yet';
  String get noTrendDataBody => isZhTw
      ? '先完成一次「筆記紀錄」或「睡眠紀錄」，就能開始看到你的 7/14/30 天變化。'
      : 'Complete one check-in or sleep log to start seeing your 7/14/30-day changes.';
  String get doCheckin => isZhTw ? '去做覺察' : 'Do Check-in';
  String get recordSleep => isZhTw ? '記錄睡眠' : 'Record Sleep';
  String get moodPercentage => isZhTw ? '心情百分比' : 'Mood Percentage';
  String get sleepHoursLabel => isZhTw ? '睡眠時長' : 'Sleep Hours';
  String get riskScore => isZhTw ? '風險分數' : 'Risk Score';
  String chartLoadError(Object error) => isZhTw
      ? '圖表載入錯誤：請稍後再試\n$error'
      : 'Chart failed to load. Try again later.\n$error';
  String get loadingTrendData => isZhTw ? '載入趨勢資料...' : 'Loading trend data...';
  String get chooseAiRange =>
      isZhTw ? '選擇 AI 分析範圍' : 'Choose AI Analysis Range';
  String get lastMonth => isZhTw ? '近 1 個月' : 'Last 1 month';
  String get lastThreeMonths => isZhTw ? '近 3 個月' : 'Last 3 months';
  String get lastYear => isZhTw ? '近 1 年' : 'Last 1 year';
  String analysisFailed(Object error) =>
      isZhTw ? '分析失敗：$error' : 'Analysis failed: $error';
  String get aiReportTitle => isZhTw ? 'AI 分析報告' : 'AI Analysis Report';
  String get copyReport => isZhTw ? '複製內容' : 'Copy Content';
  String get reportCopied => isZhTw ? '已複製報告內容' : 'Report copied';
  String get noAnalysisReports =>
      isZhTw ? '目前沒有任何分析紀錄' : 'No analysis reports yet';
  String recentDays(int value) => isZhTw ? '近 $value 天' : 'Last $value days';
  String get viewFullReport => isZhTw ? '查看完整報告' : 'View Full Report';

  String get exportTitle => navExport;
  String exportedTo(String path) =>
      isZhTw ? '已匯出至：$path' : 'Exported to: $path';
  String exportFailed(Object error) =>
      isZhTw ? '匯出失敗：$error' : 'Export failed: $error';
  String get wellbeingReport => isZhTw ? '身心報告' : 'well-being report';
  String exportReportTitle(int days) =>
      isZhTw ? '$days 日身心報告' : '$days-day well-being report';
  String exportReportBody(int days) => isZhTw
      ? '將近 $days 天的心情、睡眠、風險趨勢摘要匯出為 JSON，可分享給專業人員。'
      : 'Export the last $days days of mood, sleep, and risk trends as JSON for sharing with professionals.';
  String get exporting => isZhTw ? '匯出中...' : 'Exporting...';
  String get generateAndSave => isZhTw ? '產生 & 儲存' : 'Generate & Save';
  String get reportDisclaimer => isZhTw
      ? '報告僅供參考，非醫療診斷。'
      : 'This report is for reference only, not medical diagnosis.';
  String get resetDemoData =>
      isZhTw ? '重置並匯入模擬資料 (Demo)' : 'Reset and Import Demo Data';
  String get resetData => isZhTw ? '重置資料' : 'Reset Data';
  String get resetDemoConfirm => isZhTw
      ? '確定要刪除所有現有資料，並匯入 6 個月的模擬數據嗎？\n此動作無法復原。'
      : 'Delete all existing data and import 6 months of demo data?\nThis cannot be undone.';
  String get demoDataImported =>
      isZhTw ? '已重置並匯入模擬資料！' : 'Demo data has been reset and imported.';
}
