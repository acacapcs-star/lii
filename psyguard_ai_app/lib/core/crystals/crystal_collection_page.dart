// 水晶收藏
//
// 已經拿到的會自己呼吸；還沒拿到的是暗的，但形狀看得見 ——
// 看得見才會想要，全黑的格子只會讓人覺得「反正拿不到」。
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../widgets/luna_orb.dart';
import 'crystal_store.dart';

const Color _paper = Color(0xFFF3F0EA);
const Color _ink = Color(0xFF1B2440);
const Color _inkSoft = Color(0xFF6B7590);

Future<void> showCrystalCollection(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => const CrystalCollectionPage()),
  );
}

class CrystalCollectionPage extends StatefulWidget {
  const CrystalCollectionPage({super.key});

  @override
  State<CrystalCollectionPage> createState() => _CrystalCollectionPageState();
}

class _CrystalCollectionPageState extends State<CrystalCollectionPage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _time = 0;
  void Function(void Function())? _bigRepaint;
  int _skip = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    CrystalStore.ensureLoaded().then((_) {
      if (mounted) setState(() => _ready = true);
    });
    _ticker = createTicker((d) {
      _time = d.inMicroseconds / 1e6;
      _bigRepaint?.call(() {});
      _skip = (_skip + 1) % 2;
      if (_skip == 0 && mounted) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final got = _ready ? CrystalStore.unlocked().length : 0;

    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _paper,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text('Crystals', style: TextStyle(fontSize: 16)),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              children: [
                Text(
                  '$got / ${kCrystalRules.length}',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w400, color: _ink),
                ),
                const SizedBox(height: 4),
                Text(
                  CrystalStore.nextHint(zh: false) ?? 'All collected',
                  style: const TextStyle(fontSize: 13, color: _inkSoft),
                ),
                const SizedBox(height: 22),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.74,
                  children: kCrystalRules.map(_cell).toList(),
                ),
                const SizedBox(height: 26),
                Text(
                  'Crystals come only from breathing.\nEach one marks something you actually did.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5,
                      height: 1.9,
                      color: _inkSoft.withAlpha(150)),
                ),
              ],
            ),
    );
  }

  /// 解鎖了顯示日期，還沒解鎖顯示進度。
  String _subLabel(CrystalRule r, bool got) {
    if (got) {
      final at = CrystalStore.unlockedAt[r.tone];
      if (at == null) return 'Collected';
      final m = at.month.toString().padLeft(2, '0');
      final d = at.day.toString().padLeft(2, '0');
      return 'Collected · ${at.year}-$m-$d';
    }
    final p = CrystalStore.progress(r.tone);
    if (p == null) return r.requirementEn;
    final unit = p.isStreak ? 'days' : 'sessions';
    return '${p.done} / ${p.need} $unit';
  }

  Widget _cell(CrystalRule r) {
    final got = CrystalStore.isUnlocked(r.tone);

    Widget orb = LunaOrb(
      time: got ? _time : 0,
      w: -80,
      tone: r.tone,
    );

    if (!got) {
      orb = Opacity(
        opacity: 0.28,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: orb,
        ),
      );
      orb = Stack(
        alignment: Alignment.center,
        children: [
          orb,
          Icon(Icons.lock_outline_rounded,
              size: 22, color: _inkSoft.withAlpha(150)),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showBig(r, got),
      child: Column(
      children: [
        Expanded(child: AspectRatio(aspectRatio: 1, child: orb)),
        const SizedBox(height: 8),
        Text(
          r.tone.labelEn,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: got ? _ink : _inkSoft.withAlpha(120),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _subLabel(r, got),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10.5, color: _inkSoft.withAlpha(160)),
        ),
      ],
      ),
    );
  }

  /// 點一下水晶 -> 全螢幕放大檢視（向量繪製，放多大都不會糊）
  void _showBig(CrystalRule r, bool got) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'crystal',
      barrierColor: Colors.black.withAlpha(200),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, a1, a2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final t = Curves.easeOutCubic.transform(anim.value);
        final side = MediaQuery.of(ctx).size.width * 0.68;
        return Opacity(
          opacity: anim.value,
          child: Transform.scale(
            scale: 0.86 + 0.14 * t,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _bigRepaint = null;
                Navigator.of(ctx).pop();
              },
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: side,
                      height: side,
                      child: StatefulBuilder(
                        builder: (bctx, setBig) {
                          _bigRepaint = setBig;
                          Widget big = LunaOrb(
                            time: got ? _time : 0,
                            w: -80,
                            tone: r.tone,
                          );
                          if (!got) {
                            big = Opacity(
                              opacity: 0.3,
                              child: ColorFiltered(
                                colorFilter: const ColorFilter.matrix(<double>[
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0, 0, 0, 1, 0,
                                ]),
                                child: big,
                              ),
                            );
                          }
                          return big;
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      r.tone.labelEn,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Colors.white.withAlpha(got ? 255 : 130),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      got ? 'Collected' : r.requirementEn,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withAlpha(150),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'tap anywhere to close',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withAlpha(80),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
