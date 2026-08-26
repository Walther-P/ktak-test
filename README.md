# KTAK V1.8.1 Online

修正：
- 修正 V1.8 地圖備註 / 查看資訊 / 滑鼠提示 / 物件照片全部失效的共同根因
- 物件附件 JavaScript 已移回正確 script 區段
- 地圖「查看資訊」可直接顯示備註與附件照片
- 車輛快速選擇：巡邏車、偵防車、警備車，可直接輸入台數
- 裝備快速選擇改成數量模式，依項目顯示面 / 支 / 發 / 台 / 組
- 保留其他車輛與其他裝備自訂名稱、數量、單位

更新既有 V1.8：
1. 不需要再執行新的 Supabase SQL（前提：V1.8 PATCH 已成功執行）
2. GitHub 覆蓋 index.html、sw.js、manifest.webmanifest
3. 不要覆蓋現有 config.js
