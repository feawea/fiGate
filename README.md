# fiGate

Version / 版本: `Beta 0.1`

## Download / 下載

Direct downloads / 直接下載：

- [Download DMG](https://github.com/feawea/fiGate/raw/main/dist/fiGate-Beta-0.1.dmg)
- [Download ZIP](https://github.com/feawea/fiGate/raw/main/dist/fiGate-Beta-0.1.zip)

Packaged files / 封裝檔案：

- `dist/fiGate-Beta-0.1.dmg`
- `dist/fiGate-Beta-0.1.zip`

## Overview / 簡介

fiGate is a macOS iMessage gateway for OpenClaw, Apple Messages automation, AI agent workflows, and Telegram Bot alternative setups. It reads incoming iMessages from the local Messages database, forwards approved messages to OpenClaw or other webhook-based systems, and sends the returned reply back through iMessage.

fiGate 是一個運行在 macOS 上的 iMessage gateway，適合用於 OpenClaw、Apple Messages automation、AI agent 工作流，以及 Telegram Bot 替代方案。它會從本地 Messages 資料庫讀取新訊息，將符合條件的 iMessage 轉發到 OpenClaw 或其他以 webhook 為基礎的系統，再把回覆結果透過 iMessage 送回原對話。

fiGate is not an AI model and does not perform reasoning locally. It is the transport layer between iMessage and OpenClaw.

fiGate 不是 AI 系統，也不在本機進行推理。它的定位是連接 iMessage 與 OpenClaw 的訊息通道。

## Why fiGate / 為什麼是 fiGate

- Use iMessage as a natural Apple-native entry point for OpenClaw and AI automation.  
  用 iMessage 作為更自然的 Apple 生態入口，連接 OpenClaw 與 AI automation。
- Replace Telegram Bot workflows with Apple Messages when you want a simpler private control channel.  
  當你想要更簡單、更私有的控制通道時，可用 Apple Messages 取代 Telegram Bot 工作流。
- Keep commands, confirmations, and replies inside the same iMessage conversation.  
  讓指令、確認訊息與回覆都留在同一個 iMessage 對話中。
- Bridge iPhone, iMessage, macOS, OpenClaw, and webhook automation with minimal moving parts.  
  以最少的中介層串起 iPhone、iMessage、macOS、OpenClaw 與 webhook automation。

## Core Flow / 核心流程

```text
iPhone
  ↓
iMessage
  ↓
fiGate
  ↓
OpenClaw / AI Agent / Webhook Automation
  ↓
fiGate
  ↓
iMessage
```

## Positioning / 核心定位

- fiGate handles message ingestion, extraction, filtering, forwarding, and reply delivery.  
  fiGate 負責訊息讀取、提取、過濾、轉發與回傳。
- OpenClaw, AI agents, webhooks, or automation scripts handle execution and decision-making.  
  OpenClaw、AI agents、webhook 或自動化腳本負責執行與決策。
- fiGate is intentionally designed as an iMessage-first alternative to a Telegram Bot command channel.  
  fiGate 刻意被設計成以 iMessage 為核心、可替代 Telegram Bot 指令通道的方案。

## Core Features / 核心功能

### 1. iMessage Listener / iMessage 訊息監聽

fiGate polls the local Apple Messages database:

fiGate 會定期輪詢本地 Apple Messages 資料庫：

```text
~/Library/Messages/chat.db
```

It extracts message text, sender, timestamps, and message direction.

它會提取訊息文字、發送者、時間戳，以及訊息方向。

### 2. Source Filtering / 訊息來源過濾

Only approved phone numbers, Apple IDs, or email addresses can trigger the gateway.

只有允許列表中的電話號碼、Apple ID 或電子郵件地址才可以觸發 gateway。

### 3. Message Forwarding / 訊息轉發

Approved messages are forwarded to OpenClaw or another external webhook-based system.

符合條件的訊息會被轉發到 OpenClaw 或其他外部 webhook 系統。

### 4. Automatic iMessage Reply / 自動回覆 iMessage

fiGate sends reply text back through Apple Messages using AppleScript.

fiGate 會透過 AppleScript 與 Apple Messages 將回覆文字送回 iMessage。

## Input / Output / 輸入輸出

### Input / 輸入

- iMessage text messages / iMessage 文字訊息
- Allowed source configuration / 允許來源設定
- Polling interval / 輪詢間隔
- OpenClaw endpoint and token / OpenClaw 端點與 token

### Output / 輸出

- Structured message events / 結構化訊息事件
- OpenClaw or webhook relay requests / OpenClaw 或 webhook 轉發請求
- iMessage replies / iMessage 回覆

## Project Structure / 專案結構

### fiGateCore

- `MessageListener`
- `SourceFilter`
- `PollingEngine`
- `GatewayRunner`
- `OpenClawClient`
- `MessageSender`
- `ConfigManager`
- `Logger`

### fiGate.app

- Single-app resident SwiftUI macOS app / 單一常駐式 SwiftUI macOS app
- Polls iMessage and sends replies inside the same app process / 在同一個 app 程序內輪詢 iMessage 並發送回覆
- Keeps running from the menu bar even after the main window closes / 主視窗關閉後仍可從選單列保持常駐

## Xcode / Xcode 使用方式

Open / 請打開：

- `fiGate.xcodeproj`

Do not open only the package root if you want the full macOS app project.

如果你要的是完整 macOS app 專案，請不要只打開 package root。

## Runtime Config / 執行期設定

Config path / 設定檔位置：

```text
~/Library/Application Support/fiGate/config.json
```

Sample config / 範例設定：

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

## Permissions / 權限要求

- Full Disk Access  
  Required to read `~/Library/Messages/chat.db`  
  需要用來讀取 `~/Library/Messages/chat.db`
- Automation  
  Required to control Apple Messages for sending replies  
  需要用來控制 Apple Messages 發送回覆

## Build / Build 與打包

Swift package build:

```bash
swift build
```

Generate the Xcode project:

```bash
./scripts/generate-xcodeproj.sh
```

Build with Xcode project:

```bash
xcodebuild -project fiGate.xcodeproj -scheme fiGate -destination 'platform=macOS' build
```

Install locally to `/Applications`:

```bash
./scripts/install-local.sh
```

Create local DMG and ZIP:

```bash
./scripts/package-local.sh
```

## Documentation / 文件

- `docs/USER_GUIDE.md`
- `docs/OPENCLAW_SETUP.md`

## Author / 作者

- Name / 姓名: `f`
- Email / 郵件: `feawea@gmail.com`

## Summary / 總結

fiGate turns iMessage into a practical OpenClaw control channel on macOS. If Telegram Bot is a common remote automation entry point, fiGate is the Apple-native alternative: use iMessage instead of Telegram, connect it to OpenClaw, and keep the full loop inside Apple Messages.

fiGate 讓 iMessage 成為一個實用的 OpenClaw 控制通道。如果說 Telegram Bot 是一種常見的遠端自動化入口，那 fiGate 就是更貼近 Apple 生態的替代方案：不用 Telegram，而是直接用 iMessage 連接 OpenClaw，並把整個來回流程保留在 Apple Messages 裡。
