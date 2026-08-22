// lib/core/safety/crisis_lines.dart
//
// 各地區求助專線。每一筆都標註來源與查證日期。
// 這些號碼會停用、改號、改時段 — 每半年至少複查一次，
// 並更新 verifiedOn。查不到官方頁面就不要放。
//
// 最後全面查證：2026-08-22

class CrisisLine {
  const CrisisLine({
    required this.name,
    required this.contact,
    required this.description,
    required this.source,
    required this.verifiedOn,
  });

  final String name;
  final String contact;
  final String description;

  /// 官方來源網址
  final String source;

  /// 查證日期 YYYY-MM-DD
  final String verifiedOn;
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
  CrisisRegion.taiwan: [
    CrisisLine(
      name: '安心專線',
      contact: '1925',
      description: '衛福部 24 小時免付費心理諮詢專線。',
      source: 'https://dep.mohw.gov.tw/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '生命線',
      contact: '1995',
      description: '24 小時情緒支持與危機協談。',
      source: 'https://www.life1995.org.tw/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '張老師專線',
      contact: '1980',
      description: '青少年與家庭心理輔導。',
      source: 'https://www.1980.org.tw/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '緊急',
      contact: '119 · 110',
      description: '立即危險：119 救護車、110 警察。',
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.hongKong: [
    CrisisLine(
      name: '撒瑪利亞防止自殺會',
      contact: '2389 2222',
      description: '24 小時情緒支援熱線（廣東話、普通話）。',
      source: 'https://sbhk.org.hk/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'SBHK English line',
      contact: '2389 2223',
      description: '英文情緒支援，週一至五 18:30–22:00。',
      source: 'https://sbhk.org.hk/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '生命熱線',
      contact: '2382 0000',
      description: '24 小時預防自殺熱線。',
      source: 'https://www.sps.org.hk/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '緊急',
      contact: '999',
      description: '立即危險請撥 999。',
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.china: [
    CrisisLine(
      name: '全国心理援助热线',
      contact: '12356',
      description: '国家卫健委统一号码，各地至少每日 18 小时，部分城市 24 小时。',
      source: 'https://www.nhc.gov.cn/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '紧急',
      contact: '120 · 110',
      description: '立即危险：120 急救、110 报警。',
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.japan: [
    CrisisLine(
      name: 'よりそいホットライン',
      contact: '0120-279-338',
      description: '毎日 24 時間、通話無料。',
      source: 'https://www.since2011.net/yorisoi/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'こころの健康相談統一ダイヤル',
      contact: '0570-064-556',
      description: '厚生労働省。受付時間は都道府県により異なる（24 時間ではない）。',
      source:
          'https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/hukushi_kaigo/seikatsuhogo/jisatsu/kokoro_dial.html',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '緊急',
      contact: '119 · 110',
      description: '命の危険があるときは 119 または 110。',
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.korea: [
    CrisisLine(
      name: '자살예방 상담전화',
      contact: '109',
      description: '보건복지부, 24시간. 2024년부터 1393 등을 109로 통합.',
      source: 'https://www.129.go.kr/109',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: '긴급',
      contact: '119 · 112',
      description: '즉각적인 위험이 있을 때 119 또는 112.',
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.singapore: [
    CrisisLine(
      name: 'Samaritans of Singapore',
      contact: '1767',
      description: '24-hour hotline.',
      source: 'https://www.sos.org.sg/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'SOS CareText',
      contact: '9151 1767',
      description: '24-hour WhatsApp text support.',
      source: 'https://www.sos.org.sg/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Emergency',
      contact: '995 · 999',
      description: 'Immediate danger: 995 ambulance, 999 police.',
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.unitedStates: [
    CrisisLine(
      name: '988 Suicide & Crisis Lifeline',
      contact: '988',
      description: 'Call or text 988 — free, confidential, 24/7.',
      source: 'https://988lifeline.org/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Crisis Text Line',
      contact: 'Text HOME to 741741',
      description: 'Free, confidential text support, 24/7.',
      source: 'https://www.crisistextline.org/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Emergency',
      contact: '911',
      description: 'Immediate danger — call 911.',
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.canada: [
    CrisisLine(
      name: '9-8-8 Suicide Crisis Helpline',
      contact: '988',
      description:
          'Call or text 988 — free, bilingual English and French, 24/7/365.',
      source: 'https://988.ca/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Québec · 1-866-APPELLE',
      contact: '1-866-277-3553',
      description: 'Ligne québécoise de prévention du suicide, 24 h/24.',
      source: 'https://suicide.ca/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Emergency',
      contact: '911',
      description: 'Immediate danger — call 911.',
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.unitedKingdom: [
    CrisisLine(
      name: 'Samaritans',
      contact: '116 123',
      description: 'Free to call, 24 hours a day, 365 days a year.',
      source: 'https://www.samaritans.org/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Emergency',
      contact: '999',
      description: 'Immediate danger — call 999.',
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.france: [
    CrisisLine(
      name: 'Numéro national de prévention du suicide',
      contact: '3114',
      description:
          'Gratuit, confidentiel, 24 h/24 et 7 j/7. Piloté par le ministère de la Santé.',
      source: 'https://3114.fr/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Urgence',
      contact: '15 · 112',
      description: 'Danger immédiat : SAMU 15, numéro européen 112.',
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  CrisisRegion.germany: [
    CrisisLine(
      name: 'TelefonSeelsorge',
      contact: '0800 111 0 111',
      description: 'Kostenfrei, anonym, rund um die Uhr.',
      source: 'https://www.telefonseelsorge.de/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'TelefonSeelsorge (2)',
      contact: '0800 111 0 222',
      description: 'Zweite kostenfreie Nummer, ebenfalls 24 Stunden.',
      source: 'https://www.telefonseelsorge.de/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Europaweit',
      contact: '116 123',
      description: 'Europaweit erreichbare Nummer der TelefonSeelsorge.',
      source: 'https://www.telefonseelsorge.de/',
      verifiedOn: '2026-08-22',
    ),
    CrisisLine(
      name: 'Notfall',
      contact: '112',
      description: 'Bei akuter Gefahr 112 anrufen.',
      source: '—',
      verifiedOn: '2026-08-22',
    ),
  ],

  // 使用者自行填入。預設給一個國際目錄，避免完全沒有去處。
  CrisisRegion.custom: [
    CrisisLine(
      name: 'Find a Helpline',
      contact: 'findahelpline.com',
      description:
          '國際求助專線目錄，可依所在國家查詢。International directory of crisis lines.',
      source: 'https://findahelpline.com/',
      verifiedOn: '2026-08-22',
    ),
  ],
};
