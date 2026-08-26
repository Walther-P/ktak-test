# KTAK V1.6 Online — Supabase 設定

這個版本已經是跨裝置架構；但在部署前要先建立一個 Supabase 專案並填入兩個公開連線值。

## 1. 建立 Supabase Project
登入 Supabase，建立一個新 Project。

## 2. 開啟 Anonymous Sign-Ins
在 Supabase Dashboard 的 Authentication / Auth 設定中，開啟：
`Allow anonymous sign-ins`

KTAK 不要求每名隊員建立 Email 帳號；每個瀏覽器會取得自己的匿名 Auth UID。

## 3. 執行資料庫設定
開啟：
`SQL Editor`

把本資料夾的：
`SUPABASE_SETUP.sql`

整份貼上並執行。

它會建立：
- 房間
- 成員 / 角色
- 任務簡報
- 地圖物件
- 戰術板樓層與物件
- 聊天訊息
- 私有聊天室照片 bucket
- RLS 權限
- Realtime publication

## 4. 取得 Project URL + Publishable Key
到 Project 的 Connect / API Keys 頁面取得：
- Project URL，例如 `https://xxxx.supabase.co`
- Publishable key，例如 `sb_publishable_...`

只使用 Publishable key。
不要把 Secret key / service_role 放進網頁。

## 5. 編輯 config.js
把：

SUPABASE_URL: "YOUR_SUPABASE_URL"
SUPABASE_PUBLISHABLE_KEY: "YOUR_SUPABASE_PUBLISHABLE_KEY"

改成你的值。

## 6. 上傳 GitHub Pages
把 V1.6 資料夾內所有檔案覆蓋原 GitHub repository 根目錄並 Commit。
Pages 不需要重新設定。

## 7. 跨裝置測試
手機 A：
- 建立房間
- 房號 TEST01
- 密碼自行設定
- 暱稱 K

手機 B / 電腦：
- 開同一 GitHub Pages 網址
- 加入 TEST01
- 輸入相同密碼
- 選角色

接著測：
- 任務簡報
- 地圖物件
- 地圖照片
- 戰術板
- 聊天文字
- 聊天照片
- 權限變更
- 在線成員

## 安全界線
這版有真正的 Auth、伺服器端房間密碼驗證、RLS 與私有照片 Storage，
比之前的 localStorage prototype 完整很多。
但仍應先視為測試 / 開發版，不代表已完成正式警勤系統所需的資安認證、稽核、裝置管理與部署審查。
