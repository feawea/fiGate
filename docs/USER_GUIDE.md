# fiGate 使用手冊

版本：`Beta 0.1`

## 1. 產品定位

fiGate 是運行在 macOS 上的 iMessage Gateway。

它會定期讀取本地 `~/Library/Messages/chat.db`，提取新訊息內容與來源，轉發給外部系統，再把外部系統生成的文字回覆送回 iMessage。

## 2. 運行前準備

### 系統需求

- macOS
- 已登入 iMessage / Messages
- 已授予 `Full Disk Access`
- 已授予 `Automation -> Messages`

### 設定檔位置

```text
~/Library/Application Support/fiGate/config.json
```

### 範例設定

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

## 3. 啟動方式

1. 打開 `fiGate.app`
2. 首次啟動時確認權限引導頁
3. 點擊 `Open Full Disk Access Settings`
4. 將 `fiGate.app` 加入 `Full Disk Access`
5. 回到 fiGate 並確認 Dashboard 狀態為可讀

## 4. 核心工作流程

1. fiGate 讀取 `chat.db`
2. 過濾不在允許列表中的來源
3. 對符合條件的新訊息發送確認回覆
4. 將訊息轉發到外部系統
5. 如果外部系統返回文字，fiGate 再發送回 iMessage

## 5. 自動回覆規則

- fiGate 的自動回覆會加上 `[fiGate] ` 前綴
- 收到以 `[fiGate]` 開頭的訊息時，fiGate 會忽略，避免形成回圈
- 收到普通新訊息時，fiGate 會先回：

```text
[fiGate]Recieved.(MM-DD HH:MM)
```

## 6. Dashboard 判讀

### Gateway Status

- 顯示目前是否已具備外部系統必要設定

### chat.db Access

- 綠色：目前 app 可讀取 Messages 資料庫
- 紅色：未拿到權限或資料庫不可讀

### Recent Database Messages

- 顯示最近 2 條從本地資料庫讀到的訊息
- `Incoming` 表示入站訊息
- `From Me` 表示由本機帳號送出
- `fiGate` 表示帶有 `[fiGate]` 前綴的自動回覆

## 7. 常見問題

### 能讀到訊息但沒有自動回覆

請先檢查：

- `Sources` 中是否已加入測試來源
- 訊息是否以 `[fiGate]` 開頭
- `Messages` 是否允許 Automation

### Dashboard 顯示無法讀取 `chat.db`

請重新確認：

- `fiGate.app` 是否已加入 `Full Disk Access`
- `chat_db` 路徑是否正確

## 8. 日誌位置

```text
~/Library/Application Support/fiGate/logs/
```

包含：

- `gateway.log`
- `message.log`
- `error.log`

## 9. 聯繫方式

- 作者：`f`
- 郵件：`feawea@gmail.com`
