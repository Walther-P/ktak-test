# KTAK V1.8.2 Online

重點修正
1. 圖片上傳：
   - 桌面版優先使用 createImageBitmap 直接解碼檔案，避免 FileReader/Base64 額外複製。
   - iOS 保留相容性較好的 FileReader fallback。
   - 新增的「地圖照片標示」改存 ktak-object-media，不再把 Base64 圖片塞進 Postgres JSON。
2. 任務地圖：
   - 查看照片改成站內大圖檢視，不再開新分頁。
   - 舊版 dataUrl 照片仍可查看。
3. 戰術板：
   - 新增「查看資訊」。
   - 查看資訊可顯示名稱、備註、建立者及照片。
   - 查看照片改成站內大圖檢視。

既有 V1.8.1 升級
- 不需要再執行 Supabase SQL（V1.8 PATCH 已執行即可）。
- GitHub 覆蓋 index.html、sw.js、manifest.webmanifest。
- 保留現有 config.js。
