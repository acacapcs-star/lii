import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../l10n/app_language.dart';

class PetSelectionPage extends ConsumerStatefulWidget {
  const PetSelectionPage({super.key});

  @override
  ConsumerState<PetSelectionPage> createState() => _PetSelectionPageState();
}

class _PetSelectionPageState extends ConsumerState<PetSelectionPage> {
  bool _isZh = true;
  String _selectedPet = 'otter';
  final TextEditingController _nameController = TextEditingController();

  final Map<String, Map<String, String>> _pets = {
    'otter': {
      'name_zh': '水獺',
      'name_en': 'Otter',
      'desc_zh': '個性｜看起來在放空，其實什麼都知道\n興趣｜抱愛心漂流、叼魚、對天花板發呆三小時\n面向｜「算了沒關係」的鼻祖，但其實超在意',
      'desc_en': 'Personality | "I\'m fine" energy but processing 47 emotions simultaneously\nInterests | Floating, holding hearts, eating fish at 3am\nVibe | EMOTIONAL DAMAGE but make it soft',
      'image': 'assets/images/otter1.png',
      'bg': 'assets/images/pet_otter_bg.jpeg',
    },
    'capybara': {
      'name_zh': '水豚',
      'name_en': 'Capybara',
      'desc_zh': '個性｜萬年淡定，天塌下來也是這個臉\n興趣｜坐著、繼續坐著、決定不動\n面向｜失敗十次臉不紅心不跳那種',
      'desc_en': 'Personality | Literally unbothered. Scientifically proven.\nInterests | Sitting, sitting with purpose, watching others panic\nVibe | "Is this the real strat?" — does nothing, wins anyway',
      'image': 'assets/images/capy1.png',
      'bg': 'assets/images/pet_capybara_bg.jpeg',
    },
  };

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final name = _nameController.text.trim().isEmpty
        ? (_selectedPet == 'otter'
            ? (_isZh ? '小獺' : 'Otty')
            : (_isZh ? '小豚' : 'Cappy'))
        : _nameController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pet_type', _selectedPet);
    await prefs.setString('pet_name', name);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    _isZh = ref.watch(appLanguageControllerProvider) == AppLanguage.zhTw;
    final pet = _pets[_selectedPet]!;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Image.asset(pet['bg']!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A3558))),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC1A3558), Color(0xDD2C5282)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
              children: [
                const SizedBox(height: 24),
                Text(_isZh ? '選一個夥伴陪你' : 'Choose a companion',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24, fontStyle: FontStyle.italic,
                    color: Colors.white, letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(_isZh ? '牠會一直在' : 'They will always be here', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _pets.keys.map((key) {
                    final isSelected = key == _selectedPet;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedPet = key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Image.asset(_pets[key]!['image']!, width: 80, height: 80, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 60, color: Colors.white)),
                            const SizedBox(height: 8),
                            Text(_isZh ? _pets[key]!['name_zh']! : _pets[key]!['name_en']!,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isZh ? pet['desc_zh']! : pet['desc_en']!,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 18, height: 1.8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(_isZh ? '幫牠取個名字' : 'Give them a name',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                        decoration: InputDecoration(
                          hintText: _selectedPet == 'otter'
                              ? (_isZh ? '小獺' : 'Otty')
                              : (_isZh ? '小豚' : 'Cappy'),
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2C5282),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(_isZh ? '開始吧' : "Let's go", style: GoogleFonts.playfairDisplay(
                            fontSize: 16, fontStyle: FontStyle.italic, letterSpacing: 4)),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}
