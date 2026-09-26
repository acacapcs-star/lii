/// 微光的回聲：留下一顆球、寫下幾句話之後，Luna 回一句。
///
/// ── 為什麼每次都不一樣 ─────────────────────────────────
///
/// 同一句安慰聽第三次就不是安慰了，是罐頭。
/// 所以每次呼叫會隨機換一個「回應的角度」（接住感受、看見他做到的事、
/// 讓這個感覺變得正常、一個下一分鐘能做的小事、回應他寫的某個細節），
/// 也會告訴模型上一次說了什麼，不要用同樣的開頭。
///
/// ── 為什麼刻意說得很短 ─────────────────────────────────
///
/// 這裡不是聊天。使用者寫的是一張便條，回應也該是一張便條的份量：
/// 一兩句，不列建議清單、不診斷、最多問一個問題。
/// 想多說的人，聊天頁一直都在。
///
/// ── 沒有金鑰、或連不上的時候 ───────────────────────────
///
/// 用本機的句子，一樣隨機、一樣避開上一句，
/// 所以離線模式也不會每次都是同一句話。
library;

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../network/ai_api_client.dart';
import '../network/ai_chat_repository.dart' show aiApiClientProvider;
import '../network/app_config_controller.dart' show appConfigProvider;
import 'memory_ball.dart';

class GleamReplyService {
  GleamReplyService(this._client, this._config, [Random? rng])
      : _rng = rng ?? Random();

  final AiApiClient _client;
  final AppConfig _config;
  final Random _rng;

  static const _marker = 'GLEAM_ECHO';

  static const _angles = [
    'Acknowledge the feeling by its name, simply and warmly.',
    'Notice something the user did well, such as putting this into words.',
    'Make it feel normal to feel this way, without minimizing it.',
    'Offer one small, gentle thing they could do in the next minute.',
    'Reflect back one specific detail from what they wrote.',
  ];

  Future<String> reply({
    required EmotionGroup group,
    required String word,
    required String memo,
    required bool zh,
    String previous = '',
  }) async {
    if (!_config.isConfigured) return localReply(group, zh, previous: previous);

    try {
      final angle = _angles[_rng.nextInt(_angles.length)];
      final lang = zh ? 'Traditional Chinese as used in Taiwan' : 'English';
      final limit = zh ? 'under 60 Chinese characters' : 'under 40 words';
      final avoid = previous.trim().isEmpty
          ? ''
          : 'Your previous reply was: "${previous.trim()}". '
              'Say something different and do not open the same way. ';
      final system = '$_marker\n'
          'You are Luna, a gentle companion in an emotional wellbeing app '
          'for high school and university students. The user just named a '
          'feeling and wrote a short note. Reply in $lang with one or two '
          'short sentences, $limit. $angle $avoid'
          'Do not give lists of advice. Do not diagnose. Ask at most one '
          'question. Never mention methods of self-harm. Plain text only.';
      final label = group.label(zh);
      final feeling = word.isEmpty || word == label ? label : '$label / $word';
      final user = zh ? '感覺：$feeling\n寫下的話：$memo' : 'Feeling: $feeling\nNote: $memo';

      final out = (await _client.createChatCompletion(
        model: _config.model,
        messages: [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
      ))
          .trim();
      return out.isEmpty ? localReply(group, zh, previous: previous) : out;
    } catch (_) {
      return localReply(group, zh, previous: previous);
    }
  }

  /// 本機的句子。隨機挑，但不會跟上一句一樣。
  String localReply(EmotionGroup group, bool zh, {String previous = ''}) {
    final pool = (zh ? _localZh : _localEn)[group] ?? const ['謝謝你寫下來。'];
    final choices = pool.where((l) => l != previous).toList();
    final list = choices.isEmpty ? pool : choices;
    return list[_rng.nextInt(list.length)];
  }

  static const _localZh = <EmotionGroup, List<String>>{
    EmotionGroup.angry: [
      '會生氣，是因為這件事對你來說很重要。',
      '把它寫下來，火就不用全部悶在心裡了。',
      '你沒有做錯什麼，只是這件事真的很讓人不舒服。',
      '生氣是在提醒你：有一條線被越過了。',
      '先讓這股氣待在罐子裡，你不用現在就處理它。',
      '能說出自己在氣什麼，已經比多數人勇敢了。',
      '氣會過去的，你在意的那件事不會因此變得不重要。',
      '先深呼吸一次。你不需要馬上原諒，也不需要馬上反擊。',
    ],
    EmotionGroup.sad: [
      '難過的時候，能寫下來已經很不容易了。',
      '這個感覺可以先放在這裡，你不用急著好起來。',
      '謝謝你願意把它說出來，Luna 有看到。',
      '會難過，是因為你真的在乎過。',
      '今天慢一點也沒關係，難過本來就需要時間。',
      '你不用假裝沒事，在這裡可以不堅強。',
      '把這一刻收好，之後的你會記得自己撐過來了。',
      '如果可以，今天對自己溫柔一點。',
    ],
    EmotionGroup.afraid: [
      '擔心的事還沒有發生，你現在是安全的。',
      '先吸一口氣再慢慢吐掉，一次只要想一小步就好。',
      '會害怕，代表你很在意。這不是軟弱。',
      '把擔心寫下來，它就從腦袋搬到了紙上。',
      '你不用一次想好全部，只要想好下一步。',
      '腳踩在地上，感覺一下，你在這裡。',
      '最壞的情況不一定會來，就算來了，你也不是一個人。',
      '先照顧現在的自己，未來的事等一下再說。',
    ],
    EmotionGroup.tired: [
      '累了就是累了，今天能撐到這裡已經很好了。',
      '休息不是偷懶，是讓明天的你有力氣。',
      '先放下一件事就好，剩下的明天再說。',
      '你已經用了很多力氣，現在可以先停一下。',
      '喝口水、伸個懶腰，身體也辛苦了。',
      '今天不用再更努力了，這樣就夠了。',
      '累的時候看什麼都比較灰，這不是你的錯。',
      '早點睡吧，很多事睡醒會輕一點。',
    ],
    EmotionGroup.pressured: [
      '事情很多的時候，先挑一件最小的做完就好。',
      '你已經很努力了，不需要一次把全部扛起來。',
      '壓力大，是因為你想把事情做好。',
      '把要做的事寫成清單，腦袋就不用一直記著。',
      '先做五分鐘就好，開始了就會輕一點。',
      '你的價值不等於這一次的結果。',
      '可以跟別人說你需要幫忙，這不丟臉。',
      '一件一件來，你比自己以為的更能應付。',
    ],
    EmotionGroup.okay: [
      '還可以的日子，也值得被好好記住。',
      '這一點平靜，是你自己留下來的。',
      '謝謝你把這一刻收進罐子裡。',
      '平平淡淡的一天，其實很珍貴。',
      '記住現在的感覺，下次難過時可以回來看看。',
      '今天的你，照顧得很好。',
      '還可以，就是很好的意思。',
      '這樣的時刻多收集幾顆吧。',
    ],
  };

  static const _localEn = <EmotionGroup, List<String>>{
    EmotionGroup.angry: [
      'You are angry because this matters to you.',
      'Writing it down means you do not have to hold all of it inside.',
      'You did nothing wrong. This really was upsetting.',
      'Anger is a signal that a line was crossed.',
      'Let the anger sit in the jar for now. You do not have to deal with it yet.',
      'Naming what you are angry about takes courage.',
      'The anger will pass. What you care about will still matter.',
      'Take one breath. You do not have to forgive or fight back right now.',
    ],
    EmotionGroup.sad: [
      'Putting sadness into words is not easy. You did it.',
      'This feeling can rest here. You do not have to be okay yet.',
      'Thank you for saying it. Luna sees it.',
      'You feel sad because you truly cared.',
      'It is okay to go slowly today. Sadness takes time.',
      'You do not have to pretend here. You can be not okay.',
      'Keep this moment. Later you will remember that you got through it.',
      'If you can, be gentle with yourself today.',
    ],
    EmotionGroup.afraid: [
      'The thing you fear has not happened. Right now, you are safe.',
      'Breathe in, and let it out slowly. Just one small step at a time.',
      'Being afraid means you care. It is not weakness.',
      'Writing the worry down moves it out of your head.',
      'You do not need the whole plan. Just the next step.',
      'Feel your feet on the floor. You are here.',
      'The worst may not come. And if it does, you are not alone.',
      'Take care of yourself now. The future can wait a moment.',
    ],
    EmotionGroup.tired: [
      'Tired is tired. Getting this far today is enough.',
      'Resting is not lazy. It is how tomorrow gets its energy.',
      'Put down just one thing. The rest can wait until tomorrow.',
      'You have used a lot of energy. You can stop for a bit.',
      'Drink some water and stretch. Your body worked hard too.',
      'You do not need to try harder today. This is enough.',
      'Everything looks greyer when you are tired. That is not your fault.',
      'Sleep early if you can. Many things feel lighter in the morning.',
    ],
    EmotionGroup.pressured: [
      'When there is too much, finish the smallest thing first.',
      'You are already trying hard. You do not have to carry it all at once.',
      'The pressure is there because you want to do this well.',
      'Make a list, so your head does not have to hold everything.',
      'Start with five minutes. Starting makes it lighter.',
      'Your worth is not this one result.',
      'It is okay to ask for help. There is nothing shameful in it.',
      'One thing at a time. You can handle more than you think.',
    ],
    EmotionGroup.okay: [
      'An okay day is worth remembering too.',
      'This bit of calm is something you kept for yourself.',
      'Thank you for keeping this moment in the jar.',
      'A quiet, ordinary day is precious.',
      'Remember this feeling. You can come back to it on a hard day.',
      'You took good care of yourself today.',
      'Okay is a good place to be.',
      'Collect a few more moments like this one.',
    ],
  };
}

final gleamReplyServiceProvider = Provider<GleamReplyService>((ref) {
  return GleamReplyService(
    ref.watch(aiApiClientProvider),
    ref.watch(appConfigProvider),
  );
});
