// 我的暖話卡 — 存檔記憶（含照片、文字位置、貼圖）
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MyCard {
  final String id;
  final String text;
  final String author;
  final int fontIndex;
  final int bgIndex;
  final double size;
  final String? photoB64;
  final double photoScale;
  final double textX;
  final double textY;
  final int align;
  final List<Map<String, dynamic>> stickers;
  final DateTime createdAt;
  /// Luna Pacer 版型：夜空轉開的程度 0~1。null = 一般卡片。
  final double? orbT;
  MyCard({
    required this.id,
    required this.text,
    required this.author,
    required this.fontIndex,
    required this.bgIndex,
    required this.size,
    required this.createdAt,
    this.photoB64,
    this.photoScale = 1.0,
    this.textX = 0.08,
    this.textY = 0.12,
    this.align = 0,
    this.stickers = const [],
    this.orbT,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'author': author,
        'font': fontIndex,
        'bg': bgIndex,
        'size': size,
        'ts': createdAt.millisecondsSinceEpoch,
        'tx': textX,
        'ty': textY,
        'al': align,
        'stk': stickers,
        'pscale': photoScale,
        if (orbT != null) 'orbT': orbT,
        if (photoB64 != null) 'photo': photoB64,
      };
  factory MyCard.fromJson(Map<String, dynamic> j) => MyCard(
        id: j['id'] as String,
        text: j['text'] as String,
        author: j['author'] as String,
        fontIndex: (j['font'] as num).toInt(),
        bgIndex: (j['bg'] as num).toInt(),
        size: (j['size'] as num).toDouble(),
        photoB64: j['photo'] as String?,
        photoScale: (j['pscale'] as num?)?.toDouble() ?? 1.0,
        textX: (j['tx'] as num?)?.toDouble() ?? 0.08,
        textY: (j['ty'] as num?)?.toDouble() ?? 0.12,
        align: (j['al'] as num?)?.toInt() ?? 0,
        orbT: (j['orbT'] as num?)?.toDouble(),
        stickers: (j['stk'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [],
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((j['ts'] as num).toInt()),
      );
}

class MyCardsStore {
  static const String _key = 'my_cards_v1';

  static Future<List<MyCard>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => MyCard.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(MyCard card) async {
    final list = await load();
    list.add(card);
    await _save(list);
  }

  static Future<void> remove(String id) async {
    final list = await load();
    list.removeWhere((e) => e.id == id);
    await _save(list);
  }

  static Future<void> _save(List<MyCard> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}
