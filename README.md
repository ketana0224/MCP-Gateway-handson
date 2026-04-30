# MCP Gateway ハンズオン — Azure API Management × API Center × MCP

> **「社内ITサービスデスク向け AIエージェント基盤の構築」**

Azure API Management を MCP Gateway、API Center を MCP Server Registry として活用し、AIエージェントが業務ツールに安全にアクセスする基盤を構築するハンズオンワークショップです。

## 🎯 学習目標

- REST API を APIM で MCP Server（Tool）として公開する
- 既存 MCP Server を APIM 配下に配置しガバナンスを適用する
- Entra ID 認証・認可ポリシーを設計・実装する
- レート制限・監査ログ・相関IDを設定する
- API Center で MCP Server Registry を構成しメタデータを標準化する
- VS Code / GitHub Copilot Agent Mode から MCP Server を利用する

## 📂 リポジトリ構成

```
MCP-Gateway-handson/
├── docs/                          ← ハンズオン手順書
│   └── hands-on.md
├── infra/                         ← Bicep テンプレート
│   ├── main.bicep
│   ├── parameters.json
│   └── modules/
│       ├── apim.bicep
│       ├── api-center.bicep
│       └── container-apps.bicep
├── src/
│   ├── knowledge-api/             ← Lab 1 用 REST API (Node.js)
│   ├── incident-mcp-server/       ← Lab 2 用 MCP Server (Node.js)
│   └── oncall-api/                ← Lab 1 用 REST API (Node.js)
├── policies/                      ← APIM ポリシー XML サンプル
│   ├── auth-user-delegated.xml
│   ├── auth-service-identity.xml
│   ├── rate-limit.xml
│   └── security-origin.xml
├── queries/                       ← KQL クエリ集
│   └── dashboard.kql
└── .vscode/
    └── mcp.json                   ← Lab 6 用 MCP 設定
```

## 🛤️ 学習パス

| パス | 対象者 | Lab | 時間 |
|---|---|---|---|
| A | API開発者 | 0→1→2→5→6 | 3時間45分 |
| B | クラウドアーキテクト | 0→1→2→3→4→5 | 5時間15分 |
| C | セキュリティ | 0→1→3→4→7 | 4時間30分 |
| D | フルコース | 0→1→2→3→4→5→6→7 | 6時間45分 |

## 🚀 クイックスタート

```bash
# 1. クローン
git clone https://github.com/ketana0224/MCP-Gateway-handson.git
cd MCP-Gateway-handson

# 2. Azure にログイン
az login

# 3. リソースデプロイ
az deployment group create \
  --resource-group rg-mcp-workshop \
  --template-file infra/main.bicep \
  --parameters infra/parameters.json

# 4. ハンズオン開始
# docs/hands-on.md を参照
```

## 📋 前提条件

- Azure サブスクリプション（Contributor 権限）
- Azure CLI 2.60+
- Node.js 20+
- VS Code + GitHub Copilot

## 📖 関連資料

- [APIM MCP 概要](https://learn.microsoft.com/en-us/azure/api-management/mcp-server-overview)
- [API Center MCP Registry](https://learn.microsoft.com/en-us/azure/api-center/register-discover-mcp-server)
- [MCP 仕様](https://modelcontextprotocol.io/specification/2025-06-18)
- [AI Gateway サンプル集](https://github.com/Azure-Samples/ai-gateway)

## 📄 ライセンス

MIT
