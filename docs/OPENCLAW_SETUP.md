# fiGate + OpenClaw Setup / fiGate 與 OpenClaw 配合說明

Version / 版本: `Beta 0.1`

## 1. Purpose / 目標

This guide explains how to use fiGate as a macOS iMessage gateway for OpenClaw, Apple Messages automation, and Telegram Bot alternative workflows.

本文件說明如何把 fiGate 用作 OpenClaw、Apple Messages automation，以及 Telegram Bot 替代工作流的 macOS iMessage gateway。

## 2. Relay Model / 通訊模型

fiGate forwards approved iMessages to OpenClaw through an HTTP webhook.

fiGate 會透過 HTTP webhook，把符合條件的 iMessage 轉發到 OpenClaw。

Default endpoint / 預設端點：

```text
http://127.0.0.1:18789/hooks/wake
```

Headers / Header：

```text
Content-Type: application/json
Authorization: Bearer <token>
```

Payload / 請求內容：

```json
{
  "source": "+15551234567",
  "text": "build ios",
  "mode": "now"
}
```

## 3. fiGate Config / fiGate 設定

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

## 4. OpenClaw Requirements / OpenClaw 端要求

- OpenClaw Gateway must be running locally  
  OpenClaw Gateway 必須在本機運行
- The webhook endpoint must be reachable from fiGate  
  webhook endpoint 必須可被 fiGate 存取
- The token must match the one configured in fiGate  
  token 必須與 fiGate 設定一致

## 5. Typical Flow / 典型流程

```text
iPhone -> iMessage -> fiGate -> OpenClaw -> fiGate -> iMessage
```

1. A user sends an iMessage from iPhone / 使用者從 iPhone 發送 iMessage
2. fiGate detects the new message in Apple Messages `chat.db` / fiGate 在 Apple Messages `chat.db` 中偵測新訊息
3. fiGate validates the sender against the allowlist / fiGate 依允許列表驗證來源
4. fiGate sends `[fiGate]Recieved.(MM-DD HH:MM)` / fiGate 先回 `[fiGate]Recieved.(MM-DD HH:MM)`
5. fiGate forwards the message to OpenClaw / fiGate 將訊息轉發到 OpenClaw
6. OpenClaw returns a text reply / OpenClaw 回傳文字結果
7. fiGate sends that reply back through iMessage / fiGate 再把回覆內容送回 iMessage

## 6. Verification / 驗證方式

1. Start OpenClaw / 啟動 OpenClaw
2. Start fiGate / 啟動 fiGate
3. Add your sender to `Sources` / 在 `Sources` 中加入測試來源
4. Send a message that does not start with `[fiGate]` / 發送一條不以 `[fiGate]` 開頭的訊息
5. Verify the acknowledgement and OpenClaw reply / 確認收到確認回覆與 OpenClaw 回覆

## 7. Common Issues / 常見問題

- Missing token / 缺少 token  
  Add `openclaw_token` / 補上 `openclaw_token`
- Endpoint unreachable / endpoint 無法連線  
  Confirm OpenClaw is running at `127.0.0.1:18789` / 確認 OpenClaw 已在 `127.0.0.1:18789` 啟動
- Ack arrives but no OpenClaw reply / 有確認回覆但沒有 OpenClaw 回覆  
  Check OpenClaw health, token, and webhook response body / 檢查 OpenClaw 狀態、token 與 webhook 回傳內容

## 8. Contact / 聯繫方式

- Author / 作者: `f`
- Email / 郵件: `feawea@gmail.com`
