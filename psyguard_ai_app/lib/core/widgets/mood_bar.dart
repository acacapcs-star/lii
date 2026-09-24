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

import 'package:google_fonts/google_fonts.dart';

import '../theme/mood_theme_service.dart';
import '../theme/background_theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_strings.dart';
import '../security/local_settings_service.dart';

import 'luna_orb.dart' show GlassTone, GlassToneX;
import 'memory_ball.dart';
import '../../features/card_studio/presentation/my_cards_store.dart';
import '../../features/card_studio/presentation/card_studio_page.dart';

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
          center: const Alignment(0.35, -0.42),
          radius: 0.95,
          colors: [
            Color.lerp(highlight, Colors.white, 0.55)!
                .withValues(alpha: 0.92),
            main.withValues(alpha: 0.58),
            deep.withValues(alpha: 0.86),
          ],
          stops: const [0.0, 0.48, 1.0],
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
                MemoryBallDot(
                  tone: b.tone,
                  size: ballSize,
                  onTap: () => onTapBall(b.id),
                ),
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
              MemoryBallDot(
                tone: b.tone,
                size: ballSize,
                onTap: () => onTapBall(b.id),
              ),
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
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

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
          IconButton(
            tooltip: zh ? '自己留一顆' : 'Add one',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _addManually(zh),
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
              ? _empty(zh, theme)
              : Column(
                  children: [
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
  /// 這是選配的——主要的來源還是練習，這裡只是補一條路。
  Future<void> _addManually(bool zh) async {
    final picked = await showModalBottomSheet<EmotionGroup?>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zh ? '現在是哪一種？' : 'Which one is it now?',
                  style: theme.textTheme.titleMedium,
                ),
                SizedBox(height: 4),
                Text(
                  zh
                      ? '選一個就好。想說得更精準的話，到情緒詞彙庫。'
                      : 'Just pick one. For a more precise word, open the dictionary.',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 18),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final g in EmotionGroup.values)
                      GestureDetector(
                        onTap: () => Navigator.pop(context, g),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IgnorePointer(
                              child: MemoryBallDot(tone: g.tone, size: 52),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              g.label(zh),
                              style: GoogleFonts.nunitoSans(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null || !mounted) return;
    await MemoryBallStore.addFromEmotion(
      group: picked,
      // 刻意存空字串，不存組名的翻譯。
      //
      // 存「難過」的話，使用者之後切成英文，那顆球還是顯示「難過」——
      // 因為那是當下語言的字串，被寫死進資料了。
      //
      // 存空的，顯示時用 group.label(zh) 現算，語言就跟得上。
      // 從字典來的球才有 word，那是使用者真的挑的那個詞，
      // 語言固定反而是對的——他當時就是用那個語言在想這件事。
      word: '',
    );
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(zh ? '留下一點光了' : 'A little more gleam'),
        duration: const Duration(seconds: 2),
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
                  ? '在情緒詞彙庫裡找到一個詞，\n或做完一次練習，就會留下一顆球。'
                  : 'Name a feeling in the dictionary,\nor finish a practice, to leave a ball here.',
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
          const SizedBox(width: 10),
          for (final s in BallSource.values) ...[
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
