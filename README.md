# KTAK V1.9 Online

本版只集中處理三件事：

1. 桌面圖片上傳
   - 桌面先讀取圖片尺寸，再用 createImageBitmap 直接以接近目標尺寸解碼。
   - 上傳時顯示「原始大小 → 壓縮後大小 → 壓縮耗時 → 總耗時」，方便判斷到底慢在壓縮還是網路上傳。

2. 任務地圖
   - 「查看照片（大圖）」固定在 KTAK 站內顯示。
   - 不使用 window.open，不會再開新分頁。
   - 大圖可點一下放大，再點一下縮回。

3. 戰術板
   - 明確保留「查看資訊」。
   - 「查看資訊」可顯示名稱、備註、建立者、附件照片。
   - 「查看照片（大圖）」固定在 KTAK 站內顯示，不開新分頁。

快取處理：
- V1.9 會清除舊 KTAK Service Worker / Cache Storage。
- 因 KTAK 是即時線上多人系統，V1.9 起不再使用離線 HTML shell，避免更新後仍讀到舊版。

升級：
- 不需要新的 Supabase SQL。
- GitHub 覆蓋 index.html、sw.js、manifest.webmanifest。
- 不要覆蓋 config.js。
- 部署後第一次請用網址尾端加 ?v=1.9 開啟，例如 https://你的網址/?v=1.9
