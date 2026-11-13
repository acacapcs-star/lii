import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../security/local_settings_service.dart';
import '../storage/app_database.dart';
import '../storage/database_provider.dart';
import '../../l10n/app_language.dart';
import 'ai_lang_pref.dart';
import 'ai_api_client.dart';
import 'app_config_controller.dart';
import 'dio_provider.dart';
import 'ai_error_formatter.dart';
import 'ai_local_messages.dart';

class AiReply {
  AiReply({
    required this.content,
    required this.isFallback,
    required this.model,
    this.warningMessage,
  });

  final String content;
  final bool isFallback;
  final String model;
  final String? warningMessage;
}

abstract class AiChatRepository {
  Future<AiReply> sendMessage({
    required String sessionId,
    required String userText,
    String? contextSummary,
  });

  Future<String> generateReport({required String analysisData});
}

final aiApiClientProvider = Provider<AiApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.isConfigured) {
    return MockAiClient();
  }
  return OpenAiCompatibleClient(ref.read(dioProvider), config);
});

final aiChatRepositoryProvider = Provider<AiChatRepository>((ref) {
  return AiChatRepositoryImpl(
    client: ref.watch(aiApiClientProvider),
    db: ref.watch(appDatabaseProvider),
    config: ref.watch(appConfigProvider),
    language: ref.watch(appLanguageControllerProvider),
    replyLang: ref.watch(aiReplyLangProvider),
  );
});

class AiChatRepositoryImpl implements AiChatRepository {
  AiChatRepositoryImpl({
    required AiApiClient client,
    required AppDatabase db,
    required AppConfig config,
    AppLanguage language = AppLanguage.zhTw,
    AiReplyLang replyLang = AiReplyLang.auto,
  }) : _client = client,
       _db = db,
       _config = config,
       _language = language,
       _replyLang = replyLang;

  final AiApiClient _client;
  final AppDatabase _db;
  final AppConfig _config;
  final AppLanguage _language;
  final AiReplyLang _replyLang;

  static const _estimatedContextWindowTokens = 128000;
  static const _compressionTriggerTokens = 118000;
  static const _targetPromptTokens = 108000;
  static const _maxRecentMessagesToKeep = 12;
  static const _minRecentMessagesToKeep = 4;
  static const _maxStoredSummaryChars = 1200;

  @override
  Future<AiReply> sendMessage({
    required String sessionId,
    required String userText,
    String? contextSummary,
  }) async {
    final messages = await _buildPromptMessages(
      sessionId: sessionId,
      userText: userText,
      contextSummary: contextSummary,
    );

    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final content = await _client.createChatCompletion(
          messages: messages,
          model: _config.model,
        );

        await _recordApiUsage(userText, content);
        return AiReply(
          content: content,
          isFallback: false,
          model: _config.model,
          warningMessage: null,
        );
      } catch (error) {
        lastError = error;
        final isLastAttempt = attempt == 2;
        if (isLastAttempt || !_isRetriable(error)) {
          break;
        }

        final backoff = Duration(milliseconds: 500 * (attempt + 1));
        await Future<void>.delayed(backoff);
      }
    }

    await _db.logAudit(
      eventType: 'ai_fallback',
      meta: {
        'sessionId': sessionId,
        'error': lastError.toString(),
        'time': DateTime.now().toIso8601String(),
      },
    );

    return AiReply(
      content: aiFallbackReplyFor(_language),
      isFallback: true,
      model: _config.model,
      warningMessage: userFacingAiError(lastError, language: _language),
    );
  }

  Future<void> _recordApiUsage(String prompt, String completion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chars = prompt.length + completion.length;
      final estTokens = (chars / 3).round();
      final reqs = (prefs.getInt('api_usage_requests') ?? 0) + 1;
      final toks = (prefs.getInt('api_usage_tokens') ?? 0) + estTokens;
      await prefs.setInt('api_usage_requests', reqs);
      await prefs.setInt('api_usage_tokens', toks);
    } catch (_) {}
  }

  Future<List<Map<String, String>>> _buildPromptMessages({
    required String sessionId,
    required String userText,
    String? contextSummary,
  }) async {
    String todayNoteContext = "";
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final dateKey = 'note_${now.year}_${now.month}_${now.day}';
      final raw = prefs.getString(dateKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        if (list.isNotEmpty) {
          todayNoteContext = "\n【使用者今日手刻筆記與待辦事項】\n";
          for (var item in list) {
            String status = item['checked'] == true ? "[已完成]" : "[未完成]";
            String priority = "綠色(輕)";
            if (item['priority'] == 0) priority = "紅色(最緊急!)";
            if (item['priority'] == 1) priority = "黃色(重要)";
            todayNoteContext += "- $status 優先級:$priority 内容: ${item['text']}\n";
          }
          todayNoteContext += "（請在接下來的對話中，主動關心、整合、或協助使用者優化上述提及的目標與情緒狀態。）\n";
        }
      }
    } catch (e) {
      print("[Note System Link Error]: $e");
    }

    final trimmedUserText = userText.trim();
    final history = await _db.getSessionMessages(sessionId);
    final storedSummary = await _db.getChatContextSummary(sessionId);

    var summaryText = storedSummary?.summary.trim();
    var summarizedUntilMessageId = storedSummary?.summarizedUntilMessageId ?? 0;

    final normalizedHistory = _normalizeHistory(
      history: history,
      userText: trimmedUserText,
    );

    var rawHistory = _messagesAfterSummary(
      normalizedHistory,
      summarizedUntilMessageId,
    );
    var promptMessages = _composePromptMessages(
      contextSummary: contextSummary,
      summaryText: summaryText,
      history: rawHistory,
    );

    final estimatedBeforeCompression = _estimateMessagesTokens(promptMessages);
    if (estimatedBeforeCompression >= _compressionTriggerTokens) {
      final compressionResult = await _compressContextIfNeeded(
        sessionId: sessionId,
        fullHistory: normalizedHistory,
        currentSummary: summaryText,
        summarizedUntilMessageId: summarizedUntilMessageId,
        contextSummary: contextSummary,
      );
      summaryText = compressionResult.summaryText;
      summarizedUntilMessageId = compressionResult.summarizedUntilMessageId;
      rawHistory = _messagesAfterSummary(
        normalizedHistory,
        summarizedUntilMessageId,
      );
      promptMessages = _composePromptMessages(
        contextSummary: contextSummary,
        summaryText: summaryText,
        history: rawHistory,
      );
    }

    if (_estimateMessagesTokens(promptMessages) >
        _estimatedContextWindowTokens) {
      final trimmedHistory = _trimHistoryToBudget(rawHistory);
      promptMessages = _composePromptMessages(
        contextSummary: contextSummary,
        summaryText: summaryText,
        history: trimmedHistory,
      );
    }

    return promptMessages;
  }

  Future<_CompressionResult> _compressContextIfNeeded({
    required String sessionId,
    required List<_PromptHistoryMessage> fullHistory,
    required String? currentSummary,
    required int summarizedUntilMessageId,
    String? contextSummary,
  }) async {
    var summaryText = currentSummary;
    var summaryBoundary = summarizedUntilMessageId;

    while (true) {
      final rawHistory = _messagesAfterSummary(fullHistory, summaryBoundary);
      final currentMessages = _composePromptMessages(
        contextSummary: contextSummary,
        summaryText: summaryText,
        history: rawHistory,
      );
      final estimatedTokens = _estimateMessagesTokens(currentMessages);
      if (estimatedTokens < _compressionTriggerTokens) {
        break;
      }

      final persistedHistory = rawHistory
          .where((message) => message.id != null)
          .toList();
      if (persistedHistory.length <= _minRecentMessagesToKeep) {
        break;
      }

      final keepCount = math.min(
        _maxRecentMessagesToKeep,
        persistedHistory.length,
      );
      final splitIndex = math.max(1, persistedHistory.length - keepCount);
      final messagesToSummarize = persistedHistory.take(splitIndex).toList();

      final nextSummary = await _summarizeContext(
        existingSummary: summaryText,
        history: messagesToSummarize,
      );
      summaryText = _truncateSummary(nextSummary);
      summaryBoundary = messagesToSummarize.last.id!;

      await _db.upsertChatContextSummary(
        sessionId: sessionId,
        summary: summaryText,
        summarizedUntilMessageId: summaryBoundary,
      );
      await _db.logAudit(
        eventType: 'chat_context_compressed',
        meta: {
          'sessionId': sessionId,
          'summarizedUntilMessageId': summaryBoundary,
          'sourceMessageCount': messagesToSummarize.length,
          'estimatedTokensBefore': estimatedTokens,
          'time': DateTime.now().toIso8601String(),
        },
      );
    }

    return _CompressionResult(
      summaryText: summaryText,
      summarizedUntilMessageId: summaryBoundary,
    );
  }

  Future<String> _summarizeContext({
    required String? existingSummary,
    required List<_PromptHistoryMessage> history,
  }) async {
    final summaryMessages = <Map<String, String>>[
      {'role': 'system', 'content': _summaryPrompt},
      if (existingSummary != null && existingSummary.trim().isNotEmpty)
        {
          'role': 'system',
          'content': _existingSummaryMessage(existingSummary.trim()),
        },
      {
        'role': 'user',
        'content': _summarizeHistoryMessage(_formatHistoryForSummary(history)),
      },
    ];

    try {
      final summary = await _client.createChatCompletion(
        messages: summaryMessages,
        model: _config.model,
      );
      final normalized = summary.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    } catch (_) {
      // Fall back to a deterministic local summary so chat can continue.
    }

    return _buildLocalSummary(
      existingSummary: existingSummary,
      history: history,
    );
  }

  List<_PromptHistoryMessage> _normalizeHistory({
    required List<ChatMessage> history,
    required String userText,
  }) {
    final normalized = history
        .map(
          (message) => _PromptHistoryMessage(
            id: message.id,
            role: _normalizeRole(message.role),
            content: message.content.trim(),
          ),
        )
        .where((message) => message.content.isNotEmpty)
        .where(_shouldIncludeInPrompt)
        .toList();

    if (userText.isEmpty) {
      return normalized;
    }

    final alreadyIncluded =
        normalized.isNotEmpty &&
        normalized.last.role == 'user' &&
        normalized.last.content == userText;
    if (!alreadyIncluded) {
      normalized.add(
        _PromptHistoryMessage(id: null, role: 'user', content: userText),
      );
    }

    return normalized;
  }

  List<_PromptHistoryMessage> _messagesAfterSummary(
    List<_PromptHistoryMessage> history,
    int summarizedUntilMessageId,
  ) {
    return history
        .where(
          (message) =>
              message.id == null || message.id! > summarizedUntilMessageId,
        )
        .toList();
  }

  List<Map<String, String>> _composePromptMessages({
    required String? contextSummary,
    required String? summaryText,
    required List<_PromptHistoryMessage> history,
  }) {
    return <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt + _replyLang.directive()},
      if (contextSummary != null && contextSummary.trim().isNotEmpty)
        {
          'role': 'system',
          'content': _todayRiskSummaryMessage(contextSummary.trim()),
        },
      if (summaryText != null && summaryText.trim().isNotEmpty)
        {
          'role': 'system',
          'content': _compressedSummaryMessage(summaryText.trim()),
        },
      ...history.map(
        (message) => {'role': message.role, 'content': message.content},
      ),
    ];
  }

  List<_PromptHistoryMessage> _trimHistoryToBudget(
    List<_PromptHistoryMessage> history,
  ) {
    final retained = <_PromptHistoryMessage>[];
    for (final message in history.reversed) {
      retained.insert(0, message);
      final estimatedTokens = _estimateMessagesTokens([
        {'role': 'system', 'content': _systemPrompt + _replyLang.directive()},
        ...retained.map((item) => {'role': item.role, 'content': item.content}),
      ]);
      if (estimatedTokens > _targetPromptTokens && retained.length > 1) {
        retained.removeAt(0);
        break;
      }
    }

    return retained.length >= _minRecentMessagesToKeep
        ? retained
        : history.takeLast(_minRecentMessagesToKeep);
  }

  String _normalizeRole(String role) {
    switch (role) {
      case 'assistant':
      case 'ai':
        return 'assistant';
      case 'system':
        return 'system';
      default:
        return 'user';
    }
  }

  bool _shouldIncludeInPrompt(_PromptHistoryMessage message) {
    if (message.role != 'assistant') {
      return true;
    }
    return !localOnlyAssistantReplies.contains(message.content);
  }

  int _estimateMessagesTokens(List<Map<String, String>> messages) {
    return messages.fold<int>(0, (total, message) {
      final role = message['role'] ?? '';
      final content = message['content'] ?? '';
      return total + 12 + role.length + content.runes.length;
    });
  }

  String _formatHistoryForSummary(List<_PromptHistoryMessage> history) {
    return history
        .map((message) => '[${message.role}] ${message.content}')
        .join('\n');
  }

  String _buildLocalSummary({
    required String? existingSummary,
    required List<_PromptHistoryMessage> history,
  }) {
    final parts = <String>[];
    final cleanedSummary = existingSummary?.trim();
    if (cleanedSummary != null && cleanedSummary.isNotEmpty) {
      parts.add(_localPreviousSummary(cleanedSummary));
    }

    final userMessages = history
        .where((message) => message.role == 'user')
        .map((message) => message.content)
        .toList();
    final assistantMessages = history
        .where((message) => message.role == 'assistant')
        .map((message) => message.content)
        .toList();

    if (userMessages.isNotEmpty) {
      parts.add(_localUserMentioned(userMessages.takeLast(3)));
    }
    if (assistantMessages.isNotEmpty) {
      parts.add(_localAssistantReplied(assistantMessages.takeLast(2)));
    }

    return _truncateSummary(parts.join('\n'));
  }

  String _truncateSummary(String summary) {
    final normalized = summary.trim();
    if (normalized.runes.length <= _maxStoredSummaryChars) {
      return normalized;
    }
    return String.fromCharCodes(normalized.runes.take(_maxStoredSummaryChars));
  }

  bool _isRetriable(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == null) {
        return true;
      }
      return status == 429 || status >= 500;
    }
    return false;
  }

  @override
  Future<String> generateReport({required String analysisData}) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _reportPrompt},
      {'role': 'user', 'content': _reportUserMessage(analysisData)},
    ];

    try {
      final content = await _client.createChatCompletion(
        messages: messages,
        model: _config.model,
      );
      return content;
    } catch (error) {
      throw AiRequestException(userFacingAiError(error, language: _language));
    }
  }

  bool get _usesZhTw => _language == AppLanguage.zhTw;

  String get _reportPrompt {
    if (_usesZhTw) {
      return '你是專業的心理健康數據分析師。請分析以下使用者近期數據（包含心情百分比 0-100、睡眠時長、風險評估分數）。'
          '請找出數據中的模式、潛在觸發因素，並提供 3 個具體且可行的改善建議。'
          '請保持語氣溫柔、鼓勵且專業。'
          '輸出格式請使用 Markdown，第一行必須是標題「# 心理健康趨勢分析」，接著是重點列點。'
          '字數控制在 300-500 字之間。'
          '語言：繁體中文。';
    }

    return 'You are a professional mental health data analyst. Analyze the user\'s recent data, including mood percentage from 0-100, sleep duration, and risk scores. '
        'Identify patterns, possible triggers, and provide 3 concrete, actionable suggestions. '
        'Keep the tone warm, encouraging, and professional. '
        'Use Markdown. The first line must be the title "# Mental Health Trend Analysis", followed by concise bullet points. '
        'Keep the response between 300 and 500 words. Language: English.';
  }

  String _reportUserMessage(String analysisData) {
    return _usesZhTw
        ? '請分析我的數據：\n$analysisData'
        : 'Please analyze my data:\n$analysisData';
  }

  String get _systemPrompt {
    if (_usesZhTw) {
      return '你在 Luna 中扮演一位心理輔導師風格的 AI 陪伴者。'
          '請全程使用繁體中文，以支持性會談方式回應：先同理、再澄清、最後提供一個可執行的小步驟。'
          '你需要記住先前對話脈絡，延續使用者已提過的壓力來源、情緒、支持系統與已嘗試的方法。'
          '你必須根據使用者最近的對話內容，自行判斷當下更需要哪一種回應方式。'
          '如果對方情緒極端、明顯低落、接近失衡或只是想被理解，請以陪伴傾聽為主，先接住情緒，避免一次給太多建議。'
          '如果對方狀態較緩和、已有餘裕整理問題，或主動詢問做法，再提供較具體的分析、建議或下一步。'
          '你不能做醫療診斷，也不能宣稱可替代心理師、醫師或任何執照專業。'
          '禁止鼓勵自傷、自殺或危險行為。'
          '若使用者出現自傷或高度危機語句，先安撫並明確建議立即尋求真人協助（校方輔導老師、1925、110、119）。'
          '避免條列過多理論，優先使用自然對話。每次回應開頭必須完全不同，絕對禁止使用「謝謝你願意說出來」「這很不容易」「聽起來你」等固定句型開場。直接切入重點，像真實的朋友對話一樣自然。有時可以用問句、有時可以用感嘆、有時直接回應。';
    }

    return 'In Luna, you act as an AI companion with the style of a mental health counselor. '
        'Use English throughout. Respond like a supportive conversation: start with empathy, then clarify, then offer one actionable small step. '
        'Remember prior context and continue the relationship using the user\'s stressors, emotions, support system, and tried strategies. '
        'Decide from the recent conversation whether the user needs comfort, reflection, or practical suggestions right now. '
        'If the user is emotionally overwhelmed, very low, close to losing balance, or mainly wants to be understood, focus on listening and emotional support first; avoid giving too much advice at once. '
        'If the user is calmer, has capacity to organize the issue, or directly asks what to do, provide more concrete analysis, suggestions, or next steps. '
        'Do not diagnose, and do not claim to replace licensed mental health or medical professionals. '
        'Never encourage self-harm, suicide, or dangerous behavior. '
        'If the user expresses self-harm or high crisis signals, first stabilize and clearly recommend immediate real-person support such as school counselors, trusted adults, crisis lines, or local emergency services. '
        'Prefer natural conversation over long theoretical bullet lists. Vary your responses — never start with the same opening phrase twice in a row. Match the user emotional tone: be light and warm when they are happy, gentle and present when sad, non-judgmental when angry, and curiously engaged when calm.';
  }

  String get _summaryPrompt {
    if (_usesZhTw) {
      return '你是心理陪伴對話摘要整理器。'
          '請把對話壓縮成可長期保存的摘要，供下一次回應使用。'
          '摘要必須只保留與陪伴有關的重要脈絡：主要困擾、情緒、觸發事件、保護因子、可用資源、已嘗試的方法、未解決問題。'
          '不要加入新事實，不要做診斷，不要保留客套話。'
          '輸出使用繁體中文，控制在 8 點內、800 字內。';
    }

    return 'You are a summarizer for supportive mental health conversations. '
        'Compress the conversation into a long-term summary for future replies. '
        'Keep only context relevant to support: main concerns, emotions, triggers, protective factors, available resources, tried strategies, and unresolved issues. '
        'Do not add new facts, do not diagnose, and do not preserve pleasantries. '
        'Write in English, within 8 bullets and 800 words.';
  }

  String _existingSummaryMessage(String summary) => _usesZhTw
      ? '目前已保存的長期摘要：\n$summary'
      : 'Current saved long-term summary:\n$summary';

  String _summarizeHistoryMessage(String history) => _usesZhTw
      ? '請整合以下較舊的對話內容，產出更新後的長期摘要：\n$history'
      : 'Integrate the older conversation below and produce an updated long-term summary:\n$history';

  String _todayRiskSummaryMessage(String summary) =>
      _usesZhTw ? '今日風險摘要：$summary' : 'Today\'s risk summary: $summary';

  String _compressedSummaryMessage(String summary) => _usesZhTw
      ? '以下是已壓縮的先前對話摘要，請視為長期記憶並延續關係脈絡：\n$summary'
      : 'Below is a compressed summary of prior conversation. Treat it as long-term memory and continue the relationship context:\n$summary';

  String _localPreviousSummary(String summary) =>
      _usesZhTw ? '先前摘要：$summary' : 'Previous summary: $summary';

  String _localUserMentioned(List<String> messages) => _usesZhTw
      ? '使用者先前提到：${messages.join('；')}'
      : 'The user previously mentioned: ${messages.join('; ')}';

  String _localAssistantReplied(List<String> messages) => _usesZhTw
      ? 'AI 已回應：${messages.join('；')}'
      : 'The AI previously replied: ${messages.join('; ')}';
}

class _PromptHistoryMessage {
  const _PromptHistoryMessage({
    required this.id,
    required this.role,
    required this.content,
  });

  final int? id;
  final String role;
  final String content;
}

class _CompressionResult {
  const _CompressionResult({
    required this.summaryText,
    required this.summarizedUntilMessageId,
  });

  final String? summaryText;
  final int summarizedUntilMessageId;
}

extension on List<String> {
  List<String> takeLast(int count) {
    if (length <= count) {
      return this;
    }
    return sublist(length - count);
  }
}

extension on List<_PromptHistoryMessage> {
  List<_PromptHistoryMessage> takeLast(int count) {
    if (length <= count) {
      return this;
    }
    return sublist(length - count);
  }
}
