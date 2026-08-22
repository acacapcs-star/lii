import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../l10n/app_language.dart';
import '../../../core/security/local_settings_service.dart';

/// API 用量頁 — 顯示個人 API key 的估算用量與花費（可自訂單價）。
/// token 依文字長度估算，實際以供應商帳單為準。
class ApiUsagePage extends ConsumerStatefulWidget {
  const ApiUsagePage({super.key});

  @override
  ConsumerState<ApiUsagePage> createState() => _ApiUsagePageState();
}

class _ApiUsagePageState extends ConsumerState<ApiUsagePage> {
  int _requests = 0;
  int _tokens = 0;
  double _pricePer1m = 0;
  bool _loaded = false;
  final TextEditingController _priceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _requests = prefs.getInt('api_usage_requests') ?? 0;
      _tokens = prefs.getInt('api_usage_tokens') ?? 0;
      _pricePer1m = prefs.getDouble('api_usage_price_per_1m') ?? 0;
      _priceCtrl.text = _pricePer1m == 0 ? '' : _pricePer1m.toString();
      _loaded = true;
    });
  }

  Future<void> _savePrice(String v) async {
    final p = double.tryParse(v.trim()) ?? 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('api_usage_price_per_1m', p);
    if (mounted) setState(() => _pricePer1m = p);
  }

  Future<void> _reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('api_usage_requests', 0);
    await prefs.setInt('api_usage_tokens', 0);
    if (mounted) setState(() {
      _requests = 0;
      _tokens = 0;
    });
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zh = ref.watch(appLanguageControllerProvider) == AppLanguage.zhTw;
    final cost = _tokens / 1000000.0 * _pricePer1m;
    const teal = Color(0xFF0ABFBC);

    Widget bigCard(String label, String value, IconData icon, Color c) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(icon, color: c, size: 26),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF7A8896))),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w600, color: c)),
          ]),
        ]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(zh ? 'API 用量' : 'API Usage'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF22343A),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                bigCard(zh ? '總請求次數' : 'Total requests', '$_requests',
                    Icons.send_rounded, teal),
                bigCard(zh ? '估算 tokens' : 'Estimated tokens', '$_tokens',
                    Icons.token_rounded, const Color(0xFF9B5DE5)),
                // 自訂單價
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF3F7FC),
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            zh
                                ? '自訂單價（每 100 萬 tokens 的價格）'
                                : 'Custom price (per 1M tokens)',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF7A8896))),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            prefixText: '\$ ',
                            hintText: zh ? '例如 0.5' : 'e.g. 0.5',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          onChanged: _savePrice,
                        ),
                      ]),
                ),
                bigCard(zh ? '估算花費' : 'Estimated cost',
                    '\$${cost.toStringAsFixed(4)}', Icons.payments_rounded,
                    const Color(0xFFE8833A)),
                const SizedBox(height: 8),
                Text(
                    zh
                        ? '⚠️ token 依文字長度估算，實際用量與費用以你的 API 供應商帳單為準。'
                        : '⚠️ Tokens are estimated from text length. Actual usage and cost follow your API provider\u2019s bill.',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9AA5B1), height: 1.5)),
                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.restart_alt_rounded,
                        color: Color(0xFFD14343)),
                    label: Text(zh ? '歸零紀錄' : 'Reset',
                        style: const TextStyle(color: Color(0xFFD14343))),
                  ),
                ),
              ],
            ),
    );
  }
}
