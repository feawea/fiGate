# fiGate

Version: `Beta 0.1`

## Download

直接下載：

- [Download DMG](https://github.com/feawea/fiGate/raw/main/dist/fiGate-Beta-0.1.dmg)
- [Download ZIP](https://github.com/feawea/fiGate/raw/main/dist/fiGate-Beta-0.1.zip)

檔案位置：

- `dist/fiGate-Beta-0.1.dmg`
- `dist/fiGate-Beta-0.1.zip`

fiGate 是一個運行在 macOS 上的 iMessage Gateway。

它的責任很單純：從本地 Messages 資料庫讀取訊息、提取文字內容與來源資訊、轉發到外部系統，並在取得回覆後透過 iMessage 回送結果。

fiGate 不是 AI 系統，也不在本機進行 AI 推理。它是訊息閘道，不是語義引擎。

對 OpenClaw 來說，fiGate 的價值在於把 `iMessage` 變成一個可直接使用的入口，替代常見的 `Telegram Bot` 方案。你不需要另外維護一個 Telegram 機器人，也不需要改變日常溝通習慣，而是直接用 iPhone 上原本就會使用的 iMessage，把訊息送進 OpenClaw，再把執行結果回傳到同一個對話裡。

簡單說，fiGate 是「用 iMessage 來使用 OpenClaw」的橋樑。

## 核心流程

```text
iPhone
  ↓
iMessage
  ↓
fiGate
  ↓
AI 或自動化系統
  ↓
fiGate
  ↓
iMessage
```

## 核心定位

- fiGate 負責訊息讀取、提取、過濾、轉發、回傳
- AI Agent、Webhook、OpenClaw 或自動化腳本負責決策與執行
- fiGate 本身不做 AI reasoning
- 它特別適合用來替代 Telegram，讓 OpenClaw 直接接入 iMessage 工作流

## 為什麼用 iMessage 取代 Telegram

- 不需要額外建立或維護 Telegram Bot
- 對 Apple 使用者來說，iMessage 是更自然、更低摩擦的入口
- 指令、回覆、確認訊息都留在既有的 Messages 對話中
- 當 OpenClaw 需要一個簡單可靠的遠端入口時，iMessage 比額外引入聊天平台更直接
- 對個人自動化場景來說，fiGate 的目標就是「用 iMessage 來驅動 OpenClaw」

## 核心功能

### 1. iMessage 訊息監聽

fiGate 會定期掃描：

```text
~/Library/Messages/chat.db
```

並提取：

- 訊息文字
- 發送者
- 訊息時間
- 是否為自己送出的訊息

### 2. 訊息來源過濾

只有允許列表中的來源會被處理。支援：

- 手機號碼
- Apple ID / Email

### 3. 訊息轉發

新訊息會被轉發給外部系統。外部系統可以是：

- OpenClaw
- AI Agent Gateway
- 一般 Webhook
- 本地自動化程式

目前專案內建的預設 adapter 是 OpenClaw webhook client，但 `GatewayRunner` 已改為依賴通用的 external relay 介面，因此可以擴充成其他外部系統。

### 4. 自動回覆 iMessage

當外部系統回傳文字結果後，fiGate 會透過 `Messages` 應用程式與 AppleScript 自動發送回覆。

## Input / Output

### Input

- iMessage 文字訊息
- 使用者設定
  - allowed sources
  - polling interval
  - external system endpoint
  - access token

### Output

- 結構化訊息事件
- 外部系統轉發請求
- iMessage 自動回覆

## 專案結構

### Shared Core

- `fiGateCore`
  - `MessageListener`
  - `SourceFilter`
  - `PollingEngine`
  - `GatewayRunner`
  - `OpenClawClient`
  - `MessageSender`
  - `ConfigManager`
  - `Logger`

### Native macOS App Structure

- `fiGate.app`
  - 單一常駐式 SwiftUI app
  - 啟動後直接在 app 內執行 gateway polling / reply runtime
  - 關閉 dashboard 視窗後仍可透過選單列保持常駐
- `fiGateCore`
  - 共用核心邏輯仍保留在本地 Swift package

## Xcode 使用方式

請打開：

- `fiGate.xcodeproj`

不要只打開 package root，否則你拿到的是 Swift Package 視圖，而不是完整的 macOS app 專案結構。

使用方式：

1. 選擇 `fiGate` scheme
2. Destination 選 `My Mac`
3. Run

## 設定檔

執行期設定位置：

```text
~/Library/Application Support/fiGate/config.json
```

範例設定：

```json
{
  "poll_interval": 15,
  "chat_db": "~/Library/Messages/chat.db",
  "openclaw_endpoint": "http://127.0.0.1:18789/hooks/wake",
  "openclaw_token": "replace-with-token",
  "allowed_sources": [
    "+15551234567",
    "tester@example.com"
  ]
}
```

雖然欄位名稱目前沿用 `openclaw_*`，但其角色已經被整理為「外部系統 webhook 設定」。

## 權限要求

fiGate 需要以下 macOS 權限：

- Full Disk Access
  - 讀取 `~/Library/Messages/chat.db`
- Automation
  - 控制 `Messages` 以發送回覆

## 目前已完成

- SQLite 讀取 iMessage 資料庫
- 輪詢式新訊息偵測
- 來源 allowlist 過濾
- 外部系統 webhook 轉發
- iMessage 自動回覆
- 日誌檔寫入
- SwiftUI 設定介面
- 原生 Xcode 單 app 常駐結構

## Build / Generate

Swift package build：

```bash
swift build
```

生成 Xcode project：

```bash
./scripts/generate-xcodeproj.sh
```

用 Xcode project build：

```bash
xcodebuild -project fiGate.xcodeproj -scheme fiGate -destination 'platform=macOS' build
```

本機安裝到 `/Applications` 以便穩定測試權限：

```bash
./scripts/install-local.sh
```

如果安裝腳本最後顯示 `Signature: adhoc`，表示目前 Xcode 還沒有使用有效的 Apple Development 簽名。這種 build 常會被 macOS 隱私設定頁拒絕，出現 `Failed to create archivableRepresentation`，需要先在 Xcode 更新開發憑證並為 `fiGate` 指定 Development Team。

生成本機 zip / dmg：

```bash
./scripts/package-local.sh
```

預設會輸出：

- `dist/fiGate-Beta-0.1.zip`
- `dist/fiGate-Beta-0.1.dmg`

## 文件

- `docs/USER_GUIDE.md`
- `docs/OPENCLAW_SETUP.md`

## 作者

- 姓名：`f`
- 郵件：`feawea@gmail.com`

## 專案總結

fiGate 的定位是「訊息閘道」。

它讓 iPhone 可以作為一個遠端入口，透過 iMessage 將指令或文字送入 Mac 上的 AI / 自動化系統，再把結果回傳到原本的 iMessage 對話中。

如果把 Telegram Bot 看成一種常見的 AI / automation 入口，那 fiGate 的目標就是提供一個更貼近 Apple 生態的替代方案：不用 Telegram，而是直接用 iMessage 來接 OpenClaw。

簡單說：

- iPhone 是入口
- fiGate 是通道
- OpenClaw 或其他外部系統負責處理
- iMessage 是回傳介面
