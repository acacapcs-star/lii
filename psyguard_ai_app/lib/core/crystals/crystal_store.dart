// 水晶收集：只能靠呼吸取得。
// 不是課金也不是隨機抽 —— 每一顆都對應一件他真的做過的事。
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/luna_orb.dart';

class CrystalRule {
  final GlassTone tone;
  final int sessions;
  final int streak;
  const CrystalRule(this.tone, {this.sessions = 0, this.streak = 0});

  String get requirement {
    if (sessions > 0) return '完成 $sessions 次呼吸';
    if (streak > 0) return '連續 $streak 天';
    return '一開始就有';
  }

  String get requirementEn {
    if (sessions > 0) return 'Complete $sessions sessions';
    if (streak > 0) return '$streak-day streak';
    return 'Yours from the start';
  }

  String requirementFor(bool zh) => zh ? requirement : requirementEn;
}

const List<CrystalRule> kCrystalRules = [
  CrystalRule(GlassTone.ice),
  CrystalRule(GlassTone.sea, sessions: 3),
  CrystalRule(GlassTone.amethyst, sessions: 7),
  CrystalRule(GlassTone.amber, sessions: 14),
  CrystalRule(GlassTone.moss, streak: 3),
  CrystalRule(GlassTone.dawn, streak: 7),
];

class CrystalStore {
  static const _kSessions = 'crystal_sessions';
  static const _kStreak = 'crystal_streak';
  static const _kLastDay = 'crystal_last_day';
  static const _kDemoAll = 'crystal_demo_unlock_all';
  static String _kAt(GlassTone t) => 'crystal_at_${t.name}';

  static int sessions = 0;
  static int streak = 0;
  static String lastDay = '';
  static bool _loaded = false;

  /// 展示模式：評審現場需要看到六顆，平常關閉。
  static bool demoUnlockAll = false;

  /// 每顆水晶的解鎖時間。舊資料沒有紀錄的會是 null。
  static final Map<GlassTone, DateTime> unlockedAt = {};

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    sessions = p.getInt(_kSessions) ?? 0;
    streak = p.getInt(_kStreak) ?? 0;
    lastDay = p.getString(_kLastDay) ?? '';
    demoUnlockAll = p.getBool(_kDemoAll) ?? false;
    for (final r in kCrystalRules) {
      final raw = p.getString(_kAt(r.tone));
      if (raw != null) {
        final d = DateTime.tryParse(raw);
        if (d != null) unlockedAt[r.tone] = d;
      }
    }
    _loaded = true;
  }

  static String _day(DateTime n) => '${n.year}-${n.month}-${n.day}';

  static Future<List<GlassTone>> recordSession() async {
    await ensureLoaded();
    final before = unlocked().toSet();

    sessions += 1;
    final today = _day(DateTime.now());
    if (lastDay != today) {
      final y = _day(DateTime.now().subtract(const Duration(days: 1)));
      streak = (lastDay == y) ? streak + 1 : 1;
      lastDay = today;
    }

    final p = await SharedPreferences.getInstance();
    await p.setInt(_kSessions, sessions);
    await p.setInt(_kStreak, streak);
    await p.setString(_kLastDay, lastDay);

    final fresh = unlocked().where((t) => !before.contains(t)).toList();
    final now = DateTime.now();
    for (final t in fresh) {
      unlockedAt[t] = now;
      await p.setString(_kAt(t), now.toIso8601String());
    }
    return fresh;
  }

  static Future<void> setDemoUnlockAll(bool on) async {
    demoUnlockAll = on;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDemoAll, on);
  }

  /// 距離解鎖還差多少。已解鎖回傳 null。
  static ({int done, int need, bool isStreak})? progress(GlassTone t) {
    if (isUnlocked(t)) return null;
    final r = kCrystalRules.firstWhere((e) => e.tone == t);
    if (r.sessions > 0) {
      return (done: sessions, need: r.sessions, isStreak: false);
    }
    return (done: streak, need: r.streak, isStreak: true);
  }

  static bool isUnlocked(GlassTone t) {
    if (demoUnlockAll) return true;
    final r = kCrystalRules.firstWhere((e) => e.tone == t);
    if (r.sessions > 0) return sessions >= r.sessions;
    if (r.streak > 0) return streak >= r.streak;
    return true;
  }

  static List<GlassTone> unlocked() =>
      kCrystalRules.map((e) => e.tone).where(isUnlocked).toList();

  static String? nextHint({bool zh = true}) {
    for (final r in kCrystalRules) {
      if (isUnlocked(r.tone)) continue;
      if (r.sessions > 0) {
        return zh
            ? '再 ${r.sessions - sessions} 次呼吸 → ${r.tone.label}'
            : '${r.sessions - sessions} more to unlock ${r.tone.labelEn}';
      }
      return zh
          ? '連續 ${r.streak} 天 → ${r.tone.label}（現在 $streak 天）'
          : '${r.streak}-day streak for ${r.tone.labelEn} (now $streak)';
    }
    return null;
  }
}
