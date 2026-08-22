// 我的專屬格言 — 畫廊頁（依作者分組，渲染照片/文字位置/貼圖）
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'my_cards_store.dart';
import '../../../l10n/app_strings.dart';
import '../../../core/security/local_settings_service.dart';

class MyCardsPage extends ConsumerStatefulWidget {
  const MyCardsPage({super.key});
  @override
  ConsumerState<MyCardsPage> createState() => _MyCardsPageState();
}

class _MyCardsPageState extends ConsumerState<MyCardsPage> {
  List<MyCard> _cards = [];
  bool _loading = true;
  bool _zh = true;

  static const List<List<Color>> _bgs = [
    [Color(0xFFFF6EC7), Color(0xFF9B5DE5)],
    [Color(0xFF00E0FF), Color(0xFFFF61D2)],
    [Color(0xFFB4FF39), Color(0xFF00D4B4)],
    [Color(0xFFFFD194), Color(0xFFFF7EB3)],
    [Color(0xFF7E8FE8), Color(0xFF9C8CE0)],
    [Color(0xFFB39DDB), Color(0xFF9575CD)],
    [Color(0xFF5DCAA5), Color(0xFF2EC4B6)],
    [Color(0xFFF5A6C0), Color(0xFFE58AA9)],
    [Color(0xFFFFB74D), Color(0xFFEF9F27)],
    [Color(0xFF1A2540), Color(0xFF0D1426)],
    [Color(0xFFFFFFFF), Color(0xFFF2F2F7)],
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await MyCardsStore.load();
    if (!mounted) return;
    setState(() {
      _cards = c;
      _loading = false;
    });
  }

  TextStyle _fontStyle(int i, double size, Color color) {
    switch (i) {
      case 0:
        return GoogleFonts.zcoolQingKeHuangYou(fontSize: size + 2, color: color, height: 1.4);
      case 1:
        return GoogleFonts.liuJianMaoCao(fontSize: size + 6, color: color, height: 1.3);
      case 2:
        return GoogleFonts.zcoolKuaiLe(fontSize: size, color: color, height: 1.5);
      case 3:
        return GoogleFonts.zhiMangXing(fontSize: size + 4, color: color, height: 1.4);
      case 4:
        return GoogleFonts.notoSansTc(fontSize: size, color: color, fontWeight: FontWeight.w600, height: 1.4);
      case 5:
        return GoogleFonts.mPlusRounded1c(fontSize: size, color: color, fontWeight: FontWeight.w600, height: 1.5);
      case 6:
        return GoogleFonts.maShanZheng(fontSize: size + 4, color: color, height: 1.4);
      case 7:
        return GoogleFonts.longCang(fontSize: size + 4, color: color, height: 1.4);
      case 8:
        return GoogleFonts.zcoolXiaoWei(fontSize: size, color: color, height: 1.5);
      default:
        return GoogleFonts.notoSansTc(fontSize: size, color: color, height: 1.5);
    }
  }

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year - 1911}/${two(d.month)}/${two(d.day)}';
  }

  Future<void> _delete(String id) async {
    await MyCardsStore.remove(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    _zh = AppStrings.of(ref.watch(appLanguageControllerProvider)).isZhTw;
    final byAuthor = <String, List<MyCard>>{};
    for (final c in _cards) {
      (byAuthor[c.author] ??= []).add(c);
    }
    final authors = byAuthor.keys.toList();
    for (final a in authors) {
      byAuthor[a]!.sort((x, y) => x.createdAt.compareTo(y.createdAt));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF2C3150),
        title: Text(_zh ? '我的專屬格言' : 'My Quotes'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF9B5DE5),
        onPressed: () async {
          await context.push('/card-studio');
          _load();
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(_zh ? '做新卡' : 'New card', style: const TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? _empty()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  children: [
                    for (final a in authors)
                      ..._authorSection(a, byAuthor[a]!),
                  ],
                ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded,
                size: 56, color: Color(0xFFB0B6C6)),
            const SizedBox(height: 12),
            Text(_zh ? '還沒有專屬格言卡' : 'No cards yet',
                style: const TextStyle(color: Color(0xFF8A92A6), fontSize: 15)),
            const SizedBox(height: 6),
            Text(_zh ? '點右下角「做新卡」開始' : 'Tap "New card" to start',
                style: const TextStyle(color: Color(0xFFB0B6C6), fontSize: 13)),
          ],
        ),
      );

  List<Widget> _authorSection(String author, List<MyCard> list) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Row(
          children: [
            const Icon(Icons.person_rounded, size: 18, color: Color(0xFF9B5DE5)),
            const SizedBox(width: 6),
            Text(author,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF2C3150))),
            const SizedBox(width: 6),
            Text('${list.length}',
                style: const TextStyle(color: Color(0xFF9AA3B5), fontSize: 13)),
          ],
        ),
      ),
      for (final c in list) _cardTile(c),
    ];
  }

  Widget _cardTile(MyCard c) {
    final hasPhoto = c.photoB64 != null && c.photoB64!.isNotEmpty;
    Uint8List? photo;
    if (hasPhoto) {
      try {
        photo = base64Decode(c.photoB64!);
      } catch (_) {}
    }
    final usePhoto = photo != null;
    final dark = !usePhoto && c.bgIndex == 10;
    final textColor =
        usePhoto ? Colors.white : (dark ? const Color(0xFF2C3150) : Colors.white);
    final subColor = usePhoto
        ? Colors.white.withValues(alpha: 0.9)
        : (dark ? const Color(0xFF7A8296) : Colors.white.withValues(alpha: 0.85));
    final bg = (c.bgIndex >= 0 && c.bgIndex < _bgs.length) ? _bgs[c.bgIndex] : _bgs[0];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (context, cons) {
              final s = cons.maxWidth;
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: bg),
                        ),
                      ),
                    ),
                    if (usePhoto)
                      Positioned.fill(
                        child: ClipRect(
                          child: Transform.scale(
                            scale: c.photoScale,
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                  Colors.black.withValues(alpha: 0.28),
                                  BlendMode.darken),
                              child: Image.memory(
                                photo!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: c.align == 2 ? null : (c.align == 1 ? 0 : 22),
                      right: c.align == 0 ? null : (c.align == 1 ? 0 : 22),
                      bottom: 22,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: c.align == 1 ? s : s * 0.82),
                        child: Column(
                          crossAxisAlignment: c.align == 0
                              ? CrossAxisAlignment.start
                              : c.align == 2
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c.text,
                                textAlign: c.align == 0
                                    ? TextAlign.left
                                    : c.align == 2
                                        ? TextAlign.right
                                        : TextAlign.center,
                                style:
                                    _fontStyle(c.fontIndex, c.size, textColor)),
                            const SizedBox(height: 10),
                            Text('${_zh ? '作者：' : 'by '}${c.author}',
                                style: TextStyle(color: subColor, fontSize: 12)),
                            Text(_fmt(c.createdAt),
                                style: TextStyle(color: subColor, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    for (final st in c.stickers)
                      Positioned(
                        left: ((st['x'] as num?)?.toDouble() ?? 0.4) * s,
                        top: ((st['y'] as num?)?.toDouble() ?? 0.4) * s,
                        child: Text(st['e'] as String? ?? '',
                            style: TextStyle(
                                fontSize:
                                    34 * ((st['s'] as num?)?.toDouble() ?? 1.0))),
                      ),
                  ],
                ),
              );
            }),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: GestureDetector(
              onTap: () => _confirmDelete(c),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(MyCard c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_zh ? '刪除這張卡？' : 'Delete this card?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_zh ? '取消' : 'Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _delete(c.id);
            },
            child: Text(_zh ? '刪除' : 'Delete', style: const TextStyle(color: Color(0xFFEF5350))),
          ),
        ],
      ),
    );
  }
}
