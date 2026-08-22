import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../l10n/app_language.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/analytics/usage_tracker.dart';

/// 身心儀表板 — 一頁看完 ERS、連續天數、規律性、筆記數與近期趨勢。
/// 全部只讀本機既有資料，不呼叫 AI、不改核心。
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _loaded = false;
  double _ersScore = 0;
  String _ersLevel = 'green';
  List<double> _ersRecent = [];
  int _streak = 0;
  double _consistency = 0;
  int _noteCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final recent = (prefs.getStringList('ers_recent') ?? const <String>[])
        .map((e) => double.tryParse(e) ?? 0)
        .toList();
    final notes = prefs
        .getKeys()
        .where((k) =>
            k.startsWith('note_') &&
            ((prefs.getString(k) ?? '').trim().isNotEmpty))
        .length;
    final streak = await UsageTracker.streakDays();
    final consistency = await UsageTracker.consistency7();
    if (!mounted) return;
    setState(() {
      _ersScore = prefs.getDouble('last_ers_score') ?? 0;
      _ersLevel = prefs.getString('last_ers_level') ?? 'green';
      _ersRecent = recent;
      _streak = streak;
      _consistency = consistency;
      _noteCount = notes;
      _loaded = true;
    });
  }

  Color _levelColor(String lv) {
    switch (lv) {
      case 'red':
        return const Color(0xFFD14343);
      case 'yellow':
        return const Color(0xFFF5A623);
      default:
        return const Color(0xFF0ABFBC);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zh = ref.watch(appLanguageControllerProvider) == AppLanguage.zhTw;
    final color = _levelColor(_ersLevel);
    final levelText = _ersLevel == 'red'
        ? (zh ? '需要關注' : 'Needs attention')
        : _ersLevel == 'yellow'
            ? (zh ? '請多留意' : 'Keep an eye on it')
            : (zh ? '狀態良好' : 'Doing okay');

    Widget statCard(String label, String value, IconData icon, Color c) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600, color: c)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Color(0xFF7A8896))),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(zh ? '身心儀表板' : 'Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF22343A),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(24)),
                  child: Row(children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(zh ? '目前情緒風險 ERS' : 'Current ERS',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF7A8896))),
                          const SizedBox(height: 4),
                          Text(_ersScore.round().toString(),
                              style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                  height: 1)),
                        ]),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(levelText,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  statCard(zh ? '連續天數' : 'Streak', '$_streak',
                      Icons.local_fire_department_rounded,
                      const Color(0xFFE8833A)),
                  const SizedBox(width: 10),
                  statCard(zh ? '規律性' : 'Consistency',
                      '${(_consistency * 100).round()}%',
                      Icons.event_available_rounded, const Color(0xFF0ABFBC)),
                  const SizedBox(width: 10),
                  statCard(zh ? '筆記' : 'Notes', '$_noteCount',
                      Icons.sticky_note_2_rounded, const Color(0xFF9B5DE5)),
                ]),
                const SizedBox(height: 22),
                Text(zh ? 'ERS 近期趨勢' : 'Recent ERS trend',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF22343A))),
                const SizedBox(height: 10),
                _buildTrend(zh),
              ],
            ),
    );
  }

  Widget _buildTrend(bool zh) {
    if (_ersRecent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: const Color(0xFFF3F7FC),
            borderRadius: BorderRadius.circular(16)),
        child: Text(
            zh
                ? '還沒有足夠的紀錄，多用幾天就會出現 📈'
                : 'Not enough records yet — check in a few more days 📈',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF7A8896), fontSize: 13)),
      );
    }
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFF3F7FC),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _ersRecent.map((v) {
          final h = (v / 100.0).clamp(0.05, 1.0) * 100;
          final c = v >= 70
              ? const Color(0xFFD14343)
              : v >= 45
                  ? const Color(0xFFF5A623)
                  : const Color(0xFF0ABFBC);
          return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(v.round().toString(),
                style: TextStyle(
                    fontSize: 10, color: c, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Container(
                width: 22,
                height: h,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(6))),
          ]);
        }).toList(),
      ),
    );
  }
}
