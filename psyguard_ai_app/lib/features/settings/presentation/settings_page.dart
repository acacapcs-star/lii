import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/ai_api_client.dart';
import '../../../core/network/ai_error_formatter.dart';
import '../../../core/network/app_config_controller.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/settings/font_scale_provider.dart';
import '../../../core/storage/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_language.dart';
import '../../../core/ers/group_norms.dart';
import '../../../core/security/secret_diary_lock.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const _recommendedBaseUrl = 'https://free.v36.cm';
  static const _recommendedModel = 'gpt-4o-mini';

  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  bool _obscureApiKey = true;
  bool _didSeedFields = false;
  bool _hasManualChanges = false;
  bool _isSaving = false;
  double _ttsSpeechRate = defaultTtsSpeechRate;
  bool _didLoadTtsSpeechRate = false;
  bool _hasPendingTtsSpeechRateChanges = false;
  bool _isSavingTtsSpeechRate = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController.addListener(_markEdited);
    _apiKeyController.addListener(_markEdited);
    _modelController.addListener(_markEdited);
    _loadTtsSpeechRate();
  }

  @override
  void dispose() {
    _baseUrlController.removeListener(_markEdited);
    _apiKeyController.removeListener(_markEdited);
    _modelController.removeListener(_markEdited);
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppConfig>(appConfigProvider, (previous, next) {
      if (!_didSeedFields || !_hasManualChanges) {
        _seedFields(next);
      }
    });

    final config = ref.watch(appConfigProvider);
    final language = ref.watch(appLanguageControllerProvider);
    final copy = _SettingsCopy(language);
    final aiEnabled = config.isConfigured;
    if (!_didSeedFields) {
      _seedFields(config);
    }

    return Scaffold(
      backgroundColor: LumiTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          copy.title,
          style: GoogleFonts.nunitoSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: LumiTheme.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            _sectionTitle(language == AppLanguage.zhTw ? '🎂 年齡' : '🎂 Age'),
            const SizedBox(height: 12),
            _card(child: _ageBandSelector(language == AppLanguage.zhTw)),
            const SizedBox(height: 18),
            _sectionTitle(language == AppLanguage.zhTw ? '🔤 字體大小' : '🔤 Font Size'),
            const SizedBox(height: 12),
            _card(
              child: Consumer(
                builder: (context, r, _) {
                  final current = r.watch(fontScaleProvider);
                  final zh = language == AppLanguage.zhTw;
                  final opts = <List<Object>>[
                    [zh ? '小' : 'S', 0.9],
                    [zh ? '標準' : 'M', 1.0],
                    [zh ? '大' : 'L', 1.15],
                    [zh ? '特大' : 'XL', 1.3],
                  ];
                  return Row(
                    children: [
                      for (final o in opts)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: GestureDetector(
                              onTap: () => r
                                  .read(fontScaleProvider.notifier)
                                  .set(o[1] as double),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: current == (o[1] as double)
                                      ? const Color(0xFF7E8FE8)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  o[0] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: current == (o[1] as double)
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            _sectionTitle(language == AppLanguage.zhTw ? '🚡 每日 Pacer' : '🚡 Daily Pacer'),
            const SizedBox(height: 8),
            _card(child: const _DailyPacerSwitch()),
            const SizedBox(height: 20),
            _sectionTitle(copy.languageSectionTitle),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.languageDescription,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      height: 1.6,
                      color: LumiTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<AppLanguage>(
                    segments: [
                      ButtonSegment<AppLanguage>(
                        value: AppLanguage.english,
                        icon: const Icon(Icons.translate_rounded),
                        label: Text(copy.englishOption),
                      ),
                      ButtonSegment<AppLanguage>(
                        value: AppLanguage.zhTw,
                        icon: const Icon(Icons.language_rounded),
                        label: Text(copy.chineseOption),
                      ),
                    ],
                    selected: {language},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      final selectedLanguage = selection.first;
                      if (selectedLanguage != language) {
                        _saveLanguage(selectedLanguage);
                      }
                    },
                    style: ButtonStyle(
                      textStyle: WidgetStatePropertyAll(
                        GoogleFonts.nunitoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _sectionTitle(copy.aiStatusSectionTitle),
            const SizedBox(height: 12),
            _card(
              child: Row(
                children: [
                  Icon(
                    aiEnabled
                        ? Icons.check_circle_outline_rounded
                        : Icons.offline_bolt_rounded,
                    color: aiEnabled
                        ? const Color(0xFF2E7D32)
                        : LumiTheme.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          aiEnabled ? copy.aiEnabled : copy.aiOffline,
                          style: GoogleFonts.nunitoSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: LumiTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          aiEnabled
                              ? copy.aiStatusDetails(
                                  model: config.model,
                                  isUserProvided: config.isUserProvided,
                                )
                              : copy.aiOfflineDescription,
                          style: GoogleFonts.nunitoSans(
                            fontSize: 13,
                            height: 1.5,
                            color: LumiTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _sectionTitle(copy.aiSettingsSectionTitle),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.aiSettingsDescription,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      height: 1.6,
                      color: LumiTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _baseUrlController,
                    label: 'API Base URL',
                    hint: _recommendedBaseUrl,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _apiKeyController,
                    label: 'API Key',
                    hint: 'sk-...',
                    obscureText: _obscureApiKey,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _obscureApiKey = !_obscureApiKey);
                      },
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _modelController,
                    label: copy.modelFieldLabel,
                    hint: _recommendedModel,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAiSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LumiTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.nunitoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text(
                        _isSaving ? copy.saving : copy.saveAiSettings,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _clearAiSettings,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LumiTheme.textPrimary,
                        side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.1),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.nunitoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(copy.clearAiSettings),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _sectionTitle(copy.voiceSectionTitle),
            const SizedBox(height: 12),
            _card(
              child: _didLoadTtsSpeechRate
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.voiceDescription,
                          style: GoogleFonts.nunitoSans(
                            fontSize: 13,
                            height: 1.6,
                            color: LumiTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              copy.currentSpeechRate,
                              style: GoogleFonts.nunitoSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: LumiTheme.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_describeTtsSpeechRate(_ttsSpeechRate, copy)} (${_ttsSpeechRate.toStringAsFixed(2)})',
                              style: GoogleFonts.nunitoSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: LumiTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _ttsSpeechRate,
                          min: minTtsSpeechRate,
                          max: maxTtsSpeechRate,
                          divisions:
                              ((maxTtsSpeechRate - minTtsSpeechRate) / 0.05)
                                  .round(),
                          label: _ttsSpeechRate.toStringAsFixed(2),
                          activeColor: LumiTheme.primary,
                          inactiveColor: LumiTheme.primary.withValues(
                            alpha: 0.18,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _ttsSpeechRate = normalizeTtsSpeechRate(value);
                              _hasPendingTtsSpeechRateChanges = true;
                            });
                          },
                        ),
                        Row(
                          children: [
                            Text(
                              copy.slower,
                              style: GoogleFonts.nunitoSans(
                                fontSize: 12,
                                color: LumiTheme.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              copy.faster,
                              style: GoogleFonts.nunitoSans(
                                fontSize: 12,
                                color: LumiTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed:
                                _isSavingTtsSpeechRate ||
                                    !_hasPendingTtsSpeechRateChanges
                                ? null
                                : _saveTtsSpeechRate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LumiTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: GoogleFonts.nunitoSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: Text(
                              _isSavingTtsSpeechRate
                                  ? copy.saving
                                  : copy.saveVoiceSettings,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 18),
            _sectionTitle(
                language == AppLanguage.zhTw ? '🔔 提醒方式' : '🔔 Alerts'),
            const SizedBox(height: 12),
            _card(
              child: StatefulBuilder(
                builder: (localCtx, setLocal) =>
                    FutureBuilder<SharedPreferences>(
                  future: SharedPreferences.getInstance(),
                  builder: (fCtx, snap) {
                    final p = snap.data;
                    final on = p?.getBool('alerts_red_enabled') ?? true;
                    final zh = language == AppLanguage.zhTw;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: on,
                          onChanged: p == null
                              ? null
                              : (v) async {
                                  if (!v) {
                                    final ok = await showDialog<bool>(
                                      context: localCtx,
                                      builder: (dCtx) => AlertDialog(
                                        title: Text(zh
                                            ? '關掉紅色等級？'
                                            : 'Turn off the red tier?'),
                                        content: Text(zh
                                            ? '關掉之後，等級最多顯示到黃色，lii 也不會自己打開求助流程。\n\n'
                                              '分數本身還是會照常記錄，求助資源頁也一直都在選單裡，你隨時點得進去。\n\n'
                                              '只是那一刻，沒有人會先開口。'
                                            : 'With this off, the tier stops at amber and lii will not '
                                              'open the safety flow by itself.\n\n'
                                              'Your scores are still recorded, and the help page stays in '
                                              'the menu for you to open any time.\n\n'
                                              'It only means that in that moment, nothing will speak first.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dCtx, false),
                                            child: Text(
                                                zh ? '維持開啟' : 'Keep it on'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dCtx, true),
                                            child:
                                                Text(zh ? '關掉' : 'Turn off'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok != true) return;
                                  }
                                  await p.setBool('alerts_red_enabled', v);
                                  setLocal(() {});
                                },
                          title: Text(
                            zh
                                ? '顯示紅色風險等級'
                                : 'Show the red risk tier',
                            style: GoogleFonts.nunitoSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: LumiTheme.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          zh
                              ? '分數到 70 以上時顯示紅色，並直接把求助流程打開。'
                                '關掉的話等級最多到黃色 —— 分數照常記錄，'
                                '求助資源頁也一直在選單裡，隨時點得進去。'
                              : 'Above 70 the tier turns red and lii opens the safety flow for you. '
                                'With this off the tier stops at amber — scores are still recorded, '
                                'and the help page stays in the menu at all times.',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 13,
                            height: 1.6,
                            color: LumiTheme.textSecondary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 28),
            _sectionTitle(copy.dataPrivacySectionTitle),
            const SizedBox(height: 12),
            _card(
              child: Text(
                copy.dataPrivacyDescription,
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  height: 1.6,
                  color: LumiTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _sectionTitle(language == AppLanguage.zhTw
                ? '🔒 秘密日記'
                : '🔒 Secret Diary'),
            const SizedBox(height: 12),
            _card(child: _autoLockSelector(language == AppLanguage.zhTw)),
            const SizedBox(height: 18),
            // ── DEMO 用 · 只在 debug 模式出現，release 版自動消失 ──
            if (kDebugMode) ...[
              _sectionTitle(language == AppLanguage.zhTw
                  ? '🎬 Demo 工具（僅 debug）'
                  : '🎬 Demo tools (debug only)'),
              const SizedBox(height: 12),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language == AppLanguage.zhTw
                          ? '清除 ERS 平滑歷史'
                          : 'Clear ERS smoothing history',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: LumiTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      language == AppLanguage.zhTw
                          ? 'ERS 會取最近 3 次的平均，所以之前測試的分數會把新分數拉低。'
                            '清掉之後，下一次 check-in 就是單獨計分。'
                            '只影響平滑用的暫存，不會刪日記、心情紀錄或睡眠資料。'
                          : 'ERS averages the last 3 scores, so earlier test runs pull new '
                            'scores down. Clearing this makes the next check-in count on its own. '
                            'Only the smoothing cache is removed — diaries, moods and sleep logs stay.',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        height: 1.6,
                        color: LumiTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () async {
                          final zh = language == AppLanguage.zhTw;
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(zh
                                  ? '清除 ERS 平滑歷史？'
                                  : 'Clear ERS smoothing history?'),
                              content: Text(zh
                                  ? '下一次 check-in 會單獨計分，儀表板的趨勢圖也會少掉這幾點。'
                                  : 'The next check-in will be scored on its own, and those '
                                    'points will disappear from the dashboard trend.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(zh ? '取消' : 'Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(zh ? '清除' : 'Clear'),
                                ),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('ers_recent');
                          await prefs.remove('last_ers_level');
                          await prefs.remove('last_ers_score');
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(zh
                                  ? '已清除。回首頁前先滑掉重進，畫面才會更新。'
                                  : 'Cleared. Reopen the app for the home screen to refresh.'),
                            ),
                          );
                        },
                        child: Text(
                          language == AppLanguage.zhTw
                              ? '清除'
                              : 'Clear',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                child: StatefulBuilder(
                  builder: (localCtx, setLocal) =>
                      FutureBuilder<SharedPreferences>(
                    future: SharedPreferences.getInstance(),
                    builder: (fCtx, snap) {
                      final p = snap.data;
                      final on =
                          p?.getBool('demo_skip_ers_smoothing') ?? false;
                      final zh = language == AppLanguage.zhTw;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: on,
                            onChanged: p == null
                                ? null
                                : (v) async {
                                    await p.setBool(
                                        'demo_skip_ers_smoothing', v);
                                    setLocal(() {});
                                  },
                            title: Text(
                              zh
                                  ? '跳過 ERS 平滑（錄影用）'
                                  : 'Skip ERS smoothing (for filming)',
                              style: GoogleFonts.nunitoSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: LumiTheme.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            zh
                                ? '平常 ERS 會取最近 3 次平均，避免有人只是今天狀態差就被丟進紅色警報。'
                                  '打開這個開關之後，等級只看這一次的分數，紅燈會立刻成立。'
                                  '錄完請關掉。'
                                : 'Normally ERS averages the last 3 scores, so nobody is thrown into a '
                                  'red alert over one bad day. With this on, the tier follows this '
                                  'check-in alone and red can trigger immediately. Turn it off after filming.',
                            style: GoogleFonts.nunitoSans(
                              fontSize: 13,
                              height: 1.6,
                              color: LumiTheme.textSecondary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
            _sectionTitle(copy.resetSectionTitle),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.clearLocalDataTitle,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: LumiTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.clearLocalDataDescription,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      height: 1.6,
                      color: LumiTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text(copy.clearConfirmTitle),
                              content: Text(copy.clearConfirmContent),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(copy.cancel),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(copy.clear),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmed != true) {
                          return;
                        }

                        final db = ref.read(appDatabaseProvider);
                        final settings = ref.read(localSettingsServiceProvider);
                        await db.clearAllData();
                        await settings.clearAll();
                        await ref
                            .read(appLanguageControllerProvider.notifier)
                            .setLanguage(AppLanguage.english);
                        ref.invalidate(welcomeSeenProvider);
                        ref.invalidate(consentAcceptedProvider);
                        if (context.mounted) {
                          context.go('/welcome');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB00020),
                        side: const BorderSide(color: Color(0xFFB00020)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.nunitoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text(copy.clearDataButton),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // 🧪 加密自我測試（確認沒問題後可以整段刪掉）
  // ═══════════════════════════════════════════════════
  Future<void> _runCryptoSelfTest(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('🧪 測試加密'),
        content: const Text(
          '這會重設秘密日記的金鑰與密碼。\n\n'
          '如果你已經寫過真的秘密日記，跑下去就再也打不開了。\n\n'
          '確定要測嗎？',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確定測試'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, bool> results;
    try {
      results = await SecretDiaryLock.selfTest();
    } catch (e) {
      results = {'整個炸掉：$e': false};
    }

    if (!context.mounted) return;
    Navigator.pop(context); // 關掉轉圈圈

    final passed = results.values.where((v) => v).length;
    final total = results.length;
    final allPassed = passed == total && total > 0;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(allPassed ? '✅ 全部通過 ($passed/$total)' : '❌ 有問題 ($passed/$total)'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...results.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '${e.value ? "✅" : "❌"}  ${e.key}',
                        style: TextStyle(
                          fontSize: 13,
                          color: e.value
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                        ),
                      ),
                    )),
                const SizedBox(height: 12),
                Text(
                  allPassed
                      ? '加密運作正常，可以開始寫秘密日記了。記得回來把這顆測試按鈕拿掉。'
                      : '請把這個畫面截圖回報，先不要寫真的秘密日記。',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7A8FA6)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  // ⏱️ 秘密日記什麼時候自動上鎖
  Widget _autoLockSelector(bool isZh) {
    return FutureBuilder<AutoLockPolicy>(
      future: SecretDiaryLock.instance.loadPolicy(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final current = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isZh ? '自動上鎖時機' : 'Auto-lock',
              style: GoogleFonts.nunitoSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: LumiTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isZh
                  ? '解鎖後金鑰會留在記憶體裡，這裡決定什麼時候清掉'
                  : 'The key stays in memory after unlocking. This decides when to clear it.',
              style: GoogleFonts.nunitoSans(
                fontSize: 12,
                color: LumiTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...AutoLockPolicy.values.map(
              (p) => RadioListTile<AutoLockPolicy>(
                value: p,
                groupValue: current,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF8B6FBF),
                title: Text(
                  p.labelFor(isZh),
                  style: GoogleFonts.nunitoSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: LumiTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  p.hintFor(isZh),
                  style: GoogleFonts.nunitoSans(
                    fontSize: 11,
                    color: LumiTheme.textSecondary,
                  ),
                ),
                onChanged: (v) async {
                  if (v == null) return;
                  await SecretDiaryLock.instance.setPolicy(v);
                  if (mounted) setState(() {});
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // 🎂 年齡層（趨勢圖團體對比要用來對到同齡人常模）
  Widget _ageBandSelector(bool isZh) {
    return FutureBuilder<AgeBand?>(
      future: AgeBandStore.get(),
      builder: (context, snap) {
        final current = snap.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isZh ? '你的年齡層' : 'Your age group',
              style: GoogleFonts.nunitoSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: LumiTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isZh
                  ? '用來在趨勢圖裡跟同齡人的研究常模做對比'
                  : 'Used to compare your trends with peer research norms',
              style: GoogleFonts.nunitoSans(
                fontSize: 12,
                color: LumiTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AgeBand.values.map((b) {
                final on = b == current;
                return GestureDetector(
                  onTap: () async {
                    await AgeBandStore.set(b);
                    if (mounted) setState(() {});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: on
                          ? LumiTheme.primary
                          : LumiTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: on
                            ? LumiTheme.primary
                            : Colors.grey.withValues(alpha: 0.25),
                        width: 1.4,
                      ),
                    ),
                    child: Text(
                      b.labelFor(isZh),
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white : LumiTheme.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (current == null) ...[
              const SizedBox(height: 10),
              Text(
                isZh
                    ? '⚠️ 尚未選擇，團體對比會用預設族群'
                    : '⚠️ Not set yet — group comparison uses a default',
                style: GoogleFonts.nunitoSans(
                  fontSize: 11,
                  color: const Color(0xFFE0863A),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.nunitoSans(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: LumiTheme.textPrimary,
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: LumiTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF8F7FB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.black.withValues(alpha: 0.06),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: LumiTheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveAiSettings() async {
    final copy = _SettingsCopy(ref.read(appLanguageControllerProvider));
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final model = _modelController.text.trim();

    // 將原本的 if 判斷式註解掉，或者直接改成永遠不成立
    // if (baseUrl.isEmpty || apiKey.isEmpty) {
    //   _showMessage(copy.missingApiFields);
    //   return;
    // }
    
    // 現在強制讓程式往下執行，不再驗證欄位是否為空

    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      _showMessage(copy.invalidBaseUrl);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(appConfigProvider.notifier);
      final nextConfig = notifier.previewUserConfig(
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
      );

      await validateOpenAiCompatibleConfig(nextConfig);
      await ref
          .read(appConfigProvider.notifier)
          .saveUserConfig(baseUrl: baseUrl, apiKey: apiKey, model: model);
      await ref.read(appDatabaseProvider).cleanupLocalOnlyAiArtifacts();
      _hasManualChanges = false;
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).clearSnackBars();
      _showMessage(copy.aiSettingsSaved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).clearSnackBars();
      _showMessage(copy.aiSettingsNotSaved(userFacingAiError(error)));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _clearAiSettings() async {
    final copy = _SettingsCopy(ref.read(appLanguageControllerProvider));
    setState(() => _isSaving = true);
    try {
      await ref.read(appConfigProvider.notifier).clearUserConfig();
      final config = ref.read(appConfigProvider);
      _seedFields(config);
      _showMessage(copy.aiSettingsCleared);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _saveLanguage(AppLanguage language) async {
    await ref
        .read(appLanguageControllerProvider.notifier)
        .setLanguage(language);
    if (!mounted) {
      return;
    }
    final copy = _SettingsCopy(language);
    ScaffoldMessenger.of(context).clearSnackBars();
    _showMessage(copy.languageSaved);
  }

  Future<void> _loadTtsSpeechRate() async {
    double speechRate = defaultTtsSpeechRate;
    try {
      speechRate = await ref
          .read(localSettingsServiceProvider)
          .getTtsSpeechRate();
    } catch (_) {
      // 網頁版等不支援時用預設值，避免整頁崩潰（黑屏）
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _ttsSpeechRate = speechRate;
      _didLoadTtsSpeechRate = true;
      _hasPendingTtsSpeechRateChanges = false;
    });
  }

  Future<void> _saveTtsSpeechRate() async {
    final copy = _SettingsCopy(ref.read(appLanguageControllerProvider));
    setState(() => _isSavingTtsSpeechRate = true);
    try {
      final normalizedValue = normalizeTtsSpeechRate(_ttsSpeechRate);
      await ref
          .read(localSettingsServiceProvider)
          .setTtsSpeechRate(normalizedValue);
      ref.invalidate(ttsSpeechRateProvider);
      if (!mounted) {
        return;
      }
      setState(() {
        _ttsSpeechRate = normalizedValue;
        _hasPendingTtsSpeechRateChanges = false;
      });
      _showMessage(copy.voiceSettingsSaved);
    } finally {
      if (mounted) {
        setState(() => _isSavingTtsSpeechRate = false);
      }
    }
  }

  void _seedFields(AppConfig config) {
    _baseUrlController.text = _defaultBaseUrlFor(config);
    _apiKeyController.text = config.isUserProvided ? config.apiKey : '';
    _modelController.text = _defaultModelFor(config);
    _didSeedFields = true;
    _hasManualChanges = false;
  }

  void _markEdited() {
    if (_didSeedFields && !_isSaving) {
      _hasManualChanges = true;
    }
  }

  String _describeTtsSpeechRate(double value, _SettingsCopy copy) {
    if (value <= 0.45) {
      return copy.slower;
    }
    if (value >= 0.8) {
      return copy.faster;
    }
    return copy.standard;
  }

  String _defaultBaseUrlFor(AppConfig config) {
    if (config.isUserProvided || config.isConfigured) {
      return config.baseUrl;
    }
    return _recommendedBaseUrl;
  }

  String _defaultModelFor(AppConfig config) {
    if (config.isUserProvided || config.isConfigured) {
      return config.model;
    }
    return _recommendedModel;
  }
}

class _SettingsCopy {
  const _SettingsCopy(this.language);

  final AppLanguage language;

  bool get _isZhTw => language == AppLanguage.zhTw;

  String get title => _isZhTw ? '設定' : 'Settings';
  String get languageSectionTitle => _isZhTw ? '語言' : 'Language';
  String get languageDescription => _isZhTw
      ? '選擇 App 顯示語言與 AI 回覆語言。預設語言為英文，變更後會立即套用。'
      : 'Choose the app display language and AI reply language. English is the default and changes apply immediately.';
  String get englishOption => _isZhTw ? '英文' : 'English';
  String get chineseOption => _isZhTw ? '中文' : 'Chinese';
  String get languageSaved => _isZhTw ? '語言已更新' : 'Language updated';

  String get aiStatusSectionTitle => _isZhTw ? 'AI 狀態' : 'AI Status';
  String get aiEnabled => _isZhTw ? '已啟用 AI 串接' : 'AI connection enabled';
  String get aiOffline =>
      _isZhTw ? '離線模式（未設定 API Key）' : 'Offline mode (no API key)';
  String get aiOfflineDescription => _isZhTw
      ? '目前聊天會使用示範回覆；完成下方 AI 設定後，聊天與分析功能都會改用你提供的服務。'
      : 'Chats currently use demo replies. After you complete the AI settings below, chat and analysis will use your configured service.';
  String aiStatusDetails({
    required String model,
    required bool isUserProvided,
  }) {
    if (_isZhTw) {
      return '模型：$model\n來源：${isUserProvided ? '使用者自訂設定' : '環境變數'}';
    }
    return 'Model: $model\nSource: ${isUserProvided ? 'User settings' : 'Environment variables'}';
  }

  String get aiSettingsSectionTitle => _isZhTw ? 'AI 設定' : 'AI Settings';
  String get aiSettingsDescription => _isZhTw
      ? '你可以自行提供 OpenAI 相容 API 的 Base URL、API Key 與模型名稱。為了方便測試，已預設帶入 free_chatgpt_api 建議的 Base URL 與 gpt-4o-mini；你只需要填入 API Key。儲存後，整個 App 的 AI 對話與趨勢分析都會使用這組設定。'
      : 'You can provide an OpenAI-compatible Base URL, API key, and model name. For easier testing, the recommended free_chatgpt_api Base URL and gpt-4o-mini are prefilled, so you only need to enter an API key. After saving, AI chat and trend analysis will use this configuration.';
  String get modelFieldLabel => _isZhTw ? '模型' : 'Model';
  String get saving => _isZhTw ? '儲存中...' : 'Saving...';
  String get saveAiSettings => _isZhTw ? '儲存 AI 設定' : 'Save AI Settings';
  String get clearAiSettings => _isZhTw ? '清除 AI 設定' : 'Clear AI Settings';
  String get missingApiFields => _isZhTw
      ? '請先填寫 API Base URL 與 API Key'
      : 'Enter the API Base URL and API key first';
  String get invalidBaseUrl =>
      _isZhTw ? 'API Base URL 格式不正確' : 'The API Base URL format is invalid';
  String get aiSettingsSaved => _isZhTw
      ? 'AI 設定已儲存，並已通過連線測試；聊天與分析會立即使用新設定'
      : 'AI settings saved and connection test passed. Chat and analysis will use the new settings immediately.';
  String aiSettingsNotSaved(String error) =>
      _isZhTw ? 'AI 設定未儲存：$error' : 'AI settings were not saved: $error';
  String get aiSettingsCleared => _isZhTw
      ? '已清除自訂 AI 設定，系統會回到目前預設模式'
      : 'Custom AI settings cleared. The app will return to the current default mode.';

  String get voiceSectionTitle => _isZhTw ? '語音設定' : 'Voice Settings';
  String get voiceDescription => _isZhTw
      ? '調整 AI 回覆朗讀速度。儲存後，聊天頁的語音播放會立即套用新的語速。'
      : 'Adjust the read-aloud speed for AI replies. After saving, the chat page will use the new speed immediately.';
  String get currentSpeechRate => _isZhTw ? '目前語速' : 'Current speed';
  String get slower => _isZhTw ? '較慢' : 'Slower';
  String get faster => _isZhTw ? '較快' : 'Faster';
  String get standard => _isZhTw ? '標準' : 'Standard';
  String get saveVoiceSettings => _isZhTw ? '儲存語音設定' : 'Save Voice Settings';
  String get voiceSettingsSaved =>
      _isZhTw ? '語音播放速度已更新' : 'Voice playback speed updated';

  String get dataPrivacySectionTitle => _isZhTw ? '資料與隱私' : 'Data and Privacy';
  String get dataPrivacyDescription => _isZhTw
      ? '第一版資料只儲存在本機（SQLite）。你可以隨時在這裡清除資料。\n若你之後自行設定 API Key，聊天內容可能會送到第三方 AI 服務進行生成回覆。'
      : 'In this first version, data is stored locally in SQLite. You can clear it here at any time.\nIf you later configure your own API key, chat content may be sent to a third-party AI service to generate replies.';

  String get resetSectionTitle => _isZhTw ? '重置' : 'Reset';
  String get clearLocalDataTitle => _isZhTw ? '清除本機資料' : 'Clear Local Data';
  String get clearLocalDataDescription => _isZhTw
      ? '將刪除所有聊天、日記、睡眠、趨勢、AI 報告與設定（包含同意狀態）。此操作無法復原。'
      : 'This deletes all chats, notes, sleep records, trends, AI reports, and settings, including consent status. This cannot be undone.';
  String get clearConfirmTitle => _isZhTw ? '確認清除？' : 'Confirm Clear?';
  String get clearConfirmContent =>
      _isZhTw ? '確定要清除所有本機資料與設定嗎？' : 'Clear all local data and settings?';
  String get cancel => _isZhTw ? '取消' : 'Cancel';
  String get clear => _isZhTw ? '清除' : 'Clear';
  String get clearDataButton => _isZhTw ? '清除資料' : 'Clear Data';
}

class _DailyPacerSwitch extends StatefulWidget {
  const _DailyPacerSwitch();
  @override
  State<_DailyPacerSwitch> createState() => _DailyPacerSwitchState();
}

class _DailyPacerSwitchState extends State<_DailyPacerSwitch> {
  bool _on = true;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _on = p.getBool('daily_pacer_on') ?? true;
        _ready = true;
      });
    });
  }

  Future<void> _set(bool v) async {
    setState(() => _on = v);
    final p = await SharedPreferences.getInstance();
    await p.setBool('daily_pacer_on', v);
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return SwitchListTile(
      value: _on,
      onChanged: _ready ? _set : null,
      contentPadding: EdgeInsets.zero,
      title: Text(zh ? '每天拿一則出來' : 'Bring one back each day',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(
        zh ? '每天第一次打開時，Luna 會拿一則你存過的話出來。' : 'Luna brings back one saved line each day.',
        style: const TextStyle(fontSize: 12.5, height: 1.6),
      ),
    );
  }
}
