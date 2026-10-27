import 'dart:convert';
import '../../../l10n/month_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../l10n/app_language.dart';
import '../../../core/security/local_settings_service.dart';
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

  /// 按「日」索引的事項。月曆格子用這個。
  ///
  /// 原本的 _monthData 是按週彙整的，而且只留紅黃——
  /// 月曆格子要知道「這一天有沒有東西」，那是不同的查詢。
  /// 所以另外存一份，不去改動原本那套已經在運作的邏輯。
  ///
  /// key 是 '月/日'，value 是那天的所有事項。
  Map<String, List<Map<String, dynamic>>> _byDay = {};

  Future<void> _loadAllMonths() async {
    final prefs = await SharedPreferences.getInstance();
    final year = _year;

    final Map<int, List<_WeekSummary>> result = {};
    final Map<String, List<Map<String, dynamic>>> byDay = {};

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
              // 月曆格子要的是全部，不只紅黃
              byDay.putIfAbsent('$month/$day', () => []).add({
                ...entry,
                'priority': priority,
                'checked': item['checked'] == true,
              });
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
        _byDay = byDay;
        _loading = false;
      });
    }
  }

  void _showWeekDetail(bool isZh, int month, int weekIndex, _WeekSummary week) {
    // 這一週是哪幾天：月曆是 1–7、8–14… 這樣切的
    final daysInMonth = DateTime(_year, month + 1, 0).day;
    final firstDay = weekIndex * 7 + 1;
    final weekDays = [
      for (var d = firstDay; d <= daysInMonth && d < firstDay + 7; d++) d
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
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
                  const Divider(height: 28),
                  _QuickTodo(
                    isZh: isZh,
                    month: month,
                    days: weekDays,
                    accent: _bar,
                    onAdd: (day, text, level) async {
                      await _addTodo(month, day, text, level);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isZh ? '已加到 $month/$day' : 'Added to $month/$day'),
                        duration: const Duration(seconds: 2),
                      ));
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 把一個待辦加到某一天的筆記裡。
  ///
  /// 存的格式跟筆記頁完全一樣（打勾框、優先度），
  /// 所以在筆記頁打開那一天，看到的就是這一條，可以照常打勾、改字、拖動。
  /// 優先度：紅 → red3、黃 → yellow3、一般 → green3（筆記頁的預設）。
  Future<void> _addTodo(int month, int day, String text, int level) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = widget.secret ? 'secret_note_' : 'note_';
    final key = '$prefix${_year}_${month}_$day';
    var list = <dynamic>[];
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        final decoded = widget.secret ? _lock.decryptContent(raw) : raw;
        list = jsonDecode(decoded) as List<dynamic>;
      } catch (_) {
        // 讀不出來的話不要蓋掉——那一天原本的內容比這一條待辦重要
        return;
      }
    }
    final priority = switch (level) {
      0 => NotePriority.red3,
      1 => NotePriority.yellow3,
      _ => NotePriority.green3,
    };
    list.add(NoteItem(
      text: text,
      type: NoteItemType.checkbox,
      priority: priority,
    ).toJson());
    final encoded = jsonEncode(list);
    await prefs.setString(
        key, widget.secret ? _lock.encryptContent(encoded) : encoded);
    await _loadAllMonths();
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
  static const _monthNamesEn = kMonthShortEn;

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
                        final isEven = weekIdx % 2 == 0;
                        // 斑馬紋用月份標題的顏色淡淡一層，不跟背景色走——
                        // 背景選深色（夜紫、深藍、純黑）時，深色混進白色只會變成一片灰。
                        final stripeColor = isEven
                            ? Colors.white
                            : Color.alphaBlend(_bar.withValues(alpha: 0.10), Colors.white);
                        return GestureDetector(
                          // 空的週也可以點：點進去就能直接新增待辦
                          onTap: () => _showWeekDetail(isZh, month, weekIdx, week),
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

/// 週詳細裡的「新增待辦」：選哪一天、選重要程度、寫一句，按新增。
///
/// 自己持有輸入框的 controller：表單收起的動畫還在跑時輸入框還在畫面上，
/// 在外面 await 完就 dispose 的話會用到已經釋放的 controller。
class _QuickTodo extends StatefulWidget {
  const _QuickTodo({
    required this.isZh,
    required this.month,
    required this.days,
    required this.accent,
    required this.onAdd,
  });

  final bool isZh;
  final int month;
  final List<int> days;
  final Color accent;

  /// level：0 紅（緊急）、1 黃（重要）、2 一般
  final Future<void> Function(int day, String text, int level) onAdd;

  @override
  State<_QuickTodo> createState() => _QuickTodoState();
}

class _QuickTodoState extends State<_QuickTodo> {
  final _ctrl = TextEditingController();
  late int _day;
  int _level = 1; // 預設「重要」：新增完馬上就會出現在月曆上
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    // 這週有今天就預設今天，沒有就選這週第一天
    _day = (today.month == widget.month && widget.days.contains(today.day))
        ? today.day
        : widget.days.first;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    await widget.onAdd(_day, text, _level);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final zh = widget.isZh;
    final levels = [
      (zh ? '緊急' : 'Urgent', Colors.red),
      (zh ? '重要' : 'Important', Colors.amber),
      (zh ? '一般' : 'Normal', Colors.grey),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(zh ? '新增待辦' : 'Add a to-do',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        // 哪一天
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final d in widget.days)
              ChoiceChip(
                label: Text('${widget.month}/$d'),
                selected: _day == d,
                onSelected: (_) => setState(() => _day = d),
                selectedColor: widget.accent.withValues(alpha: 0.25),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // 重要程度（紅、黃才會出現在月曆和首頁的重點行事曆）
        Wrap(
          spacing: 6,
          children: [
            for (var i = 0; i < levels.length; i++)
              ChoiceChip(
                avatar: CircleAvatar(backgroundColor: levels[i].$2, radius: 5),
                label: Text(levels[i].$1),
                selected: _level == i,
                onSelected: (_) => setState(() => _level = i),
                selectedColor: widget.accent.withValues(alpha: 0.25),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLength: 60,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: zh ? '例：交報告、社團開會' : 'e.g. Hand in report',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: widget.accent,
                minimumSize: const Size(64, 48),
              ),
              child: Text(zh ? '新增' : 'Add'),
            ),
          ],
        ),
        if (_level == 2)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              zh
                  ? '「一般」會存進那天的筆記，但不會出現在重點行事曆上'
                  : '"Normal" goes into that day\'s note but not the key calendar',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }
}
