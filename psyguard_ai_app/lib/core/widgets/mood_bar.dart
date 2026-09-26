/// 微光 Gleam：一排記憶球。
///
/// ── 為什麼是獨立頁面，不放首頁 ──────────────────────────
///
/// 首頁已經有四區、十四張卡、飄落效果。再塞一排橫向滾動的球進去，
/// 首頁就會變成當初被指出的「太亂」。
///
/// 而且 Linda 的回饋是「越簡單越好」——
/// 那條意見跟「首頁再加一個區塊」是直接衝突的。
///
/// 所以首頁只放一個入口，內容在這一頁。
///
/// ── 為什麼球不用 LunaOrb ───────────────────────────────
///
/// LunaOrb 是 CustomPaint 加上每幀重算的時間驅動動畫。
/// 主球只有一顆，那個成本沒問題；一排三十顆就會掉幀。
///
/// 所以記憶球用輕量版：漸層加高光，靜態的，不跑每幀動畫。
/// 但色票沿用同一套 GlassTone，視覺上仍是同一家人。
///
/// 只有被點到的那一顆會跑動畫——那一顆的成本可以接受。
///
/// ── 為什麼同色要堆疊 ───────────────────────────────────
///
/// 球的顏色來自情緒組，所以同色就是同一種情緒。
/// 一週下來一整排 amber（累），那個畫面本身就是資訊——
/// 比任何一張趨勢圖都直接。
///
/// 但平鋪的話，三十顆球佔滿整個畫面卻看不出結構。
/// 堆疊之後，一眼看到的是「這週有幾種情緒、哪一種最多」，
/// 點開才看到細節。
///
/// 堆疊是可以關掉的——有些人想看到每一顆，
/// 那是「我做了這麼多次」的感覺，不該被摘要掉。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' show ImageFilter;

import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/mood_theme_service.dart';
import '../theme/background_theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_strings.dart';
import '../security/local_settings_service.dart';

import 'luna_orb.dart' show GlassTone, GlassToneX;
import 'memory_ball.dart';
import 'gleam_reply.dart';
import '../network/app_config_controller.dart' show appConfigProvider;
import '../risk_engine/risk_engine.dart';
import '../network/ai_local_messages.dart'
    show aiHighRiskSafetyReply, aiHighRiskSafetyReplyEn;
import '../../features/card_studio/presentation/my_cards_store.dart';
import '../../features/card_studio/presentation/card_studio_page.dart';
import '../../features/tools_library/presentation/tools_page.dart'
    show emotionWordsOf, recordEmotionWord;

// ══════════════════════════════════════════════════════
//  單顆球
// ══════════════════════════════════════════════════════

/// 一顆記憶球。
///
/// ── 圓球，點開變便條 ───────────────────────────────────
///
/// 沒點開的時候是正圓的球——那是「一顆還沒打開的記憶」。
///
/// 點一下，球原地長大成一張便條：形狀從圓變成圓角方形，
/// 尺寸從 46 長到 168，裡面的字浮出來。
///
/// 那個變形本身就是「打開」的動作，使用者不用看說明就懂。
/// 再點一次會縮回去。
class MemoryBallDot extends StatefulWidget {
  const MemoryBallDot({
    super.key,
    required this.tone,
    this.size = 46,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.expanded = false,
    this.expandedChild,
    this.expandedSize = 168,
    this.expandFull = false,
  });

  final GlassTone tone;
  final double size;
  final bool selected;

  /// 點開了沒。展開時球會長大成一張便條。
  final bool expanded;

  /// 展開後顯示在便條裡的內容
  final Widget? expandedChild;

  /// 展開後的邊長
  final double expandedSize;

  /// 展開成整列寬的長方形卡片，而不是正方形。
  ///
  /// 為什麼需要：照片本來就是橫的或直的，塞進正方形一定會被裁掉。
  /// 而且 Pacer 那句話長度不定——長方形可以隨內容長高，不用捲動。
  final bool expandFull;

  /// 點一下：抖一下，選取
  final VoidCallback? onTap;

  /// 長按：展開內容
  final VoidCallback? onLongPress;

  @override
  State<MemoryBallDot> createState() => _MemoryBallDotState();
}

class _MemoryBallDotState extends State<MemoryBallDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _bounce() {
    _ctrl.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.tone.stops;
    // 四個停止點由亮到暗：高光、主色、深色、底色
    final highlight = stops[0];
    final main = stops[1];
    final deep = stops[2];

    // 展開時不要跑抖動——兩個動畫疊在一起會很亂
    if (widget.expanded) {
      return GestureDetector(
        onTap: widget.onTap,
        child: _ball(highlight, main, deep),
      );
    }

    return GestureDetector(
      onTap: _bounce,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _ctrl.forward(from: 0);
              widget.onLongPress!();
            },
      child: AnimatedBuilder(
        animation: _ctrl,
        // child 傳進來的部分只建一次——球的漸層不會因為抖動而改變
        child: _ball(highlight, main, deep),
        builder: (context, child) {
          // 果凍感：先壓扁再彈回，用兩個相位交錯
          final t = _ctrl.value;
          final squash = t == 0 ? 0.0 : (1 - t) * 0.18 * _wobble(t);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scale(1 + squash, 1 - squash * 1.2),
            child: child,
          );
        },
      ),
    );
  }

  /// 阻尼震盪：一開始大幅度，之後慢慢收斂
  double _wobble(double t) {
    // 三個來回，振幅隨時間遞減
    return (1 - t) * (t * 18).clamp(0, 1) *
        (1.0 - 2.0 * ((t * 3) % 1.0 - 0.5).abs()) * 2;
  }

  Widget _ball(Color highlight, Color main, Color deep) {
    final full = widget.expanded && widget.expandFull;
    final s = widget.expanded ? widget.expandedSize : widget.size;
    // 沒展開：半徑等於一半 → 正圓
    // 展開後：半徑 22 → 卡片的圓角
    final r = widget.expanded ? 22.0 : s * 0.5;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      // 展開成長方形時寬度撐滿，高度由內容決定
      width: full ? double.infinity : s,
      height: full ? null : s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        // 半透明的玻璃珠：背景透得過去，球才像玻璃不像塑膠。
        //
        // 三個停止點的透明度不一樣——
        // 中心的高光接近不透明（那是光打在表面上），
        // 中段最透（玻璃最薄的地方），
        // 邊緣又濃起來（光從側面穿過比較厚的玻璃）。
        //
        // 那個「中間比兩端透」是玻璃球跟實心球最大的差別。
        gradient: RadialGradient(
          // 球：高光在右上偏中，像光打在球面上。
          // 展開成便條時：光點固定在右上角，不會壓在中間的文字上。
          center: widget.expanded
              ? const Alignment(0.92, -0.92)
              : const Alignment(0.35, -0.42),
          radius: 0.95,
          colors: [
            Color.lerp(highlight, Colors.white, 0.55)!
                .withValues(alpha: 0.92),
            main.withValues(alpha: 0.58),
            deep.withValues(alpha: 0.86),
          ],
          // 便條比球大很多，同樣的比例光會暈成一大片，
          // 所以展開時把白光收小，只留右上角一點。
          stops: widget.expanded
              ? const [0.0, 0.16, 1.0]
              : const [0.0, 0.48, 1.0],
        ),
        boxShadow: [
          // 球本身的陰影
          BoxShadow(
            color: deep.withValues(alpha: 0.22),
            blurRadius: s * 0.26,
            offset: Offset(-s * 0.04, s * 0.10),
          ),
          // 選中時多一圈同色的光暈
          if (widget.selected)
            BoxShadow(
              color: main.withValues(alpha: 0.55),
              blurRadius: s * 0.38,
              spreadRadius: s * 0.06,
            ),
        ],
        border: widget.selected
            ? Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2)
            : null,
      ),
      // 高光也要跟著切圓角，不然會溢出方塊的角
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 展開後的內容
          // 展開時內容直接當 Stack 的子層，不用 Positioned.fill。
          //
          // Positioned.fill 的意思是「填滿父層」，但這裡父層的高度
          // 正要由子層決定（expandFull 設了 height: null）。
          // 兩邊互相等，結果卡片縮到最小，內容永遠沒有空間。
          if (widget.expanded && widget.expandedChild != null)
            Padding(
              padding: const EdgeInsets.all(14),
              child: widget.expandedChild!,
            ),
          // 左上的柔和高光——果凍的關鍵。
          // 展開時不畫，不然會蓋在文字上
          if (!widget.expanded)
            Positioned(
            right: s * 0.20,
            top: s * 0.15,
            child: Container(
              width: s * 0.26,
              height: s * 0.20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // 右下的反射光——讓球看起來是半透明的，不是實心的
          if (!full)
            Positioned(
              left: s * 0.16,
              bottom: s * 0.18,
              child: Container(
                width: s * 0.18,
                height: s * 0.12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
            ),
        ],
      ),
    );

    if (!widget.expanded) return card;

    // 展開時外面再包一層光暈。
    //
    // 為什麼用 AnimatedContainer 的 boxShadow 而不是另外畫一個圓：
    // 陰影會跟著卡片的圓角走，所以長方形和圓形的光暈形狀自動正確。
    // spreadRadius 讓它往外擴，blurRadius 讓邊緣柔化。
    return AnimatedContainer(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: [
          // 內圈：濃一點，貼著卡片
          BoxShadow(
            color: main.withValues(alpha: 0.42),
            blurRadius: 26,
            spreadRadius: 2,
          ),
          // 外圈：淡而大，那個是真正「暈開」的部分
          BoxShadow(
            color: main.withValues(alpha: 0.18),
            blurRadius: 54,
            spreadRadius: 14,
          ),
        ],
      ),
      child: card,
    );
  }
}


// ══════════════════════════════════════════════════════
//  罐子本體
// ══════════════════════════════════════════════════════

/// 整頁的玻璃罐，球堆在裡面，可以往下捲看更早的。
///
/// ── 球怎麼排 ───────────────────────────────────────────
///
/// 不是清單，也不是格線——球從底部往上堆，每一顆的位置
/// 由它的 id 算出一個固定的偏移，所以看起來是倒進去的，
/// 但捲動時不會亂跳。
///
/// 日期不做成區塊標題，只在那一天的第一顆球旁邊標一行很淡的字。
/// 標題會把罐子切成一段一段，那就又變回清單了。
class _JarBody extends StatelessWidget {
  const _JarBody({
    required this.balls,
    required this.pacers,
    required this.zh,
    required this.ballSize,
    required this.openId,
    required this.stacked,
    required this.onTapBall,
    required this.onPickPacer,
    required this.scrollController,
    this.justAddedId,
    this.onReplyAgain,
  });

  final List<MemoryBall> balls;
  final List<MyCard> pacers;
  final bool zh;
  final double ballSize;
  final int? openId;

  /// 同色聚集。false 的話照日期排。
  ///
  /// 兩種排法回答不同的問題：
  ///   日期  這陣子我留下了什麼
  ///   同色  哪一種情緒最多
  final bool stacked;

  final void Function(int id) onTapBall;
  final void Function(MemoryBall b) onPickPacer;
  final ScrollController scrollController;

  /// 剛留下的那一顆。只有它會跑「落進罐子」的動畫。
  final int? justAddedId;

  /// 請 Luna 再說一句
  final void Function(MemoryBall b)? onReplyAgain;

  /// 罐子裡的一顆球。剛留下的那顆外面包一層落下的漣漪。
  Widget _dot(MemoryBall b) {
    final dot = MemoryBallDot(
      tone: b.tone,
      size: ballSize,
      onTap: () => onTapBall(b.id),
    );
    if (b.id != justAddedId) return dot;
    return DropEcho(key: ValueKey('echo-${b.id}'), tone: b.tone, child: dot);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Stack(
        children: [
          // ── 罐身 ──
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(34),
                    bottomRight: Radius.circular(34),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.015),
                      const Color(0xFF9FB4C7).withValues(alpha: 0.07),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),

          // ── 球 ──
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(34),
                bottomRight: Radius.circular(34),
              ),
              child: balls.isEmpty
                  ? Center(
                      child: Text(
                        zh ? '還沒有光' : 'Empty for now',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 20, 14, 26),
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      children: _rows(context, theme),
                    ),
            ),
          ),

          // ── 玻璃的反光 ──
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(34),
                    bottomRight: Radius.circular(34),
                  ),
                  gradient: LinearGradient(
                    begin: const Alignment(0.9, -1),
                    end: const Alignment(-0.3, 0.2),
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.28, 0.55],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 把球排成一列一列，日期標在那一天的第一顆旁邊。
  List<Widget> _rows(BuildContext context, ThemeData theme) {
    return stacked ? _byTone(context, theme) : _byDate(context, theme);
  }

  /// 同色聚集：一種情緒一組，數量多的排前面。
  ///
  /// 罐子裡一整區粉紅，那個畫面本身就是資訊 --
  /// 比任何一張同樣資料做成的圖表都直接。
  List<Widget> _byTone(BuildContext context, ThemeData theme) {
    final groups = <GlassTone, List<MemoryBall>>{};
    for (final b in balls) {
      groups.putIfAbsent(b.tone, () => []).add(b);
    }
    // 數量多的排前面 -- 最常出現的情緒先看到
    final tones = groups.keys.toList()
      ..sort((a, b) => groups[b]!.length.compareTo(groups[a]!.length));

    final out = <Widget>[];
    for (final t in tones) {
      final group = groups[t]!;
      final label = group.first.group?.label(zh);

      out.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 7),
        child: Text(
          label == null
              ? '${group.length}'
              : (zh ? '$label　${group.length}' : '$label  ${group.length}'),
          style: GoogleFonts.nunitoSans(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant
                .withValues(alpha: 0.55),
          ),
        ),
      ));

      final pending = <MemoryBall>[];
      void flush() {
        if (pending.isEmpty) return;
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final b in pending)
                _dot(b),
            ],
          ),
        ));
        pending.clear();
      }

      for (final b in group) {
        if (b.id == openId) {
          flush();
          out.add(Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: MemoryBallDot(
              tone: b.tone,
              size: ballSize,
              expanded: true,
              expandFull: true,
              expandedChild: _inner(b, theme),
              onTap: () => onTapBall(b.id),
            ),
          ));
        } else {
          pending.add(b);
        }
      }
      flush();
    }
    return out;
  }

  /// 照日期排，新的在上。
  List<Widget> _byDate(BuildContext context, ThemeData theme) {
    final out = <Widget>[];
    final now = DateTime.now();
    DateTime? lastDay;

    // 展開的那一顆獨佔一列
    final open = openId == null
        ? null
        : balls.where((b) => b.id == openId).firstOrNull;

    final pending = <MemoryBall>[];

    void flush() {
      if (pending.isEmpty) return;
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final b in pending)
              _dot(b),
          ],
        ),
      ));
      pending.clear();
    }

    for (final b in balls) {
      final day =
          DateTime(b.createdAt.year, b.createdAt.month, b.createdAt.day);

      // 換日期時先把前一批排出去，再標一行很淡的日期
      if (lastDay == null || day != lastDay) {
        flush();
        final isToday = day.year == now.year &&
            day.month == now.month &&
            day.day == now.day;
        out.add(Padding(
          padding: EdgeInsets.only(top: lastDay == null ? 0 : 6, bottom: 7),
          child: Text(
            isToday
                ? (zh ? '今天' : 'Today')
                : (zh
                    ? '${day.month} / ${day.day}'
                    : '${day.month}/${day.day}'),
            style: GoogleFonts.nunitoSans(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.55),
            ),
          ),
        ));
        lastDay = day;
      }

      if (open != null && b.id == open.id) {
        flush();
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: MemoryBallDot(
            tone: b.tone,
            size: ballSize,
            expanded: true,
            expandFull: true,
            expandedChild: _inner(b, theme),
            onTap: () => onTapBall(b.id),
          ),
        ));
      } else {
        pending.add(b);
      }
    }
    flush();
    return out;
  }

  Widget _inner(MemoryBall b, ThemeData theme) {
    final card = b.pacerId == null
        ? null
        : pacers.where((c) => c.id == b.pacerId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          b.note.isEmpty
              ? b.source.label(zh)
              : (b.group?.label(zh) ?? b.source.label(zh)),
          style: GoogleFonts.nunitoSans(
            fontSize: 11.5,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 5),
        Text(
          b.note.isEmpty
              ? (b.group?.label(zh) ?? b.source.label(zh))
              : b.note,
          style: GoogleFonts.varelaRound(
            fontSize: 19,
            height: 1.3,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (b.memo.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            b.memo,
            style: GoogleFonts.nunitoSans(
                fontSize: 13.5, height: 1.6, color: Colors.white),
          ),
        ],
        if (b.reply.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Luna',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFFD166))),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(b.reply,
                      style: GoogleFonts.nunitoSans(
                          fontSize: 13.5, height: 1.6, color: Colors.white)),
                ),
                if (onReplyAgain != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => onReplyAgain!(b),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        minimumSize: const Size(44, 36),
                      ),
                      child: Text(zh ? '換一句' : 'Another',
                          style: GoogleFonts.nunitoSans(fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (card?.photoB64 != null) ...[
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(card!.photoB64!),
              width: double.infinity,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
        if (card != null && card.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Text(
              card.text,
              style: GoogleFonts.nunitoSans(
                  fontSize: 13.5, height: 1.65, color: Colors.white),
            ),
          ),
        ],
        SizedBox(height: 11),
        Row(
          children: [
            Text(
              '${b.createdAt.hour.toString().padLeft(2, '0')}:'
              '${b.createdAt.minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.nunitoSans(fontSize: 11, color: Colors.white60),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => onPickPacer(b),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    card == null ? Icons.add_rounded : Icons.swap_horiz_rounded,
                    size: 15,
                    color: Colors.white70,
                  ),
                  SizedBox(width: 3),
                  Text(
                    card == null
                        ? (zh ? '配一張卡' : 'Attach')
                        : (zh ? '換一張' : 'Change'),
                    style:
                        GoogleFonts.nunitoSans(fontSize: 11.5, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════
//  心情 bar 頁面
// ══════════════════════════════════════════════════════

class MoodBarPage extends ConsumerStatefulWidget {
  const MoodBarPage({super.key});

  @override
  ConsumerState<MoodBarPage> createState() => _MoodBarPageState();
}

class _MoodBarPageState extends ConsumerState<MoodBarPage> {
  List<MemoryBall> _all = [];
  List<MyCard> _pacers = [];
  bool _loaded = false;

  /// 目前展開的那一顆。null 表示沒有展開任何一顆。
  int? _openId;

  /// 篩選：null 表示不篩
  GlassTone? _toneFilter;
  BallSource? _sourceFilter;

  /// 同色堆疊。關掉的話每一顆都獨立顯示。
  bool _stacked = true;

  /// 展開的那一疊（用 tone 當識別）
  GlassTone? _openStack;

  /// 縮放用的 controller。
  ///
  /// 為什麼要自己持有而不是讓 InteractiveViewer 自己管：
  /// 因為要做「重置」按鈕，而重置需要動到那個矩陣。
  /// 沒有 controller 的話使用者縮太小之後找不回來。
  late final TransformationController _zoom;

  /// 罐子裡的捲動控制
  late final ScrollController _listCtrl;

  /// 目前的縮放倍率。用來顯示在按鈕上，也用來判斷要不要顯示重置。
  double _scale = 1.0;

  /// 球的顯示尺寸檔位。
  ///
  /// 跟畫面縮放是兩件事——縮放是暫時的瀏覽動作，
  /// 這個是使用者對「我想看多大」的偏好，會記住。
  ///
  /// 三檔而不是滑桿：滑桿給的自由度沒有意義，
  /// 使用者不會想調到 53.7 這種數字。
  int _sizeStep = 1;   // 0 小 · 1 中 · 2 大

  static const _sizes = [34.0, 46.0, 64.0];
  double get _ballSize => _sizes[_sizeStep];

  /// 堆疊裡的球小一點——那裡本來就是「看細節」的地方
  double get _innerBallSize => _sizes[_sizeStep] * 0.82;

  @override
  void initState() {
    super.initState();
    _loadSizePref();
    _zoom = TransformationController();
    _listCtrl = ScrollController();
    // 縮放時更新倍率的顯示。
    // 用 addListener 而不是 onInteractionUpdate，
    // 因為程式呼叫 _resetZoom() 時也要更新。
    _zoom.addListener(_onZoomChanged);
    _load();
  }

  @override
  void dispose() {
    _zoom.removeListener(_onZoomChanged);
    _zoom.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  void _onZoomChanged() {
    // 矩陣的第一個元素就是 x 方向的縮放倍率
    final next = _zoom.value.getMaxScaleOnAxis();
    // 差距太小就不重建——縮放時這個會被呼叫很多次
    if ((next - _scale).abs() < 0.02) return;
    setState(() => _scale = next);
  }

  void _resetZoom() {
    _zoom.value = Matrix4.identity();
    setState(() => _scale = 1.0);
  }

  static const _sizePrefKey = 'gleam_ball_size';

  Future<void> _loadSizePref() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getInt(_sizePrefKey);
      if (v != null && v >= 0 && v < _sizes.length && mounted) {
        setState(() => _sizeStep = v);
      }
    } catch (_) {}
  }

  Future<void> _cycleSize() async {
    final next = (_sizeStep + 1) % _sizes.length;
    setState(() => _sizeStep = next);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_sizePrefKey, next);
    } catch (_) {}
  }

  Future<void> _load() async {
    // 先依使用者選的保存時間整理一次，再讀出來
    await MemoryBallStore.applyKeepRule();
    // 兩個查詢並行——它們互不依賴
    final results = await Future.wait([
      MemoryBallStore.load(),
      MyCardsStore.load(),
    ]);
    if (!mounted) return;
    setState(() {
      _all = results[0] as List<MemoryBall>;
      _pacers = results[1] as List<MyCard>;
      _loaded = true;
    });
  }

  List<MemoryBall> get _filtered {
    return _all.where((b) {
      if (_toneFilter != null && b.tone != _toneFilter) return false;
      if (_sourceFilter != null && b.source != _sourceFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // 語言跟著設定走，不由呼叫端決定——
    // 那樣使用者切換語言時這一頁會自己更新
    final zh = AppStrings.of(ref.watch(appLanguageControllerProvider)).isZhTw;
    final theme = Theme.of(context);
    final grouped = MemoryBallStore.groupByDay(_filtered);

    // 氛圍背景跟首頁同一套——罐子浮在夜空前面，
    // 玻璃的半透明才看得出效果。貼在純色上的話玻璃感出不來。
    final mood = ref.watch(moodThemeProvider);
    final bg = ref.watch(backgroundThemeProvider);

    return Scaffold(
      backgroundColor: mood.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.white.withValues(alpha: 0.18)),
          ),
        ),
        title: Text(zh ? '微光' : 'Gleam'),
        actions: [
          if (_all.isNotEmpty)
            IconButton(
              tooltip: zh
                  ? ['小', '中', '大'][_sizeStep]
                  : ['Small', 'Medium', 'Large'][_sizeStep],
              icon: Icon([
                Icons.grain_rounded,
                Icons.blur_circular_rounded,
                Icons.circle_rounded,
              ][_sizeStep]),
              onPressed: _cycleSize,
            ),
          if (_all.isNotEmpty)
            IconButton(
              tooltip: zh ? '清空罐子' : 'Empty the jar',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _clearJar(zh),
            ),
          IconButton(
            tooltip: zh ? '這些光要留多久' : 'How long to keep',
            icon: const Icon(Icons.hourglass_bottom_rounded),
            onPressed: () => _chooseKeep(zh),
          ),
          if (_all.isNotEmpty)
            IconButton(
              tooltip: zh ? (_stacked ? '攤開來看' : '同色疊起來') : 'Toggle stacking',
              icon: Icon(_stacked
                  ? Icons.blur_on_rounded
                  : Icons.scatter_plot_outlined),
              onPressed: () => setState(() {
                _stacked = !_stacked;
                _openStack = null;
                _openId = null;
              }),
            ),
          if (_all.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Text(
                  zh ? '${_all.length} 顆' : '${_all.length}',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      // 縮放過才顯示重置——沒縮放的時候那個按鈕只是噪音
      floatingActionButton: (_loaded && _all.isNotEmpty && (_scale - 1.0).abs() > 0.05)
          ? FloatingActionButton.small(
              onPressed: _resetZoom,
              tooltip: zh ? '回到原本大小' : 'Reset zoom',
              child: const Icon(Icons.zoom_out_map_rounded),
            )
          : null,
      body: Stack(
        children: [
          // 背景圖。asset 可能是 null（使用者選了純色氛圍）
          if (bg.image.asset != null)
            Positioned.fill(
              child: Image.asset(bg.image.asset!, fit: BoxFit.cover),
            ),
          // Positioned.fill 給它一個明確的尺寸。
          // 沒有這層的話 Stack 不給高度，裡面的 Expanded 就算不出來。
          Positioned.fill(
            child: SafeArea(child: !_loaded
          ? const SizedBox.shrink()
          : _all.isEmpty
              ? Column(
                  children: [
                    _quickPick(zh, theme),
                    Expanded(child: _empty(zh, theme)),
                  ],
                )
              : Column(
                  children: [
                    _quickPick(zh, theme),
                    if (_all.length >= MemoryBallStore.nearFull)
                      _nearFullHint(zh, theme),
                    _filterRow(zh, theme),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                      child: Text(
                        zh
                            ? '往下是更早的　·　點一顆打開'
                            : 'Scroll down for older · tap to open',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    // 罐子佔滿剩下的空間。
                    //
                    // 為什麼不是「頂部一個小罐子加底下的清單」：
                    // 那樣罐子只是一張裝飾圖，真正在用的還是清單。
                    // 罐子要是介面本身，球才是被收藏的東西而不是清單項目。
                    Expanded(
                      child: _JarBody(
                        balls: _filtered,
                        pacers: _pacers,
                        zh: zh,
                        ballSize: _ballSize,
                        openId: _openId,
                        stacked: _stacked,
                        justAddedId: _justAddedId,
                        onReplyAgain: (b) => _showReply(b, zh, again: true),
                        onTapBall: (id) =>
                            setState(() => _openId = _openId == id ? null : id),
                        onPickPacer: (b) => _pickPacer(b, zh),
                        scrollController: _listCtrl,
                      ),
                    ),
                  ],
                )),
          ),
        ],
      ),
    );
  }


  // ══════════════════════════════════════════════════
  //  自己留一顆
  // ══════════════════════════════════════════════════

  /// 不透過練習，直接選一個心情留下一顆球。
  ///
  /// 為什麼要有這個入口：有時候使用者只是想記一下「現在是這樣」，
  /// 不想做完整的五頁著地練習。強迫走完流程才能留下紀錄的話，
  /// 那些「只是想記一下」的時刻就消失了。
  ///
  /// ── 為什麼直接放在頁面上，不藏在「＋」後面 ─────────────
  ///
  /// 原本要先按右上角的「＋」、跳出表單、再點一顆球。
  /// 「只是想記一下」的時刻撐不過三個步驟，
  /// 現在六顆球就在罐子上方，點一下就留下。
  Widget _quickPick(bool zh, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              zh ? '現在是哪一種？' : 'Which one is it now?',
              style: GoogleFonts.nunitoSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final g in EmotionGroup.values)
                Semantics(
                  button: true,
                  label: zh ? '留下一顆「${g.label(zh)}」' : 'Leave a ${g.label(zh)} ball',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _leave(g, zh),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 點下去時球會抖一下，那就是「收到了」
                        MemoryBallDot(
                          tone: g.tone,
                          size: 38,
                          onTap: () => _leave(g, zh),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          g.label(zh),
                          style: GoogleFonts.nunitoSans(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 防止連點：球還在存的時候，再點不會多留一顆
  bool _leaving = false;

  /// 點一個顏色之後，選這個顏色裡的哪一種情緒。
  ///
  /// 顏色只是大類，「生氣」底下還有惱怒、委屈、被冒犯、不甘心。
  /// 叫得出更精準的名字，那顆球才真的是「那天的那個感覺」。
  /// 但說不上來的時候也可以只留大類，所以最下面留一個「就是這個顏色」。
  Future<void> _leave(EmotionGroup g, bool zh) async {
    if (_leaving) return;
    final words = emotionWordsOf(g);
    final main = g.tone.stops[1];

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IgnorePointer(child: MemoryBallDot(tone: g.tone, size: 26)),
                    const SizedBox(width: 10),
                    Text(
                      zh ? '是哪一種${g.label(zh)}？' : 'What kind of ${g.label(zh).toLowerCase()}?',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final w in words)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: main.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(13),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, zh ? w.zh : w.en),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      zh ? w.zh : w.en,
                                      style: GoogleFonts.nunitoSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      zh ? w.zhWhen : w.enWhen,
                                      style: GoogleFonts.nunitoSans(
                                        fontSize: 12.5,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  size: 18, color: main),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // 說不上來的時候，只留大類也可以
                TextButton(
                  onPressed: () => Navigator.pop(context, ''),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: main,
                  ),
                  child: Text(zh
                      ? '說不上來，就是${g.label(zh)}'
                      : 'Hard to say — just ${g.label(zh).toLowerCase()}'),
                ),
              ],
            ),
          ),
        );
      },
    );

    // null：把表單拉掉，什麼都不留
    if (picked == null || !mounted) return;

    // 像寫便條一樣寫下想寫的話。可以不寫，直接留下
    final label = picked.isEmpty ? g.label(zh) : picked;
    // 有設定 AI 金鑰時，便條才會送出去；沒有的話 Luna 用本機的句子
    final aiOn = ref.read(appConfigProvider).isConfigured;
    final res = await showModalBottomSheet<(String, bool)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          _MemoSheet(tone: g.tone, title: label, zh: zh, aiOn: aiOn),
    );
    if (res == null || !mounted) return;
    final (memo, askLuna) = res;
    if (picked.isNotEmpty) await recordEmotionWord(picked);

    _leaving = true;
    try {
      final ball = await MemoryBallStore.addFromEmotion(
        group: g,
        memo: memo,
        // 刻意存空字串，不存組名的翻譯。
        //
        // 存「難過」的話，使用者之後切成英文，那顆球還是顯示「難過」——
        // 因為那是當下語言的字串，被寫死進資料了。
        //
        // 存空的，顯示時用 group.label(zh) 現算，語言就跟得上。
        // 選了詞的話存那個詞，那是使用者真的挑的，
        // 語言固定反而是對的——他當時就是用那個語言在想這件事。
        word: picked,
      );
      await _load();
      if (!mounted) return;
      // 讓新的那顆「啵」地落進罐子
      setState(() => _justAddedId = ball.id);
      if (_listCtrl.hasClients) {
        _listCtrl.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }

      // 沒寫字、或選了不讓 Luna 回應，就只留下球。
      // 但有高風險字眼時一定走下面的安全回應——那段不會送去 AI。
      if (ball.memo.isEmpty ||
          (!askLuna && !RiskEngine.mentionsHighRisk(ball.memo))) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(zh ? '留下一點光了' : 'A little more gleam'),
              duration: const Duration(seconds: 2),
            ),
          );
        return;
      }
      // 等球落下之後，Luna 再回話
      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) await _showReply(ball, zh);
    } finally {
      _leaving = false;
    }
  }

  /// 剛留下的那一顆，用來播落下的動畫
  int? _justAddedId;

  /// Luna 的回聲。
  ///
  /// 便條裡出現高風險字眼時不送 AI：
  /// 回的是 App 裡既有的安全訊息，並提供進入安全流程的入口。
  /// 球和他寫的話照樣留下——那是他真的說出口的東西。
  Future<void> _showReply(MemoryBall ball, bool zh, {bool again = false}) async {
    final risky = RiskEngine.mentionsHighRisk(ball.memo);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ReplySheet(
        ball: ball,
        zh: zh,
        risky: risky,
        startFresh: again,
        service: ref.read(gleamReplyServiceProvider),
      ),
    );
    if (!mounted) return;
    await _load();
    if (risky && mounted) context.go('/safety');
  }

  /// 清空整個罐子。
  ///
  /// 先問一次，因為球是使用者自己留下的東西；
  /// 清空之後幾秒內還能復原，按錯了不會真的不見。
  Future<void> _clearJar(bool zh) async {
    final count = _all.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(zh ? '清空罐子？' : 'Empty the jar?'),
        content: Text(zh
            ? '罐子裡的 $count 顆球都會拿掉。'
            : 'All $count balls will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(zh ? '取消' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(zh ? '清空' : 'Empty'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final backup = List<MemoryBall>.from(_all);
    await MemoryBallStore.clear();
    if (!mounted) return;
    setState(() => _openId = null);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(zh ? '罐子清空了' : 'The jar is empty'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: zh ? '復原' : 'Undo',
            onPressed: () async {
              await MemoryBallStore.restoreAll(backup);
              if (mounted) await _load();
            },
          ),
        ),
      );
  }

  /// 選罐子要保存多久。
  ///
  /// 換成比較短的時間時，會先說清楚有幾顆會被拿掉，
  /// 確認之後才動——不讓使用者在不知道的情況下失去自己的球。
  Future<void> _chooseKeep(bool zh) async {
    final current = await MemoryBallStore.loadKeep();
    if (!mounted) return;
    final picked = await showModalBottomSheet<JarKeep>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(zh ? '這些光要留多久？' : 'How long should the jar keep balls?',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final k in JarKeep.values)
                ListTile(
                  leading: Icon(
                    k == current
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: k == current
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(k.label(zh)),
                  subtitle: Text(k.hint(zh)),
                  onTap: () => Navigator.pop(context, k),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked == current || !mounted) return;

    final losing = MemoryBallStore.countExpired(_all, picked);
    if (losing > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(zh ? '換成「${picked.label(zh)}」？' : 'Switch to "${picked.label(zh)}"?'),
          content: Text(zh
              ? '有 $losing 顆球比這更早，會被收走，收走之後就找不回來了。'
              : '$losing balls are older than this and will be removed for good.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(zh ? '取消' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(zh ? '確定' : 'Switch'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    await MemoryBallStore.saveKeep(picked);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(zh ? '之後會${picked.label(zh)}' : 'The jar will ${picked.label(zh).toLowerCase()}'),
        duration: const Duration(seconds: 2),
      ));
  }

  /// 罐子快滿時的提醒。
  ///
  /// 超過上限時最舊的球會被收走。與其讓它默默消失，
  /// 不如先說一聲，讓使用者有機會回頭看、或自己決定保存多久。
  Widget _nearFullHint(bool zh, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              zh
                  ? '罐子快滿了（${_all.length}/${MemoryBallStore.maxBalls}），滿了之後最舊的會被收走。'
                  : 'The jar is almost full (${_all.length}/${MemoryBallStore.maxBalls}). The oldest will be removed after that.',
              style: GoogleFonts.nunitoSans(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(bool zh, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MemoryBallDot(tone: GlassTone.ice, size: 64),
            SizedBox(height: 18),
            Text(
              zh ? '還沒有光' : 'No gleam yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 7),
            Text(
              zh
                  // 以前寫「或做完一次練習」，但練習其實不會留下球
                  ? '在上面選一種心情，\n或在情緒詞彙庫找到一個詞，就會留下一顆球。'
                  : 'Pick a mood above, or name a feeling\nin the dictionary, to leave a ball here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                height: 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterRow(bool zh, ThemeData theme) {
    // 只列罐子裡真的有的來源。「呼吸練習」那些點下去永遠是空的，
    // 比沒有那個選項更讓人困惑。只有一種來源時，這排篩選不是篩選，整排不顯示。
    final sources = _all.map((b) => b.source).toSet();
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(
            label: zh ? '全部' : 'All',
            selected: _toneFilter == null && _sourceFilter == null,
            onTap: () => setState(() {
              _toneFilter = null;
              _sourceFilter = null;
            }),
            theme: theme,
          ),
          const SizedBox(width: 7),
          // 顏色篩選：直接用球當按鈕，不用文字
          for (final t in GlassTone.values) ...[
            GestureDetector(
              onTap: () => setState(() {
                _toneFilter = _toneFilter == t ? null : t;
                _sourceFilter = null;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
                child: MemoryBallDot(
                  tone: t,
                  size: 30,
                  selected: _toneFilter == t,
                ),
              ),
            ),
          ],
          if (sources.length > 1) const SizedBox(width: 10),
          for (final s in BallSource.values.where(
              (s) => sources.length > 1 && sources.contains(s))) ...[
            _chip(
              label: s.label(zh),
              selected: _sourceFilter == s,
              onTap: () => setState(() {
                _sourceFilter = _sourceFilter == s ? null : s;
                _toneFilter = null;
              }),
              theme: theme,
            ),
            const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Center(
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.55)
                    : theme.dividerColor,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.nunitoSans(
                fontSize: 12.5,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _daySection(
      DateTime day, List<MemoryBall> balls, bool zh, ThemeData theme) {
    final now = DateTime.now();
    final isToday = day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 9),
          child: Row(
            children: [
              Text(
                isToday
                    ? (zh ? '今天' : 'Today')
                    : (zh
                        ? (day.year == now.year
                            ? '${day.month} 月 ${day.day} 日'
                            : '${day.year} 年 ${day.month} 月 ${day.day} 日')
                        : (day.year == now.year
                            ? '${_monthAbbr(day.month)} ${day.day}'
                            : '${_monthAbbr(day.month)} ${day.day}, ${day.year}')),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 8),
              Text(
                zh ? '${balls.length} 顆' : '${balls.length}',
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // 這一天的球
        if (_stacked)
          _stackedRow(balls, zh, theme)
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 沒展開的球排成一列
              Wrap(
                spacing: 11,
                runSpacing: 11,
                children: [
                  for (final b in balls)
                    if (_openId != b.id)
                      MemoryBallDot(
                        tone: b.tone,
                        size: _ballSize,
                        // 點一下長大成卡片，再點一次縮回去
                        onTap: () => setState(() => _openId = b.id),
                      ),
                ],
              ),
              // 展開的那一顆獨佔一整列——
              // 留在 Wrap 裡的話會把其他球擠到奇怪的位置
              if (balls.any((b) => b.id == _openId)) ...[
                const SizedBox(height: 14),
                MemoryBallDot(
                  tone: balls.firstWhere((b) => b.id == _openId).tone,
                  size: _ballSize,
                  expanded: true,
                  expandFull: true,
                  expandedChild: _ballInner(
                      balls.firstWhere((b) => b.id == _openId), zh),
                  onTap: () => setState(() => _openId = null),
                ),
              ],
            ],
          ),
        // 內容現在都在展開的球裡面，不需要另一張詳情卡
      ],
    );
  }


  /// 同色堆成一疊。
  ///
  /// 視覺上是幾顆球互相重疊，最上面那顆完整、底下的露出一點邊緣。
  /// 右上角標數量——只有兩顆以上才標，一顆的話標「1」很多餘。
  Widget _stackedRow(List<MemoryBall> balls, bool zh, ThemeData theme) {
    // 依 tone 分組，數量多的排前面
    final byTone = <GlassTone, List<MemoryBall>>{};
    for (final b in balls) {
      byTone.putIfAbsent(b.tone, () => []).add(b);
    }
    final tones = byTone.keys.toList()
      ..sort((a, b) => byTone[b]!.length.compareTo(byTone[a]!.length));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 14,
          children: [
            for (final t in tones)
              _stack(t, byTone[t]!, zh, theme),
          ],
        ),
        // 展開的那一疊
        if (_openStack != null && byTone.containsKey(_openStack))
          _stackDetail(byTone[_openStack]!, zh, theme),
      ],
    );
  }

  Widget _stack(
      GlassTone tone, List<MemoryBall> group, bool zh, ThemeData theme) {
    final n = group.length;
    // 最多疊三顆的視覺，再多就靠數字表示
    final visible = n > 3 ? 3 : n;
    final size = _ballSize;
    // 錯開的距離跟著尺寸走，不然大球疊起來會完全蓋住
    final offset = size * 0.15;
    final open = _openStack == tone;

    return GestureDetector(
      onTap: () => setState(() {
        _openStack = open ? null : tone;
        _openId = null;
      }),
      child: SizedBox(
        width: size + offset * (visible - 1) + 4,
        height: size + 4,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 底下那幾顆：從後往前畫，越後面越淡
            for (int i = visible - 1; i >= 1; i--)
              Positioned(
                left: offset * i,
                top: 0,
                child: Opacity(
                  opacity: 1 - i * 0.22,
                  child: IgnorePointer(
                    child: MemoryBallDot(tone: tone, size: size),
                  ),
                ),
              ),
            // 最上面那顆
            Positioned(
              left: 0,
              top: 0,
              child: IgnorePointer(
                child: MemoryBallDot(tone: tone, size: size, selected: open),
              ),
            ),
            // 數量。一顆的話不標——標「1」很多餘
            if (n > 1)
              Positioned(
                right: -2,
                top: -3,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: tone.stops[2],
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color: theme.colorScheme.surface, width: 1.5),
                  ),
                  child: Text(
                    '$n',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 展開一疊：把那一疊的球攤開，點任一顆看內容
  Widget _stackDetail(List<MemoryBall> group, bool zh, ThemeData theme) {
    final main = group.first.tone.stops[1];
    // 那一組的情緒名稱——從第一顆球拿，同一疊本來就是同一組
    final groupLabel = group.first.group?.label(zh);

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 13),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
              main.withValues(alpha: 0.06), theme.colorScheme.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: main.withValues(alpha: 0.22), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (groupLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  zh ? '$groupLabel · ${group.length} 次' : '$groupLabel · ${group.length}',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: main,
                  ),
                ),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final b in group)
                  if (_openId != b.id)
                    MemoryBallDot(
                      tone: b.tone,
                      size: _innerBallSize,
                      onTap: () => setState(() => _openId = b.id),
                    ),
              ],
            ),
            if (group.any((b) => b.id == _openId)) ...[
              const SizedBox(height: 12),
              MemoryBallDot(
                tone: group.firstWhere((b) => b.id == _openId).tone,
                size: _innerBallSize,
                expanded: true,
                expandFull: true,
                expandedChild:
                    _ballInner(group.firstWhere((b) => b.id == _openId), zh),
                onTap: () => setState(() => _openId = null),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 球展開成卡片之後，裡面的完整內容。
  ///
  /// 順序是刻意的：情緒 → 那個詞 → 照片 → Pacer → 時間。
  /// 照片放中間而不是最上面，因為主角是「那天的那個感覺」，
  /// 照片是附帶的說明。
  Widget _ballInner(MemoryBall b, bool zh) {
    final card = b.pacerId == null
        ? null
        : _pacers.where((c) => c.id == b.pacerId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // note 是空的時候，主標已經是組名了，這裡就改顯示來源
        Text(
          b.note.isEmpty
              ? b.source.label(zh)
              : (b.group?.label(zh) ?? b.source.label(zh)),
          style: GoogleFonts.nunitoSans(
            fontSize: 11.5,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 5),
        Text(
          // note 是空的 = 手動留的球，用組名現算，語言才跟得上
          b.note.isEmpty
              ? (b.group?.label(zh) ?? b.source.label(zh))
              : b.note,
          style: GoogleFonts.varelaRound(
            fontSize: 19,
            height: 1.3,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),

        // 照片
        if (card?.photoB64 != null) ...[
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(card!.photoB64!),
              width: double.infinity,
              height: 150,
              fit: BoxFit.cover,
              // 照片壞掉不該讓整張卡顯示不出來
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],

        // Pacer 的那句話
        if (card != null && card.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.text,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13.5,
                    height: 1.65,
                    color: Colors.white,
                  ),
                ),
                if (card.author.isNotEmpty) ...[
                  SizedBox(height: 5),
                  Text(
                    '\u2014 ${card.author}',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 11.5,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        SizedBox(height: 11),
        Row(
          children: [
            Text(
              '${b.createdAt.month}/${b.createdAt.day}'
              '  ${b.createdAt.hour.toString().padLeft(2, '0')}:'
              '${b.createdAt.minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.nunitoSans(fontSize: 11, color: Colors.white60),
            ),
            if (b.ersScore != null) ...[
              SizedBox(width: 10),
              Text(
                zh
                    ? '\u00b7  \u72c0\u614b ${b.ersScore!.toStringAsFixed(0)}'
                    : '\u00b7  ${b.ersScore!.toStringAsFixed(0)}',
                style: GoogleFonts.nunitoSans(fontSize: 11, color: Colors.white60),
              ),
            ],
            const Spacer(),
            // 連結 Pacer 的入口就放在卡片裡，不用再往下找
            GestureDetector(
              onTap: () => _pickPacer(b, zh),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    card == null ? Icons.add_rounded : Icons.swap_horiz_rounded,
                    size: 15,
                    color: Colors.white70,
                  ),
                  SizedBox(width: 3),
                  Text(
                    card == null
                        ? (zh ? '\u914d\u4e00\u5f35\u5361' : 'Attach')
                        : (zh ? '\u63db\u4e00\u5f35' : 'Change'),
                    style: GoogleFonts.nunitoSans(
                        fontSize: 11.5, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _detail(MemoryBall b, bool zh, ThemeData theme) {
    final main = b.tone.stops[1];
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
              main.withValues(alpha: 0.08), theme.colorScheme.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: main.withValues(alpha: 0.28), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  // 情緒球顯示組名，其他顯示來源
                  b.group?.label(zh) ?? b.source.label(zh),
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: main,
                  ),
                ),
                const Spacer(),
                Text(
                  '${b.createdAt.hour.toString().padLeft(2, '0')}:'
                  '${b.createdAt.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (b.note.isNotEmpty) ...[
              SizedBox(height: 9),
              Text(
                b.note,
                style: GoogleFonts.nunitoSans(fontSize: 13.5, height: 1.6),
              ),
            ],
            // ERS 只在真的有分數時顯示。
            // 沒有分數不是錯誤，只是那天沒做 check-in。
            if (b.ersScore != null) ...[
              SizedBox(height: 9),
              Text(
                zh
                    ? '那天的狀態分數 ${b.ersScore!.toStringAsFixed(0)}'
                    : 'Score that day: ${b.ersScore!.toStringAsFixed(0)}',
                style: GoogleFonts.nunitoSans(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 11),
            _pacerSlot(b, zh, theme, main),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  Pacer 連結
  // ══════════════════════════════════════════════════

  /// 這顆球連著的那張 Pacer 卡，或一個「配一句話」的入口。
  ///
  /// 為什麼是選配的：不是每一次記錄都需要一句話。
  /// 強制要選的話，使用者會隨便挑一張，那句話就失去意義了。
  Widget _pacerSlot(
      MemoryBall b, bool zh, ThemeData theme, Color main) {
    final card = b.pacerId == null
        ? null
        : _pacers.where((c) => c.id == b.pacerId).firstOrNull;

    // 有連結但找不到卡片——那張卡被刪掉了
    if (b.pacerId != null && card == null) {
      return Row(
        children: [
          Icon(Icons.link_off_rounded,
              size: 15, color: theme.colorScheme.onSurfaceVariant),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              zh ? '那張卡已經不在了' : 'That card is gone',
              style: GoogleFonts.nunitoSans(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _pickPacer(b, zh),
            child: Text(zh ? '換一張' : 'Pick another',
                style: GoogleFonts.nunitoSans(fontSize: 12)),
          ),
        ],
      );
    }

    if (card != null) {
      return GestureDetector(
        onLongPress: () => _pickPacer(b, zh),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: main.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: main.withValues(alpha: 0.20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (card.photoB64 != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.memory(
                    base64Decode(card.photoB64!),
                    width: double.infinity,
                    height: 128,
                    fit: BoxFit.cover,
                    // 照片壞掉不該讓整顆球顯示不出來
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                SizedBox(height: 9),
              ],
              Text(
                card.text,
                style: GoogleFonts.nunitoSans(fontSize: 13.5, height: 1.65),
              ),
              if (card.author.isNotEmpty) ...[
                SizedBox(height: 5),
                Text(
                  '— ${card.author}',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // 還沒連結：一個很輕的入口
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _pickPacer(b, zh),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: Text(
          zh ? '配一句話或一張照片' : 'Attach a line or a photo',
          style: GoogleFonts.nunitoSans(fontSize: 12.5),
        ),
        style: TextButton.styleFrom(
          foregroundColor: main,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Future<void> _pickPacer(MemoryBall b, bool zh) async {
    // 一張卡都沒有的時候，不要只是說「去別的地方寫」——
    // 直接帶他去寫，回來自動連上。少一個步驟就少一次放棄的機會。
    if (_pacers.isEmpty) {
      await _writeNewCard(b, zh);
      return;
    }

    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.62,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        zh ? '配一句自己的話' : 'Attach one of your lines',
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      if (b.pacerId != null)
                        TextButton(
                          // 傳空字串代表「解除連結」——
                          // 跟 null（取消）要分開，不然按取消會變成解除
                          onPressed: () => Navigator.pop(context, ''),
                          child: Text(zh ? '取消連結' : 'Unlink',
                              style: GoogleFonts.nunitoSans(fontSize: 12.5)),
                        ),
                      TextButton.icon(
                        // 回傳 'NEW' 這個標記，外面再帶去 Card Studio
                        onPressed: () => Navigator.pop(context, 'NEW'),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(zh ? '新寫一張' : 'Write one',
                            style: GoogleFonts.nunitoSans(fontSize: 12.5)),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _pacers.length,
                    itemBuilder: (context, i) {
                      final c = _pacers[i];
                      final isCurrent = c.id == b.pacerId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: isCurrent
                              ? theme.colorScheme.primary
                                  .withValues(alpha: 0.10)
                              : theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(13),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.pop(context, c.id),
                            child: Padding(
                              padding: const EdgeInsets.all(13),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.text,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.nunitoSans(
                                          fontSize: 13.5, height: 1.55),
                                    ),
                                  ),
                                  if (isCurrent)
                                    Icon(Icons.check_rounded,
                                        size: 18,
                                        color: theme.colorScheme.primary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // null = 使用者按了返回，什麼都不做
    if (picked == null || !mounted) return;
    // 'NEW' = 去寫一張新的
    if (picked == 'NEW') {
      await _writeNewCard(b, zh);
      return;
    }
    // 空字串 = 解除連結
    await MemoryBallStore.linkPacer(b.id, picked.isEmpty ? null : picked);
    await _load();
  }

  /// 帶使用者去 Card Studio 寫一張新的，回來自動連上這顆球。
  ///
  /// Card Studio 存檔時會 pop 出新卡片的 id，所以這裡接得到。
  /// 使用者中途離開的話回傳 null，那就什麼都不做——
  /// 不要硬連一張他沒寫完的卡。
  Future<void> _writeNewCard(MemoryBall b, bool zh) async {
    final newId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CardStudioPage()),
    );
    if (!mounted) return;
    if (newId != null && newId.isNotEmpty) {
      await MemoryBallStore.linkPacer(b.id, newId);
    }
    await _load();
  }

  String _monthAbbr(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}

// ══════════════════════════════════════════════════════
//  落進罐子的漣漪
// ══════════════════════════════════════════════════════

/// 一顆球「啵」地落進罐子，泛起一圈光的漣漪。
///
/// 球從上方稍微掉下來、彈一下停住，同時在它周圍擴散兩圈淡淡的光環。
/// 只有剛留下的那一顆會跑，播完就停——跟 [MemoryBallDot] 的效能原則一樣。
/// 只用圓形描邊，不用模糊濾鏡；系統開「減少動態效果」時直接略過。
class DropEcho extends StatefulWidget {
  const DropEcho({super.key, required this.tone, required this.child});
  final GlassTone tone;
  final Widget child;

  @override
  State<DropEcho> createState() => _DropEchoState();
}

class _DropEchoState extends State<DropEcho>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _ctrl.value = 1;
    } else {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.tone.stops[1];
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        final t = _ctrl.value;
        // 前 45%：落下並彈一下
        final drop = Curves.easeOutBack.transform((t / 0.45).clamp(0.0, 1.0));
        final dy = (1 - drop) * -28;
        return CustomPaint(
          painter: _EchoRingPainter(t: t, color: color),
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
    );
  }
}

class _EchoRingPainter extends CustomPainter {
  _EchoRingPainter({required this.t, required this.color});
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0.3 || t >= 1) return;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    // 兩圈，第二圈晚一點出發——像回聲
    for (final delay in const [0.3, 0.45]) {
      final u = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (u <= 0) continue;
      final fade = 1 - u;
      canvas.drawCircle(
        c,
        r * (1.0 + 0.9 * Curves.easeOut.transform(u)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * fade + 0.3
          ..color = color.withValues(alpha: 0.7 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_EchoRingPainter old) => old.t != t || old.color != color;
}

// ══════════════════════════════════════════════════════
//  像寫便條一樣
// ══════════════════════════════════════════════════════

/// 選完情緒之後的便條。寫不寫都可以。
///
/// 自己持有輸入框的 controller：表單收起的動畫還在跑時輸入框還在畫面上，
/// 在外面 await 完就 dispose 的話會用到已經釋放的 controller。
class _MemoSheet extends StatefulWidget {
  const _MemoSheet({
    required this.tone,
    required this.title,
    required this.zh,
    required this.aiOn,
  });
  final GlassTone tone;
  final String title;
  final bool zh;

  /// 有沒有設定 AI 金鑰。決定要不要顯示「送去 AI」的說明和開關
  final bool aiOn;

  @override
  State<_MemoSheet> createState() => _MemoSheetState();
}

class _MemoSheetState extends State<_MemoSheet> {
  final _ctrl = TextEditingController();

  /// 要不要讓 Luna 回應。關掉的話便條只存在手機裡，不會送去 AI。
  bool _askLuna = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zh = widget.zh;
    final main = widget.tone.stops[1];
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IgnorePointer(
                      child: MemoryBallDot(tone: widget.tone, size: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.title,
                        style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: 300,
                decoration: InputDecoration(
                  hintText: zh ? '想寫什麼都可以，發生了什麼、現在的感覺……' : 'Anything you want to write down…',
                  border: const OutlineInputBorder(),
                ),
              ),
              // ── 隱私 ─────────────────────────────────────
              //
              // README 承諾日記留在手機裡。便條要送去 AI 才能產生回應，
              // 所以寫的當下就說清楚，並讓使用者可以選擇不送。
              Row(
                children: [
                  Icon(
                    widget.aiOn && _askLuna
                        ? Icons.cloud_outlined
                        : Icons.lock_outline_rounded,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      !widget.aiOn
                          ? (zh ? '只存在這支手機，不會上傳' : 'Stays on this device only')
                          : _askLuna
                              ? (zh ? '會送到 AI 服務，讓 Luna 回應你' : 'Sent to the AI service so Luna can reply')
                              : (zh ? '只存在這支手機，Luna 不會回應' : 'Stays on this device. No reply.'),
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (widget.aiOn)
                    Semantics(
                      label: zh ? '讓 Luna 回應' : 'Let Luna reply',
                      child: Switch(
                        value: _askLuna,
                        onChanged: (v) => setState(() => _askLuna = v),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, ('', false)),
                      style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      child: Text(zh ? '不寫，直接留下' : 'Just leave it'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, (_ctrl.text.trim(), _askLuna)),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: main,
                      ),
                      child: Text(zh ? '寫好了' : 'Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  Luna 的回聲
// ══════════════════════════════════════════════════════

class _ReplySheet extends StatefulWidget {
  const _ReplySheet({
    required this.ball,
    required this.zh,
    required this.risky,
    required this.startFresh,
    required this.service,
  });
  final MemoryBall ball;
  final bool zh;

  /// 便條裡有高風險字眼：不送 AI，改成安全訊息
  final bool risky;

  /// true：已經有回聲了，使用者按了「換一句」
  final bool startFresh;
  final GleamReplyService service;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  String _text = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.risky) {
      _text = widget.zh ? aiHighRiskSafetyReply : aiHighRiskSafetyReplyEn;
      _loading = false;
    } else {
      _fetch(previous: widget.ball.reply, first: true);
    }
  }

  Future<void> _fetch({String previous = '', bool first = false}) async {
    // 第一次是從 initState 叫的，那時候還不能 setState；_loading 本來就是 true
    if (!first) setState(() => _loading = true);
    final g = widget.ball.group ?? EmotionGroup.okay;
    final out = await widget.service.reply(
      group: g,
      word: widget.ball.note,
      memo: widget.ball.memo,
      zh: widget.zh,
      previous: previous,
    );
    await MemoryBallStore.setReply(widget.ball.id, out);
    if (!mounted) return;
    setState(() {
      _text = out;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zh = widget.zh;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFD166),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Luna',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _loading
                  ? Padding(
                      key: const ValueKey('loading'),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(zh ? 'Luna 在讀你寫的……' : 'Luna is reading…',
                          style: GoogleFonts.nunitoSans(
                              fontSize: 14,
                              color: theme.colorScheme.onSurfaceVariant)),
                    )
                  : Text(_text,
                      key: ValueKey(_text),
                      style: GoogleFonts.nunitoSans(fontSize: 15.5, height: 1.65)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!widget.risky)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => _fetch(previous: _text),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      child: Text(zh ? '換一句' : 'Another'),
                    ),
                  ),
                if (!widget.risky) const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: Text(widget.risky
                        ? (zh ? '找人聊聊' : 'Reach someone')
                        : (zh ? '收好了' : 'Keep it')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  首頁的入口
// ══════════════════════════════════════════════════════

/// 放在首頁的一小排預覽——最近五顆球加一個「看全部」。
///
/// 刻意做得很小：首頁已經很滿了，這裡只是一個入口，
/// 不是心情 bar 本身。
class MoodBarEntry extends ConsumerStatefulWidget {
  const MoodBarEntry({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  ConsumerState<MoodBarEntry> createState() => _MoodBarEntryState();
}

class _MoodBarEntryState extends ConsumerState<MoodBarEntry> {
  List<MemoryBall> _recent = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await MemoryBallStore.load();
    if (!mounted) return;
    setState(() {
      _recent = all.take(5).toList();
      _loaded = true;
    });
  }

  /// 從心情罐頁面回來時重新載入
  Future<void> refresh() => _load();

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _recent.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final zh = AppStrings.of(ref.watch(appLanguageControllerProvider)).isZhTw;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              for (final b in _recent) ...[
                // 入口的球不需要互動，所以不給 onTap
                IgnorePointer(
                  child: MemoryBallDot(tone: b.tone, size: 26),
                ),
                SizedBox(width: 6),
              ],
              const Spacer(),
              Text(
                zh ? '微光' : 'Gleam',
                style: GoogleFonts.nunitoSans(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
