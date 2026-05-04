# MCP Gateway ハンズオン — Azure API Management × API Center × MCP

> **レベル**: L300（中級〜上級）  
> **所要時間**: コア約5時間45分 ＋ オプション1時間

Azure API Management を MCP Gateway、API Center を MCP Server Registry として活用し、AIエージェントが業務ツールに安全にアクセスする基盤を構築するハンズオンワークショップです。

## 🎯 学習目標

- REST API を APIM で MCP Server（Tool）として公開する
- 既存 MCP Server を APIM 配下に配置しガバナンスを適用する
- Entra ID 認証・認可ポリシーを設計・実装する
- レート制限・監査ログ・相関IDを設定する
- API Center で MCP Server Registry を構成しメタデータを標準化する
- API Center で Skill を登録し Git 連携で管理する
- API Center Portal から MCP Server を発見・ドキュメント参照する
- VS Code / GitHub Copilot Agent Mode から MCP Server を利用する
- API Center 登録資産を Microsoft Foundry のプライベートカタログとして活用する

## 🚀 ハンズオンを始める

**[→ docs/hands-on.md を開く](docs/hands-on.md)**

## 📂 リポジトリ構成

```
MCP-Gateway-handson/
├── AGENTS.md                      ← AIエージェント向け動作確認指示書
├── knowledge-openapi.json         ← Knowledge API の OpenAPI 定義
├── docs/                          ← ハンズオン手順書・設計資料
│   ├── hands-on.md                ← メイン手順書（Lab 0〜7 + 補足）
│   ├── APIM_MCP_spec.md           ← APIM MCP 仕様メモ
│   ├── layer-c-setup.md           ← Layer C (E2E) セットアップガイド
│   └── images/                    ← スクリーンショット等
├── infra/                         ← Bicep テンプレート
│   ├── main.bicep
│   ├── main.json                  ← ARM テンプレート（Bicep 出力）
│   ├── parameters.json
│   └── modules/
│       ├── apim.bicep
│       ├── api-center.bicep
│       ├── container-apps.bicep
│       └── acr.bicep
├── src/
│   ├── knowledge-api/             ← Lab 1 用 REST API (Node.js / port 3000)
│   ├── incident-mcp-server/       ← Lab 2 用 MCP Server (Node.js / port 3001)
│   └── oncall-api/                ← Lab 1 用 REST API (Node.js / port 3002)
├── policies/                      ← APIM ポリシー XML サンプル
│   ├── auth-user-delegated.xml    ← Lab 3: ユーザー代理実行
│   ├── auth-service-identity.xml  ← Lab 3: サービスID実行
│   ├── rate-limit.xml             ← Lab 4: レート制限
│   └── security-origin.xml        ← Lab 4: Origin 検証
└── .github/
    └── workflows/
        └── layer-c.yml            ← E2E 自動テスト（Azure OIDC）
```

## 🗺️ Lab 一覧

| Lab | タイトル | 所要時間 |
|---|---|---|
| Lab 0 | 環境構築・アーキテクチャ概観 | 30分 |
| Lab 1 | REST API を MCP Server として公開 | 60分 |
| Lab 2 | 既存 MCP Server を APIM 経由で公開 | 60分 |
| Lab 3 | 認証・認可 — ユーザー代理実行とサービスID実行 | 60分 |
| Lab 4 | ガバナンス・レート制限・監査ログ | 60分 |
| Lab 5 | API Center で MCP Server Registry を構築 | 45分 |
| Lab 6 | API Center で Skill を登録 | 30分 |
| Lab 7 | API Center Portal で MCP Server を発見 | 25分 |
| 補足1 | API Center 登録資産を Microsoft Foundry のプライベートカタログとして活用 | 参考 |

## 🛤️ 学習パス

| パス | 対象者 | Lab | 時間 |
|---|---|---|---|
| A | API開発者（MCP初学者） | 0→1→2→5→6→7 | 4時間10分 |
| B | クラウドアーキテクト | 0→1→2→3→4→5 | 5時間15分 |
| C | セキュリティエンジニア | 0→1→3→4 | 3時間30分 |
| D | フルコース | 0→1→2→3→4→5→6→7 | 6時間10分 |

## 🚀 クイックスタート

```bash
# 1. クローン
git clone https://github.com/ketana0224/MCP-Gateway-handson.git
cd MCP-Gateway-handson

# 2. ローカル動作確認（Azure なし）
( cd src/knowledge-api       && npm install && npm start )  # http://localhost:3000
( cd src/incident-mcp-server && npm install && npm start )  # http://localhost:3001
( cd src/oncall-api          && npm install && npm start )  # http://localhost:3002

# 3. Azure にログイン
az login

# 4. parameters.json の apimPublisherEmail を実在メールアドレスに変更してからデプロイ
az group create -n rg-mcp-workshop -l japaneast
az deployment group create \
  --resource-group rg-mcp-workshop \
  --template-file infra/main.bicep \
  --parameters infra/parameters.json

# 5. ハンズオン開始
# docs/hands-on.md を参照
```

> ⚠️ APIM Developer SKU のプロビジョニングには **15〜20分** かかります。

## 📋 前提条件

- Azure サブスクリプション（Contributor 権限）
- Azure CLI 2.60+
- Node.js 20+
- VS Code + GitHub Copilot 拡張機能
- npx（MCP Inspector 起動用）

## 📖 関連資料

| リソース | URL |
|---|---|
| APIM MCP 概要 | https://learn.microsoft.com/azure/api-management/mcp-server-overview |
| REST API を MCP 公開 | https://learn.microsoft.com/azure/api-management/export-rest-mcp-server |
| 既存 MCP Server を公開 | https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server |
| API Center MCP Registry | https://learn.microsoft.com/azure/api-center/register-discover-mcp-server |
| MCP 仕様 | https://modelcontextprotocol.io/specification/2025-06-18 |
| AI Gateway サンプル集 | https://github.com/Azure-Samples/ai-gateway |

## 📄 ライセンス

MIT
