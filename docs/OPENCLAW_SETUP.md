# fiGate 與 OpenClaw 配合說明

版本：`Beta 0.1`

## 1. 目標

本文件說明如何讓 fiGate 將 iMessage 訊息轉發到 OpenClaw，並把回覆再送回 iMessage。

## 2. 通訊方式

fiGate 會將接收到的訊息透過 HTTP POST 送到 OpenClaw webhook。

預設 endpoint：

```text
http://127.0.0.1:18789/hooks/wake
```

Header：

```text
Content-Type: application/json
Authorization: Bearer <token>
```

Payload：

```json
{
  "source": "+15551234567",
  "text": "build ios",
  "mode": "now"
}
```

## 3. fiGate 設定

在 `~/Library/Application Support/fiGate/config.json` 中設定：

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

## 4. OpenClaw 端要求

- OpenClaw Gateway 必須在本機運行
- Webhook endpoint 必須可被 fiGate 存取
- token 必須與 fiGate 設定一致

## 5. 典型流程

```text
iPhone -> iMessage -> fiGate -> OpenClaw -> fiGate -> iMessage
```

### 流程細節

1. 使用者從 iPhone 發送一條 iMessage
2. fiGate 輪詢 `chat.db` 並偵測新訊息
3. fiGate 驗證來源是否在允許列表中
4. fiGate 先回一條 `[fiGate]Recieved.(MM-DD HH:MM)`
5. fiGate 將訊息轉發到 OpenClaw
6. OpenClaw 返回文字結果
7. fiGate 將 OpenClaw 的文字回覆重新送回 iMessage

## 6. 驗證方式

1. 啟動 OpenClaw
2. 啟動 fiGate
3. 在 `Sources` 中加入你的測試來源
4. 發送一條不以 `[fiGate]` 開頭的訊息
5. 檢查：
   - 是否收到 `[fiGate]Recieved.(MM-DD HH:MM)`
   - `Logs` 中是否出現轉發紀錄
   - OpenClaw 是否收到 webhook

## 7. 常見錯誤

### token 缺失

- 現象：Dashboard 顯示 `Needs external system token`
- 處理：補上 `openclaw_token`

### endpoint 無法連線

- 現象：`error.log` 出現連線錯誤
- 處理：確認 OpenClaw 是否已在 `127.0.0.1:18789` 啟動

### 收到確認回覆但沒有外部回覆

- 現象：只收到 `[fiGate]Recieved...`
- 處理：
  - 檢查 OpenClaw 是否正常運行
  - 檢查 token 是否正確
  - 檢查 webhook 回傳內容是否為文字

## 8. 聯繫方式

- 作者：`f`
- 郵件：`feawea@gmail.com`
