# lii 功能心理學理論依據

> lii 是一個跨領域專案，結合心理學理論、Flutter 行動開發與 UX 設計。
> 本文件說明各功能的心理學依據，目的是確保工具設計有實證基礎，
> 而非憑直覺開發。心理學在此作為設計依據，技術實作為核心產出。

---

## 功能對照表

| lii 功能 | 心理學理論 | 提出者／來源 |
|---------|-----------|------------|
| 情緒詞彙庫 | 情緒粒度（Emotional Granularity） | Lisa Feldman Barrett |
| 4-7-8 呼吸 | 副交感神經調節、呼吸調節焦慮 | Andrew Weil；生理心理學 |
| 5-4-3-2-1 五感回神 | 接地技術（Grounding）、辯證行為治療（DBT） | Marsha Linehan |
| 自我對話卡 | 認知重構（Cognitive Restructuring） | Aaron Beck（CBT） |
| 思考教練 | 蘇格拉底式提問、後設認知（Metacognition） | CBT / ACT |
| 微光每日情緒記錄 | 情緒書寫（Expressive Writing） | James Pennebaker |
| Pacer Lift | 正向錨點、資源狀態（Resource State） | NLP；正向心理學 |
| 睡眠紀錄 | 睡眠與情緒雙向關係 | Matthew Walker |
| 最近的起伏（趨勢圖） | 自我監控（Self-Monitoring） | CBT 行為活化理論 |
| 主動介入（ERS 引擎） | 及時適應性介入（Just-in-Time Adaptive Intervention, JITAI） | 行為健康科技研究 |
| 聊聊（Luna） | 非評斷性傾聽、心理支持可及性 | Carl Rogers 個人中心治療 |

---

## 核心理論說明

### 情緒粒度（Emotional Granularity）
Lisa Feldman Barrett 的研究顯示，能精確命名自己情緒的人，
情緒調節能力顯著優於只能說「開心」或「難過」的人。
lii 的情緒詞彙庫旨在幫助使用者提升情緒粒度，
從「不開心」找到更準確的詞，進而更有效地調節情緒。

> 參考：Barrett, L. F. (2017). *How Emotions Are Made*. Houghton Mifflin Harcourt.

---

### 及時適應性介入（JITAI）
JITAI 是行為健康科技的核心研究方向，
指系統根據使用者當下的狀態，在最適合的時機提供最合適的支援。
lii 的 ERS（情緒風險分數）引擎即實作此概念——
偵測到使用者狀態異常時，主動推送對應層級的介入工具，
而非等待使用者自行開啟 app。

> 參考：Nahum-Shani, I. et al. (2018). Just-in-Time Adaptive Interventions (JITAIs) in Mobile Health. *Health Psychology*, 37(12), 1178–1196.

---

### 認知重構（Cognitive Restructuring）
CBT（認知行為治療）的核心技術之一。
透過識別並挑戰負面自動化思考，將其替換為更平衡的觀點。
lii 的自我對話卡引導使用者把對自己說的負面話，練習換個角度表達。

> 參考：Beck, A. T. (1979). *Cognitive Therapy of Depression*. Guilford Press.

---

### 接地技術（Grounding）／DBT
由 Marsha Linehan 發展的辯證行為治療（DBT）中的情緒調節技術。
5-4-3-2-1 五感回神透過將注意力拉回當下的感官體驗，
中斷反芻思考或恐慌狀態，恢復對當下的覺察。

> 參考：Linehan, M. M. (1993). *Cognitive-Behavioral Treatment of Borderline Personality Disorder*. Guilford Press.

---

## 設計定位

lii 定位為**預防性情緒健康工具**，非臨床診斷或治療工具。
適合有一定自我覺察能力、希望建立日常情緒健康習慣的青少年。
嚴重心理健康問題仍需尋求專業心理師或醫療協助。

技術實作：Flutter（iOS／Android）、AES-256-GCM 加密、ERS 風險引擎。
