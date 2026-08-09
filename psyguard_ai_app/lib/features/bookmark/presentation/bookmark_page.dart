// ═══════════════════════════════════════════════════════════
// lii - Pacer Lift 🚡🏔️（語錄纜車 + 觀景台成就）
//
// 兩個分頁：
//  🚡 語錄  = 別人對你說的話，變成纜車掛在山上（誰說的）。
//  🏔️ 觀景台 = 成就里程碑：標題 + 鼓勵小語 + 選觀景台圖 + 顏色。
// 都存在手機（SharedPreferences）。中英嚴格分開。
// ═══════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_strings.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/widgets/luna_orb.dart';

const _kBookmarksKey = 'bookmarks_v2';
const _kStationsKey = 'achievements_v1';

const List<Color> _bgColors = [
  Color(0xFF337FB0), // ice 冰藍
  Color(0xFF2A8A88), // sea 海藍
  Color(0xFF7A54B0), // amethyst 紫水晶
  Color(0xFFA65F14), // amber 琥珀
  Color(0xFF2C7247), // moss 苔綠
  Color(0xFFB04E6C), // dawn 晨曦
];

const List<String> _bgImages = [
  'assets/images/hope_night.jpg',
  'assets/images/hope_lonely.jpg',
  'assets/images/hope_tired.jpg',
  'assets/images/hope_cheer.jpg',
];

// 觀景台圖（9 種成就）
const List<Map<String, String>> _decks = [
  {'img': 'assets/images/atheletic.png', 'zh': '運動', 'en': 'Sports'},
  {'img': 'assets/images/piano.png', 'zh': '音樂', 'en': 'Music'},
  {'img': 'assets/images/art.png', 'zh': '美術', 'en': 'Art'},
  {'img': 'assets/images/no_human_basketball.png', 'zh': '體育', 'en': 'PE'},
  {'img': 'assets/images/nerdy_study.png', 'zh': '學術', 'en': 'Academic'},
  {'img': 'assets/images/code.png', 'zh': '程式', 'en': 'Coding'},
  {'img': 'assets/images/man_climbing.png', 'zh': '攀岩', 'en': 'Climbing'},
  {'img': 'assets/images/rock_climbing_woman.png', 'zh': '攀岩', 'en': 'Climbing'},
  {'img': 'assets/images/night_scenic.png', 'zh': '夜景', 'en': 'Night View'},
];

// 觀景台顏色
const List<Color> _stationColors = [
  Color(0xFFF2994A),
  Color(0xFFB57EDC),
  Color(0xFFF48FB1),
  Color(0xFF6FCF97),
  Color(0xFF56A9F0),
  Color(0xFF2D9CDB),
];

class Bookmark {
  final String quote;
  final String author;
  final int colorIndex;
  final int imageIndex;
  final int frameIndex;
  final double darkY; // 暗區中心 0~1（襯字用），可手指拖曳
  final double darkRange; // 暗區範圍 0~1
  final String customImagePath; // 自己選的照片路徑（空=用內建背景）
  /// 那顆球被拉到哪 0~1。null = 還沒拉過。
  final double? orbT;
  /// 球的顏色 0=冰藍 1=海藍 2=紫水晶
  final int toneIndex;
  /// 收藏當下的心情 0~100。null = 舊資料，不限心情，隨時可能被抽到。
  final int? moodTag;

  const Bookmark({
    required this.quote,
    required this.author,
    required this.colorIndex,
    required this.imageIndex,
    required this.frameIndex,
    this.darkY = 0.72,
    this.darkRange = 0.35,
    this.customImagePath = '',
    this.orbT,
    this.toneIndex = 0,
    this.moodTag,
  });

  bool get hasCustomImage => customImagePath.isNotEmpty;

  Bookmark copyWith(
          {double? darkY,
          double? darkRange,
          double? orbT,
          int? toneIndex,
          int? moodTag}) =>
      Bookmark(
        quote: quote,
        author: author,
        colorIndex: colorIndex,
        imageIndex: imageIndex,
        frameIndex: frameIndex,
        darkY: darkY ?? this.darkY,
        darkRange: darkRange ?? this.darkRange,
        customImagePath: customImagePath,
        orbT: orbT ?? this.orbT,
        toneIndex: toneIndex ?? this.toneIndex,
        moodTag: moodTag ?? this.moodTag,
      );

  Map<String, dynamic> toJson() => {
        'quote': quote,
        'author': author,
        'colorIndex': colorIndex,
        'imageIndex': imageIndex,
        'frameIndex': frameIndex,
        'darkY': darkY,
        'darkRange': darkRange,
        'customImagePath': customImagePath,
        if (orbT != null) 'orbT': orbT,
        'tone': toneIndex,
        if (moodTag != null) 'mood': moodTag,
      };

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        quote: j['quote'] as String? ?? '',
        author: j['author'] as String? ?? '',
        colorIndex: j['colorIndex'] as int? ?? 0,
        imageIndex: j['imageIndex'] as int? ?? -1,
        frameIndex: j['frameIndex'] as int? ?? 0,
        darkY: (j['darkY'] as num?)?.toDouble() ?? 0.72,
        darkRange: (j['darkRange'] as num?)?.toDouble() ?? 0.35,
        customImagePath: j['customImagePath'] as String? ?? '',
        orbT: (j['orbT'] as num?)?.toDouble(),
        toneIndex: (j['tone'] as num?)?.toInt() ?? 0,
        moodTag: (j['mood'] as num?)?.toInt(),
      );
}

class Achievement {
  final String title;
  final String note;
  final int deckIndex;
  final int colorIndex;

  const Achievement({
    required this.title,
    required this.note,
    required this.deckIndex,
    required this.colorIndex,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'note': note,
        'deckIndex': deckIndex,
        'colorIndex': colorIndex,
      };

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        title: j['title'] as String? ?? '',
        note: j['note'] as String? ?? '',
        deckIndex: j['deckIndex'] as int? ?? 0,
        colorIndex: j['colorIndex'] as int? ?? 0,
      );
}

class BookmarkPage extends ConsumerStatefulWidget {
  const BookmarkPage({super.key});
  @override
  ConsumerState<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends ConsumerState<BookmarkPage> {
  List<Bookmark> _items = [];
  List<Achievement> _stations = [];
  bool _loaded = false;
  int _tab = 0; // 0 語錄 / 1 觀景台

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kBookmarksKey);
      if (raw != null && raw.isNotEmpty) {
        _items = (jsonDecode(raw) as List)
            .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final rawS = prefs.getString(_kStationsKey);
      if (rawS != null && rawS.isNotEmpty) {
        _stations = (jsonDecode(rawS) as List)
            .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kBookmarksKey, jsonEncode(_items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _saveStations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStationsKey,
          jsonEncode(_stations.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  void _addBookmark(Bookmark b) {
    setState(() => _items.insert(0, b));
    _save();
  }

  void _delete(int index) {
    setState(() => _items.removeAt(index));
    _save();
  }

  void _addStation(Achievement a) {
    setState(() => _stations.insert(0, a));
    _saveStations();
  }

  void _deleteStation(int index) {
    setState(() => _stations.removeAt(index));
    _saveStations();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));
    final zh = copy.isZhTw;
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          zh ? '🚡 Pacer Lift' : '🚡 Pacer Lift',
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2C3150)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _tabChip(zh ? '🚡 語錄' : '🚡 Quotes', 0),
                const SizedBox(width: 8),
                _tabChip(zh ? '🏔️ 觀景台' : '🏔️ Decks', 1),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0ABFBC),
        foregroundColor: Colors.white,
        onPressed: () => _tab == 0 ? _openCreator(zh) : _openStationCreator(zh),
        icon: const Icon(Icons.add),
        label: Text(_tab == 0
            ? (zh ? '新增語錄' : 'New quote')
            : (zh ? '新增觀景台' : 'New deck')),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : (_tab == 0 ? _quoteTab(zh) : _stationTab(zh)),
    );
  }

  Widget _tabChip(String label, int idx) {
    final selected = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF7E8FE8) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF2C3150),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════ 語錄分頁（纜車）══════════════
  Widget _quoteTab(bool zh) {
    return _items.isEmpty ? _emptyQuote(zh) : _cableMountain(zh);
  }

  Widget _emptyQuote(bool zh) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _MountainPainter())),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚡', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(zh ? '纜車還空空的' : 'The cable car is empty',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3150))),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: Text(
                  zh
                      ? '存下有人對你說過、想記得的話 🌙'
                      : 'Save the words someone said to you 🌙',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade700, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cableMountain(bool zh) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const cabinW = 132.0;
        const cabinH = 104.0;
        const rowH = 168.0;
        const topPad = 110.0;
        final n = _items.length;
        final totalH = topPad + n * rowH + 90.0;

        final cabins = <_CabinPos>[];
        for (var i = 0; i < n; i++) {
          final leftSide = i.isEven;
          final x = leftSide ? width * 0.08 : width * 0.92 - cabinW;
          final y = topPad + i * rowH;
          cabins.add(_CabinPos(
            index: i,
            rect: Rect.fromLTWH(x, y, cabinW, cabinH),
            anchor: Offset(x + cabinW / 2, y - 16),
          ));
        }

        return SingleChildScrollView(
          child: SizedBox(
            width: width,
            height: totalH,
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _MountainPainter())),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CablePainter(
                      anchors: cabins.map((c) => c.anchor).toList(),
                      cabins: cabins.map((c) => c.rect).toList(),
                    ),
                  ),
                ),
                for (final c in cabins)
                  Positioned(
                    left: c.rect.left,
                    top: c.rect.top,
                    width: c.rect.width,
                    height: c.rect.height,
                    child: GestureDetector(
                      onTap: () => _viewBookmark(c.index, zh),
                      child: _cableCar(_items[c.index], c.index),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cableCar(Bookmark b, int index) {
    final useImage = b.imageIndex >= 0;
    final bg = useImage
        ? null
        : _bgColors[b.colorIndex.clamp(0, _bgColors.length - 1)];
    // CAR_DELETE 右上角的 ✕。不用滑動刪除 —— 纜車太小，很容易誤觸。
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _cableCarBody(b, bg, useImage),
        Positioned(
          top: 10,
          right: -6,
          child: GestureDetector(
            onTap: () => _confirmDeleteCar(index),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.92),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Color(0xFF6C7BA6)),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteCar(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪掉這則？ / Delete this one?'),
        content: const Text('刪了就找不回來了 / This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消 / Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _delete(index);
            },
            child: const Text('刪除 / Delete',
                style: TextStyle(color: Color(0xFFD9534F))),
          ),
        ],
      ),
    );
  }

  Widget _cableCarBody(Bookmark b, Color? bg, bool useImage) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFF6C7BA6),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: bg,
              image: b.hasCustomImage
                  ? DecorationImage(
                      image: _imgOf(b.customImagePath),
                      fit: BoxFit.cover,
                    )
                  : useImage
                      ? DecorationImage(
                          image: AssetImage(_bgImages[
                              b.imageIndex.clamp(0, _bgImages.length - 1)]),
                          fit: BoxFit.cover,
                        )
                      : null,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: useImage
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.12),
                          Colors.black.withOpacity(0.62),
                        ],
                      )
                    : null,
              ),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        b.quote,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                  if (b.author.isNotEmpty)
                    Text(
                      '\u2014 ${b.author}',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _viewBookmark(int i, bool zh) {
    var b = _items[i]; // 可變：拖曳暗區時會替換成新的 copyWith
    final useImage = b.imageIndex >= 0;
    final shotKey = GlobalKey(); // 截圖用
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setCard) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(28),
        // DELETE_SCROLL 卡片加球超過 500px，在手機上會把按鈕擠出畫面 ——
        // 包一層捲動，Save/Delete/Close 一定按得到。
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: shotKey,
              child: _PacerCardView(
                bookmark: b,
                bgColors: _bgColors,
                bgImages: _bgImages,
                onChanged: (nb) => setCard(() => b = nb),
                onEnd: () {
                  _items[i] = b;
                  _save();
                },
              ),
            ),
            // TONE_PICKER 三種球色。放在卡片外面，截圖時不會拍進去。
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(GlassTone.values.length, (ti) {
                const cols = [
                  Color(0xFF337FB0), // 冰藍
                  Color(0xFF2A8A88), // 海藍
                  Color(0xFF7A54B0), // 紫水晶
                  Color(0xFFA65F14), // 琥珀 amber
                  Color(0xFF2C7247), // 苔綠 moss
                  Color(0xFFB04E6C), // 晨曦 dawn
                ];
                final on = b.toneIndex == ti;
                return GestureDetector(
                  onTap: () {
                    setCard(() => b = b.copyWith(toneIndex: ti));
                    _items[i] = b;
                    _save();
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cols[ti],
                      border: Border.all(
                        color: on ? Colors.white : const Color(0x40FFFFFF),
                        width: on ? 2.5 : 1,
                      ),
                      boxShadow: on
                          ? const [
                              BoxShadow(
                                  color: Color(0x59000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2)),
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _saveQuoteImage(shotKey, zh),
                  icon: const Icon(Icons.download_rounded,
                      color: Color(0xFF0ABFBC)),
                  label: Text(zh ? '儲存' : 'Save',
                      style: const TextStyle(color: Color(0xFF0ABFBC))),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _delete(i);
                  },
                  icon: const Icon(Icons.delete_outline, color: Color(0xFF2C3150)),
                  label: Text(zh ? '刪除' : 'Delete',
                      style: const TextStyle(color: Color(0xFF2C3150))),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(zh ? '關閉' : 'Close',
                      style: const TextStyle(color: Color(0xFF2C3150))),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
      ),
    );
  }

  /// 把引言卡截成 PNG，叫出系統分享面板（可存到相簿/傳給朋友）。
  Future<void> _saveQuoteImage(GlobalKey shotKey, bool zh) async {
    try {
      final boundary = shotKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      // pixelRatio 3.0 → 高解析輸出
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final pngBytes = bytes.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = await File(
        '${dir.path}/quote_${DateTime.now().millisecondsSinceEpoch}.png',
      ).create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: zh ? '我的引言卡' : 'My quote card',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(zh ? '儲存失敗，請再試一次' : 'Save failed, try again')),
        );
      }
    }
  }

  /// 從相簿選一張照片，複製到 app 永久目錄後回傳新路徑。
  /// （相簿原檔可能被使用者刪掉，所以自己留一份。）
  /// 舊資料是檔案路徑、新資料是 b64: 前綴，兩種都要讀得到
  static ImageProvider _imgOf(String p) => p.startsWith('b64:')
      ? MemoryImage(base64Decode(p.substring(4)))
      : FileImage(File(p));

  Future<String?> _pickCustomImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (picked == null) return null;
      // 存 base64 而不是檔案路徑 —— dart:io 的 File 在瀏覽器不存在，
      // 原本的寫法在 web 上一定丟例外，照片功能整個是壞的。
      final bytes = await picked.readAsBytes();
      return 'b64:' + base64Encode(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法讀取照片 / Cannot read photo')),
        );
      }
      return null;
    }
  }

  void _openCreator(bool zh) {
    final quoteCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    int colorIndex = 0;
    int imageIndex = -1;
    int toneIndex = 0; // 球的顏色 = 使用者選的背景色
    String customImagePath = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _grabber(),
                    Text(zh ? '新增一個 Pacer 🔖' : 'Add a Pacer 🔖',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    // COLD_START 16 位試用者裡 10 位沒寫成，3 位說「想不出來要寫什麼」。
                    // 空白框對青少年太難 —— 給開頭讓他接，比從無到有容易得多。
                    Text(
                      zh ? '想不到的話，從這裡開始：' : 'Not sure? Start with:',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (zh
                              ? const [
                                  '有人跟我說',
                                  '我想記得那天',
                                  '如果以後忘記了',
                                  '謝謝你那時候',
                                ]
                              : const [
                                  'Someone told me',
                                  'I want to remember',
                                  'If I ever forget',
                                  'Thank you for',
                                ])
                          .map((seed) => ActionChip(
                                label: Text(seed,
                                    style: const TextStyle(fontSize: 12.5)),
                                onPressed: () {
                                  quoteCtrl.text = seed;
                                  quoteCtrl.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(
                                        offset: quoteCtrl.text.length),
                                  );
                                  setSheet(() {});
                                },
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: quoteCtrl,
                      maxLines: 3,
                      onChanged: (_) => setSheet(() {}),
                      decoration: InputDecoration(
                        labelText: zh ? '他說過的那句話' : 'The line they said',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: authorCtrl,
                      onChanged: (_) => setSheet(() {}),
                      decoration: InputDecoration(
                        labelText: zh ? '誰說的' : 'Who said it',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(zh ? '背景顏色' : 'Background color',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: List.generate(_bgColors.length, (i) {
                        final selected = colorIndex == i;
                        return GestureDetector(
                          onTap: () => setSheet(() {
                            toneIndex = i; // 球的顏色
                            colorIndex = i; // 沒放圖時的卡片底色
                          }),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _bgColors[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    selected ? Colors.black87 : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Text(zh ? '背景圖片' : 'Background image',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                      // ＋ 從相簿選自己的照片
                      GestureDetector(
                        onTap: () async {
                          final path = await _pickCustomImage();
                          if (path != null) {
                            setSheet(() {
                              customImagePath = path;
                              imageIndex = -1;
                            });
                          }
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFFEFF1FA),
                            border: Border.all(
                              color: customImagePath.isNotEmpty
                                  ? const Color(0xFF7E8FE8)
                                  : const Color(0xFFCED4EA),
                              width: customImagePath.isNotEmpty ? 3 : 1.5,
                            ),
                            image: customImagePath.isNotEmpty
                                ? DecorationImage(
                                    image: _imgOf(customImagePath),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: customImagePath.isEmpty
                              ? const Icon(Icons.add_a_photo_outlined,
                                  size: 20, color: Color(0xFF7E8FE8))
                              : null,
                        ),
                      ),
                      ...List.generate(_bgImages.length, (i) {
                        final selected =
                            imageIndex == i && customImagePath.isEmpty;
                        return GestureDetector(
                          onTap: () => setSheet(() {
                            imageIndex = i;
                            customImagePath = '';
                          }),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: AssetImage(_bgImages[i]),
                                fit: BoxFit.cover,
                              ),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF7E8FE8)
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        );
                      }),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _saveButton(zh ? '收好' : 'Keep it', () {
                      if (quoteCtrl.text.trim().isEmpty) return;
                      _addBookmark(Bookmark(
                        quote: quoteCtrl.text.trim(),
                        author: authorCtrl.text.trim(),
                        colorIndex: colorIndex,
                        imageIndex: imageIndex,
                        toneIndex: toneIndex,
                        frameIndex: 0,
                        customImagePath: customImagePath,
                      ));
                      Navigator.pop(ctx);
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ══════════════ 觀景台分頁（成就）══════════════
  Widget _stationTab(bool zh) {
    if (_stations.isEmpty) {
      return Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MountainPainter())),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏔️', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(zh ? '還沒有觀景台' : 'No decks yet',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C3150))),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: Text(
                    zh
                        ? '達成一個目標，就在山上蓋一座觀景台紀念 🏔️'
                        : 'Reach a goal, build a deck to remember it 🏔️',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade700, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _MountainPainter())),
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: _stations.length,
          itemBuilder: (context, i) => _stationCard(_stations[i], i, zh),
        ),
      ],
    );
  }

  Widget _stationCard(Achievement a, int i, bool zh) {
    final color = _stationColors[a.colorIndex.clamp(0, _stationColors.length - 1)];
    final deck = _decks[a.deckIndex.clamp(0, _decks.length - 1)];
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Image.asset(
            deck['img']!,
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Text('🏔️', style: TextStyle(fontSize: 60)),
          ),
          Transform.translate(
            offset: const Offset(0, -8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '🏔️ ${a.title}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _confirmDeleteStation(i, zh),
                        child: const Icon(Icons.close,
                            color: Colors.white70, size: 20),
                      ),
                    ],
                  ),
                  if (a.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      a.note,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white.withOpacity(0.95),
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteStation(int i, bool zh) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(zh ? '刪除這座觀景台？' : 'Delete this deck?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(zh ? '取消' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteStation(i);
            },
            child: Text(zh ? '刪除' : 'Delete',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openStationCreator(bool zh) {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    int deckIndex = 0;
    int colorIndex = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _grabber(),
                    Text(zh ? '蓋一座觀景台 🏔️' : 'Build a deck 🏔️',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleCtrl,
                      onChanged: (_) => setSheet(() {}),
                      decoration: InputDecoration(
                        labelText: zh ? '成就（例：英文考 90 分）' : 'Achievement',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      onChanged: (_) => setSheet(() {}),
                      decoration: InputDecoration(
                        labelText: zh ? '給自己的鼓勵小語' : 'A note to yourself',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(zh ? '選觀景台' : 'Pick a deck',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _decks.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final selected = deckIndex == i;
                          return GestureDetector(
                            onTap: () => setSheet(() => deckIndex = i),
                            child: Container(
                              width: 84,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF7E8FE8)
                                      : Colors.grey.shade200,
                                  width: selected ? 3 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: Image.asset(
                                      _decks[i]['img']!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Text(
                                          '🏔️',
                                          style: TextStyle(fontSize: 30)),
                                    ),
                                  ),
                                  Text(
                                    zh ? _decks[i]['zh']! : _decks[i]['en']!,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(zh ? '牌子顏色' : 'Plaque color',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: List.generate(_stationColors.length, (i) {
                        final selected = colorIndex == i;
                        return GestureDetector(
                          onTap: () => setSheet(() => colorIndex = i),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _stationColors[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    selected ? Colors.black87 : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    _saveButton(zh ? '蓋好了！' : 'Build it!', () {
                      if (titleCtrl.text.trim().isEmpty) return;
                      _addStation(Achievement(
                        title: titleCtrl.text.trim(),
                        note: noteCtrl.text.trim(),
                        deckIndex: deckIndex,
                        colorIndex: colorIndex,
                      ));
                      Navigator.pop(ctx);
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _grabber() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _saveButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0ABFBC),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _CabinPos {
  final int index;
  final Rect rect;
  final Offset anchor;
  const _CabinPos({required this.index, required this.rect, required this.anchor});
}

class _MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFCDE7F7), Color(0xFFE7F3E9)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), sky);

    final far = Paint()..color = const Color(0xFFBFD3E8).withOpacity(0.55);
    for (double y = 60; y < h; y += 260) {
      final p = Path()
        ..moveTo(0, y + 120)
        ..lineTo(w * 0.30, y)
        ..lineTo(w * 0.60, y + 90)
        ..lineTo(w, y + 20)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(p, far);
    }

    final peakShadow = Paint()..color = const Color(0xFFD8E6F5);
    final peakPath = Path()
      ..moveTo(w * 0.5, 20)
      ..lineTo(w * 0.16, 150)
      ..lineTo(w * 0.84, 150)
      ..close();
    canvas.drawPath(peakPath, peakShadow);
    final peak = Paint()..color = const Color(0xFFF6FAFF);
    final peakPath2 = Path()
      ..moveTo(w * 0.5, 20)
      ..lineTo(w * 0.30, 150)
      ..lineTo(w * 0.60, 150)
      ..close();
    canvas.drawPath(peakPath2, peak);

    final cloud = Paint()..color = Colors.white.withOpacity(0.85);
    void drawCloud(double cx, double cy, double s) {
      canvas.drawCircle(Offset(cx, cy), 14 * s, cloud);
      canvas.drawCircle(Offset(cx + 16 * s, cy + 4 * s), 18 * s, cloud);
      canvas.drawCircle(Offset(cx + 36 * s, cy), 13 * s, cloud);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 2 * s, cy + 2 * s, 40 * s, 12 * s),
          Radius.circular(8 * s),
        ),
        cloud,
      );
    }

    for (double y = 200; y < h; y += 340) {
      drawCloud(w * 0.18, y, 0.9);
      drawCloud(w * 0.62, y + 150, 1.1);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CablePainter extends CustomPainter {
  final List<Offset> anchors;
  final List<Rect> cabins;
  _CablePainter({required this.anchors, required this.cabins});

  @override
  void paint(Canvas canvas, Size size) {
    if (anchors.isEmpty) return;
    final line = Paint()
      ..color = const Color(0xFF6C7BA6)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(anchors.first.dx, 0);
    for (final a in anchors) {
      path.lineTo(a.dx, a.dy);
    }
    path.lineTo(anchors.last.dx, size.height);
    canvas.drawPath(path, line);

    final wheel = Paint()..color = const Color(0xFF4E5A7E);
    final arm = Paint()
      ..color = const Color(0xFF6C7BA6)
      ..strokeWidth = 2.2;
    for (var i = 0; i < anchors.length; i++) {
      final a = anchors[i];
      final cabinTop = Offset(cabins[i].center.dx, cabins[i].top);
      canvas.drawLine(a, cabinTop, arm);
      canvas.drawCircle(a, 5, wheel);
      canvas.drawCircle(a, 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _CablePainter old) => old.anchors != anchors;
}


/// 引言卡的可拖曳暗區：手指上下拖移動暗區、左右拖調範圍，放開存檔。
/// 暗區畫在 [child]（引言文字）後方，只讓文字那一段變暗襯字。
class _QuoteDarkOverlay extends StatelessWidget {
  const _QuoteDarkOverlay({
    required this.darkY,
    required this.darkRange,
    required this.onChanged,
    required this.onEnd,
    required this.child,
  });

  final double darkY;
  final double darkRange;
  final void Function(double darkY, double darkRange) onChanged;
  final VoidCallback onEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final h = c.maxHeight;
      final w = c.maxWidth;
      // 依 darkY / darkRange 算出漸層：中心處最暗，往兩側淡出
      final center = darkY.clamp(0.06, 0.94);
      final half = (darkRange.clamp(0.12, 0.9)) / 2;
      final top = (center - half).clamp(0.0, 1.0);
      final bot = (center + half).clamp(0.0, 1.0);
      final s1 = (top).clamp(0.0, 1.0);
      final s2 = ((top + center) / 2).clamp(0.0, 1.0);
      final s3 = ((bot + center) / 2).clamp(0.0, 1.0);
      final s4 = (bot).clamp(0.0, 1.0);
      final stops = <double>[0.0, s1, s2, s3, s4, 1.0];
      // 確保遞增
      for (var k = 1; k < stops.length; k++) {
        if (stops[k] < stops[k - 1]) stops[k] = stops[k - 1];
      }
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.0),
                    ],
                    stops: stops,
                  ),
                ),
              ),
            ),
          ),
          child,
          // 透明手勢層：上下拖移動暗區、左右拖調範圍
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (d) {
                final ny = (darkY + d.delta.dy / h).clamp(0.06, 0.94);
                final nr = (darkRange + d.delta.dx / w).clamp(0.12, 0.9);
                onChanged(ny, nr);
              },
              onPanEnd: (_) => onEnd(),
              onPanCancel: onEnd,
            ),
          ),
        ],
      );
    });
  }
}


// ═══════════════════════════════════════════════════════════
// PACER_CARD_VIEW — 一則 pacer 的大卡
//
// 球用繩子吊在上緣（半顆露出），往上提整顆出來，左右拉控制句子浮現。
// 照片可以縮放平移。句子自己帶暗牌，所以底下照片再亮都讀得到。


// ═══════════════════════════════════════════════════════════
// PACER_CARD_VIEW — 一則 pacer 的大卡
//
// 球是支點，纜線穿過它；兩條繩子從球往下吊住這張卡。
// 拖球：左右 → 句子逐字浮現；上下 → 車廂升降。甩它會擺盪幾下才停。
// 照片可以縮放平移。句子自己帶暗牌，底下照片再亮都讀得到。
// ═══════════════════════════════════════════════════════════
class _PacerCardView extends StatefulWidget {
  final Bookmark bookmark;
  final List<Color> bgColors;
  final List<String> bgImages;
  final void Function(Bookmark) onChanged;
  final VoidCallback onEnd;

  const _PacerCardView({
    required this.bookmark,
    required this.bgColors,
    required this.bgImages,
    required this.onChanged,
    required this.onEnd,
  });

  @override
  State<_PacerCardView> createState() => _PacerCardViewState();
}

class _PacerCardViewState extends State<_PacerCardView> {
  double _pull = 0; // 只在這次檢視有意義，不必存進書籤
  // 逐字浮現只在拖曳的當下發生。存起來的卡片一定是完整句子 ——
  // 打開看到空白會以為壞掉了。
  double _t = 1;

  static const double _w = 250;
  static const double _h = 340;

  ImageProvider? get _image {
    final b = widget.bookmark;
    if (b.hasCustomImage) {
      final p = b.customImagePath;
      if (p.startsWith('b64:')) {
        return MemoryImage(base64Decode(p.substring(4)));
      }
      return FileImage(File(p));
    }
    if (b.imageIndex >= 0) {
      return AssetImage(
          widget.bgImages[b.imageIndex.clamp(0, widget.bgImages.length - 1)]);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bookmark;
    final t = _t;

    return LunaCableCar(
      tone: GlassTone
          .values[b.toneIndex.clamp(0, GlassTone.values.length - 1)],
      childWidth: _w,
      childHeight: _h,
      t: t,
      pull: _pull,
      onChanged: (nt, np) => setState(() {
        _t = nt;
        _pull = np;
      }),
      onEnd: widget.onEnd,
      child: _car(b, t),
    );
  }

  Widget _car(Bookmark b, double t) {
    final img = _image;
    // 取當前水晶的最深色階，卡片和球才是一套
    final deep = GlassTone
        .values[b.toneIndex.clamp(0, GlassTone.values.length - 1)]
        .stops
        .last;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: img == null
            ? widget.bgColors[b.colorIndex.clamp(0, widget.bgColors.length - 1)]
            : null,
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: const [
          BoxShadow(
              color: Colors.black38, blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 照片跟著文字一起浮現 —— 拉球的時候整張卡一起醒過來
            if (img != null)
              Opacity(
                opacity: (0.18 + 0.82 * t).clamp(0.0, 1.0),
                child: InteractiveViewer(
                minScale: 1,
                maxScale: 3.5,
                clipBehavior: Clip.none,
                  child: Image(image: img, fit: BoxFit.cover),
                ),
              ),
            // 沒有邊界的染色：從底部往上化開，越上面越透明
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    deep.withAlpha(0x00),
                    deep.withAlpha(0x59),
                    deep.withAlpha(0xC4),
                    deep.withAlpha(0xE0),
                  ],
                  stops: const [0.34, 0.58, 0.84, 1.0],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // NO_PLATE3 沒有底板，靠雙層陰影撐可讀性
                    LunaReveal(
                      text: b.quote,
                      progress: t,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.55,
                        shadows: [
                          Shadow(blurRadius: 12, color: Colors.black87),
                          Shadow(blurRadius: 3, color: Colors.black87),
                        ],
                      ),
                    ),
                    if (b.author.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '\u2014 ${b.author}',
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Color(0xE6FFFFFF),
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black87),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────
// 給推播卡（home_page 的 _DailyCableCard）用。
// 兩邊共用同一份清單，卡片才會長得一模一樣。
// ─────────────────────────────────────────────────────────
const List<Color> kBookmarkBgColors = _bgColors;
const List<String> kBookmarkBgImages = _bgImages;
