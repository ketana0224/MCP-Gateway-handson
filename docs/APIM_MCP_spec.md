# APIM MCP 機能 挙動調査メモ

> 調査日: 2026-05-03  
> 対象環境: `apim-mcp-workshop` (japaneast, Developer SKU)

---

## 概要

Azure API Management の MCP 関連機能には **2種類の登録方式**があり、挙動が大きく異なる。
API Center Portal との組み合わせでは、方式によって動作可否に差がある。

---

## 1. APIM の MCP 登録方式比較

| 項目 | Expose existing MCP server | Expose API as MCP server |
|---|---|---|
| 対象 | 既存 MCP Server（Streamable HTTP 対応） | 既存の REST/OpenAPI |
| Lab | Lab 2（`incident-mcp`） | Lab 1（`knowledge-search-mcp`, `oncall-schedule-mcp`） |
| バックエンド | Container Apps 上の MCP サーバー | APIM が REST → MCP 変換 |
| APIM の役割 | 透過的プロキシ | MCP プロトコル変換レイヤー |
| `mcpProperties` PATCH | 不要（自動設定） | **必要**（プレビュー制限により未設定で作成される） |
| `serverInfo.name` | バックエンドの値（例: `incident-mcp-server`） | `Azure API Management` |
| `X-Powered-By` ヘッダー | `Express`（バックエンド通過の証拠） | なし |

---

## 2. `initialize` レスポンスの差異（実測）

### `incident-mcp`（Expose existing MCP server）✅

```
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
X-Powered-By: Express

event: message
data: {"result":{"protocolVersion":"2025-03-26","capabilities":{"tools":{"listChanged":true}},"serverInfo":{"name":"incident-mcp-server","version":"1.0.0",...}},"jsonrpc":"2.0","id":1}

← ここで HTTP 接続が正常終了（Connection left intact と curl が報告）
```

### `knowledge-search-mcp`（Expose API as MCP server）❌

```
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache,no-store
Content-Encoding: identity          ← incident-mcp にはない

event: message
data: {"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{"listChanged":true}},"serverInfo":{"name":"Azure API Management","version":"1.0.0"}}}

event: close   ← MCP レベルの終了シグナルは送られる
data:
               ← しかし TCP/HTTP 接続は閉じない → curl は 8 秒後にタイムアウト
```

### 差異まとめ

| 項目 | `incident-mcp` | `knowledge-search-mcp` |
|---|---|---|
| HTTP 接続の終了 | **正常終了** | **閉じない**（タイムアウト待ち） |
| `Content-Encoding` | なし | `identity` |
| `Cache-Control` | `no-cache` | `no-cache,no-store` |
| `serverInfo.name` | `incident-mcp-server` | `Azure API Management` |
| SSE 末尾 `event: close` | なし | あり（ただし HTTP は閉じない） |

---

## 3. API Center Portal との互換性

### 動作フロー（期待値）

```
Portal → POST /mcp (initialize)
       ← 200 + event: message (initialize 応答) → HTTP 接続クローズ
Portal → POST /mcp (tools/list)
       ← 200 + event: message (tools 一覧) → HTTP 接続クローズ
Portal → ツール一覧を Documentation タブに表示
```

### 実際の動作

| API | Portal の Documentation タブ | 原因 |
|---|---|---|
| `incident-mcp` | ✅ ツール一覧が表示される | HTTP 接続が正常終了するため Portal が応答完了を検知できる |
| `knowledge-search-mcp` | ❌ ツール一覧が表示されない | `event: close` 後も HTTP 接続が閉じないため Portal がタイムアウト |
| `oncall-schedule-mcp` | ❌ "The MCP server requires authentication, but the server did not provide discovery information." | 認証スキップポリシー未適用 + RFC9728 非準拠の 401 |

---

## 4. 認証まわりの問題（`oncall-schedule-mcp`）

### MCP 仕様（2025-06-18）の MUST 要件

[RFC9728 (OAuth 2.0 Protected Resource Metadata)](https://datatracker.ietf.org/doc/html/rfc9728) に従い、  
認証が必要なサーバーは 401 を返す際に `WWW-Authenticate` ヘッダーを含めなければならない：

```
WWW-Authenticate: Bearer resource_metadata="https://<apim>/.well-known/oauth-protected-resource"
```

MCP クライアント（Portal 含む）はこのフローで認証先を自動発見する：

```
1. MCP リクエスト送信
2. 401 + WWW-Authenticate ヘッダー受信
3. GET /.well-known/oauth-protected-resource
4. レスポンスの authorization_servers から AS URL を取得
5. GET /.well-known/oauth-authorization-server
6. PKCE + OAuth フロー → トークン取得
7. Bearer トークン付きで再リクエスト
```

### APIM の現状

`validate-azure-ad-token` ポリシーが返す 401 には `WWW-Authenticate: Bearer resource_metadata=...` が**含まれない**。

```json
{"statusCode":401,"message":"Unauthorized: Invalid or missing token"}
```

これにより Portal はどこで認証すれば良いか判断できず、  
**"The MCP server requires authentication, but the server did not provide discovery information."** が表示される。

### `knowledge-search-mcp` が従来表示できていた理由

Lab 6 Step 2 で以下のポリシーを適用することで `initialize` / `tools/list` の認証を回避している：

```xml
<choose>
    <when condition="@{
        var body = context.Request.Body.As<JObject>(preserveContent: true);
        var method = body?[&quot;method&quot;]?.ToString();
        return method == &quot;tools/list&quot; || method == &quot;initialize&quot;;
    }">
        <!-- 認証スキップ -->
    </when>
    <otherwise>
        <validate-azure-ad-token .../>
    </otherwise>
</choose>
```

ただし、これは MCP 仕様準拠の解決策ではなく、ホワイトリスト方式の回避策。  
さらに `knowledge-search-mcp` は HTTP 接続が閉じない問題（§3）により、実際には Portal で表示できない状態にある。

---

## 5. Lab 6 Step 2 の対象漏れ

`docs/hands-on.md` の Lab 6 Step 2 では以下の API へのポリシー適用のみ記載：

- ✅ `knowledge-search-mcp`
- ✅ `incident-mcp`
- ❌ **`oncall-schedule-mcp`（記載なし）**

`oncall-schedule-mcp` は Lab 3 Pattern B（サービス ID 認証）のポリシーのみ適用されており、  
`initialize` / `tools/list` のスキップ条件がないため Portal から認証エラーになる。

---

## 6. 問題整理と分類

| # | API | 問題 | 種別 | 回避策 |
|---|---|---|---|---|
| 1 | `knowledge-search-mcp` | HTTP 接続が `event: close` 後に閉じない | **APIM プレビューバグ** | "Expose existing MCP server" 方式に変更 |
| 2 | `oncall-schedule-mcp` | `initialize` が 401（discovery 情報なし） | **docs 漏れ** + APIM 制限 | Lab 6 Step 2 に `oncall-schedule-mcp` のスキップポリシーを追加 |
| 3 | 全 API | APIM の 401 が RFC9728 非準拠 | **APIM 制限**（未実装） | `/.well-known/oauth-protected-resource` エンドポイントを APIM ポリシーで実装 + 401 応答ヘッダーにカスタム `WWW-Authenticate` を追加 |

---

## 7. 完全対応するための理想実装（参考）

MCP 仕様準拠の認証フローを実装するには：

### Step A: Protected Resource Metadata エンドポイントを追加

```
GET /.well-known/oauth-protected-resource
→ {"resource":"https://apim-mcp-workshop.azure-api.net","authorization_servers":["https://login.microsoftonline.com/<tenantId>/v2.0"]}
```

### Step B: 401 応答に WWW-Authenticate ヘッダーを追加

```xml
<on-error>
    <set-header name="WWW-Authenticate" exists-action="override">
        <value>Bearer resource_metadata="https://apim-mcp-workshop.azure-api.net/.well-known/oauth-protected-resource"</value>
    </set-header>
    <base />
</on-error>
```

### Step C: HTTP 接続クローズ問題（要 APIM 修正待ち）

"Expose API as MCP server" 機能が SSE `event: close` 送信後に HTTP 応答を完了させないバグは  
APIM 側の修正が必要。回避策は "Expose existing MCP server" 方式へ変更（バックエンドに MCP SDK 実装が必要）。

---

## 8. 参考リンク

- [MCP Spec 2025-06-18 Authorization](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization)
- [RFC9728: OAuth 2.0 Protected Resource Metadata](https://datatracker.ietf.org/doc/html/rfc9728)
- [APIM Secure MCP Servers](https://learn.microsoft.com/azure/api-management/secure-mcp-servers)
- [APIM × PRM サンプル](https://github.com/blackchoey/remote-mcp-apim-oauth-prm)
- [AI-Gateway MCP PRM Lab](https://github.com/Azure-Samples/AI-Gateway/tree/main/labs/mcp-prm-oauth)
