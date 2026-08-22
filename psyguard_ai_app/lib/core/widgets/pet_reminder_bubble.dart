// ═══════════════════════════════════════════════════════════
// PsyGuard AI - 寵物提醒泡泡 💬
//
// 你的水獺／水豚會在首頁冒出一個對話框提醒你事情。
//
// 訊息優先序（一次只挑一個，不洗版）
//   1. 三天以上沒開 App  -> 「已經 N 天沒看到你了，今天心情如何呀？」
//   2. 今天有 ⏰ 倒數項目 -> 「別忘了『○○』喔～」
//   3. 今天有未打勾待辦   -> 「今天要記得『○○』的東東喔～」
//   4. 都沒有            -> 不顯示（沒事不要吵）
//
// 資料來源都是現成的，沒有另外建一套提醒系統：
//   倒數提醒  語音筆記寫進未來每天的 note_YYYY_M_D，文字開頭是 ⏰
//   待辦      同一份筆記裡 type == 2 且 checked == false 的項目
//   沉默天數  SilenceDetector.getSilenceDays()
//
// 同一則訊息一天只出現一次，回首頁不會一直跳。
// ═══════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/ers/silence_detector.dart';

/// 泡泡出現前的緩衝，讓首頁先畫完
const Duration _kAppearDelay = Duration(milliseconds: 800);

/// 幾秒後自動收起
const Duration _kAutoHide = Duration(seconds: 8);

/// 幾天沒開才觸發問候
const int _kSilenceDays = 3;

const String _kShownKey = 'pet_bubble_shown';

enum _BubbleKind { silence, countdown, todo }

class _BubbleMessage {
  final _BubbleKind kind;
  final String text;
  const _BubbleMessage(this.kind, this.text);
}

class PetReminderBubble extends StatefulWidget {
  const PetReminderBubble({super.key, required this.isZh});

  final bool isZh;

  @override
  State<PetReminderBubble> createState() => _PetReminderBubbleState();
}

class _PetReminderBubbleState extends State<PetReminderBubble> {
  _BubbleMessage? _message;
  String _petName = 'Luna';
  bool _visible = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    final prefs = await SharedPreferences.getInstance();
    _petName = prefs.getString('pet_name') ?? 'Luna';

    final msg = await _pickMessage(prefs);
    if (msg == null || !mounted) return;

    // 同一則一天只出現一次
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final stamp = '$today|${msg.kind.name}';
    if (prefs.getString(_kShownKey) == stamp) return;
    await prefs.setString(_kShownKey, stamp);

    await Future<void>.delayed(_kAppearDelay);
    if (!mounted) return;

    setState(() {
      _message = msg;
      _visible = true;
    });

    _hideTimer = Timer(_kAutoHide, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  Future<_BubbleMessage?> _pickMessage(SharedPreferences prefs) async {
    final zh = widget.isZh;

    // 1️⃣ 好久不見
    // 用 getSilenceDays() 而不是 checkSilence()，
    // 後者會把「今天已提醒」標記掉，跟首頁的沉默對話框互相搶。
    final days = await SilenceDetector().getSilenceDays();
    if (days >= _kSilenceDays) {
      return _BubbleMessage(
        _BubbleKind.silence,
        zh
            ? '嘿嘿～已經 $days 天沒看到你了，今天心情如何呀？>///<'
            : "Hey~ it's been $days days! How are you feeling today? >///<",
      );
    }

    // 讀今天的筆記
    final now = DateTime.now();
    final raw = prefs.getString('note_${now.year}_${now.month}_${now.day}');
    if (raw == null) return null;

    List items;
    try {
      items = jsonDecode(raw) as List;
    } catch (_) {
      return null;
    }

    String? countdown;
    String? todo;

    for (final it in items) {
      if (it is! Map) continue;
      final text = (it['text'] ?? '').toString();
      final checked = it['checked'] == true;
      if (checked || text.isEmpty) continue;

      if (text.startsWith('⏰')) {
        countdown ??= _clean(text);
      } else if (it['type'] == 2) {
        todo ??= _clean(text);
      }
    }

    // 2️⃣ 倒數提醒優先
    if (countdown != null) {
      return _BubbleMessage(
        _BubbleKind.countdown,
        zh
            ? '嗨嗨！別忘了「$countdown」喔～>///<'
            : 'Hi hi! Don\'t forget "$countdown" okay~ >///<',
      );
    }

    // 3️⃣ 一般待辦
    if (todo != null) {
      return _BubbleMessage(
        _BubbleKind.todo,
        zh
            ? '今天要記得「$todo」的東東喔～'
            : 'Remember "$todo" today, okay~',
      );
    }

    return null;
  }

  /// 把 '☐ '、'⏰ 距離 3 天：' 這些前綴拿掉，只留內容
  static String _clean(String raw) {
    var t = raw.trim();
    if (t.startsWith('⏰')) {
      final i = t.indexOf('：');
      final j = t.indexOf(':');
      final cut = i >= 0 ? i : j;
      if (cut >= 0) t = t.substring(cut + 1);
    }
    t = t.replaceFirst(RegExp(r'^[☐☑✓•\-\s]+'), '').trim();
    if (t.length > 24) t = '${t.substring(0, 24)}…';
    return t;
  }


  @override
  Widget build(BuildContext context) {
    final msg = _message;
    if (msg == null) return const SizedBox.shrink();

    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, -0.25),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        child: _visible
            ? Padding(
                padding: const EdgeInsets.only(top: 16),
                child: GestureDetector(
                  onTap: () {
                    _hideTimer?.cancel();
                    setState(() => _visible = false);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFB2EBE9)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140ABFBC),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset('assets/images/lii_ball.png', width: 26, height: 26, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _petName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0ABFBC),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                msg.text,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.close_rounded,
                            size: 15, color: Color(0xFFB0BEC5)),
                      ],
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
