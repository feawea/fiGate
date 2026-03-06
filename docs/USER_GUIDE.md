# fiGate User Guide / fiGate 使用手冊

Version / 版本: `Beta 0.1`

## 1. What fiGate Is / fiGate 是什麼

fiGate is a macOS iMessage gateway for OpenClaw, Apple Messages automation, webhook relays, and Telegram Bot alternative workflows.

fiGate 是一個運行在 macOS 上的 iMessage gateway，適用於 OpenClaw、Apple Messages automation、webhook relay，以及 Telegram Bot 替代工作流。

## 2. Requirements / 使用前準備

- macOS
- Signed in to iMessage / Messages / 已登入 iMessage 或 Messages
- Full Disk Access enabled / 已授予 Full Disk Access
- Automation permission for Messages / 已授予 Messages Automation 權限

## 3. Config File / 設定檔

```text
~/Library/Application Support/fiGate/config.json
```

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

## 4. Startup / 啟動方式

1. Open `fiGate.app` / 打開 `fiGate.app`
2. Review the permission guide on first launch / 首次啟動時檢查權限引導
3. Open Full Disk Access settings / 開啟 Full Disk Access 設定
4. Add `fiGate.app` to Full Disk Access / 將 `fiGate.app` 加入 Full Disk Access
5. Return to fiGate and verify `chat.db Access` is green / 回到 fiGate 並確認 `chat.db Access` 顯示綠色

## 5. Runtime Flow / 執行流程

1. fiGate polls Apple Messages `chat.db` / fiGate 輪詢 Apple Messages 的 `chat.db`
2. fiGate filters unauthorized senders / fiGate 過濾未授權來源
3. fiGate sends an acknowledgement reply / fiGate 先發送確認回覆
4. fiGate forwards the message to OpenClaw or another webhook / fiGate 將訊息轉發到 OpenClaw 或其他 webhook
5. fiGate sends the returned reply back through iMessage / fiGate 再將回覆內容送回 iMessage

## 6. Reply Rules / 回覆規則

- fiGate auto-replies are prefixed with `[fiGate] `  
  fiGate 的自動回覆會帶 `[fiGate] ` 前綴
- Messages starting with `[fiGate]` are ignored to avoid loops  
  以 `[fiGate]` 開頭的訊息會被忽略，以避免形成回圈
- New incoming messages receive:  
  新入站訊息會先收到：

```text
[fiGate]Recieved.(MM-DD HH:MM)
```

## 7. Dashboard Guide / Dashboard 判讀

- `Gateway Status`  
  Shows whether fiGate has enough configuration to relay messages  
  顯示 fiGate 是否具備足夠設定來轉發訊息
- `Gateway Runtime`  
  Shows whether the resident single-app runtime is active  
  顯示單一常駐 runtime 是否正在運行
- `chat.db Access`  
  Green means the Apple Messages database is readable  
  綠色表示 Apple Messages 資料庫可讀
- `Recent Database Messages`  
  Shows the latest 2 messages read from `chat.db`  
  顯示最近 2 條從 `chat.db` 讀出的訊息

## 8. Logs / 日誌

```text
~/Library/Application Support/fiGate/logs/
```

- `gateway.log`
- `message.log`
- `error.log`

## 9. Contact / 聯繫方式

- Author / 作者: `f`
- Email / 郵件: `feawea@gmail.com`
