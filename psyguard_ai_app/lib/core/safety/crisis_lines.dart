// lib/core/safety/crisis_lines.dart
//
// 各地區求助專線。
//
// 三件事刻意分開：
//   name       專線的官方名稱 — 不翻譯。學生要撥它、要 Google 它。
//   descZh/En  說明文字 — 跟著介面語言走。
//   languages  接線員實際說的語言 — 這一項最重要。
//              地區選日本、介面用中文的學生，需要知道那頭講日文。
//
// 每一筆都標註來源與查證日期。號碼會停用、改號、改時段 —
// 每半年至少複查一次並更新 verifiedOn。查不到官方頁面就不要放。
//
// 最後全面查證：2026-08-22

class CrisisLine {
  const CrisisLine({
    required this.name,
    required this.contact,
    required this.descZh,
    required this.descEn,
    required this.languages,
    required this.source,
    required this.verifiedOn,
  });

  /// 官方名稱，不翻譯
  final String name;
  final String contact;

  /// 中文介面顯示
  final String descZh;

  /// 英文介面顯示
  final String descEn;

  /// 接線員說的語言
  final List<String> languages;

  final String source;

  /// YYYY-MM-DD
  final String verifiedOn;

  String desc(bool zh) => zh ? descZh : descEn;
}

enum CrisisRegion {
  taiwan,
  hongKong,
  china,
  japan,
  korea,
  singapore,
  unitedStates,
  canada,
  unitedKingdom,
  france,
  germany,
  custom,
}

extension CrisisRegionLabel on CrisisRegion {
  String label(bool zh) => switch (this) {
        CrisisRegion.taiwan => zh ? '台灣' : 'Taiwan',
        CrisisRegion.hongKong => zh ? '香港' : 'Hong Kong',
        CrisisRegion.china => zh ? '中國' : 'China',
        CrisisRegion.japan => zh ? '日本' : 'Japan',
        CrisisRegion.korea => zh ? '韓國' : 'South Korea',
        CrisisRegion.singapore => zh ? '新加坡' : 'Singapore',
        CrisisRegion.unitedStates => zh ? '美國' : 'United States',
        CrisisRegion.canada => zh ? '加拿大' : 'Canada',
        CrisisRegion.unitedKingdom => zh ? '英國' : 'United Kingdom',
        CrisisRegion.france => zh ? '法國' : 'France',
        CrisisRegion.germany => zh ? '德國' : 'Germany',
        CrisisRegion.custom => zh ? '其他 · 自行填入' : 'Other · custom',
      };

  String get storageKey => name;
}

const Map<CrisisRegion, List<CrisisLine>> kCrisisLines = {
  // ── 台灣 · 沿用原有資料，未更動 ──────────────────────
  CrisisRegion.taiwan: [
    CrisisLine(
      name: '安心專線',
      contact: '1925',
      descZh: '衛福部 24 小時免付費心理諮詢專線。',
      descEn: 'Free mental-health and suicide-prevention line, 24 hours.',
      languages: ['中文'],
      source: 'https://dep.mohw.gov.tw/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '生命線',
      contact: '1995',
      descZh: '24 小時情緒支持與危機協談。',
      descEn: '24-hour emotional support and crisis counseling.',
      languages: ['中文'],
      source: 'https://www.life1995.org.tw/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '張老師專線',
      contact: '1980',
      descZh: '青少年與家庭心理輔導。',
      descEn: 'Counselling for young people and families.',
      languages: ['中文'],
      source: 'https://www.1980.org.tw/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '緊急 · Emergency',
      contact: '119 · 110',
      descZh: '立即危險：119 救護車、110 警察。',
      descEn: 'Immediate danger: 119 ambulance, 110 police.',
      languages: ['中文'],
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.hongKong: [
    CrisisLine(
      name: '撒瑪利亞防止自殺會',
      contact: '2389 2222',
      descZh: '24 小時情緒支援熱線。',
      descEn: '24-hour emotional support hotline.',
      languages: ['廣東話', '普通話'],
      source: 'https://sbhk.org.hk/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'SBHK English Emotional Support',
      contact: '2389 2223',
      descZh: '英文專線，僅週一至五 18:30–22:00。',
      descEn: 'English line, Monday to Friday 18:30–22:00 only.',
      languages: ['English'],
      source: 'https://sbhk.org.hk/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '生命熱線',
      contact: '2382 0000',
      descZh: '24 小時預防自殺熱線。',
      descEn: '24-hour suicide prevention hotline.',
      languages: ['廣東話'],
      source: 'https://www.sps.org.hk/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '緊急 · Emergency',
      contact: '999',
      descZh: '立即危險請撥 999。',
      descEn: 'Immediate danger — call 999.',
      languages: ['廣東話', 'English'],
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.china: [
    CrisisLine(
      name: '全国心理援助热线',
      contact: '12356',
      descZh: '国家卫健委统一号码。各地至少每日 18 小时，部分城市 24 小时。',
      descEn:
          'National unified line. At least 18 hours daily in each city; 24 hours in some.',
      languages: ['中文'],
      source: 'https://www.nhc.gov.cn/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '紧急 · Emergency',
      contact: '120 · 110',
      descZh: '立即危险：120 急救、110 报警。',
      descEn: 'Immediate danger: 120 ambulance, 110 police.',
      languages: ['中文'],
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.japan: [
    CrisisLine(
      name: 'よりそいホットライン',
      contact: '0120-279-338',
      descZh: '每日 24 小時免付費。撥通後按 2 可接非日語服務，含英語。',
      descEn:
          'Free, 24 hours every day. Press 2 for support in languages other than Japanese, including English.',
      languages: ['日本語', 'English'],
      source: 'https://jp.usembassy.gov/services/mental-health-in-japan/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'TELL Lifeline',
      contact: '03-5774-0992',
      descZh: '純英語專線，每日 9:00–23:00。',
      descEn: 'English-language lifeline, every day 9:00–23:00.',
      languages: ['English'],
      source: 'https://telljp.com/lifeline/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'こころの健康相談統一ダイヤル',
      contact: '0570-064-556',
      descZh: '厚生勞動省。受理時間依都道府縣不同，並非 24 小時。',
      descEn:
          'Ministry of Health line. Hours vary by prefecture — not 24 hours.',
      languages: ['日本語'],
      source:
          'https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/hukushi_kaigo/seikatsuhogo/jisatsu/kokoro_dial.html',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '緊急 · Emergency',
      contact: '119 · 110',
      descZh: '立即危險：119 救護車、110 警察。110 可要求翻譯。',
      descEn:
          'Immediate danger: 119 ambulance, 110 police. Interpretation available via 110.',
      languages: ['日本語', 'English'],
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.korea: [
    CrisisLine(
      name: '자살예방 상담전화',
      contact: '109',
      descZh: '保健福祉部，24 小時。2024 年起將 1393 等專線整併為 109。',
      descEn:
          'Ministry of Health and Welfare, 24 hours. Replaced 1393 and others in 2024.',
      languages: ['한국어'],
      source: 'https://www.129.go.kr/109',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '긴급 · Emergency',
      contact: '119 · 112',
      descZh: '立即危險：119 救護、112 報警。',
      descEn: 'Immediate danger: 119 ambulance, 112 police.',
      languages: ['한국어'],
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.singapore: [
    CrisisLine(
      name: 'Samaritans of Singapore',
      contact: '1767',
      descZh: '24 小時熱線。志工僅提供英語服務。',
      descEn: '24-hour hotline. Volunteers are trained in English only.',
      languages: ['English'],
      source: 'https://www.sos.org.sg/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'SOS CareText',
      contact: '9151 1767',
      descZh: '24 小時 WhatsApp 文字支持。',
      descEn: '24-hour WhatsApp text support.',
      languages: ['English'],
      source: 'https://www.sos.org.sg/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Emergency',
      contact: '995 · 999',
      descZh: '立即危險：995 救護車、999 警察。',
      descEn: 'Immediate danger: 995 ambulance, 999 police.',
      languages: ['English'],
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  // ── 美國 · 沿用原有資料，未更動 ──────────────────────
  CrisisRegion.unitedStates: [
    CrisisLine(
      name: '988 Suicide & Crisis Lifeline',
      contact: '988',
      descZh: '撥打或傳簡訊至 988 — 免費、保密、24/7。',
      descEn: 'Call or text 988 — free, confidential, 24/7.',
      languages: ['English', 'Español'],
      source: 'https://988lifeline.org/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Crisis Text Line',
      contact: 'Text HOME to 741741',
      descZh: '免費、保密的文字支持，24/7。',
      descEn: 'Free, confidential text support, 24/7.',
      languages: ['English'],
      source: 'https://www.crisistextline.org/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Emergency',
      contact: '911',
      descZh: '立即危險請撥 911。',
      descEn: 'Immediate danger — call 911.',
      languages: ['English'],
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.canada: [
    CrisisLine(
      name: '9-8-8 Suicide Crisis Helpline',
      contact: '988',
      descZh: '撥打或傳簡訊至 988 — 免費，英語與法語，24/7/365。',
      descEn:
          'Call or text 988 — free, bilingual English and French, 24/7/365.',
      languages: ['English', 'Français'],
      source: 'https://988.ca/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Québec · 1-866-APPELLE',
      contact: '1-866-277-3553',
      descZh: '魁北克在地專線，24 小時。在魁北克撥 988 會轉接至此。',
      descEn:
          'Québec line, 24 h/24. Calls to 988 in Québec are routed here.',
      languages: ['Français'],
      source: 'https://suicide.ca/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Emergency',
      contact: '911',
      descZh: '立即危險請撥 911。',
      descEn: 'Immediate danger — call 911.',
      languages: ['English', 'Français'],
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.unitedKingdom: [
    CrisisLine(
      name: 'Samaritans',
      contact: '116 123',
      descZh: '免付費，全年 24 小時。',
      descEn: 'Free to call, 24 hours a day, 365 days a year.',
      languages: ['English'],
      source: 'https://www.samaritans.org/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Emergency',
      contact: '999',
      descZh: '立即危險請撥 999。',
      descEn: 'Immediate danger — call 999.',
      languages: ['English'],
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.france: [
    CrisisLine(
      name: 'Numéro national de prévention du suicide',
      contact: '3114',
      descZh: '免費、保密，24 小時全年無休。由衛生部主管。',
      descEn:
          'Free, confidential, 24 h/24 and 7 j/7. Run by the Ministry of Health.',
      languages: ['Français'],
      source: 'https://3114.fr/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Urgence · Emergency',
      contact: '15 · 112',
      descZh: '立即危險：SAMU 15，歐洲通用號碼 112。',
      descEn: 'Immediate danger: SAMU 15, European number 112.',
      languages: ['Français'],
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.germany: [
    CrisisLine(
      name: 'TelefonSeelsorge',
      contact: '0800 111 0 111',
      descZh: '免費、匿名，24 小時。',
      descEn: 'Free, anonymous, around the clock.',
      languages: ['Deutsch'],
      source: 'https://www.telefonseelsorge.de/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'TelefonSeelsorge · zweite Nummer',
      contact: '0800 111 0 222',
      descZh: '第二組免費號碼，同樣 24 小時。',
      descEn: 'Second free number, also 24 hours.',
      languages: ['Deutsch'],
      source: 'https://www.telefonseelsorge.de/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Europaweit · Europe-wide',
      contact: '116 123',
      descZh: '歐洲通用的心理支持號碼。',
      descEn: 'Europe-wide number for emotional support.',
      languages: ['Deutsch'],
      source: 'https://www.telefonseelsorge.de/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Notfall · Emergency',
      contact: '112',
      descZh: '立即危險請撥 112。',
      descEn: 'Immediate danger — call 112.',
      languages: ['Deutsch', 'English'],
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  // 使用者自行填入。預設給國際目錄，避免完全沒有去處。
  CrisisRegion.custom: [
    CrisisLine(
      name: 'Find a Helpline',
      contact: 'findahelpline.com',
      descZh: '國際求助專線目錄，可依所在國家與語言查詢。',
      descEn:
          'International directory of crisis lines, searchable by country and language.',
      languages: ['多語言 · multilingual'],
      source: 'https://findahelpline.com/',
      verifiedOn: '2026-08-22',
    ),
  ],
};
