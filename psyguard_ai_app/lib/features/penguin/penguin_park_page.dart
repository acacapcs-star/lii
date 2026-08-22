import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_language.dart';
import '../../core/security/local_settings_service.dart';
import 'joke_data.dart';

class PenguinParkPage extends ConsumerStatefulWidget {
  const PenguinParkPage({super.key});
  @override
  ConsumerState<PenguinParkPage> createState() => _PenguinParkPageState();
}

class _PenguinParkPageState extends ConsumerState<PenguinParkPage>
    with TickerProviderStateMixin {
  int _xp = 0;
  int _skin = 0;
  String _petType = 'otter';
  String _petName = 'Luna';
  bool _isZh = true;
  bool _showFish = false;
  bool _showShy = false;
  String _message = '';

  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  final _random = Random();
  Map<String, dynamic>? _currentJoke;
  bool _jokeAnswerShown = false;

  static const _skinLabelsZh = ['原味', '二號', '三號', '四號', '五號'];
  static const _skinLabelsEn = ['Classic', 'No.2', 'No.3', 'No.4', 'No.5'];
  List<String> get _skinLabels => _isZh ? _skinLabelsZh : _skinLabelsEn;

  String _petEmoji() {
    switch (_petType) {
      case 'otter': return '🦦';
      case 'capybara': return '🦫';
      default: return '🦦';
    }
  }
  String _shyImage() {
    switch (_petType) {
      case 'otter':    return 'assets/images/shy_otter.jpeg';
      case 'capybara': return 'assets/images/shy_capybara.jpeg';
      default:         return 'assets/images/shy_otter.jpeg';
    }
  }

  String _shyTextZh() {
    switch (_petType) {
      case 'otter': return '人家快被你摸融化惹 >///<';
      default:        return '哎呀>///<被摸摸，好害羞捏';
    }
  }

  String _shyTextEn() {
    switch (_petType) {
      case 'otter': return "I'm melting from your touch~ >///<";
      default:        return 'awww love it>///<';
    }
  }

  String _bgImage() {
  switch (_petType) {
    case 'otter':    return 'assets/images/bg_otter.jpeg';
    case 'capybara': return 'assets/images/bg_capybara.jpeg';
    default:         return 'assets/images/bg_otter.jpeg';
  }
}
  String _animalImage(String type, int skin) {
    final n = (skin.clamp(0, 3)) + 2; // 首頁用 otter1/capy1，樂園用 2-5
    switch (type) {
      case 'capybara': return 'assets/images/capy$n.png';
      default:         return 'assets/images/otter$n.png';
    }
  }

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut));
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _xp      = prefs.getInt('lumi_xp')    ?? 0;
      _skin    = prefs.getInt('lumi_skin')   ?? 0;
      _petType = prefs.getString('pet_type') ?? 'otter';
      _petName = prefs.getString('pet_name') ?? 'Luna';
    });
  }

  Future<void> _saveXp()   async => (await SharedPreferences.getInstance()).setInt('lumi_xp', _xp);
  Future<void> _saveSkin() async => (await SharedPreferences.getInstance()).setInt('lumi_skin', _skin);

  void _bounce() {
    _bounceCtrl.forward().then((_) => _bounceCtrl.reverse());
  }

  void _feedFish() {
    setState(() {
      _showFish = true;
      _xp += 5;
      _message = _isZh ? '$_petName 開心地吃掉了魚！+5 XP 🐟' : '$_petName happily ate the fish! +5 XP 🐟';
    });
    _bounce();
    _saveXp();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showFish = false);
    });
  }

  void _pet() {
    setState(() {
      _xp += 2;
      _showShy = true;
      _message = '';
    });
    _bounce();
    _saveXp();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showShy = false);
    });
  }

  void _newJoke() {
    setState(() {
      _currentJoke = JokeData.jokes[_random.nextInt(JokeData.jokes.length)];
      _jokeAnswerShown = false;
      _message = '';
    });
  }

  void _showAnswer() {
    setState(() {
      _jokeAnswerShown = true;
      _xp += 1;
      final petLabelZh = _petType == "otter" ? "水獺" : _petType == "capybara" ? "卡皮巴拉" : "水獺";
      final petLabelEn = _petType == "otter" ? "otter" : _petType == "capybara" ? "capybara" : "otter";
      _message = JokeData.lazyResponse(
        _random.nextInt(4),
        isZh: _isZh,
        petNameZh: petLabelZh,
        petNameEn: petLabelEn,
      );
    });
    _saveXp();
  }

  void _showCostumePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_isZh ? '幫 $_petName 換造型 👗' : "Change $_petName's Outfit 👗",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_petType == 'otter' || _petType == 'capybara' ? 4 : 5, (i) {
                final selected = _skin == i;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _skin = i;
                      _xp += 1;
                      _message = _isZh ? '換上造型 ${i + 1}！+1 XP ✨' : 'Outfit ${i + 1} equipped! +1 XP ✨';
                    });
                    _saveSkin();
                    _saveXp();
                    Navigator.pop(ctx);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF0ABFBC)
                                : Colors.grey.shade300,
                            width: selected ? 3 : 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            _animalImage(_petType, i),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.pets, size: 32),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(_skinLabels[i],
                          style: TextStyle(
                              fontSize: 10,
                              color: selected
                                  ? const Color(0xFF0ABFBC)
                                  : Colors.grey)),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🌐 語言跟 App 其他頁面共用同一個來源，切換時這頁會自動重建
    _isZh = ref.watch(appLanguageControllerProvider) == AppLanguage.zhTw;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => context.go('/home'),
        ),
        title: Text(_isZh ? '$_petName 的樂園 🏝' : "$_petName's Park 🏝",
            style: const TextStyle(color: Colors.white)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0ABFBC).withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF0ABFBC)),
            ),
            child: Text('⭐ $_xp XP',
                style: const TextStyle(
                    color: Color(0xFF0ABFBC), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(_bgImage()),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
        child: Column(
          children: [
            // ── 按鈕（上方）───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionBtn(icon: '🐟', label: _isZh ? '丟魚' : 'Feed', onTap: _feedFish),
                  _ActionBtn(icon: '😂', label: _isZh ? '出題' : 'Joke', onTap: _newJoke),
                  _ActionBtn(icon: '👗', label: _isZh ? '換造型' : 'Outfit', onTap: _showCostumePicker),
                ],
              ),
            ),

            // ── 主角動物 ───────────────────────────────────────
            GestureDetector(
              onTap: _pet,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ScaleTransition(
                      scale: _bounceAnim,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D3B5E),
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          _animalImage(_petType, _skin),
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Text(
                              _petEmoji(), style: const TextStyle(fontSize: 100)),
                        ),
                      ),
                    ),
                    if (_showFish)
                      const Positioned(
                        top: 10, right: 10,
                        child: Text('🐟', style: TextStyle(fontSize: 40)),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── 害羞泡泡 ───────────────────────────────────────
            if (_showShy)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(_shyImage(), width: 60, height: 60, fit: BoxFit.contain),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _isZh ? _shyTextZh() : _shyTextEn(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),

            // ── 訊息 ───────────────────────────────────────────
            if (_message.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(_message,
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    textAlign: TextAlign.center),
              ),

            // ── 笑話 ───────────────────────────────────────────
            if (_currentJoke != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text("Q: ${_isZh ? _currentJoke!['q_zh'] : _currentJoke!['q_en']}",
                        style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    if (_jokeAnswerShown) ...[
                      const SizedBox(height: 6),
                      Text("A: ${_isZh ? _currentJoke!['a_zh'] : _currentJoke!['a_en']}",
                          style: const TextStyle(
                              color: Color(0xFF0A7A6B),
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    ] else
                      TextButton(
                        onPressed: _showAnswer,
                        child: Text(_isZh ? '直接看答案 😅' : 'Just show me 😅',
                            style: TextStyle(color: Color(0xFF0A7A6B))),
                      ),
                  ],
                ),
              ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_isZh ? '點擊 $_petName 可以摸摸牠 💙' : 'Tap $_petName to give some pets 💙',
                  style: const TextStyle(color: Colors.black45, fontSize: 12)),
            ),
          ],
        ),
      ),
        ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Color(0xFF3B4668), fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
