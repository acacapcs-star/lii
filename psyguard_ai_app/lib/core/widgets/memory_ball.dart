/// 記憶球：一次完成的練習留下的一顆球。
///
/// ── 為什麼先用 SharedPreferences ────────────────────────
///
/// 球的資料結構還沒定下來——顏色怎麼決定、要不要存摘要、
/// 篩選要支援到什麼程度，這些都還在變。
/// 這個時候改 Drift 的 schema，等於要跑兩次 build_runner，
/// 而且展示在即，那個風險不值得。
///
/// 但欄位名稱一開始就照 Drift 的表來命名，
/// 所以之後要搬家時，搬的是儲存層不是資料結構。
///
/// ── 顏色從哪裡來 ───────────────────────────────────────
///
/// 原本規劃「使用者自選顏色」，但那會多一個步驟：
/// 做完練習之後還要再選一次顏色，而那個選擇沒有意義——
/// 使用者不知道該選什麼，只好隨便點一個。
///
/// 改成從情緒詞彙庫來。那個字典本來就有六個大類，
/// 而 GlassTone 剛好也是六色，一對一對得上：
///
///   生氣   → dawn      （粉紅玫瑰）
///   難過   → ice       （冰藍）
///   害怕   → amethyst  （紫水晶）
///   累     → amber     （琥珀）
///   有壓力 → sea       （海藍綠）
///   還可以 → moss      （苔綠）
///
/// 這樣做解決三件事：
///   · 字典不再是唯讀的——選一個詞會留下一顆球
///   · 顏色不用多問一步，選詞的同時就決定了
///   · 球本身帶著意義：那天你選了哪個詞
///
/// 而且因為顏色由情緒決定，同色的球自然會聚在一起——
/// 一週下來一整排 amber，那個畫面本身就是資訊。
///
/// ── 但刻意不用 ERS 配色 ────────────────────────────────
///
/// 依風險分層自動配色的話，紅燈那天的球會是紅的——
/// 那等於在記憶裡標記「這天你很糟」。使用者回頭看罐子，
/// 看到一片紅，那不是回顧，是壓力。
///
/// 情緒詞是使用者自己挑的，風險分層是系統判的。
/// 前者可以顯示，後者不行。
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'luna_orb.dart' show GlassTone;


/// 情緒詞彙庫的六個大類。
///
/// 這個 enum 存在的理由是：讓「情緒組」成為一個型別，
/// 而不是散在各處的字串。字典那邊改了組名，
/// 這裡的對應不會跟著壞掉。
enum EmotionGroup { angry, sad, afraid, tired, pressured, okay }

extension EmotionGroupX on EmotionGroup {
  /// 六組對六色，一對一。
  ///
  /// 這個對應不是隨便配的——每一組本來就有自己的顏色
  /// （字典頁面在用），而 GlassTone 裡剛好有色相最接近的那一個。
  GlassTone get tone => switch (this) {
        EmotionGroup.angry => GlassTone.dawn,       // 紅 → 粉紅玫瑰
        EmotionGroup.sad => GlassTone.ice,          // 藍 → 冰藍
        EmotionGroup.afraid => GlassTone.amethyst,  // 紫 → 紫水晶
        EmotionGroup.tired => GlassTone.amber,      // 橘 → 琥珀
        EmotionGroup.pressured => GlassTone.sea,    // 青 → 海藍綠
        EmotionGroup.okay => GlassTone.moss,        // 綠 → 苔綠
      };

  String get key => switch (this) {
        EmotionGroup.angry => 'angry',
        EmotionGroup.sad => 'sad',
        EmotionGroup.afraid => 'afraid',
        EmotionGroup.tired => 'tired',
        EmotionGroup.pressured => 'pressured',
        EmotionGroup.okay => 'okay',
      };

  String label(bool zh) => switch (this) {
        EmotionGroup.angry => zh ? '生氣' : 'Angry',
        EmotionGroup.sad => zh ? '難過' : 'Sad',
        EmotionGroup.afraid => zh ? '害怕' : 'Afraid',
        EmotionGroup.tired => zh ? '累' : 'Tired',
        EmotionGroup.pressured => zh ? '有壓力' : 'Pressured',
        EmotionGroup.okay => zh ? '還可以' : 'Okay',
      };

  static EmotionGroup fromKey(String k) => switch (k) {
        'sad' => EmotionGroup.sad,
        'afraid' => EmotionGroup.afraid,
        'tired' => EmotionGroup.tired,
        'pressured' => EmotionGroup.pressured,
        'okay' => EmotionGroup.okay,
        _ => EmotionGroup.angry,
      };

  /// 依字典裡的組名反查。字典用的是中文組名當識別。
  static EmotionGroup fromZhName(String name) => switch (name) {
        '難過' => EmotionGroup.sad,
        '害怕' => EmotionGroup.afraid,
        '累' => EmotionGroup.tired,
        '有壓力' => EmotionGroup.pressured,
        '還可以' => EmotionGroup.okay,
        _ => EmotionGroup.angry,
      };
}

/// 這顆球是從哪個練習來的
enum BallSource { grounding, checkin, breathing, lunaChat, emotionDict }

extension BallSourceX on BallSource {
  /// 存進 JSON 用的字串——不用 index，因為 enum 順序之後可能會變
  String get key => switch (this) {
        BallSource.grounding => 'grounding',
        BallSource.checkin => 'checkin',
        BallSource.breathing => 'breathing',
        BallSource.lunaChat => 'luna_chat',
        BallSource.emotionDict => 'emotion_dict',
      };

  String label(bool zh) => switch (this) {
        BallSource.grounding => zh ? '五感回神' : 'Grounding',
        BallSource.checkin => zh ? '心情記錄' : 'Check-in',
        BallSource.breathing => zh ? '呼吸練習' : 'Breathing',
        BallSource.lunaChat => zh ? '跟 Luna 聊天' : 'Chat with Luna',
        BallSource.emotionDict => zh ? '找到一個詞' : 'Named a feeling',
      };

  static BallSource fromKey(String k) => switch (k) {
        'checkin' => BallSource.checkin,
        'breathing' => BallSource.breathing,
        'luna_chat' => BallSource.lunaChat,
        'emotion_dict' => BallSource.emotionDict,
        _ => BallSource.grounding,
      };
}

/// 一顆球
class MemoryBall {
  const MemoryBall({
    required this.id,
    required this.createdAt,
    required this.source,
    required this.tone,
    this.note = '',
    this.ersScore,
    this.group,
    this.pacerId,
    this.memo = '',
    this.reply = '',
  });

  /// 毫秒時間戳當 id——本機唯一就夠，不需要 uuid
  final int id;
  final DateTime createdAt;
  final BallSource source;
  final GlassTone tone;

  /// 那次練習留下的文字。著地是五感的內容，聊天是摘要。
  /// 可能是空的——呼吸練習就沒有文字。
  final String note;

  /// 那天的 ERS。可能是 null（還沒算過，或使用者沒做 check-in）。
  /// 注意這裡用 null 而不是 -1.0 的哨兵值——
  /// 因為這裡「沒有分數」真的是例外情況，不像 ers_engine 裡缺串是常態。
  final double? ersScore;

  /// 這顆球對應的情緒組。只有從情緒詞彙庫來的球才有。
  ///
  /// 為什麼要另外存而不是從 tone 反推：一對一的對應之後可能會變，
  /// 而已經存下來的球不該因為對應表改了就變成另一種情緒。
  final EmotionGroup? group;

  /// 連到某一張 My Pacer 卡的 id。
  ///
  /// 為什麼只存 id 不存內容：卡片的文字之後可能被編輯，
  /// 存副本的話球上的句子會跟卡片本身不一致。
  /// 卡片被刪掉時這個 id 會指向不存在的東西——
  /// 那是刻意的，展開時會顯示「那張卡已經不在了」而不是假裝有。
  final String? pacerId;

  /// 選完情緒之後，使用者像寫便條一樣寫下的話。可能是空的。
  ///
  /// 跟 [note] 分開存：note 是那個詞（委屈、失落），
  /// memo 是發生了什麼。兩個混在一起的話，詞就沒辦法拿來分類了。
  final String memo;

  /// Luna 對這張便條的回聲。沒寫 memo 的球就沒有。
  final String reply;

  /// 複製一顆球並改掉部分欄位。
  ///
  /// 原本 [MemoryBallStore.linkPacer] 是把每個欄位手抄一次，
  /// 新增欄位時只要漏抄一個，那個欄位就會在換卡片時被默默洗掉。
  MemoryBall copyWith({
    String? pacerId,
    bool clearPacer = false,
    String? reply,
  }) =>
      MemoryBall(
        id: id,
        createdAt: createdAt,
        source: source,
        tone: tone,
        note: note,
        ersScore: ersScore,
        group: group,
        pacerId: clearPacer ? null : (pacerId ?? this.pacerId),
        memo: memo,
        reply: reply ?? this.reply,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'source': source.key,
        'tone': tone.index,
        'note': note,
        'ers_score': ersScore,
        'group': group?.key,
        'pacer_id': pacerId,
        'memo': memo,
        'reply': reply,
      };

  factory MemoryBall.fromJson(Map<String, dynamic> j) {
    final toneIdx = (j['tone'] is int) ? j['tone'] as int : 0;
    return MemoryBall(
      id: (j['id'] is int) ? j['id'] as int : 0,
      createdAt:
          DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
      source: BallSourceX.fromKey(j['source']?.toString() ?? 'grounding'),
      tone: (toneIdx >= 0 && toneIdx < GlassTone.values.length)
          ? GlassTone.values[toneIdx]
          : GlassTone.ice,
      note: j['note']?.toString() ?? '',
      ersScore: (j['ers_score'] is num) ? (j['ers_score'] as num).toDouble() : null,
      group: j['group'] == null
          ? null
          : EmotionGroupX.fromKey(j['group'].toString()),
      pacerId: j['pacer_id']?.toString(),
      // 舊資料沒有這兩個欄位，讀出來就是空的
      memo: j['memo']?.toString() ?? '',
      reply: j['reply']?.toString() ?? '',
    );
  }

  /// 同一天的判斷。用在依日期分組。
  bool isSameDay(DateTime other) =>
      createdAt.year == other.year &&
      createdAt.month == other.month &&
      createdAt.day == other.day;
}

/// 罐子要保存多久。使用者自己選，預設一直保存。
///
/// ── 為什麼預設不自動刪 ─────────────────────────────────
///
/// 球是使用者自己留下的。App 自動刪掉，等於替他決定「這段該忘了」。
/// 而且回頭看的價值常常在幾週、幾個月之後才出現——
/// 「上學期期中我都是有壓力，這學期好多了」。
///
/// 一學期取 18 週：高中、大學的壓力幾乎都跟著學期走。
enum JarKeep { forever, semester, month }

extension JarKeepX on JarKeep {
  /// null 表示一直保存
  int? get days => switch (this) {
        JarKeep.forever => null,
        JarKeep.semester => 126,
        JarKeep.month => 30,
      };

  String label(bool zh) => switch (this) {
        JarKeep.forever => zh ? '一直保存' : 'Keep everything',
        JarKeep.semester => zh ? '保存一學期' : 'Keep one semester',
        JarKeep.month => zh ? '保存一個月' : 'Keep one month',
      };

  String hint(bool zh) => switch (this) {
        JarKeep.forever => zh ? '直到你自己清空為止' : 'Until you empty the jar yourself',
        JarKeep.semester => zh ? '約 18 週，看得出開學到期末的變化' : 'About 18 weeks, a whole term',
        JarKeep.month => zh ? '只留最近的，罐子比較輕' : 'Only the recent ones',
      };
}

/// 讀寫記憶球。
///
/// 所有方法都容忍資料損壞——一顆球的 JSON 壞掉不該讓整個罐子讀不出來。
class MemoryBallStore {
  static const _key = 'memory_balls';

  /// 最多保留幾顆。超過的話從最舊的砍。
  ///
  /// 為什麼要有上限：SharedPreferences 是一次全部讀進記憶體的，
  /// 幾千顆球的 JSON 會讓 App 啟動變慢。
  /// 搬到 Drift 之後這個限制就可以拿掉。
  static const _maxBalls = 500;

  static const _keepKey = 'gleam_keep';

  static Future<JarKeep> loadKeep() async {
    final p = await SharedPreferences.getInstance();
    final name = p.getString(_keepKey);
    return JarKeep.values.firstWhere((k) => k.name == name,
        orElse: () => JarKeep.forever);
  }

  static Future<void> saveKeep(JarKeep keep) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keepKey, keep.name);
  }

  /// 依使用者選的保存時間，會被拿掉的球有幾顆。換設定前先問用的。
  static int countExpired(List<MemoryBall> all, JarKeep keep, {DateTime? now}) {
    final days = keep.days;
    if (days == null) return 0;
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
    return all.where((b) => b.createdAt.isBefore(cutoff)).length;
  }

  /// 拿掉超過保存時間的球。選「一直保存」時什麼都不做。
  static Future<void> applyKeepRule() async {
    final keep = await loadKeep();
    final days = keep.days;
    if (days == null) return;
    final all = await load();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final kept = all.where((b) => !b.createdAt.isBefore(cutoff)).toList();
    if (kept.length != all.length) await _saveAll(kept);
  }

  static Future<List<MemoryBall>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      final out = <MemoryBall>[];
      for (final item in list) {
        // 一顆壞掉就跳過那一顆，不要讓整個罐子讀不出來
        try {
          if (item is Map<String, dynamic>) out.add(MemoryBall.fromJson(item));
        } catch (_) {}
      }
      // 新的在前
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(List<MemoryBall> balls) async {
    final p = await SharedPreferences.getInstance();
    final trimmed = balls.length > _maxBalls
        ? balls.sublist(0, _maxBalls)
        : balls;
    await p.setString(
      _key,
      jsonEncode(trimmed.map((b) => b.toJson()).toList()),
    );
  }

  /// 加一顆
  static Future<MemoryBall> add({
    required BallSource source,
    required GlassTone tone,
    String note = '',
    double? ersScore,
    EmotionGroup? group,
    String? pacerId,
    String memo = '',
  }) async {
    final ball = MemoryBall(
      id: DateTime.now().millisecondsSinceEpoch,
      createdAt: DateTime.now(),
      source: source,
      tone: tone,
      note: note,
      ersScore: ersScore,
      group: group,
      pacerId: pacerId,
      memo: memo.trim(),
    );
    final all = await load();
    all.insert(0, ball);
    await _saveAll(all);
    return ball;
  }

  /// 從情緒詞彙庫留下一顆球。
  ///
  /// 顏色由組別決定，不用另外問——這是把「選顏色」那一步
  /// 併進「選一個詞」的關鍵。
  static Future<MemoryBall> addFromEmotion({
    required EmotionGroup group,
    required String word,
    String? pacerId,
    String memo = '',
  }) {
    return add(
      source: BallSource.emotionDict,
      tone: group.tone,
      note: word,
      group: group,
      pacerId: pacerId,
      memo: memo,
    );
  }

  /// 把一顆已經存在的球連上（或解除）一張 Pacer 卡。
  ///
  /// 分開做而不是在建立時就決定，是因為使用者可能先留下球，
  /// 之後回頭看的時候才想到「那天那句話很適合配這個」。
  static Future<void> linkPacer(int ballId, String? pacerId) async {
    final all = await load();
    final i = all.indexWhere((b) => b.id == ballId);
    if (i < 0) return;
    all[i] = pacerId == null
        ? all[i].copyWith(clearPacer: true)
        : all[i].copyWith(pacerId: pacerId);
    await _saveAll(all);
  }

  /// 存下 Luna 對這顆球的回聲。換一句的時候會覆蓋。
  static Future<void> setReply(int ballId, String reply) async {
    final all = await load();
    final i = all.indexWhere((b) => b.id == ballId);
    if (i < 0) return;
    all[i] = all[i].copyWith(reply: reply);
    await _saveAll(all);
  }

  static Future<void> remove(int id) async {
    final all = await load();
    all.removeWhere((b) => b.id == id);
    await _saveAll(all);
  }

  /// 把一整批球放回去。給「清空」的復原用。
  static Future<void> restoreAll(List<MemoryBall> balls) => _saveAll(balls);

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }

  /// 依日期分組，新的在前。
  /// 心情 bar 的時間軸和日期篩選都用這個。
  static Map<DateTime, List<MemoryBall>> groupByDay(List<MemoryBall> balls) {
    final map = <DateTime, List<MemoryBall>>{};
    for (final b in balls) {
      final day = DateTime(b.createdAt.year, b.createdAt.month, b.createdAt.day);
      map.putIfAbsent(day, () => []).add(b);
    }
    return map;
  }
}
