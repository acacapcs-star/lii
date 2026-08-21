import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceWakeService {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  bool _isAvailable = false;

  // 🔧 修正「重複 prompt」的問題：同一句話在講的過程中，
  // onResult 會連續觸發好幾次「部分結果」，如果每次都判斷喚醒詞，
  // 會導致 _respond() 被重複呼叫好幾次。這個旗標確保同一次聆聽，
  // 喚醒詞只會真正觸發一次，直到重新開始聆聽才會重置。
  bool _wakeWordTriggered = false;

  static const List<String> wakeWords = ['嘿在嗎', '嘿，在嗎', '在嗎', 'hey psyguard', 'hey lumi'];

  Future<void> initialize() async {
    _isAvailable = await _speech.initialize();

    // 🔊 iOS 預設的音訊類別在靜音開關打開時不會發聲，
    //    設成 playback 才會響。Android 與 Web 不需要也不支援。
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
        );
      } catch (_) {
        // 某些 iOS 版本不支援就算了，不要因此讓整個初始化失敗
      }
    }

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.1);
  }

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  Future<void> startListening({
    required Function(String) onWakeWordDetected,
    required Function(String) onResult,
    bool isZh = true,
    /// 🎤 每次辨識更新都會呼叫（含中途的部分結果），
    ///    用來算語速與停頓，不影響原本的流程
    Function(String)? onSpeechEvent,

    /// 🎤 音量回呼。停頓要靠音量判定 ——
    /// 辨識引擎在人不說話時不會吐結果，靠 onSpeechEvent 數不到停頓。
    Function(double)? onSoundLevel,
  }) async {
    if (!_isAvailable) {
      _isAvailable = await _speech.initialize();
      if (!_isAvailable) return;
    }
    _isListening = true;
    _wakeWordTriggered = false;
    await _speech.listen(
      onSoundLevelChange: onSoundLevel,
      onResult: (result) {
        onSpeechEvent?.call(result.recognizedWords);
        final text = result.recognizedWords.toLowerCase();
        final hasWakeWord = wakeWords.any((w) => text.contains(w.toLowerCase()));
        if (hasWakeWord && !_wakeWordTriggered) {
          _wakeWordTriggered = true;
          onWakeWordDetected(text);
          _respond(locale: isZh ? 'zh-TW' : 'en-US');
        } else if (result.finalResult && !hasWakeWord) {
          onResult(text);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: isZh ? 'zh-TW' : 'en-US',
    );
  }

  Future<void> stopListening() async {
    _isListening = false;
    _wakeWordTriggered = false;
    await _speech.stop();
  }

  Future<void> _respond({String locale = 'zh-TW'}) async {
    // 🔇 iOS 不允許同時佔用麥克風又播放聲音，
    //    不先停掉錄音的話 TTS 會完全沒聲音。
    await _speech.stop();
    _isListening = false;
    // 給音訊通道一點時間切換，太快講會被吃掉開頭
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (locale.startsWith('en')) {
      await _tts.setLanguage('en-US');
      await _tts.speak("Hey! I'm Luna. I'm here for you.");
    } else {
      await _tts.setLanguage('zh-TW');
      await _tts.speak('嘿，說吧。');
    }
  }

  Future<void> dispose() async {
    await _speech.stop();
    await _tts.stop();
  }
}
