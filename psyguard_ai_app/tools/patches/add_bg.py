"""新增三個背景選項：浪漫粉、彩虹、純黑簡約。

在 psyguard_ai_app 目錄下執行。
"""
import sys, os

P = 'lib/core/theme/background_theme_service.dart'
if not os.path.exists(P):
    print('x 找不到', P, '-- 請在 psyguard_ai_app 目錄下執行')
    sys.exit(1)

s = open(P).read()

if 'pinkLight' in s:
    print('. 已經加過了')
    sys.exit(0)

n = 0

# ── 1. enum ──
old = 'enum BgColorChoice { blueLight, greenLight, navyDark, forestDark }'
new = ('// 前四個是淺色模式可選，後三個是深色模式\n'
       'enum BgColorChoice {\n'
       '  blueLight, greenLight, pinkLight, rainbowLight,\n'
       '  navyDark, forestDark, pureBlack,\n'
       '}')
if old in s:
    s = s.replace(old, new, 1)
    n += 1
    print('v enum 已加三個')
else:
    print('x 找不到 enum 定義')
    sys.exit(1)

# ── 2. 顏色 ──
old2 = """      case BgColorChoice.blueLight:
        return const Color(0xFFF2F7FF);"""
new2 = """      case BgColorChoice.blueLight:
        return const Color(0xFFF2F7FF);
      case BgColorChoice.pinkLight:
        // 浪漫粉：很淡的玫瑰色，卡片放上去還看得清楚
        return const Color(0xFFFDF2F6);
      case BgColorChoice.rainbowLight:
        // 彩虹：底色取最淡的那一端。
        // 全彩當背景會蓋過所有內容，所以只留一點暈染。
        return const Color(0xFFFBF4FA);
      case BgColorChoice.pureBlack:
        // 純黑簡約：不是全黑，留一點點灰。
        // 全黑在 OLED 上跟關機沒兩樣，卡片的邊界會完全消失。
        return const Color(0xFF070707);"""
if old2 in s:
    s = s.replace(old2, new2, 1)
    n += 1
    print('v 顏色已定義')
else:
    print('! 找不到 bgColor 的 blueLight -- 顏色要手動加')

# ── 3. 儲存 ──
old3 = """      case 'greenLight':
        colorChoice = BgColorChoice.greenLight;"""
new3 = """      case 'greenLight':
        colorChoice = BgColorChoice.greenLight;
        break;
      case 'pinkLight':
        colorChoice = BgColorChoice.pinkLight;
        break;
      case 'rainbowLight':
        colorChoice = BgColorChoice.rainbowLight;
        break;
      case 'pureBlack':
        colorChoice = BgColorChoice.pureBlack;"""
if old3 in s:
    s = s.replace(old3, new3, 1)
    n += 1
    print('v 儲存已支援')
else:
    print('! 找不到讀取的 switch -- 重開 App 可能不會記住新選項')

open(P, 'w').write(s)
print()
print('完成，改了', n, '處')
print()
print('下一步：跑 flutter analyze，')
print('其他用到 BgColorChoice 的 switch 也要補上新的 case。')
print('把錯誤訊息貼給 Claude。')
