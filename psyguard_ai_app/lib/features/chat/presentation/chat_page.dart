import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import '../../../core/ers/speech_metrics.dart';
import '../../ers/incongruence_detector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/network/ai_chat_repository.dart';
import '../../../core/network/ai_local_messages.dart';
import '../../../core/risk_engine/risk_models.dart';
import '../../../core/risk_engine/risk_provider.dart';
import '../../../core/security/local_settings_service.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/database_provider.dart';
import '../../../l10n/app_language.dart';
import '../../../l10n/app_strings.dart';

final chatSessionIdProvider = FutureProvider<String>((ref) async {
  final db = ref.read(appDatabaseProvider);
  return db.ensureDefaultSession();
});

final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) async* {
  final sessionId = await ref.watch(chatSessionIdProvider.future);
  yield* ref.read(appDatabaseProvider).watchSessionMessages(sessionId);
});

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

enum _TtsPlaybackState { stopped, playing, paused }

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final SpeechMetricsCollector _voiceMetrics = SpeechMetricsCollector();
  final FlutterTts _tts = FlutterTts();
  bool _isSending = false;
  bool _voiceInitialized = false;
  bool _speechReady = false;
  bool _isListening = false;
  _TtsPlaybackState _ttsPlaybackState = _TtsPlaybackState.stopped;
  int? _activeTtsMessageId;
  String? _activeTtsText;
  int _ttsProgressOffset = 0;
  int _ttsSegmentStartOffset = 0;
  final ScrollController _scrollController = ScrollController();

  // 🌬️ 靜陪：3 秒靜默後顯示呼吸動畫，8-12 秒隨機間隔
  Timer? _idleTimer;
  bool _showBreathing = false;

  @override
  void initState() {
    super.initState();
    // Voice features are lazy-loaded to prevent permissions crash on startup
    _textController.addListener(_resetIdleTimer);
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_showBreathing && mounted) {
      setState(() => _showBreathing = false);
    }
    _idleTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showBreathing = true);
    });
  }

  Future<void> _ensureVoiceInitialized() async {
    if (_voiceInitialized && _speechReady) return;

    try {
      _speechReady = await _speech.initialize(
        onError: (e) => debugPrint('[ChatPage] STT Error: $e'),
      );
    } catch (e) {
      debugPrint('[ChatPage] SpeechToText init failed: $e');
      _speechReady = false;
    }

    try {
      final speechRate = await ref.read(ttsSpeechRateProvider.future);
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage(
        _ttsLanguageFor(ref.read(appLanguageControllerProvider)),
      );
      await _tts.setSpeechRate(speechRate);
      await _tts.setPitch(1.0);
      _tts.setStartHandler(() {
        if (!mounted) return;
        setState(() => _ttsPlaybackState = _TtsPlaybackState.playing);
      });
      _tts.setCompletionHandler(_handleTtsFinished);
      _tts.setCancelHandler(_handleTtsFinished);
      _tts.setPauseHandler(() {
        if (!mounted) return;
        setState(() => _ttsPlaybackState = _TtsPlaybackState.paused);
      });
      _tts.setContinueHandler(() {
        if (!mounted) return;
        setState(() => _ttsPlaybackState = _TtsPlaybackState.playing);
      });
      _tts.setErrorHandler((message) {
        debugPrint('[ChatPage] FlutterTts error: $message');
        _handleTtsFinished();
      });
      _tts.setProgressHandler((text, startOffset, endOffset, word) {
        _ttsProgressOffset = (_ttsSegmentStartOffset + endOffset).clamp(
          0,
          _activeTtsText?.length ?? 0,
        );
      });
    } catch (e) {
      debugPrint('[ChatPage] FlutterTts init failed: $e');
    }

    _voiceInitialized = true;
  }

  Future<void> _applyTtsSpeechRate(double value) async {
    if (!_voiceInitialized) return;

    try {
      await _tts.setSpeechRate(value);
    } catch (e) {
      debugPrint('[ChatPage] Failed to update TTS speech rate: $e');
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _textController.removeListener(_resetIdleTimer);
    _textController.dispose();
    _speech.stop();
    _tts.stop();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool get _isAndroidTts =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool _isActiveTtsMessage(ChatMessage msg) =>
      _activeTtsMessageId == msg.id &&
      _ttsPlaybackState != _TtsPlaybackState.stopped;

  void _handleTtsFinished() {
    if (!mounted) return;
    setState(() {
      _ttsPlaybackState = _TtsPlaybackState.stopped;
      _activeTtsMessageId = null;
      _activeTtsText = null;
      _ttsProgressOffset = 0;
      _ttsSegmentStartOffset = 0;
    });
  }

  Future<void> _speakMessage(ChatMessage msg) async {
    await _ensureVoiceInitialized();
    await _tts.setLanguage(
      _ttsLanguageFor(ref.read(appLanguageControllerProvider)),
    );

    if (_activeTtsMessageId != null && _activeTtsMessageId != msg.id) {
      await _tts.stop();
    }

    final text = msg.content.trim();
    if (text.isEmpty) return;

    setState(() {
      _activeTtsMessageId = msg.id;
      _activeTtsText = text;
      _ttsPlaybackState = _TtsPlaybackState.playing;
      _ttsProgressOffset = 0;
      _ttsSegmentStartOffset = 0;
    });

    final result = await _tts.speak(text);
    if (result != 1 && mounted) {
      _handleTtsFinished();
    }
  }

  Future<void> _pauseSpeaking() async {
    if (_ttsPlaybackState != _TtsPlaybackState.playing) return;
    final result = await _tts.pause();
    if (result == 1 && mounted) {
      setState(() => _ttsPlaybackState = _TtsPlaybackState.paused);
    }
  }

  Future<void> _resumeSpeaking() async {
    final activeText = _activeTtsText;
    if (_activeTtsMessageId == null || activeText == null) return;

    final resumeOffset = _ttsProgressOffset.clamp(0, activeText.length);
    if (resumeOffset >= activeText.length) {
      _handleTtsFinished();
      return;
    }

    final textToSpeak = _isAndroidTts
        ? activeText
        : activeText.substring(resumeOffset);

    setState(() {
      _ttsPlaybackState = _TtsPlaybackState.playing;
      _ttsSegmentStartOffset = resumeOffset;
    });

    final result = await _tts.speak(textToSpeak);
    if (result != 1 && mounted) {
      _handleTtsFinished();
    }
  }

  Future<void> _stopSpeaking() async {
    final result = await _tts.stop();
    if (result == 1 && mounted) {
      _handleTtsFinished();
    }
  }

  Future<void> _toggleListening() async {
    await _ensureVoiceInitialized();
    final language = ref.read(appLanguageControllerProvider);
    final copy = AppStrings.of(language);

    if (!_speechReady) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.voiceUnavailable)));
      }
      return;
    }

    if (_isListening) {
      await _speech.stop();
      _voiceMetrics.finish(_textController.text, isZh: copy.isZhTw);
      if (mounted) setState(() => _isListening = false);
      return;
    }

    _voiceMetrics.start();
    await _speech.listen(
      localeId: _speechLocaleFor(language),
      // SPEECH_FIX 停頓要靠音量判定 —— 引擎在人不說話時不會吐結果
      onSoundLevelChange: _voiceMetrics.onSoundLevel,
      onResult: (result) {
        _voiceMetrics.onEvent(result.recognizedWords);
        setState(() {
          _textController.text = result.recognizedWords;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        });
      },
    );
    if (mounted) setState(() => _isListening = true);
  }

  // 危機關鍵字清單（藍宥欣設計）
  static const List<String> _crisisKeywords = [
    '不想活', '想死', '自殺', '割腕',
    '結束生命', '消失算了', '不如死了',
    '活著沒意義', '沒有人在乎', '撐不下去',
    '不想了', '太累了不想活',
  ];

  bool _isCrisis(String text) {
    return _crisisKeywords.any((kw) => text.contains(kw));
  }

  Future<void> _send() async {
    if (_isSending) return;
    final content = _textController.text.trim();
    if (content.isEmpty) return;

    // 語義—情緒不一致偵測
    final incongruence = IncongruenceDetector().analyze(content);
    if (incongruence.needsAttention && !_isCrisis(content)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFFFFF8E1),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💭', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 12),
              Consumer(
                builder: (c, r, _) => Text(
                  incongruence.alertMessageFor(
                    AppStrings.of(r.watch(appLanguageControllerProvider)).isZhTw,
                  ),
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      child: Consumer(
                        builder: (c, r, _) => FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppStrings.of(r.watch(appLanguageControllerProvider)).isZhTw ? '繼續說' : 'Keep talking',
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0ABFBC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.go('/safety');
                      },
                      child: Consumer(
                        builder: (c, r, _) => FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppStrings.of(r.watch(appLanguageControllerProvider)).isZhTw ? '求助資源' : 'Get help',
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // 危機關鍵字偵測
    if (_isCrisis(content)) {
      _textController.clear();
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: const Color(0xFFFFEBEE),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔴', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                const Text(
                  '我注意到你說的話讓我有點擔心你',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  '要不要一起找人幫忙？',
                  style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD14343)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/safety');
                  },
                  child: Consumer(builder: (c, r, _) => Text(AppStrings.of(r.watch(appLanguageControllerProvider)).isZhTw ? '前往求助資源' : 'Get help resources', style: const TextStyle(color: Colors.white))),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Consumer(builder: (c, r, _) => Text(AppStrings.of(r.watch(appLanguageControllerProvider)).isZhTw ? '繼續對話' : 'Keep chatting')),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isSending = true);

    final db = ref.read(appDatabaseProvider);
    final repository = ref.read(aiChatRepositoryProvider);
    final riskService = ref.read(riskEvaluationServiceProvider);
    final language = ref.read(appLanguageControllerProvider);
    final copy = AppStrings.of(language);

    try {
      final sessionId = await ref.read(chatSessionIdProvider.future);

      await db.insertChatMessage(
        sessionId: sessionId,
        role: 'user',
        content: content,
      );
      _textController.clear();
      _scrollToBottom();

      final immediateRisk = await riskService.evaluateAndPersistToday(
        sessionId: sessionId,
      );
      if (immediateRisk.riskLevel == RiskLevel.high) {
        await db.insertChatMessage(
          sessionId: sessionId,
          role: 'ai',
          content: aiHighRiskSafetyReplyFor(language),
        );
        _scrollToBottom();
        if (mounted) {
          await _showHighRiskSheet();
        }
        return;
      }

      final latestRisk = await db.getLatestRiskSnapshot();
      String? contextSummary;
      if (latestRisk != null) {
        final reasons = (jsonDecode(latestRisk.reasonsJson) as List<dynamic>)
            .map((e) => e.toString())
            .join(language == AppLanguage.zhTw ? '、' : ', ');
        contextSummary = copy.riskContext(latestRisk.riskLevel, reasons);
      }

      final reply = await repository.sendMessage(
        sessionId: sessionId,
        userText: content,
        contextSummary: contextSummary,
      );

      // 過濾固定開場白
      String filteredReply = reply.content;
      final bannedPhrases = [
        '謝謝你願意說出來',
        '謝謝你說出來',
        '這很不容易',
        '聽起來你',
        'Thank you for sharing',
        'Thank you for telling me',
        "It sounds like you're",
        'I can hear that',
      ];
      for (final phrase in bannedPhrases) {
        if (filteredReply.startsWith(phrase) || filteredReply.startsWith('，') || filteredReply.contains(phrase + '，')) {
          filteredReply = filteredReply.replaceFirst(RegExp(phrase + r'[，,。\.\s]*'), '');
          if (filteredReply.isNotEmpty) {
            filteredReply = filteredReply[0].toUpperCase() + filteredReply.substring(1);
          }
        }
      }

      await db.insertChatMessage(
        sessionId: sessionId,
        role: 'ai',
        content: filteredReply,
      );
      _scrollToBottom();
      _autoSaveToNote(content, reply.content);
      if (mounted && reply.warningMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(reply.warningMessage!)));
      }

      final risk = await riskService.evaluateAndPersistToday(
        sessionId: sessionId,
      );
      if (risk.riskLevel == RiskLevel.high && mounted) {
        await _showHighRiskSheet();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.sendFailed(error))));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _showHighRiskSheet() async {
    final copy = AppStrings.of(ref.read(appLanguageControllerProvider));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: LumiTheme.error,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        copy.highRiskDetected,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: LumiTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  copy.highRiskSheetBody,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: LumiTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      this.context.go('/safety');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LumiTheme.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(copy.goToSafety),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LumiTheme.textPrimary,
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(copy.keepChatting),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final theme = Theme.of(context);
    final copy = AppStrings.of(ref.watch(appLanguageControllerProvider));

    ref.listen<AsyncValue<double>>(ttsSpeechRateProvider, (previous, next) {
      next.whenData(_applyTtsSpeechRate);
    });

    ref.listen(chatMessagesProvider, (prev, next) {
      if (next.hasValue) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    return Scaffold(
      backgroundColor: LumiTheme.background,
      appBar: AppBar(
        title: Text(copy.chatTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.psychology_alt_rounded,
                            size: 56,
                            color: LumiTheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 左右留內距 + 置中：英文標題會斷成兩行，
                        // 沒有內距的話整段會貼齊螢幕邊緣、第二行靠左
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            copy.chatEmptyTitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: LumiTheme.textSecondary,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            copy.chatEmptySubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: LumiTheme.textLight,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final msg = items[index];
                    final isUser = msg.role == 'user';
                    return _buildMessageBubble(context, msg, isUser, copy);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: LumiTheme.primary),
              ),
              error: (error, stack) => Center(
                child: Text(
                  copy.loadFailed(error),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
          if (_showBreathing) _buildBreathingIndicator(),
          _buildInputArea(context, copy),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    ChatMessage msg,
    bool isUser,
    AppStrings copy,
  ) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isUser ? LumiTheme.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(24),
            topRight: const Radius.circular(24),
            bottomLeft: Radius.circular(isUser ? 22 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 22),
          ),
          boxShadow: [
            BoxShadow(
              color: (isUser ? LumiTheme.primary : Colors.black).withValues(
                alpha: 0.08,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.content,
              style: TextStyle(
                color: isUser ? Colors.white : LumiTheme.textPrimary,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: 8),
              if (_isActiveTtsMessage(msg))
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTtsActionButton(
                      icon: _ttsPlaybackState == _TtsPlaybackState.paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      label: _ttsPlaybackState == _TtsPlaybackState.paused
                          ? copy.ttsResume
                          : copy.ttsPause,
                      onTap: _ttsPlaybackState == _TtsPlaybackState.paused
                          ? _resumeSpeaking
                          : _pauseSpeaking,
                    ),
                    _buildTtsActionButton(
                      icon: Icons.stop_rounded,
                      label: copy.ttsStop,
                      onTap: _stopSpeaking,
                    ),
                  ],
                )
              else
                _buildTtsActionButton(
                  icon: Icons.volume_up_rounded,
                  label: copy.ttsRead,
                  onTap: () => _speakMessage(msg),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTtsActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: LumiTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: LumiTheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: LumiTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, AppStrings copy) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mic button
          GestureDetector(
            onTap: _toggleListening,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isListening
                    ? LumiTheme.error.withValues(alpha: 0.1)
                    : LumiTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: _isListening
                    ? LumiTheme.error
                    : LumiTheme.primary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Text input
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: LumiTheme.background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                style: const TextStyle(
                  fontSize: 15,
                  color: LumiTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: copy.chatHint,
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send button
          GestureDetector(
            onTap: _isSending ? null : _send,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LumiTheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: LumiTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildBreathingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: _BreathingRing(),
      ),
    );
  }

  String _ttsLanguageFor(AppLanguage language) {
    return language == AppLanguage.zhTw ? 'zh-TW' : 'en-US';
  }

  String _speechLocaleFor(AppLanguage language) {
    return language == AppLanguage.zhTw ? 'zh-TW' : 'en-US';
  }

  Future<void> _autoSaveToNote(String userText, String aiReply) async {
    debugPrint('[AutoNote] 開始處理，原始文字：$userText');
    final isZh = ref.read(appLanguageControllerProvider) == AppLanguage.zhTw;
    final now = DateTime.now();
    DateTime targetDate = now;
    final combined = userText.toLowerCase();
    if (combined.contains('明天') || combined.contains('tomorrow') || combined.contains('tmr') || combined.contains('tom') || combined.contains('2moro') || combined.contains('2mrw')) {
      targetDate = now.add(const Duration(days: 1));
      debugPrint('[AutoNote] 偵測到「明天」關鍵字');
    } else if (combined.contains('後天') || combined.contains('day after tomorrow') || combined.contains('dat')) {
      targetDate = now.add(const Duration(days: 2));
      debugPrint('[AutoNote] 偵測到「後天」關鍵字');
    } else if (combined.contains('下週') || combined.contains('下周') || combined.contains('next week') || combined.contains('nxt wk') || combined.contains('next wk')) {
      targetDate = now.add(const Duration(days: 7));
      debugPrint('[AutoNote] 偵測到「下週」關鍵字');
    } else {
      final dateRegex = RegExp(r'(\d{1,2})[/月](\d{1,2})');
      final match = dateRegex.firstMatch(combined);
      if (match != null) {
        final month = int.tryParse(match.group(1) ?? '') ?? now.month;
        final day = int.tryParse(match.group(2) ?? '') ?? now.day;
        targetDate = DateTime(now.year, month, day);
        debugPrint('[AutoNote] 偵測到日期格式：$month/$day');
      } else {
        debugPrint('[AutoNote] ⚠️ 沒有偵測到任何日期關鍵字，中止寫入 Note');
        return;
      }
    }
    debugPrint('[AutoNote] 目標日期：$targetDate，即將寫入 key：note_${targetDate.year}_${targetDate.month}_${targetDate.day}');
    final prefs = await SharedPreferences.getInstance();
    // 移除日期關鍵字，只保留事項本身
    String cleanText = userText;
    for (final word in ['明天', '後天', '下週', '下周', 'tomorrow', 'tmr', 'tom', 'next week', 'nxt wk', '2moro', '2mrw', 'day after tomorrow', 'dat']) {
      cleanText = cleanText.replaceAll(word, '').trim();
    }
    cleanText = cleanText.replaceAll(RegExp(r'^[要去，,、\s]+'), '').trim();
    if (cleanText.isEmpty) cleanText = userText;
    final summary = cleanText.length > 60 ? cleanText.substring(0, 60) + '...' : cleanText;
    final daysUntil = targetDate.difference(DateTime(now.year, now.month, now.day)).inDays;

    // 存進目標日期的 diary
    final targetKey = 'note_${targetDate.year}_${targetDate.month}_${targetDate.day}';
    final targetRaw = prefs.getString(targetKey);
    final List targetItems = targetRaw != null ? (jsonDecode(targetRaw) as List) : [];
    if (targetItems.isNotEmpty) {
      targetItems.add({'text': isZh ? '── 來自 Luna 對話 ──' : '── From chat with Luna ──', 'type': 0, 'checked': false, 'priority': 12});
    }
    targetItems.add({'text': '📌 ' + summary, 'type': 2, 'checked': false, 'priority': 2});
    await prefs.setString(targetKey, jsonEncode(targetItems));

    // 如果不是今天，也在今天存一條倒數提醒
    if (daysUntil > 0) {
      final todayKey = 'note_${now.year}_${now.month}_${now.day}';
      final todayRaw = prefs.getString(todayKey);
      final List todayItems = todayRaw != null ? (jsonDecode(todayRaw) as List) : [];
      final countdown = isZh
          ? (daysUntil == 1 ? '明天' : '還有 ${daysUntil} 天')
          : (daysUntil == 1 ? 'Tomorrow' : 'In ${daysUntil} days');
      todayItems.add({'text': '⏰ ${countdown}：${summary}', 'type': 2, 'checked': false, 'priority': 6});
      await prefs.setString(todayKey, jsonEncode(todayItems));
    }
  }

}


class _BreathingRing extends StatefulWidget {
  @override
  State<_BreathingRing> createState() => _BreathingRingState();
}

class _BreathingRingState extends State<_BreathingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  final _random = Random();

  Duration _randomHalfCycle() {
    final seconds = 4 + _random.nextInt(3);
    return Duration(seconds: seconds);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _randomHalfCycle());
    _scaleAnim = Tween<double>(begin: 0.82, end: 1.18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.duration = _randomHalfCycle();
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controller.duration = _randomHalfCycle();
        _controller.forward();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              LumiTheme.primary.withValues(alpha: 0.32),
              LumiTheme.primary.withValues(alpha: 0.04),
            ],
          ),
        ),
      ),
    );
  }
}
