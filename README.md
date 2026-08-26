# KTAK V1.7 Online 修正版

更新既有 V1.6：
1. Supabase SQL Editor 執行 `V1_7_SUPABASE_PATCH.sql`
2. GitHub 只覆蓋 `index.html`、`sw.js`、`manifest.webmanifest`
3. 不要覆蓋你已經填好連線資訊的 `config.js`

修正：
- 加入房間 room_id ambiguous
- 建立者可刪除整個房間並釋放房號
- iOS 戰術板長按停用系統複製/選取 Callout
