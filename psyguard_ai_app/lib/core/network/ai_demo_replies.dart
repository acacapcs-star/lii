// 展示模式的預設回覆。
//
// 為什麼需要這個：網頁版是純前端，金鑰會出現在 JS bundle 裡
// （理由見 core/config/access_gate.dart 的檔頭）。所以公開的 demo
// 不內建金鑰，改成走這裡預先寫好的回覆。
//
// 這不是「假裝有 AI」——畫面上會明確標示是展示模式，而且
// 使用者輸入的文字在這個模式下完全不會離開瀏覽器。
//
// 開啟方式（build 時）：
//     flutter build web --dart-define=DEMO_MODE=true
// 沒有這個 flag 的 build 行為完全不變，走正常的 API 路徑。

import '../../l10n/app_language.dart';

class DemoReplies {
  const DemoReplies._();

  /// build 時用 --dart-define=DEMO_MODE=true 開啟
  static const bool enabled = bool.fromEnvironment('DEMO_MODE');

  /// 畫面上要顯示的聲明。兩句話各自成立：
  ///   第一句說明這是預錄內容（誠實）
  ///   第二句是真正的隱私性質——在這個模式下沒有任何東西被送出
  static const String noticeZh =
      '展示模式：以下回覆為預先寫好的內容，沒有連接 AI 服務。'
      '你輸入的文字不會離開這個瀏覽器。'
      '完整版需在設定中填入自己的 API 金鑰——網頁版無法安全地內建金鑰。';

  static const String noticeEn =
      'Demo mode: the replies below are written in advance; no AI service is '
      'connected. Nothing you type leaves this browser. '
      'The full version needs your own API key in Settings — a web build '
      'cannot ship a key safely.';

  static String noticeFor(AppLanguage language) =>
      language == AppLanguage.zhTw ? noticeZh : noticeEn;

  /// 主題比對。順序有意義：先比對最需要優先處理的，再往下。
  /// 高風險不在這裡處理——那條路走既有的 aiHighRiskSafetyReply，
  /// 因為展示模式不該削弱安全流程。
  static const List<_Topic> _topics = [
    _Topic(
      keys: ['睡不著', '失眠', '睡不好', '熬夜', '淺眠',
             'sleep', 'insomnia', 'awake', 'tired'],
      zh: '睡不著的時候，腦子通常不是在想一件事，是在輪流想很多件。\n\n'
          '你今天的睡眠紀錄我看到了。如果連續幾天都這樣，那不只是「今天比較累」，'
          '它會把隔天的情緒一起拉低——這也是為什麼睡眠在 lii 裡佔行為串流的 0.7。\n\n'
          '現在要不要先做一輪呼吸？四秒吸、兩秒停、六秒吐，做三次就好。',
      en: 'When you cannot sleep, the mind is usually not holding one thought — '
          'it is cycling through several.\n\n'
          'I can see your sleep log. If this runs for several days it is not '
          'just "a tired day"; it pulls the next day\'s mood down with it. That '
          'is why sleep carries 0.7 of the behaviour stream here.\n\n'
          'Would you like one round of breathing first? In for four, hold two, '
          'out for six — three times is enough.',
    ),
    _Topic(
      keys: ['考試', '段考', '模擬考', '成績', '分數', '讀不完', '複習',
             'exam', 'test', 'grade', 'study', 'revision'],
      zh: '考試的壓力有個特別的地方：它的截止日是固定的，所以焦慮會一直累加，'
          '不像別的事情可以先放著。\n\n'
          '一個具體的問題——你現在卡住的，是「讀不完」還是「讀了不確定有沒有用」？'
          '這兩個不一樣。前者是時間分配，後者通常是別的東西。',
      en: 'Exam stress has one particular quality: the deadline does not move, '
          'so the anxiety accumulates instead of being set aside.\n\n'
          'One concrete question — is what you are stuck on "there is not enough '
          'time" or "I study and cannot tell whether it is working"? Those are '
          'different. The first is scheduling. The second is usually something else.',
    ),
    _Topic(
      keys: ['孤單', '沒人', '一個人', '寂寞', '沒朋友', '被排擠',
             'lonely', 'alone', 'nobody', 'isolated'],
      zh: '覺得沒有人在，跟實際上沒有人在，是兩件常常被混在一起的事。\n\n'
          '我不會跟你說「其實有很多人關心你」——那種話在當下沒有用，'
          '因為它要你先相信一件你現在感覺不到的事。\n\n'
          '可以先回答比較小的那個問題嗎：今天有沒有任何一個人，你本來可以說，但沒說？',
      en: 'Feeling that nobody is there, and nobody actually being there, are two '
          'things that often get folded into one.\n\n'
          'I am not going to tell you that plenty of people care about you — that '
          'does not help in the moment, because it asks you to believe something '
          'you cannot currently feel.\n\n'
          'Could you answer the smaller question instead: was there anyone today '
          'you could have said something to, and did not?',
    ),
    _Topic(
      keys: ['難過', '想哭', '低落', '憂鬱', '沒動力', '提不起勁', '空',
             'sad', 'down', 'depressed', 'empty', 'unmotivated'],
      zh: '你把它寫下來了，這件事本身有用——不是因為寫了會變好，'
          '是因為寫下來之後它才有形狀，可以被看一眼。\n\n'
          '如果你願意，說說它是從什麼時候開始的？今天、這週，還是更久。'
          '這個答案會決定它是一次狀態，還是一段趨勢。',
      en: 'You wrote it down, and that part matters — not because writing makes it '
          'better, but because once it is written it has a shape you can look at.\n\n'
          'If you are willing: when did it start? Today, this week, or longer. '
          'That answer decides whether this is a state or a trend.',
    ),
    _Topic(
      keys: ['生氣', '火大', '氣死', '不爽', '煩死',
             'angry', 'furious', 'annoyed', 'pissed'],
      zh: '生氣通常不是最底下那一層。底下常常是「我覺得不公平」或者「我覺得沒被當一回事」。\n\n'
          '不用現在就分析它。但如果你想講，我想聽的是**發生了什麼**，'
          '不是你覺得自己該不該生氣。',
      en: 'Anger is usually not the bottom layer. Underneath it is often "this is '
          'not fair" or "I was not taken seriously".\n\n'
          'You do not have to analyse it now. But if you want to talk, what I want '
          'to hear is **what happened** — not whether you think you are entitled '
          'to be angry.',
    ),
    _Topic(
      keys: ['壓力', '好累', '撐不住', '喘不過', '太多事', '忙',
             'stress', 'overwhelmed', 'exhausted', 'too much'],
      zh: '「撐不住」這三個字，通常是在撐很久之後才會寫出來的。\n\n'
          '先不要排序，也不要想怎麼解決。就說一件——現在壓在你身上的，最上面那件是什麼？',
      en: '"I cannot keep this up" is usually written after keeping it up for a '
          'long time.\n\n'
          'Do not sort them and do not solve anything yet. Just one — of everything '
          'on you right now, what is on top?',
    ),
  ];

  static const String _genericZh =
      '我在。你可以就這樣寫下去，不用整理好再說。\n\n'
      '如果不知道從哪裡開始，可以先回答一個：今天有沒有哪個時刻，'
      '跟你預期的不一樣？好的壞的都算。';

  static const String _genericEn =
      'I am here. You can keep writing as it comes — it does not have to be '
      'organised first.\n\n'
      'If you do not know where to start, answer one thing: was there a moment '
      'today that did not go the way you expected? Good or bad, either counts.';

  /// 依使用者輸入挑一則回覆。比對不到就回通用的那則。
  static String replyFor(String userText, AppLanguage language) {
    final text = userText.toLowerCase();
    for (final topic in _topics) {
      for (final key in topic.keys) {
        if (text.contains(key.toLowerCase())) {
          return language == AppLanguage.zhTw ? topic.zh : topic.en;
        }
      }
    }
    return language == AppLanguage.zhTw ? _genericZh : _genericEn;
  }
}

class _Topic {
  const _Topic({required this.keys, required this.zh, required this.en});
  final List<String> keys;
  final String zh;
  final String en;
}
