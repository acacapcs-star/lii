import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../l10n/app_language.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/theme/background_theme_service.dart';
import 'note_page.dart';
import '../../../core/security/secret_diary_lock.dart';
import '../../../core/security/secret_swipe_shell.dart';

class MonthOverviewPage extends ConsumerStatefulWidget {
  /// true = 🔒 只看秘密日記（要解鎖）
  const MonthOverviewPage({super.key, this.secret = false});

  final bool secret;

  @override
  ConsumerState<MonthOverviewPage> createState() => _MonthOverviewPageState();
}

class _WeekSummary {
  final List<Map<String, dynamic>> redItems = [];
  final List<Map<String, dynamic>> yellowItems = [];
}

class _MonthOverviewPageState extends ConsumerState<MonthOverviewPage> {
  bool _loading = true;
  final Set<int> _expandedMonths = {};
  bool _unlocked = false;
  final SecretDiaryLock _lock = SecretDiaryLock.instance;
  int _year = DateTime.now().year;
  Map<int, List<_WeekSummary>> _monthData = {};

  @override
  void initState() {
    super.initState();
    if (widget.secret) {
      _lock.cancelPendingLock();
      if (_lock.isUnlocked) {
        _unlocked = true;
        _loadAllMonths();
      }
    } else {
      _loadAllMonths();
    }
  }

  @override
  void dispose() {
    if (widget.secret) _lock.scheduleLock();
    super.dispose();
  }

  Future<void> _loadAllMonths() async {
    final prefs = await SharedPreferences.getInstance();
    final year = _year;

    final Map<int, List<_WeekSummary>> result = {};

    for (int month = 1; month <= 12; month++) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final weeks = <_WeekSummary>[];
      _WeekSummary current = _WeekSummary();

      for (int day = 1; day <= daysInMonth; day++) {
        final prefix = widget.secret ? 'secret_note_' : 'note_';
        final key = '$prefix${year}_${month}_$day';
        final raw = prefs.getString(key);
        if (raw != null) {
          try {
            final decoded = widget.secret ? _lock.decryptContent(raw) : raw;
            final List items = jsonDecode(decoded);
            for (final item in items) {
              final priority = item['priority'] as int? ?? 12;
              final entry = {
                'text': item['text']?.toString() ?? '',
                'date': '$month/$day',
                'month': month,
                'day': day,
              };
              if (priority <= 4) {
                current.redItems.add(entry);
              } else if (priority <= 9) {
                current.yellowItems.add(entry);
              }
            }
          } catch (_) {
            // 忽略解析失敗的資料，不讓單一天的壞資料擋住整個月曆
          }
        }

        if (day % 7 == 0 || day == daysInMonth) {
          weeks.add(current);
          current = _WeekSummary();
        }
      }

      result[month] = weeks;
    }

    if (mounted) {
      setState(() {
        _monthData = result;
        _loading = false;
      });
    }
  }

  void _showWeekDetail(bool isZh, int month, int weekIndex, _WeekSummary week) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isZh ? '$month月 第${weekIndex + 1}週' : 'Month $month, Week ${weekIndex + 1}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (week.redItems.isEmpty && week.yellowItems.isEmpty)
                    Text(isZh ? '這週沒有重要事項' : 'No important items this week', style: TextStyle(color: Colors.grey.shade500)),
                  ...week.redItems.map((e) => InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _openDay(e['month'] as int, e['day'] as int);
                        },
                        child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${e['date']}：${e['text']}', style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                        ),
                      )),
                  ...week.yellowItems.map((e) => InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _openDay(e['month'] as int, e['day'] as int);
                        },
                        child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${e['date']}：${e['text']}', style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                        ),
                      )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDotsRow(List items, Color color) {
    if (items.isEmpty) return const SizedBox(height: 14);
    return Wrap(
      spacing: 4,
      children: List.generate(
        items.length > 8 ? 8 : items.length,
        (i) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  // 💜 秘密日曆走淺芋頭紫，公開日曆維持原色
  Color get _bg => widget.secret ? kTaroBg : const Color(0xFFF8FFFE);
  Color get _accent =>
      widget.secret ? kTaroDeep : const Color(0xFF2C5282);
  Color get _bar => widget.secret ? kTaroSoft : const Color(0xFF0ABFBC);

  Future<void> _changeYear(int delta) async {
    setState(() {
      _year += delta;
      _loading = true;
    });
    await _loadAllMonths();
  }

  Future<void> _pickYear(bool isZh) async {
    final thisYear = DateTime.now().year;
    final years = [
      for (int y = 2020; y <= thisYear + 5; y++) y,
    ];
    final picked = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isZh ? '選擇年份' : 'Choose a year',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: years
                    .map((y) => ListTile(
                          title: Text('$y'),
                          trailing: y == _year
                              ? const Icon(Icons.check_rounded,
                                  color: Color(0xFF0ABFBC))
                              : null,
                          onTap: () => Navigator.pop(ctx, y),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null && picked != _year) {
      setState(() {
        _year = picked;
        _loading = true;
      });
      await _loadAllMonths();
    }
  }

  void _openDay(int month, int day) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotePage(
          secret: widget.secret,
          initialDate: DateTime(_year, month, day),
        ),
      ),
    );
  }

  static const _monthNamesZh = ['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'];
  static const _monthNamesEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  @override
  Widget build(BuildContext context) {
    final isZh = ref.watch(appLanguageControllerProvider) == AppLanguage.zhTw;

    if (widget.secret && !_unlocked) {
      return SecretUnlockScreen(
        lock: _lock,
        isZh: isZh,
        showBackButton: false, // 滑回去就好
        onUnlocked: () async {
          await _loadAllMonths();
          if (mounted) setState(() => _unlocked = true);
        },
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2C5282)),
          onPressed: () => context.go('/home'),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded,
                  color: Color(0xFF2C5282)),
              tooltip: isZh ? '前一年' : 'Previous year',
              onPressed: _loading ? null : () => _changeYear(-1),
            ),
            GestureDetector(
              onTap: _loading ? null : () => _pickYear(isZh),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_year',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      )),
                  Text(isZh ? '年度重點總覽' : 'Year Overview',
                      style: const TextStyle(
                          color: Color(0xFF0ABFBC), fontSize: 10)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF2C5282)),
              tooltip: isZh ? '後一年' : 'Next year',
              onPressed: _loading ? null : () => _changeYear(1),
            ),
          ],
        ),
        actions: [
          // 🔒 按鈕入口，跟左滑手勢並存
          if (widget.secret)
            IconButton(
              icon: const Icon(Icons.lock_open_rounded, color: kTaroDeep),
              tooltip: isZh ? '回到公開日曆' : 'Back to public calendar',
              onPressed: () => Navigator.pop(context),
            )
          else
            IconButton(
              icon: const Icon(Icons.lock_outline_rounded,
                  color: Color(0xFF8B6FBF)),
              tooltip: isZh ? '秘密日曆' : 'Secret calendar',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MonthOverviewPage(secret: true),
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 12,
              itemBuilder: (context, idx) {
                final month = idx + 1;
                final weeks = _monthData[month] ?? [];
                final monthName = isZh ? _monthNamesZh[idx] : _monthNamesEn[idx];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          if (_expandedMonths.contains(month)) {
                            _expandedMonths.remove(month);
                          } else {
                            _expandedMonths.add(month);
                          }
                        }),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _bar,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  monthName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                              ),
                              Icon(
                                _expandedMonths.contains(month)
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_expandedMonths.contains(month)) const SizedBox(height: 8),
                      if (_expandedMonths.contains(month))
                        ...weeks.asMap().entries.map((entry) {
                        final weekIdx = entry.key;
                        final week = entry.value;
                        final hasAny = week.redItems.isNotEmpty || week.yellowItems.isNotEmpty;
                        final themeColor = ref.watch(backgroundThemeProvider).backgroundColor;
                        final isEven = weekIdx % 2 == 0;
                        final stripeColor = isEven
                            ? Colors.white
                            : Color.alphaBlend(themeColor.withValues(alpha: 0.18), Colors.white);
                        return GestureDetector(
                          onTap: hasAny ? () => _showWeekDetail(isZh, month, weekIdx, week) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: stripeColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: isEven
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 50,
                                  child: Text(
                                    isZh ? '第${weekIdx + 1}週' : 'W${weekIdx + 1}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildDotsRow(week.redItems, Colors.red),
                                      const SizedBox(height: 4),
                                      _buildDotsRow(week.yellowItems, Colors.amber),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
