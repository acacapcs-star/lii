/// 英文月份縮寫，全 App 共用這一份。
///
/// 用縮寫不用全名：'September' 九個字母在窄格子裡會換行，
/// 中文的「九月」兩個字剛好——所以只有英文版會爆。
///
/// 以前月曆和首頁「本月」卡各自寫了一份。月曆改成縮寫之後，
/// 首頁那份還是全名，同一個月在兩個地方長得不一樣。
/// 集中在這裡之後，改一次兩邊都會跟著變。
const kMonthShortEn = [
  'Jan.', 'Feb.', 'Mar.', 'Apr.', 'May', 'Jun.',
  'Jul.', 'Aug.', 'Sep.', 'Oct.', 'Nov.', 'Dec.',
];

String monthShortEn(int month) => kMonthShortEn[month - 1];
