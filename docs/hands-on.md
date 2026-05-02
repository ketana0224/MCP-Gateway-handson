# Azure API Management × API Center × MCP ハンズオンワークショップ

## 「AIエージェント基盤-MCP関連の構築」

> **レベル**: L300（中級～上級）  
> **所要時間**: コア約5時間45分 ＋ オプション1時間  
> **最終更新**: 2026-04-30

---

## 📋 目次

- [ワークショップ概要](#ワークショップ概要)
- [前提条件](#前提条件)
- [全体アーキテクチャ](#全体アーキテクチャ)
- [Lab 0: 環境構築・アーキテクチャ概観（30分）](#lab-0-環境構築アーキテクチャ概観30分)
- [Lab 1: REST API を MCP Server として公開（60分）](#lab-1-rest-api-を-mcp-server-として公開60分)
- [Lab 2: 既存 MCP Server を APIM 経由で公開（60分）](#lab-2-既存-mcp-server-を-apim-経由で公開60分)
- [Lab 3: 認証・認可 — ユーザー代理実行とサービスID実行（60分）](#lab-3-認証認可--ユーザー代理実行とサービスid実行60分)
- [Lab 4: ガバナンス・レート制限・監査ログ（60分）](#lab-4-ガバナンスレート制限監査ログ60分)
- [Lab 5: API Center で MCP Server Registry を構築（45分）](#lab-5-api-center-で-mcp-server-registry-を構築45分)
- [Lab 6: VS Code / GitHub Copilot からの利用（30分）](#lab-6-vs-code--github-copilot-からの利用30分)
- [Lab 7: セキュリティ深掘り（オプション・60分）](#lab-7-セキュリティ深掘りオプション60分)
- [対象者別 学習パス](#対象者別-学習パス)
- [参考資料](#参考資料)

---

## ワークショップ概要

### テーマ

任意のAIエージェント（このワークショップでは、社内ITサービスデスクで利用されるAIエージェント）が、**Remote MCP Server**(このワークショップでは、**社内ナレッジ検索**・**障害チケット起票**・**オンコール確認**など)の業務ツールに安全にアクセスできる基盤を、Azure API Management（APIM）と API Center を使って構築します。

### 学習目標

このワークショップを完了すると、以下ができるようになります。

1. REST API を APIM で MCP Server（Tool）として公開する
2. 既存の MCP Server を APIM の背後に配置しガバナンスを適用する
3. Entra ID を使った認証・認可ポリシーを設計・実装する
4. MCP Gateway のレート制限・監査ログ・相関IDを設定する
5. API Center を MCP Server Registry として構成し、メタデータを標準化する
6. VS Code / GitHub Copilot の Agent mode から MCP Server を利用する

### ビジネスシナリオ

```
あなたは社内プラットフォームチームのエンジニアです。
各業務チームが開発したAPIやMCP Serverを、
AIエージェントが安全に利用できるよう基盤を整備する任務を負っています。

今回のワークショップでは、以下の3つの業務システムを対象とします。

  📚 Knowledge Search API   — 社内ナレッジベースの検索（REST API）
  🎫 Incident MCP Server   — 障害チケットの参照・起票（既存MCP Server）
  📞 On-call Schedule API   — 当番表の参照（REST API）
```

---

## 前提条件

### 参加者の前提知識

| 区分 | 内容 |
|---|---|
| **必須** | Azure portal 基本操作、REST / JSON の基礎、OAuth 2.0 / Entra ID の概念理解 |
| **推奨** | APIM policy XML の読み書き、VS Code / GitHub Copilot の利用経験、Azure CLI / Bicep の基本 |

### 必要なソフトウェア

```
- Azure CLI 2.60 以上
- Node.js 20 以上 または Python 3.11 以上
- VS Code + GitHub Copilot 拡張機能
- MCP Inspector（公式デバッグツール）
- Git
```

### 必要な Azure リソース

| リソース | SKU | 用途 | 概算コスト |
|---|---|---|---|
| Azure API Management | Developer | MCP Gateway | 無料 |
| Azure API Center | Free | MCP Server Registry | 無料 |
| Azure Container Apps | Consumption | MCP Server / バックエンド API ホスト | $5〜$20/月 |
| Azure Container Registry | Basic | コンテナイメージ管理・ビルド | $5〜$10/月 |
| Microsoft Entra ID | Free Tier | OAuth 2.0 認証基盤 | 無料 |
| Application Insights | Pay-as-you-go | 監査ログ・トレーシング | $5〜$15/月 |
| Log Analytics Workspace | Pay-as-you-go | KQL クエリ基盤 | 上記に含む |
| Azure Key Vault | Standard | シークレット管理 | $1〜$5/月 |

### 必要な Azure 権限

```
- Contributor（リソースグループスコープ）
- API Management Service Contributor
- API Center Owner（API Center リソーススコープ）
- Application Administrator（Entra ID アプリ登録用）
```

---

## 全体アーキテクチャ

本ワークショップで構築するシステムの全体像です。

```
┌────────────────────────────────────────────────────────────────┐
│  利用者 / AIエージェント層                                      │
│                                                                │
│  VS Code + GitHub Copilot (Agent Mode)                         │
│  └─ MCP Client として APIM 経由で業務ツールを呼び出す           │
└───────────────────────┬────────────────────────────────────────┘
                        │ Streamable HTTP (JSON-RPC 2.0)
                        ↓
┌────────────────────────────────────────────────────────────────┐
│  Azure API Management — MCP Gateway                            │
│                                                                │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │認証・認可 │ │レート制限 │ │Origin検証│ │監査ログ          │ │
│  │Entra ID  │ │Session別 │ │DNS対策   │ │App Insights      │ │
│  │OAuth 2.1 │ │Token別   │ │          │ │Azure Monitor     │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘ │
│                                                                │
│  ┌─────────────────────┐  ┌──────────────────────────────────┐│
│  │ REST API → MCP化    │  │ 既存 MCP Server を Expose        ││
│  │ (Knowledge Search)  │  │ (Incident MCP Server)            ││
│  │ (On-call Schedule)  │  │                                  ││
│  └─────────────────────┘  └──────────────────────────────────┘│
└───────────────────────┬──────────────┬─────────────────────────┘
                        │              │
           ┌────────────┘              └────────────┐
           ↓                                        ↓
┌──────────────────────┐              ┌──────────────────────┐
│  Container Apps      │              │  Container Apps      │
│  Knowledge Search API│              │  Incident MCP Server │
│  On-call Schedule API│              │  (Streamable HTTP)   │
│  (REST)              │              │                      │
└──────────────────────┘              └──────────────────────┘
           ↑                                        ↑
           └──────────────┬─────────────────────────┘
                          │ イメージ pull
┌─────────────────────────┴──────────────────────────────────────┐
│  Azure Container Registry (ACR) — Basic SKU                    │
│                                                                │
│  knowledge-api / incident-mcp / oncall-api イメージを管理       │
│  az acr build でサーバーサイドビルド（Docker Desktop 不要）      │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│  Azure API Center — MCP Server Registry                        │
│                                                                │
│  ┌──────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────┐ │
│  │MCP Server    │ │メタデータ   │ │APIM        │ │ポータル   │ │
│  │インベントリ   │ │標準化      │ │自動同期    │ │公開      │ │
│  └──────────────┘ └────────────┘ └────────────┘ └──────────┘ │
└────────────────────────────────────────────────────────────────┘
```

---

## Lab 0: 環境構築・アーキテクチャ概観（30分）

### 🎯 目的

ワークショップで使用する Azure リソースをデプロイし、全体アーキテクチャを理解します。

### 📖 概要説明（10分）

#### MCP（Model Context Protocol）とは

MCP は AI エージェントが外部システムと接続するためのオープン標準プロトコルです。3つの基本要素（プリミティブ）で構成されます。

| プリミティブ | 役割 | 例 |
|---|---|---|
| **Tools** | エージェントが実行する関数 | ナレッジ検索、チケット起票 |
| **Resources** | コンテキストを提供するデータ | ドキュメント、DB レコード |
| **Prompts** | 再利用可能な対話テンプレート | 障害対応プロンプト |

#### APIM と API Center の役割分担

| コンポーネント | 役割 | 担当領域 |
|---|---|---|
| **Azure API Management** | ランタイムガバナンス（Gateway） | 認証、レート制限、監査ログ、ルーティング |
| **Azure API Center** | デザインタイムガバナンス（Registry） | MCP Server登録、メタデータ、カタログ、発見 |

> **💡 ポイント**: APIM は「MCP Server を**安全に動かす**」、API Center は「MCP Server を**見つけて管理する**」役割です。

### 🔨 ハンズオン：環境デプロイ（20分）

#### Step 1: リポジトリのクローン

```powershell
git clone https://github.com/ketana0224/MCP-Gateway-handson.git
cd MCP-Gateway-handson
```

#### Step 2: Azure にログイン

```powershell
az login
az account set --subscription "<your-subscription-id>"
```

#### Step 3: リソースプロバイダーの登録

新規サブスクリプションでは、以下のリソースプロバイダーを事前に登録してください。

```powershell
az provider register -n Microsoft.App --wait
az provider register -n Microsoft.ApiManagement --wait
az provider register -n Microsoft.ApiCenter --wait
az provider register -n Microsoft.KeyVault --wait
az provider register -n Microsoft.Insights --wait
az provider register -n Microsoft.OperationalInsights --wait
```

> **⏱️ 注意**: 登録には数分かかります。`--wait` を付けることで完了まで待機します。

#### Step 4: リソースグループの作成

```powershell
az group create `
  --name rg-mcp-workshop `
  --location japaneast
```

#### Step 4: Bicep テンプレートでリソースをデプロイ

```powershell
az deployment group create `
  --resource-group rg-mcp-workshop `
  --template-file infra/main.bicep `
  --parameters infra/parameters.json
```

> **⏱️ 注意**: APIM Developer SKU のプロビジョニングには約15～20分かかります。デプロイ開始後、次のセクションの座学に進んでください。

#### Step 5: コンテナイメージのビルドと Container Apps へのデプロイ

Bicep デプロイで作成された Azure Container Registry (ACR) にイメージをビルドし、Container Apps を更新します。

```powershell
# デプロイ outputs から ACR 名を取得
$ACR_NAME = az deployment group show `
  -g rg-mcp-workshop -n main `
  --query "properties.outputs.acrName.value" -o tsv
$ACR_SERVER = az deployment group show `
  -g rg-mcp-workshop -n main `
  --query "properties.outputs.acrLoginServer.value" -o tsv

Write-Host "ACR: $ACR_SERVER"

# ACR 上でサーバーサイドビルド（ローカルに Docker 不要）
az acr build --registry $ACR_NAME `
  --image "knowledge-api:latest" src/knowledge-api/

az acr build --registry $ACR_NAME `
  --image "incident-mcp:latest" src/incident-mcp-server/

az acr build --registry $ACR_NAME `
  --image "oncall-api:latest" src/oncall-api/

# ACR 認証情報を取得して Container Apps を更新
$ACR_USERNAME = az acr credential show --name $ACR_NAME --query "username" -o tsv
$ACR_PASSWORD = az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv

az containerapp update `
  --name ca-knowledge-api --resource-group rg-mcp-workshop `
  --image "$ACR_SERVER/knowledge-api:latest" `
  --registry-server $ACR_SERVER `
  --registry-username $ACR_USERNAME `
  --registry-password $ACR_PASSWORD

az containerapp update `
  --name ca-incident-mcp --resource-group rg-mcp-workshop `
  --image "$ACR_SERVER/incident-mcp:latest" `
  --registry-server $ACR_SERVER `
  --registry-username $ACR_USERNAME `
  --registry-password $ACR_PASSWORD

az containerapp update `
  --name ca-oncall-api --resource-group rg-mcp-workshop `
  --image "$ACR_SERVER/oncall-api:latest" `
  --registry-server $ACR_SERVER `
  --registry-username $ACR_USERNAME `
  --registry-password $ACR_PASSWORD
```

> **💡 ポイント**: `az acr build` はクラウド側でビルドするため、ローカルに Docker Desktop が不要です。

#### Step 6: デプロイ結果の確認

```powershell
# APIM エンドポイントの確認
az apim show --name apim-mcp-workshop --resource-group rg-mcp-workshop `
  --query "gatewayUrl" -o tsv

# ACR の確認
az acr show --name $ACR_NAME --resource-group rg-mcp-workshop `
  --query "loginServer" -o tsv

# API Center の確認
az apic show --name apic-mcp-workshop --resource-group rg-mcp-workshop `
  --query "id" -o tsv

# Application Insights の確認
az monitor app-insights component show `
  --app appinsights-mcp-workshop --resource-group rg-mcp-workshop `
  --query "instrumentationKey" -o tsv
```

### ✅ 確認ポイント

- [ ] APIM ゲートウェイ URL にアクセスして応答を確認
- [ ] ACR にイメージ（knowledge-api, incident-mcp, oncall-api）が存在する
- [ ] Container Apps 3つが実イメージで稼働している（`/health` が `{"status":"ok"}` を返す）
- [ ] Azure Portal で API Center リソースが表示される
- [ ] Application Insights のインストルメンテーションキーを取得

### 📦 成果物

| 成果物 | 内容 |
|---|---|
| デプロイ済み環境 | APIM / API Center / Container Apps / ACR / App Insights |
| パラメータファイル | `infra/parameters.json` |
| 接続情報メモ | APIM URL / ACR Login Server / API Center ID / App Insights Key |

---

## Lab 1: REST API を MCP Server として公開（60分）

### 🎯 目的

既存の REST API を APIM で MCP Server（Tool）として公開する方法を学びます。

### 📖 概要説明（10分）

APIM には **REST API を MCP Server として公開する機能** があります。API の各オペレーション（GET /articles, POST /search 等）が MCP の **Tool** として自動的にマッピングされます。

```
REST API Operation          →    MCP Tool
──────────────────────           ──────────────
GET  /articles/{id}         →    getArticle
POST /articles/search       →    searchArticles
GET  /categories            →    listCategories
```

> **⚠️ 制約**: REST API → MCP 変換では **Tools のみ対応** です（Resources / Prompts は非対応）。

### 🔨 ハンズオン（50分）

#### Step 1: Knowledge Search API のデプロイ確認（5分）

Lab 0 で Knowledge Search API が Container Apps にデプロイされていることを確認します。

```powershell
# Knowledge Search API の URL を取得
$KNOWLEDGE_API_URL = az containerapp show `
  --name ca-knowledge-api `
  --resource-group rg-mcp-workshop `
  --query "properties.configuration.ingress.fqdn" -o tsv

# 動作確認
curl https://$KNOWLEDGE_API_URL/api/categories
```

期待される応答:
```json
[
  {"id": "infra", "name": "インフラストラクチャ"},
  {"id": "security", "name": "セキュリティ"},
  {"id": "network", "name": "ネットワーク"}
]
```

#### Step 2: APIM に Knowledge Search API をインポート（5分）

```powershell
# OpenAPI 定義をインポート
az apim api import `
  --resource-group rg-mcp-workshop `
  --service-name apim-mcp-workshop `
  --api-id knowledge-search `
  --path knowledge-search `
  --specification-format OpenApiJson `
  --specification-url "https://$KNOWLEDGE_API_URL/api/openapi.json" `
  --display-name "Knowledge Search API" `
  --service-url "https://$KNOWLEDGE_API_URL"
```

Azure Portal で確認:
1. **API Management** → **APIs** → **Knowledge Search API** を開く
2. 各オペレーション（searchArticles, listCategories, getArticle）が表示されることを確認

#### Step 3: knowledge-search-mcp として公開（10分）

Azure Portal での操作:

1. **API Management** → **APIs** → **MCP Servers** を開く
2. **+ Create MCP server** をクリック
3. **API を MCP サーバーとして公開する（Expose an API as an MCP server）** を選択

**バックエンド MCP サーバー** セクション:

4. **API** で `Knowledge Search API` を選択
5. **API 操作** で公開する Operations（= Tools）を選択:
   - ✅ `[POST] searchArticles`
   - ✅ `[GET] listCategories`
   - ✅ `[GET] getArticle`

**新しい MCP サーバー** セクション:

6. 以下を入力:

| フィールド | 値 |
|---|---|
| Display name | `knowledge-search-mcp` |
| Name | `knowledge-search-mcp` |
| 説明 | `社内ナレッジベースを検索するMCP Server。記事の全文検索、カテゴリ別一覧、個別記事の取得が可能。` |

**製品** セクション:

7. 製品は任意（空のままでも可）

8. **作成** をクリック

> **💡 ポイント**: Tool の名前と説明文は、LLM がツール選択に使います。わかりやすい説明を書くことが重要です。

#### Step 4: On-call Schedule API のデプロイ確認（5分）

同様の手順で On-call Schedule API も MCP Server として公開します。

```powershell
# On-call Schedule API の URL を取得
$ONCALL_API_URL = az containerapp show `
  --name ca-oncall-api `
  --resource-group rg-mcp-workshop `
  --query "properties.configuration.ingress.fqdn" -o tsv

# 動作確認
curl https://$ONCALL_API_URL/api/oncall/2026-04-30
```

期待される応答:
```json
{"date": "2026-04-30", "primary": "佐藤次郎", "secondary": "鈴木花子", "team": "インフラチーム"}
```

#### Step 5: APIM に Oncall Schedule API をインポート（5分）

```powershell
# OpenAPI 定義をインポート
az apim api import `
  --resource-group rg-mcp-workshop `
  --service-name apim-mcp-workshop `
  --api-id oncall-schedule `
  --path oncall `
  --specification-format OpenApiJson `
  --specification-url "https://$ONCALL_API_URL/api/openapi.json" `
  --display-name "Oncall Schedule API" `
  --service-url "https://$ONCALL_API_URL"
```

Azure Portal で確認:
1. **API Management** → **APIs** → **Oncall Schedule API** を開く
2. 各オペレーション（getCurrentOncall, getScheduleByDate）が表示されることを確認

#### Step 6: oncall-schedule-mcp として公開（10分）

Azure Portal での操作:

1. **API Management** → **APIs** → **MCP Servers** を開く
2. **+ Create MCP server** をクリック
3. **API を MCP サーバーとして公開する（Expose an API as an MCP server）** を選択

**バックエンド MCP サーバー** セクション:

4. **API** で `Oncall Schedule API` を選択
5. **API 操作** で公開する Operations（= Tools）を選択:
   - ✅ `[GET] getCurrentOncall`
   - ✅ `[GET] getScheduleByDate`

**新しい MCP サーバー** セクション:

6. 以下を入力:

| フィールド | 値 |
|---|---|
| Display name | `oncall-schedule-mcp` |
| Name | `oncall-schedule-mcp` |
| 説明 | `オンコール当番スケジュール参照用 MCP Server。現在の担当者取得と日付指定での担当者検索が可能。` |

**製品** セクション:

7. 製品は任意（空のままでも可）

8. **作成** をクリック

#### Step 7: サブスクリプションキーの取得と MCP API への適用（5分）

MCP Server を Portal から作成すると、デフォルトで**サブスクリプション不要**の設定になっています。Lab でキー認証を体験するため、ここで有効化します。

**① サブスクリプションキーの取得:**

```powershell
$SUB = az account show --query id -o tsv
$APIM_KEY = (az rest --method POST `
  --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/rg-mcp-workshop/providers/Microsoft.ApiManagement/service/apim-mcp-workshop/subscriptions/master/listSecrets?api-version=2022-08-01" `
  | ConvertFrom-Json).primaryKey
Write-Host "Subscription Key: $APIM_KEY"
```

**② MCP API にサブスクリプション必須を設定（Portal）:**

`knowledge-search-mcp` と `oncall-schedule-mcp` それぞれで以下を実施します（Lab 2 で作成する `incident-mcp` は Lab 2 で同様の設定を行います）。

1. **API Management** → **APIs** → 対象の MCP Server を開く
2. 上部メニュー「**設定**」タブをクリック
3. **サブスクリプション** セクション → **サブスクリプションが必要** にチェックを入れる
4. 「**保存**」をクリック

> **💡 なぜキーが必要か**: サブスクリプションキーは「この APIM インスタンスへの正規利用者であること」を示す最初の認証レイヤーです。Lab 3 で追加する Entra ID 認証と組み合わせることで、多層防御を実現します。

> **⚠️ キーなしでのテスト**: 設定後にキーなしでリクエストを送ると `401 Unauthorized` が返ることを確認できます（Lab 3 のパターンA動作確認と同じ要領）。

#### Step 8: MCP Inspector で動作確認（10分）

```powershell
# MCP Inspector を起動
npx @modelcontextprotocol/inspector
```

MCP Inspector の接続設定:
```
Transport: Streamable HTTP
URL: https://apim-mcp-workshop.azure-api.net/knowledge-search-mcp/mcp
Headers:
  Ocp-Apim-Subscription-Key: <Step 7 で取得したキー>
```

> **💡 ポイント**: OAuth 2.0 Flow の入力欄は**空のまま**で構いません。Lab 1 ではサブスクリプションキー認証のみ使用します。OAuth 2.0 は Lab 3 で設定します。

確認手順（knowledge-search-mcp）:
1. **Connect** → 接続成功を確認
2. **Tools** タブ → 3つのツール（searchArticles, getArticle, listCategories）が表示される
3. `searchArticles` を選択 → パラメータに `{"query": "VPN"}` を入力 → **Call Tool**
4. レスポンスにナレッジ記事が返ることを確認

確認手順（oncall-schedule-mcp）:
1. URL を `https://apim-mcp-workshop.azure-api.net/oncall-schedule-mcp/mcp` に変更して **Connect**
2. **Tools** タブ → 2つのツール（getCurrentOncall, getScheduleByDate）が表示される
3. `getCurrentOncall` を選択 → **Call Tool**
4. レスポンスにオンコール担当者情報が返ることを確認

### ✅ 確認ポイント

- [ ] Knowledge Search API が APIM にインポートされている（3 オペレーション）
- [ ] Oncall Schedule API が APIM にインポートされている（2 オペレーション）
- [ ] MCP Server の「サブスクリプションが必要」が有効になっている
- [ ] キーなしでリクエストすると `401` が返る
- [ ] MCP Inspector から `https://apim-mcp-workshop.azure-api.net/knowledge-search-mcp/mcp` に接続できる
- [ ] `tools/list` で `searchArticles` / `getArticle` / `listCategories` の 3 ツールが返る
- [ ] `searchArticles` でキーワード検索結果が返る
- [ ] MCP Inspector から `https://apim-mcp-workshop.azure-api.net/oncall-schedule-mcp/mcp` に接続できる
- [ ] `tools/list` で `getCurrentOncall` / `getScheduleByDate` の 2 ツールが返る

### 📦 成果物

| 成果物 | 内容 |
|---|---|
| Knowledge Search MCP endpoint | `https://apim-mcp-workshop.azure-api.net/knowledge-search-mcp/mcp` |
| Knowledge Search Tool 一覧 | `searchArticles` / `getArticle` / `listCategories` |
| Oncall Schedule MCP endpoint | `https://apim-mcp-workshop.azure-api.net/oncall-schedule-mcp/mcp` |
| Oncall Schedule Tool 一覧 | `getCurrentOncall` / `getScheduleByDate` |
| 実行確認スクリーンショット | MCP Inspector の応答結果 |

---

## Lab 2: 既存 MCP Server を APIM 経由で公開（60分）

### 🎯 目的

既に MCP プロトコルに対応しているサーバーを APIM の背後に配置し、ガバナンスを一元化する方法を学びます。

### 📖 概要説明（10分）

Lab 1 では REST API を MCP 化しましたが、チームによっては **最初から MCP Server として開発** しているケースがあります。その場合、APIM の **Expose an existing MCP server** 機能を使います。

```
Lab 1: REST API ──[APIM変換]──→ MCP Server（tools only）
Lab 2: MCP Server ──[APIMプロキシ]──→ MCP Server（tools + resources）
```

> **💡 ポイント**: 既存 MCP Server を APIM 経由にする場合、**Tools と Resources** の両方が利用可能です（Prompts は非対応）。

> **⚠️ 要件**: 既存 MCP Server は **MCP version 2025-06-18 以降** に準拠し、**Streamable HTTP** をサポートする必要があります。

### 🔨 ハンズオン（50分）

#### Step 1: Incident MCP Server のデプロイ確認（10分）

```powershell
# Incident MCP Server の URL を取得して表示
$INCIDENT_MCP_URL = az containerapp show `
  --name ca-incident-mcp `
  --resource-group rg-mcp-workshop `
  --query "properties.configuration.ingress.fqdn" -o tsv
Write-Host "Incident MCP URL: https://$INCIDENT_MCP_URL/mcp"
```

出力例:
```
Incident MCP URL: https://ca-incident-mcp.happypond-00713c37.eastus.azurecontainerapps.io/mcp
```

上記の URL をコピーしてから MCP Inspector を起動します:
```powershell
npx @modelcontextprotocol/inspector
```

直接接続の設定（コピーした URL を貼り付け）:
```
Transport: Streamable HTTP
URL: https://ca-incident-mcp.<環境固有パス>.azurecontainerapps.io/mcp
```

このサーバーが提供するツール:
| Tool | 説明 | 種別 |
|---|---|---|
| `listIncidents` | 障害チケット一覧取得 | 読み取り |
| `getIncident` | 障害チケット詳細取得 | 読み取り |
| `createIncident` | 障害チケット起票 | 書き込み（副作用あり） |

> **💡 気づきポイント**: この時点では**認証なし・レート制限なし・ログなし**です。次のステップで APIM を経由させることで、これらの課題を解決します。

#### Step 2: APIM で既存 MCP Server を公開（15分）

Azure Portal での操作:

1. **API Management** → **APIs** → **MCP Servers** → **+ Create MCP server**
2. **既存の MCP サーバーを公開する（Expose an existing MCP server）** を選択

**バックエンド MCP サーバー** セクション:

3. **MCP サーバーのベース URL** に入力（Step 1 で表示された URL）:
   ```
   https://ca-incident-mcp.<環境固有パス>.azurecontainerapps.io/mcp
   ```

**新しい MCP サーバー** セクション:

4. 以下を入力:

| フィールド | 値 |
|---|---|
| Display name | `incident-mcp` |
| Name | `incident-mcp` |
| ベース パス | `/incident-mcp` |
| 説明 | `障害チケット管理用MCP Server。チケットの参照、起票が可能。` |

**製品** セクション:

5. 製品は任意（空のままでも可）

6. **作成** をクリック

**サブスクリプション必須を設定:**

7. 作成後、`incident-mcp` を開く → 上部メニュー「**設定**」タブ → **サブスクリプションが必要** にチェック → 「**保存**」

> **💡 ポイント**: Lab 1 で `knowledge-search-mcp` と `oncall-schedule-mcp` に設定したものと同じ設定です。これで3つすべての MCP Server にサブスクリプション認証が適用されます。

#### Step 3: APIM 経由での動作確認（10分）

MCP Inspector で APIM 経由の接続を確認:
```
URL: https://apim-mcp-workshop.azure-api.net/incident-mcp/mcp
Headers:
  Ocp-Apim-Subscription-Key: <your-subscription-key>
```

> **💡 ポイント**: OAuth 2.0 Flow の入力欄は**空のまま**で構いません。認証は Lab 3 で追加します。

確認手順:
1. `tools/list` → 3 つのツールが返る
2. `listIncidents` を呼び出し → チケット一覧が返る
3. 直接接続とAPIM経由の**レスポンス内容が同一**であることを確認

#### Step 4: 直接接続と APIM 経由の差分整理（15分）

以下の表を埋めて、APIM を経由するメリットを整理しましょう。

| 項目 | 直接接続 | APIM 経由 |
|---|---|---|
| URL | `https://<backend>/mcp` | `https://<apim>/incident-mcp/mcp` |
| 認証 | なし | なし（Lab 3 で Entra ID 認証を追加） |
| レート制限 | なし | 設定可能（Lab 4 で実装） |
| 監査ログ | なし | Azure Monitor / App Insights（Lab 4 で実装） |
| Origin 検証 | なし | ポリシーで設定可能（Lab 7 で実装） |
| IP 制限 | なし | ポリシーで設定可能 |

### ✅ 確認ポイント

- [ ] APIM 経由で Incident MCP Server のツールを呼び出せる
- [ ] 直接接続と APIM 経由のレスポンスが一致する
- [ ] APIM を経由するメリットを 3 つ以上説明できる

### 📦 成果物

| 成果物 | 内容 |
|---|---|
| APIM 経由 MCP URL | `https://apim-mcp-workshop.azure-api.net/incident-mcp/mcp` |
| 直接/APIM経由 比較表 | 認証・制限・ログの差分整理 |

---

## Lab 3: 認証・認可 — ユーザー代理実行とサービスID実行（60分）

### 🎯 目的

MCP Server へのアクセスに対して Entra ID ベースの認証・認可を設定し、ユーザー代理実行とサービスID実行の使い分けを学びます。

### 📖 概要説明（10分）

#### 2つの認証パターン

```
パターンA: ユーザー代理実行（User-delegated）
  利用者がログイン → トークンが APIM に渡される → バックエンドにユーザーIDが伝播
  → 「誰が」ツールを使ったかを追跡可能

パターンB: サービスID実行（Service Identity）
  APIM の Managed Identity で認証 → 全ユーザー共通のアクセス
  → M2M 通信、バッチ処理に適切
```

#### 使い分けの判断フロー

```
ユーザーのIDコンテキストが必要か？
├─ YES → ユーザーごとに異なるデータにアクセスするか？
│         ├─ YES → Credential Manager (user-delegated)
│         └─ NO  → Credential Manager (Attended) + ユーザー同意
└─ NO  → サービス間通信（ユーザー非依存）
           ├─ Azure リソース間 → Managed Identity
           └─ SaaS バックエンド → Credential Manager (Unattended)
```

#### 本ワークショップでの適用例

| ツール | 推奨認証パターン | 理由 |
|---|---|---|
| Knowledge Search | ユーザー代理 | 検索ログに「誰が検索したか」を残すため |
| Incident 起票 | ユーザー代理 | 「誰が起票したか」の記録が必須 |
| On-call 参照 | サービスID | 当番表は全員同一データ |

### 🔨 ハンズオン（50分）

#### Step 1: Entra ID アプリ登録（15分）

> **🔐 権限の整理**: このステップで必要な Entra ID 権限は以下の通りです。
>
> | 操作 | 必要な権限 |
> |---|---|
> | アプリの登録・表示・編集 | アプリのオーナー（作成者）であれば特別なロール不要 |
> | Application ID URI の設定 | アプリのオーナー |
> | oauth2PermissionScopes の追加 | アプリのオーナー |
> | 承認済みクライアントの追加 | アプリのオーナー |
> | **管理者の同意の付与** | **アプリケーション管理者（Application Administrator）以上** |
>
> 本ワークショップでは自分で作成したアプリを操作するため、アプリ登録・編集はオーナーとして行えます。管理者の同意付与のみ Application Administrator 以上が必要です（前提条件に記載）。

**MCP Client 用アプリ登録:**

> **💡 スクリプトでも可能**: 以下の Portal 手順は Azure CLI + PowerShell スクリプトで自動化することもできます（CI/CD や複数環境への展開時に有用）。

1. [Azure Portal](https://portal.azure.com) → **Microsoft Entra ID** → **アプリの登録** → 「**+ 新規登録**」
2. 以下を入力して「**登録**」:

   | 項目 | 値 |
   |---|---|
   | 名前 | `MCP Workshop Client` |
   | サポートされているアカウントの種類 | **この組織ディレクトリのみ** |
   | リダイレクト URI | Web / `http://localhost:3000/callback` |

3. 登録後、「**概要**」→「**アプリケーション (クライアント) ID**」を記録しておく（後で `$CLIENT_APP_ID` として使用）

**MCP Server 用アプリ登録:**

1. 「**+ 新規登録**」
2. 以下を入力して「**登録**」:

   | 項目 | 値 |
   |---|---|
   | 名前 | `MCP Workshop Server` |
   | サポートされているアカウントの種類 | **この組織ディレクトリのみ** |
   | リダイレクト URI | （空のまま） |

3. 登録後、「**概要**」→「**アプリケーション (クライアント) ID**」を記録しておく（後で `$SERVER_APP_ID` として使用）

**① Application ID URI の設定**
1. `MCP Workshop Server` の左メニュー「**API の公開**」→ 画面上部「**追加**」（Application ID URI）
2. 既定値 `api://<appId>` のまま「**保存**」

**② スコープ（access_as_user）の追加**
1. 同じ「**API の公開**」画面 → 「**+ Scope の追加**」
2. 以下を入力して「**スコープの追加**」を押す

   | 項目 | 値 |
   |---|---|
   | スコープ名 | `access_as_user` |
   | 同意できるユーザー | **管理者とユーザー** |
   | 管理者の同意の表示名 | `access_as_user` |
   | 管理者の同意の説明 | `Access MCP Server as user` |
   | ユーザーの同意の表示名 | `access_as_user` |
   | ユーザーの同意の説明 | `Access MCP Server` |
   | 状態 | **有効** |

**③ Client アプリに Server スコープの利用許可を追加し、管理者の同意を付与**

Server アプリ自身は何も API を呼ばないため、Server の「API のアクセス許可」は**空で正常**です。
同意はアクセス許可を**使う側（Client アプリ）** から行います。

1. **Microsoft Entra ID** → **アプリの登録** → `MCP Workshop Client` を開く
2. 左メニュー「**API のアクセス許可**」→「**+ アクセス許可の追加**」
3. 右側パネルで「**所属する組織で使用している API**」タブをクリック
4. 検索ボックスに `MCP Workshop Server` と入力 → 候補に表示されたらクリック
5. 「**委任されたアクセス許可**」→ `access_as_user` にチェック → 「**アクセス許可の追加**」
6. 「**Contoso に管理者の同意を与えます**」ボタンをクリック → 「**はい**」

> **⚠️ 権限要件**: 管理者の同意付与には Entra ID で **アプリケーション管理者**（Application Administrator）以上のロールが必要です。ボタンがグレーアウトしている場合はロールが不足しています。テナント管理者に依頼するか、前提条件の権限を確認してください。

> **⚠️ 注意**: 手順 3 のタブ名は「自分の組織で使用している API」ではなく「**所属する組織で使用している API**」です（Portal の表記に注意）。

**④ Azure CLI を承認済みクライアントに追加（`az account get-access-token` でのテスト用）**
1. `MCP Workshop Server` → 「**API の公開**」
2. 「**承認済みのクライアント アプリケーション**」→「**+ クライアント アプリケーションの追加**」
3. クライアント ID: `04b07795-8ddb-461a-bbee-02f9e1bf7b46`（Microsoft Azure CLI）
4. スコープ: `api://<SERVER_APP_ID>/access_as_user` にチェック → 「**アプリケーションの追加**」

設定後、Client / Server の App ID を変数に記録します:

```powershell
$CLIENT_APP_ID = az ad app list --display-name "MCP Workshop Client" `
  --query "[0].appId" -o tsv
$SERVER_APP_ID = az ad app list --display-name "MCP Workshop Server" `
  --query "[0].appId" -o tsv
Write-Host "Client App ID: $CLIENT_APP_ID"
Write-Host "Server App ID: $SERVER_APP_ID"
```

#### Step 2: パターンA — ユーザー代理実行の実装（15分）

Knowledge Search MCP Server にインバウンド認証ポリシーを追加します。

まず、ポリシーに埋め込む値を取得します:

```powershell
# テナント ID を取得
$TENANT_ID = az account show --query "tenantId" -o tsv
Write-Host "Tenant ID:        $TENANT_ID"
Write-Host "Client App ID:    $CLIENT_APP_ID"
Write-Host "Server App ID:    $SERVER_APP_ID"
```

Azure Portal → API Management → APIs → MCP Servers → `knowledge-search-mcp` → **ポリシー**

上記で表示された値を使って以下のスクリプトでポリシー XML を生成し、クリップボードにコピーします:

```powershell
$policy = @"
<policies>
    <inbound>
        <base />
        <validate-azure-ad-token
            tenant-id="$TENANT_ID"
            header-name="Authorization"
            failed-validation-httpcode="401"
            failed-validation-error-message="Unauthorized: Invalid or missing token">
            <client-application-ids>
                <!-- MCP Workshop Client（ブラウザ/クライアントアプリ用） -->
                <application-id>$CLIENT_APP_ID</application-id>
                <!-- Azure CLI（az account get-access-token でのテスト用） -->
                <application-id>04b07795-8ddb-461a-bbee-02f9e1bf7b46</application-id>
            </client-application-ids>
            <audiences>
                <!-- audience は "api://<GUID>" 形式（GUID のみは不可） -->
                <audience>api://$SERVER_APP_ID</audience>
            </audiences>
        </validate-azure-ad-token>
        <set-header name="X-User-Id" exists-action="override">
            <value>@(context.Request.Headers.GetValueOrDefault("Authorization","").AsJwt()?.Claims.GetValueOrDefault("oid","unknown"))</value>
        </set-header>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
</policies>
"@
$policy | Set-Clipboard
Write-Host "ポリシー XML をクリップボードにコピーしました。Portal に貼り付けて保存してください。"
```

Azure Portal のポリシーエディターを開き、クリップボードの内容を貼り付けて保存します。

**動作確認:**

```powershell
# 変数が設定されていない場合は再取得
$SERVER_APP_ID = az ad app list --display-name "MCP Workshop Server" --query "[0].appId" -o tsv
$TOKEN = az account get-access-token --resource "api://$SERVER_APP_ID" --query "accessToken" -o tsv
Write-Host "TOKEN length: $($TOKEN.Length)"
Write-Host "TOKEN: $TOKEN"
```

**MCP Inspector で APIM 経由の接続を確認::**

1. **Connection Type**: `Direct`
2. 以下のスクリプトを実行して、Custom Headers JSON をクリップボードにコピーする:

   ```powershell
   $json = [ordered]@{
       "Ocp-Apim-Subscription-Key" = "77cd3f1f89ce487b9e2564b79337fe11"
       "Authorization" = "Bearer $TOKEN"
   } | ConvertTo-Json
   $json | Set-Clipboard
   Write-Host "クリップボードにコピーしました"
   ```

3. Custom Headers の「**JSON**」ボタンをクリック → `Ctrl+A` → `Ctrl+V` で貼り付ける
4. 右側に OAuth フロー画面が表示されていたら「**Clear OAuth State**」を押してリセット
5. 左側の「**Connect**」ボタンを押す（OAuth フローのボタンは **押さない**）

または以下の `curl` コマンドでも動作確認できます:

```powershell
# 変数が設定されていない場合は再取得
$SERVER_APP_ID = az ad app list --display-name "MCP Workshop Server" --query "[0].appId" -o tsv
$TOKEN    = az account get-access-token --resource "api://$SERVER_APP_ID" --query "accessToken" -o tsv
$SUB      = az account show --query id -o tsv
$APIM_KEY = (az rest --method POST `
    --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/rg-mcp-workshop/providers/Microsoft.ApiManagement/service/apim-mcp-workshop/subscriptions/master/listSecrets?api-version=2022-08-01" `
    | ConvertFrom-Json).primaryKey
$APIM_GW  = az apim show -n apim-mcp-workshop -g rg-mcp-workshop --query "gatewayUrl" -o tsv
$MCP_URL  = "$APIM_GW/knowledge-search-mcp/mcp"

# ① トークンなし → 401 を確認
$body = '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
try {
    Invoke-WebRequest -Uri $MCP_URL -Method POST `
      -Headers @{ "Ocp-Apim-Subscription-Key" = $APIM_KEY; "Content-Type" = "application/json" } `
      -Body $body -ErrorAction Stop
} catch {
    Write-Host "期待どおり $($_.Exception.Response.StatusCode.value__) が返った"
}

# ② トークンあり → 200 + tools 配列を確認
$resp = Invoke-WebRequest -Uri $MCP_URL -Method POST `
  -Headers @{
      "Ocp-Apim-Subscription-Key" = $APIM_KEY
      "Authorization"              = "Bearer $TOKEN"
      "Content-Type"               = "application/json"
  } `
  -Body $body
Write-Host "Status: $($resp.StatusCode)"
$resp.Content | ConvertFrom-Json | ConvertTo-Json -Depth 5
```

期待される結果:
- ① コマンド → `401` が返る
- ② コマンド → `200` + `{"result":{"tools":[...]}}` が返る

**Incident MCP にも同じポリシーを適用します。**

Azure Portal → API Management → APIs → MCP Servers → `incident-mcp` → **ポリシー**

```powershell
$policy = @"
<policies>
    <inbound>
        <base />
        <validate-azure-ad-token
            tenant-id="$TENANT_ID"
            header-name="Authorization"
            failed-validation-httpcode="401"
            failed-validation-error-message="Unauthorized: Invalid or missing token">
            <client-application-ids>
                <application-id>$CLIENT_APP_ID</application-id>
                <application-id>04b07795-8ddb-461a-bbee-02f9e1bf7b46</application-id>
            </client-application-ids>
            <audiences>
                <audience>api://$SERVER_APP_ID</audience>
            </audiences>
        </validate-azure-ad-token>
        <set-header name="X-User-Id" exists-action="override">
            <value>@(context.Request.Headers.GetValueOrDefault("Authorization","").AsJwt()?.Claims.GetValueOrDefault("oid","unknown"))</value>
        </set-header>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
</policies>
"@
$policy | Set-Clipboard
Write-Host "ポリシー XML をクリップボードにコピーしました。Portal に貼り付けて保存してください。"
```

> **📘 「Bearer 直接利用」と本番 OAuth フローの違い**
>
> 上記で行った「`az account get-access-token` でトークンを手動取得して Authorization ヘッダーに直接セット」する方式は、**`validate-azure-ad-token` ポリシーの動作を学ぶ目的には正しい手順**です。ただし MCP の世界では以下の理由から「非主流」とされます。
>
> | | 手動 Bearer（本 Lab の学習用） | OAuth Discovery（本番標準） |
> |---|---|---|
> | トークン取得 | 開発者が `az` コマンドで手動取得 | MCP クライアントが自動で OAuth フロー実行 |
> | クライアント互換性 | 手動操作が必要（VS Code, Copilot Studio 等は自動化不可） | VS Code / MCP Inspector / Copilot Studio がネイティブ対応 |
> | 仕様準拠 | 部分的（トークン検証のみ MCP 仕様準拠） | MCP Spec 2025-06-18 + RFC 8414 完全準拠 |
>
> **本番環境での推奨**: APIM に `/.well-known/oauth-authorization-server` エンドポイントを追加し、Entra ID の OAuth メタデータを返します。これにより VS Code や MCP Inspector は「Quick OAuth Flow」でトークンを自動取得できるようになります。詳細な実装は [AI-Gateway mcp-prm-oauth Lab](https://github.com/Azure-Samples/AI-Gateway/tree/main/labs/mcp-prm-oauth) を参照してください（Lab 7 での発展課題として扱います）。

#### Step 3: パターンB — サービスID実行の実装（15分）

On-call Schedule MCP Server は**全員が同じ当番表を参照**するため、ユーザー個人のトークンは不要です。
サブスクリプションキーのみで認証し、APIM の Managed Identity でバックエンドを呼び出す構成を設定します。

まず、APIM の Managed Identity が有効であることを確認します:

```powershell
az apim show -n apim-mcp-workshop -g rg-mcp-workshop `
  --query "identity.type" -o tsv
```

> **期待値**: `SystemAssigned` と表示されれば有効です。表示されない場合は Portal から有効化してください（API Management → セキュリティ → マネージド ID → システム割り当て済み: オン）。

Azure Portal → API Management → APIs → MCP Servers → `oncall-schedule-mcp` → **ポリシー**

以下のスクリプトでポリシー XML を生成し、クリップボードにコピーします:

```powershell
$policy = @"
<policies>
    <inbound>
        <base />
        <!-- パターンB: サブスクリプションキーのみで認証（ユーザートークン不要） -->
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
</policies>
"@
$policy | Set-Clipboard
Write-Host "ポリシー XML をクリップボードにコピーしました。Portal に貼り付けて保存してください。"
```

Azure Portal のポリシーエディターを開き、クリップボードの内容を貼り付けて保存します。

> **💡 `<backend>` の制約**: APIM の `<backend>` セクションは **1つのポリシー要素しか持てません**。`<base />` と `<authentication-managed-identity>` を同時に書くとエラーになります。バックエンドに Entra ID 認証が必要な場合は `<base />` を**削除**して `<authentication-managed-identity>` のみを書きます。今回の oncall-api は認証不要な HTTP サービスなので `<base />` のみで十分です。

**動作確認:**

```powershell
# 変数が設定されていない場合は再取得
$SUB      = az account show --query id -o tsv
$APIM_KEY = (az rest --method POST `
    --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/rg-mcp-workshop/providers/Microsoft.ApiManagement/service/apim-mcp-workshop/subscriptions/master/listSecrets?api-version=2022-08-01" `
    | ConvertFrom-Json).primaryKey
$APIM_GW  = az apim show -n apim-mcp-workshop -g rg-mcp-workshop --query "gatewayUrl" -o tsv
$MCP_URL  = "$APIM_GW/oncall-schedule-mcp/mcp"
```

**MCP Inspector で APIM 経由の接続を確認:**

1. **Connection Type**: `Direct`
2. 以下のスクリプトを実行して、Custom Headers JSON をクリップボードにコピーする:

   ```powershell
   $json = [ordered]@{
       "Ocp-Apim-Subscription-Key" = $APIM_KEY
   } | ConvertTo-Json
   $json | Set-Clipboard
   Write-Host "クリップボードにコピーしました"
   ```

3. Custom Headers の「**JSON**」ボタンをクリック → `Ctrl+A` → `Ctrl+V` で貼り付ける
4. 右側に OAuth フロー画面が表示されていたら「**Clear OAuth State**」を押してリセット
5. 左側の「**Connect**」ボタンを押す（**Authorization ヘッダーは不要**）

または以下の `curl` コマンドでも動作確認できます:

```powershell
$body = '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'

# ① サブスクリプションキーのみ → 200 を確認（Bearer トークン不要）
$resp = Invoke-WebRequest -Uri $MCP_URL -Method POST `
  -Headers @{
      "Ocp-Apim-Subscription-Key" = $APIM_KEY
      "Content-Type"               = "application/json"
  } `
  -Body $body
Write-Host "Status: $($resp.StatusCode)"
$resp.Content | ConvertFrom-Json | ConvertTo-Json -Depth 5
```

期待される結果:
- ① コマンド（キーのみ） → `200` + `{"result":{"tools":[...]}}` が返る

> **💡 パターンA との違い**: パターンA（`knowledge-search-mcp`）では Bearer トークンなしで `401` でしたが、パターンB（`oncall-schedule-mcp`）はサブスクリプションキーのみで成功します。当番表のように「誰が見ても同じデータ」には、ユーザー認証を強制しないことで MCP クライアントの実装を簡素化できます。

#### Step 4: 認証方式の比較表作成（5分）

以下の表を完成させてください。

| 項目 | ユーザー代理実行 | サービスID実行 |
|---|---|---|
| 認証主体 | ? | ? |
| 監査ログの「誰が」 | ? | ? |
| 適用ツール例 | ? | ? |
| インバウンドポリシー | ? | ? |
| アウトバウンドポリシー | ? | ? |
| Conditional Access の影響 | ? | ? |

### ✅ 確認ポイント

- [ ] 認証なしリクエストが 401 で拒否される
- [ ] Entra ID トークン付きリクエストが成功する
- [ ] Managed Identity でバックエンドに認証が通る
- [ ] 認証方式の比較表を完成させた

### 📦 成果物

| 成果物 | 内容 |
|---|---|
| Entra ID アプリ登録 | Client / Server 2つの App Registration |
| Inbound policy XML | validate-azure-ad-token ポリシー |
| Outbound policy XML | authentication-managed-identity ポリシー |
| 認証方式比較表 | ユーザー代理 vs サービスID の整理 |

---

## Lab 4: ガバナンス・レート制限・監査ログ（60分）

### 🎯 目的

MCP Gateway としての「安全に運用する」ための制御を実装します。レート制限、相関ID、監査ログ、KQL ダッシュボードを構築します。

### 📖 概要説明（10分）

#### MCP Gateway に必要な3つの運用制御

```
1. レート制限   → 過剰なツール呼び出しを防止
2. 相関ID       → リクエストを横断的に追跡
3. 監査ログ     → 「誰が・いつ・何を」を記録
```

#### APIM の MCP 専用ログカテゴリ

| カテゴリ | テーブル | 用途 |
|---|---|---|
| `GatewayLogs` | `ApiManagementGatewayLogs` | 通常 HTTP リクエスト |
| `GatewayMCPLogs` | `ApiManagementGatewayMCPLog` | **MCP 専用ログ** |
| `GatewayLlmLogs` | `ApiManagementGatewayLlmLog` | LLM / 生成AI ログ |

> **⚠️ 重要**: MCP Server 使用時は、診断設定で **Frontend Response の Payload bytes to log を 0** に設定してください。ストリーミング動作がレスポンスバッファリングで破壊されます。

### 🔨 ハンズオン（50分）

#### Step 1: レート制限の設定（10分）

Knowledge Search MCP Server のポリシーにレート制限を追加します。

```xml
<inbound>
    <base />

    <!-- MCP セッション単位でレート制限（1分あたり5リクエスト） -->
    <rate-limit-by-key
        calls="5"
        renewal-period="60"
        counter-key="@(context.Request.Headers
            .GetValueOrDefault("Mcp-Session-Id","anonymous"))" />

</inbound>
```

> **💡 `increment-condition` を省略する理由**: MCP のストリーミングレスポンスでは、レスポンスコードがアウトバウンド時に確定しないケースがあり、`increment-condition="@(context.Response.StatusCode >= 200)"` を指定するとカウントが増えず 429 が発生しないことがあります。省略するとリクエスト受信時に必ずカウントされるため動作が確実です。

**動作確認:**
- MCP Inspector から連続でツールを呼び出し（`searchArticles` を何度も Call Tool）
- 6 回目で `429 Too Many Requests` が返ることを確認

> **⚠️ 429 が返らない場合の確認ポイント**:
> 1. ポリシーが **保存済み**（Portal で「保存」を押したか）
> 2. **60秒以内**に6回呼び出しているか（renewal-period 経過後はカウントがリセットされる）
> 3. MCP Inspector の **Disconnect → Connect** でセッションを張り直していないか（セッション ID が変わるとカウントがリセットされる）

> **⚠️ 401 が返る場合（トークン切れ）**: Lab 3 で取得したアクセストークンは通常 **1時間で期限切れ** になります。`401 Unauthorized` が返ったらトークンを再取得してください。
>
> ```powershell
> # トークンを再取得（TokenCreatedWithOutdatedPolicies エラーの場合は az logout → az login も実施）
> $SERVER_APP_ID = "b063657e-4af9-455b-bb1c-b2570693a03d"
> $TOKEN = az account get-access-token --resource "api://$SERVER_APP_ID" --query "accessToken" -o tsv
> Write-Host "TOKEN length: $($TOKEN.Length)"
> Write-Host "TOKEN: $TOKEN"
> ```
>
> それでも 401 が続く場合（`TokenCreatedWithOutdatedPolicies` エラー）は CAE によるトークン強制無効化が原因です。`az logout` → `az login` で再ログイン後に上記コマンドを再実行してください。
>
> MCP Inspector を使っている場合は、Custom Headers の `Authorization` 値を新しいトークンで上書きし、**Disconnect → Connect** し直してください。

#### Step 2: 相関IDの注入（10分）

**概要: 何をやっているか**

| ポリシー | 役割 |
|---|---|
| `set-header name="X-Correlation-Id"` | リクエストに一意のIDを付与。クライアントが `X-Correlation-Id` を送ってきた場合はそれを優先（`exists-action="skip"`）し、なければサーバー側で UUID を自動生成する |
| `trace` | MCP セッションID と 相関IDを Application Insights のトレースログに書き出す（デバッグ用）。`GatewayLogs` と紐付けることで「どのユーザーの・どのセッションで・どのツールが呼ばれたか」を KQL で横断検索できるようになる |

**なぜ相関IDが必要か:**  
MCP の1回の操作（例: `searchArticles`）は APIM → バックエンド API → レスポンスの複数ホップをまたぎます。各ホップのログに同じ `X-Correlation-Id` が含まれていれば、問題発生時に1本の糸で全ログをたどれます。

まず、Step 1 で設定したレート制限ポリシーに**追記**する形で適用します。

Azure Portal → API Management → APIs → MCP Servers → `knowledge-search-mcp` → **ポリシー**

```xml
<inbound>
    <base />

    <!-- Step 1 で追加済み: レート制限 -->
    <rate-limit-by-key
        calls="5"
        renewal-period="60"
        counter-key="@(context.Request.Headers
            .GetValueOrDefault("Mcp-Session-Id","anonymous"))" />

    <!-- 相関ID: クライアント提供があればそれを使い、なければ生成 -->
    <set-header name="X-Correlation-Id" exists-action="skip">
        <value>@(Guid.NewGuid().ToString())</value>
    </set-header>

    <!-- トレースポリシー（デバッグ用、本番では無効化推奨） -->
    <trace source="mcp-gateway" severity="information">
        <message>@($"MCP Tool Call: Session={context.Request.Headers.GetValueOrDefault("Mcp-Session-Id","N/A")}, CorrelationId={context.Request.Headers.GetValueOrDefault("X-Correlation-Id","N/A")}")</message>
    </trace>

</inbound>
```

**動作確認:**

MCP Inspector でツールを呼び出した後、Azure Portal → Application Insights → **トランザクション検索** に移動し、以下のように確認します。

1. フィルター: `mcp-gateway` ソース、直近 30 分
2. `Mcp-Session-Id` と `CorrelationId` が同一セッションのログに含まれることを確認
3. APIM の **トレース**（Portal → APIs → `knowledge-search-mcp` → テスト → トレース有効）でも確認可能

> **💡 ポイント**: Step 3 で診断設定を構成した後、`CorrelationId` を使って KQL クエリ（`ApiManagementGatewayMCPLog | where CorrelationId == "..."` ）で特定リクエストのログを絞り込めます。

#### Step 3: 診断設定の構成（10分）

```powershell
# APIM の診断設定を構成
$APIM_ID = az apim show -n apim-mcp-workshop -g rg-mcp-workshop --query id -o tsv
$LAW_ID = az monitor log-analytics workspace show `
  -n law-mcp-workshop -g rg-mcp-workshop --query id -o tsv
az monitor diagnostic-settings create `
  --resource $APIM_ID `
  --name "mcp-diagnostics" `
  --workspace $LAW_ID `
  --logs '[{"category":"GatewayLogs","enabled":true},{"category":"GatewayMCPLogs","enabled":true}]'
```

> **⚠️ 必須**: Payload bytes to log = 0 の設定を確認してください。

#### Step 4: KQL ダッシュボードの構築（15分）

Azure Portal → Log Analytics Workspace → Logs

**クエリ1: MCP ツール呼び出し状況**
```kql
ApiManagementGatewayMCPLog
| where TimeGenerated > ago(1h)
| summarize
    totalCalls = count(),
    errorCalls = countif(ResponseCode >= 400),
    avgDuration = avg(DurationMs)
  by ApiId, bin(TimeGenerated, 5m)
| render timechart
```

**クエリ2: セッション別のアクティビティ**
```kql
ApiManagementGatewayMCPLog
| where TimeGenerated > ago(1h)
| join kind=leftouter (
    ApiManagementGatewayLogs
    | project CorrelationId, DurationMs, ResponseCode
) on CorrelationId
| summarize
    requestCount = count(),
    errors = countif(ResponseCode >= 400)
  by CorrelationId
| order by requestCount desc
| take 20
```

**クエリ3: レート制限（429）の発生状況**
```kql
ApiManagementGatewayLogs
| where TimeGenerated > ago(1h)
| where ResponseCode == 429
| summarize count() by ApiId, bin(TimeGenerated, 5m)
| render barchart
```

#### Step 5: アラートルールの設定（5分）

```powershell
# 5xx エラーが5分間に10回以上発生したらアラート
$APIM_ID = az apim show -n apim-mcp-workshop -g rg-mcp-workshop --query id -o tsv
az monitor metrics alert create `
  --name "mcp-5xx-alert" `
  --resource-group rg-mcp-workshop `
  --scopes $APIM_ID `
  --condition "total Requests > 10 where ResponseCode includes 5xx" `
  --window-size 5m `
  --evaluation-frequency 1m `
  --description "MCP Server 5xx errors exceeded threshold"
```

### ✅ 確認ポイント

- [ ] レート制限で 429 が返ることを確認
- [ ] Application Insights で相関IDによるトレースが確認できる
- [ ] KQL クエリでツール呼び出し状況が可視化される
- [ ] Payload bytes to log = 0 を設定した
- [ ] 401 が返った場合はトークン再取得で解消できた

### 📦 成果物

| 成果物 | 内容 |
|---|---|
| APIM ポリシー | rate-limit-by-key + 相関ID + trace |
| 診断設定 | GatewayLogs + GatewayMCPLogs 有効化 |
| KQL クエリ集 | ツール呼び出し / セッション / 429 監視 |
| アラートルール | 5xx 閾値アラート |

---

## Lab 5: API Center で MCP Server Registry を構築（45分）

### 🎯 目的

API Center を MCP Server のレジストリ（カタログ）として構成し、メタデータの標準化と発見可能性を実現します。

### 📖 概要説明（10分）

#### API Center が提供する MCP Registry 機能

| 機能 | 説明 |
|---|---|
| **MCP Server 登録** | Remote / Local / Partner MCP Server の登録 |
| **APIM 自動同期** | APIM で作成した MCP Server を自動的にカタログに反映 |
| **定義の自動生成** | SSE 定義・Streamable 定義の OpenAPI 仕様を自動生成 |
| **ポータル公開** | Browse / Filter / Test Console / VS Code インストール導線 |
| **カスタムメタデータ** | 組織固有の分類・属性を定義して API に付与 |

### 🔨 ハンズオン（35分）

#### Step 1: APIM との同期設定（10分）

```powershell
# API Center に APIM をリンク
$APIM_ID = az apim show -n apim-mcp-workshop -g rg-mcp-workshop --query id -o tsv
az apic integration create `
  --resource-group rg-mcp-workshop `
  --service-name apic-mcp-workshop `
  --integration-name apim-link `
  --integration-type apim `
  --target-resource-id $APIM_ID
```

> **💡 ポイント**: 同期は一方向（APIM → API Center）で、通常数分以内に反映されます（最大24時間の場合あり）。MCP Servers と A2A Agent APIs も同期対象です。

数分待ってから同期結果を確認:

```powershell
# 登録された API 一覧を確認
az apic api list `
  --resource-group rg-mcp-workshop `
  --service-name apic-mcp-workshop `
  --output table
```

#### Step 2: カスタムメタデータの定義（10分）

組織独自のガバナンス項目をメタデータとして定義します。

```powershell
# データ分類メタデータ
az apic metadata create `
  --resource-group rg-mcp-workshop `
  --service-name apic-mcp-workshop `
  --metadata-name "dataClassification" `
  --title "Data Classification" `
  --schema '{"type":"string","enum":["public","internal","confidential","restricted"]}' `
  --assignments '[{"entity":"api","required":true}]'

# 認証方式メタデータ
az apic metadata create `
  --resource-group rg-mcp-workshop `
  --service-name apic-mcp-workshop `
  --metadata-name "authMode" `
  --title "Authentication Mode" `
  --schema '{"type":"string","enum":["user-delegated","service-identity","mixed"]}' `
  --assignments '[{"entity":"api","required":true}]'

# SLA ターゲットメタデータ
az apic metadata create `
  --resource-group rg-mcp-workshop `
  --service-name apic-mcp-workshop `
  --metadata-name "slaTarget" `
  --title "SLA Target (%)" `
  --schema '{"type":"string","enum":["99.9","99.5","99.0","best-effort"]}' `
  --assignments '[{"entity":"api","required":false}]'

# オーナーチームメタデータ
az apic metadata create `
  --resource-group rg-mcp-workshop `
  --service-name apic-mcp-workshop `
  --metadata-name "ownerTeam" `
  --title "Owner Team" `
  --schema '{"type":"string"}' `
  --assignments '[{"entity":"api","required":true}]'
```

#### Step 3: MCP Server のメタデータを付与（10分）

```powershell
# Knowledge Search MCP Server にメタデータを設定
az apic api update `
  --resource-group rg-mcp-workshop `
  --service-name apic-mcp-workshop `
  --api-id knowledge-search-mcp `
  --custom-properties '{"dataClassification":"internal","authMode":"user-delegated","slaTarget":"99.5","ownerTeam":"ナレッジ管理チーム"}'

# Incident MCP Server にメタデータを設定
az apic api update `
  --resource-group rg-mcp-workshop `
  --service-name apic-mcp-workshop `
  --api-id incident-mcp `
  --custom-properties '{"dataClassification":"confidential","authMode":"user-delegated","slaTarget":"99.9","ownerTeam":"ITサービスデスクチーム"}'
```

#### Step 4: API Center ポータルで確認（5分）

Azure Portal → API Center → Portal overview

確認事項:
1. 登録した MCP Server が一覧に表示される
2. カスタムメタデータでフィルタリングできる
3. ツールスキーマが閲覧できる
4. VS Code へのインストール導線が表示される

### ✅ 確認ポイント

- [ ] APIM の MCP Server が API Center に自動同期されている
- [ ] カスタムメタデータ（dataClassification, authMode, ownerTeam）が設定されている
- [ ] `az apic api list` で登録済み MCP Server を一覧表示できる
- [ ] ポータルからツールスキーマが閲覧できる

### 📦 成果物

| 成果物 | 内容 |
|---|---|
| API Center Registry | MCP Server カタログ（メタデータ付き） |
| メタデータ定義 | dataClassification / authMode / slaTarget / ownerTeam |
| 登録ガイドライン | ライフサイクル運用例（preview → production → deprecated） |

---

## Lab 6: VS Code / GitHub Copilot からの利用（30分）

### 🎯 目的

利用者の視点で、VS Code の GitHub Copilot Agent Mode から MCP Server を実際に使い、エンドツーエンドの動作を確認します。

### 🔨 ハンズオン（30分）

#### Step 1: VS Code に MCP Server を登録（10分）

`.vscode/mcp.json` を作成:

```json
{
  "servers": {
    "knowledge-search": {
      "type": "http",
      "url": "https://apim-mcp-workshop.azure-api.net/knowledge-search-mcp/mcp",
      "headers": {
        "Ocp-Apim-Subscription-Key": "${input:apimSubscriptionKey}"
      }
    },
    "incident": {
      "type": "http",
      "url": "https://apim-mcp-workshop.azure-api.net/incident-mcp/mcp",
      "headers": {
        "Ocp-Apim-Subscription-Key": "${input:apimSubscriptionKey}"
      }
    },
    "oncall": {
      "type": "http",
      "url": "https://apim-mcp-workshop.azure-api.net/oncall-mcp/mcp",
      "headers": {
        "Ocp-Apim-Subscription-Key": "${input:apimSubscriptionKey}"
      }
    }
  }
}
```

VS Code → `Ctrl+Shift+P` → `MCP: List Servers` で 3 つのサーバーが登録されていることを確認。

#### Step 2: Agent Mode でツールを利用（15分）

GitHub Copilot Chat を **Agent Mode** に切り替え、以下のプロンプトを試します。

**プロンプト 1: 単一ツール呼び出し**
```
社内ナレッジベースで「VPN接続エラー」に関する記事を検索してください
```

**プロンプト 2: 複数ツール連携**
```
現在のオンコール担当者を確認し、
VPN関連の障害チケットがあるか調べてください
```

**プロンプト 3: ツール実行 + 判断**
```
社内ナレッジベースでVPN接続の手順書を検索し、
該当する手順書がない場合は、障害チケットを起票してください。
タイトルは「VPN接続手順書の整備依頼」としてください。
```

> **💡 ポイント**: プロンプト 3 では、エージェントが `createIncident` ツールを呼ぶ前にユーザー確認を求めます（HITL）。これは MCP クライアント（Copilot）側の実装です。

#### Step 3: 操作ログの確認（5分）

Lab 4 で構築した KQL ダッシュボードで、今の操作が記録されていることを確認します。

```kql
ApiManagementGatewayMCPLog
| where TimeGenerated > ago(10m)
| project TimeGenerated, ApiId, ResponseCode, DurationMs, CorrelationId
| order by TimeGenerated desc
```

### ✅ 確認ポイント

- [ ] VS Code から 3 つの MCP Server に接続できる
- [ ] Agent Mode で複合プロンプトが動作する
- [ ] `createIncident` 呼び出し前にユーザー確認が表示される
- [ ] Lab 4 の監査ログに操作が記録されている

### 📦 成果物

| 成果物 | 内容 |
|---|---|
| `.vscode/mcp.json` | MCP Server 接続設定 |
| デモプロンプト集 | 単一 / 複数 / 判断付きプロンプト |
| 動作確認結果 | Agent Mode スクリーンショット |

---

## Lab 7: セキュリティ深掘り（オプション・60分）

### 🎯 目的

本番環境を見据えたセキュリティ強化を実装します。Origin 検証、Confused Deputy 対策、HITL ゲートウェイ設計を扱います。

> **⚠️ 注意**: 本 Lab はオプションです。MCP Gateway/Proxy patterns は MCP 仕様としての標準化が未完了であり、Azure の実装レベルでの対応となります。

### 🔨 ハンズオン（60分）

#### Step 1: Origin 検証の実装（15分）

MCP 仕様では、サーバーはすべての受信接続で **Origin ヘッダーを検証しなければならない（MUST）** と規定されています。

```xml
<inbound>
    <base />

    <!-- Origin 検証（DNS Rebinding 攻撃対策） -->
    <check-header name="Origin"
                  failed-check-httpcode="403"
                  failed-check-error-message="Forbidden: Invalid Origin"
                  ignore-case="true">
        <value>https://vscode.dev</value>
        <value>vscode-file://vscode-app</value>
        <value>https://github.dev</value>
    </check-header>

    <!-- MCP-Protocol-Version ヘッダー検証 -->
    <check-header name="MCP-Protocol-Version"
                  failed-check-httpcode="400"
                  failed-check-error-message="Bad Request: Missing MCP protocol version">
        <value>2025-06-18</value>
        <value>2025-11-25</value>
    </check-header>
</inbound>
```

**動作確認:**
- Origin ヘッダーなし → 403 Forbidden
- 不正な Origin → 403 Forbidden
- 正しい Origin → 正常応答

#### Step 2: Confused Deputy 攻撃の理解と対策（15分）

```
Confused Deputy 攻撃とは:

  悪意のあるMCPクライアントが、正規のMCP Proxy/Gatewayの
  Static Client IDを使って、本来アクセスできないリソースに
  アクセスする攻撃。

  対策: Per-client consent（クライアントごとの同意管理）
```

APIM ポリシーで実装:

```xml
<inbound>
    <base />

    <!-- クライアントアプリIDの検証 -->
    <validate-azure-ad-token tenant-id="{tenant-id}">
        <client-application-ids>
            <!-- 許可されたクライアントのみ列挙 -->
            <application-id>{copilot-client-id}</application-id>
            <application-id>{internal-agent-client-id}</application-id>
        </client-application-ids>
    </validate-azure-ad-token>

    <!-- 未許可クライアントの検出ログ -->
    <choose>
        <when condition="@(context.Response.StatusCode == 401)">
            <trace source="security" severity="error">
                <message>Unauthorized client attempted access</message>
            </trace>
        </when>
    </choose>
</inbound>
```

#### Step 3: HITL ゲートウェイ設計（概念設計・30分）

高リスクなツール呼び出し（例: `createIncident`）に対して、APIM をゲートとした承認フローを設計します。

**設計概要:**

```
[MCP Client] → tools/call(createIncident)
    ↓
[APIM Policy]
    ├─ ツール名を判定
    ├─ 高リスクツールの場合:
    │   ├─ send-request → Logic Apps 承認フロー起動
    │   ├─ 承認待ち（同期 or 非同期）
    │   ├─ 承認済み → backend へ転送
    │   └─ 拒否 → return-response で 403 応答
    └─ 低リスクツールの場合:
        └─ そのまま backend へ転送
```

> **💡 設計演習**: 以下の表を完成させて、各ツールのリスクレベルと HITL 要否を設計してください。

| ツール | 副作用 | リスクレベル | HITL 要否 |
|---|---|---|---|
| searchArticles | なし（読み取り） | ? | ? |
| getArticleById | なし（読み取り） | ? | ? |
| listIncidents | なし（読み取り） | ? | ? |
| createIncident | あり（書き込み） | ? | ? |
| getCurrentOncall | なし（読み取り） | ? | ? |

### ✅ 確認ポイント

- [ ] Origin なしリクエストが 403 で拒否される
- [ ] 未許可クライアントが 401 で拒否される
- [ ] HITL 設計のリスク判定表を完成させた

### 📦 成果物

| 成果物 | 内容 |
|---|---|
| セキュリティポリシー XML | Origin 検証 + MCP-Protocol-Version 検証 |
| クライアント許可リスト | 許可されたアプリID一覧 |
| HITL 設計書 | ツール別リスク判定表 + 承認フロー設計 |

---

## 対象者別 学習パス

### 🛤️ パスA: API開発者（MCP初学者）— 3時間45分

```
Lab 0 → Lab 1 → Lab 2 → Lab 5 → Lab 6
                 ↓
 REST→MCP変換、既存MCP公開、Registry登録、VS Code利用
```

### 🛤️ パスB: クラウドアーキテクト — 5時間15分

```
Lab 0 → Lab 1 → Lab 2 → Lab 3 → Lab 4 → Lab 5
                          ↓
 全体アーキテクチャ、認証設計、監査設計、Registry設計
```

### 🛤️ パスC: セキュリティエンジニア — 4時間30分

```
Lab 0 → Lab 1 → Lab 3 → Lab 4 → Lab 7
                  ↓
 認証設計、監査ログ、Origin検証、Confused Deputy対策、HITL
```

### 🛤️ パスD: フルコース — 6時間45分

```
Lab 0 → Lab 1 → Lab 2 → Lab 3 → Lab 4 → Lab 5 → Lab 6 → Lab 7
```

---

## 参考資料

### 公式ドキュメント

| リソース | URL |
|---|---|
| APIM MCP 概要 | https://learn.microsoft.com/en-us/azure/api-management/mcp-server-overview |
| REST API を MCP 公開 | https://learn.microsoft.com/en-us/azure/api-management/export-rest-mcp-server |
| 既存 MCP Server を公開 | https://learn.microsoft.com/en-us/azure/api-management/expose-existing-mcp-server |
| MCP セキュリティ | https://learn.microsoft.com/en-us/azure/api-management/secure-mcp-servers |
| API Center MCP Registry | https://learn.microsoft.com/en-us/azure/api-center/register-discover-mcp-server |
| GenAI Gateway 機能 | https://learn.microsoft.com/en-us/azure/api-management/genai-gateway-capabilities |
| MCP 仕様 | https://modelcontextprotocol.io/specification/2025-06-18 |

### サンプルコード・ラボ

| リソース | URL |
|---|---|
| AI Gateway サンプル集（30+ labs） | https://github.com/Azure-Samples/ai-gateway |
| AI Gateway ワークショップ | https://aka.ms/ai-gateway/workshop |
| APIM MCP OAuth サンプル | https://github.com/blackchoey/remote-mcp-apim-oauth-prm |
| 参考 L300 ワークショップ | https://microsoft.github.io/TechWorkshop-L300-AI-Apps-and-agents/ |

### 設計ガイド（本ワークショップ調査レポート）

| リソース | ファイル |
|---|---|
| 技術調査レポート | `report/APIM_MCP_Workshop_Design_Report.md` |

---

> **📌 注意事項**
>
> - 本ワークショップの内容は 2026年4月時点の Azure サービスおよび MCP 仕様に基づいています
> - MCP の Gateway/Proxy patterns は MCP 仕様としての標準化が未完了です（Azure の実装として動作）
> - APIM の MCP Server 機能では **Prompts は非対応** です（Tools / Resources のみ）
> - 教材のバージョンは MCP spec `2025-06-18` 以降を前提としています
