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

```bash
git clone https://github.com/ketana0224/MCP-Gateway-handson.git
cd MCP-Gateway-handson
```

#### Step 2: Azure にログイン

```bash
az login
az account set --subscription "<your-subscription-id>"
```

#### Step 3: リソースプロバイダーの登録

新規サブスクリプションでは、以下のリソースプロバイダーを事前に登録してください。

```bash
az provider register -n Microsoft.App --wait
az provider register -n Microsoft.ApiManagement --wait
az provider register -n Microsoft.ApiCenter --wait
az provider register -n Microsoft.KeyVault --wait
az provider register -n Microsoft.Insights --wait
az provider register -n Microsoft.OperationalInsights --wait
```

> **⏱️ 注意**: 登録には数分かかります。`--wait` を付けることで完了まで待機します。

#### Step 4: リソースグループの作成

```bash
az group create \
  --name rg-mcp-workshop \
  --location japaneast
```

#### Step 4: Bicep テンプレートでリソースをデプロイ

```bash
az deployment group create \
  --resource-group rg-mcp-workshop \
  --template-file infra/main.bicep \
  --parameters infra/parameters.json
```

> **⏱️ 注意**: APIM Developer SKU のプロビジョニングには約15～20分かかります。デプロイ開始後、次のセクションの座学に進んでください。

#### Step 5: コンテナイメージのビルドと Container Apps へのデプロイ

Bicep デプロイで作成された Azure Container Registry (ACR) にイメージをビルドし、Container Apps を更新します。

```bash
# デプロイ outputs から ACR 名を取得
ACR_NAME=$(az deployment group show \
  -g rg-mcp-workshop -n main \
  --query "properties.outputs.acrName.value" -o tsv)
ACR_SERVER=$(az deployment group show \
  -g rg-mcp-workshop -n main \
  --query "properties.outputs.acrLoginServer.value" -o tsv)

echo "ACR: ${ACR_SERVER}"

# ACR 上でサーバーサイドビルド（ローカルに Docker 不要）
az acr build --registry "$ACR_NAME" \
  --image "knowledge-api:latest" src/knowledge-api/

az acr build --registry "$ACR_NAME" \
  --image "incident-mcp:latest" src/incident-mcp-server/

az acr build --registry "$ACR_NAME" \
  --image "oncall-api:latest" src/oncall-api/

# ACR 認証情報を取得して Container Apps を更新
ACR_USERNAME=$(az acr credential show --name "$ACR_NAME" --query "username" -o tsv)
ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)

az containerapp update \
  --name ca-knowledge-api --resource-group rg-mcp-workshop \
  --image "${ACR_SERVER}/knowledge-api:latest" \
  --registry-server "$ACR_SERVER" \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD"

az containerapp update \
  --name ca-incident-mcp --resource-group rg-mcp-workshop \
  --image "${ACR_SERVER}/incident-mcp:latest" \
  --registry-server "$ACR_SERVER" \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD"

az containerapp update \
  --name ca-oncall-api --resource-group rg-mcp-workshop \
  --image "${ACR_SERVER}/oncall-api:latest" \
  --registry-server "$ACR_SERVER" \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD"
```

> **💡 ポイント**: `az acr build` はクラウド側でビルドするため、ローカルに Docker Desktop が不要です。

#### Step 6: デプロイ結果の確認

```bash
# APIM エンドポイントの確認
az apim show --name apim-mcp-workshop --resource-group rg-mcp-workshop \
  --query "gatewayUrl" -o tsv

# ACR の確認
az acr show --name "$ACR_NAME" --resource-group rg-mcp-workshop \
  --query "loginServer" -o tsv

# API Center の確認
az apic show --name apic-mcp-workshop --resource-group rg-mcp-workshop \
  --query "id" -o tsv

# Application Insights の確認
az monitor app-insights component show \
  --app appinsights-mcp-workshop --resource-group rg-mcp-workshop \
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

#### Step 1: サンプル REST API のデプロイ確認（5分）

Lab 0 で Knowledge Search API が Container Apps にデプロイされていることを確認します。

```bash
# Knowledge Search API の URL を取得
KNOWLEDGE_API_URL=$(az containerapp show \
  --name ca-knowledge-api \
  --resource-group rg-mcp-workshop \
  --query "properties.configuration.ingress.fqdn" -o tsv)

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

#### Step 2: APIM に REST API をインポート（10分）

```bash
# OpenAPI 定義をインポート
az apim api import \
  --resource-group rg-mcp-workshop \
  --service-name apim-mcp-workshop \
  --api-id knowledge-search \
  --path knowledge \
  --specification-format OpenApiJson \
  --specification-url "https://$KNOWLEDGE_API_URL/api/openapi.json" \
  --display-name "Knowledge Search API" \
  --service-url "https://$KNOWLEDGE_API_URL"
```

Azure Portal で確認:
1. **API Management** → **APIs** → **Knowledge Search API** を開く
2. 各オペレーション（searchArticles, getArticleById, listCategories）が表示されることを確認

#### Step 3: MCP Server として公開（15分）

Azure Portal での操作:

1. **API Management** → **APIs** → **MCP Servers** を開く
2. **+ Create MCP server** をクリック
3. **Expose an API as an MCP server** を選択
4. 以下を入力:

| 項目 | 値 |
|---|---|
| MCP Server name | `knowledge-search-mcp` |
| Base path | `/knowledge-mcp` |
| Description | `社内ナレッジベースを検索するMCP Server。記事の全文検索、カテゴリ別一覧、個別記事の取得が可能。` |

5. **Source API** で `Knowledge Search API` を選択
6. 公開する **Operations（= Tools）** を選択:
   - ✅ `searchArticles` — 記事のキーワード検索
   - ✅ `getArticleById` — 記事IDでの詳細取得
   - ✅ `listCategories` — カテゴリ一覧取得
7. **Create** をクリック

> **💡 ポイント**: Tool の名前と説明文は、LLM がツール選択に使います。わかりやすい説明を書くことが重要です。

#### Step 4: MCP Inspector で動作確認（15分）

```bash
# MCP Inspector を起動
npx @modelcontextprotocol/inspector
```

MCP Inspector の接続設定:
```
Transport: Streamable HTTP
URL: https://apim-mcp-workshop.azure-api.net/knowledge-mcp/mcp
Headers:
  Ocp-Apim-Subscription-Key: <your-subscription-key>
```

確認手順:
1. **Connect** → 接続成功を確認
2. **Tools** タブ → 3つのツール（searchArticles, getArticleById, listCategories）が表示される
3. `searchArticles` を選択 → パラメータに `{"query": "VPN"}` を入力 → **Call Tool**
4. レスポンスにナレッジ記事が返ることを確認

#### Step 5: On-call Schedule API も MCP 化（5分）

同様の手順で On-call Schedule API も MCP Server として公開します。

| 項目 | 値 |
|---|---|
| MCP Server name | `oncall-schedule-mcp` |
| Base path | `/oncall-mcp` |
| Tools | `getCurrentOncall`, `getScheduleByDate` |

### ✅ 確認ポイント

- [ ] MCP Inspector から APIM 経由でツールを呼び出せる
- [ ] `tools/list` で 3 つのツールが返る
- [ ] `searchArticles` でキーワード検索結果が返る
- [ ] MCP セッション ID（`Mcp-Session-Id`）がレスポンスヘッダーに含まれる

### 📦 成果物

| 成果物 | 内容 |
|---|---|
| MCP endpoint URL | `https://apim-mcp-workshop.azure-api.net/knowledge-mcp/mcp` |
| Tool 定義一覧 | searchArticles / getArticleById / listCategories |
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

```bash
# Incident MCP Server の URL を取得
INCIDENT_MCP_URL=$(az containerapp show \
  --name ca-incident-mcp \
  --resource-group rg-mcp-workshop \
  --query "properties.configuration.ingress.fqdn" -o tsv)

# MCP Inspector で直接接続して動作確認
npx @modelcontextprotocol/inspector
```

直接接続の設定:
```
URL: https://$INCIDENT_MCP_URL/mcp
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
2. **Expose an existing MCP server** を選択
3. 以下を入力:

| 項目 | 値 |
|---|---|
| MCP Server name | `incident-mcp` |
| Base path | `/incident-mcp` |
| Description | `障害チケット管理用MCP Server。チケットの参照、起票が可能。` |
| Backend URL | `https://<INCIDENT_MCP_URL>` |

4. **Create** をクリック

#### Step 3: APIM 経由での動作確認（10分）

MCP Inspector で APIM 経由の接続を確認:
```
URL: https://apim-mcp-workshop.azure-api.net/incident-mcp/mcp
Headers:
  Ocp-Apim-Subscription-Key: <your-subscription-key>
```

確認手順:
1. `tools/list` → 3 つのツールが返る
2. `listIncidents` を呼び出し → チケット一覧が返る
3. 直接接続とAPIM経由の**レスポンス内容が同一**であることを確認

#### Step 4: 直接接続と APIM 経由の差分整理（15分）

以下の表を埋めて、APIM を経由するメリットを整理しましょう。

| 項目 | 直接接続 | APIM 経由 |
|---|---|---|
| URL | `https://<backend>/mcp` | `https://<apim>/incident-mcp/mcp` |
| 認証 | なし | サブスクリプションキー（Lab 3 で OAuth に拡張） |
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

**MCP Client 用アプリ登録:**

```bash
# MCP Client アプリを登録
az ad app create \
  --display-name "MCP Workshop Client" \
  --sign-in-audience AzureADMyOrg \
  --web-redirect-uris "http://localhost:3000/callback"

# Client ID を記録
CLIENT_APP_ID=$(az ad app list --display-name "MCP Workshop Client" \
  --query "[0].appId" -o tsv)
echo "Client App ID: $CLIENT_APP_ID"
```

**MCP Server 用アプリ登録:**

```bash
# MCP Server アプリを登録
az ad app create \
  --display-name "MCP Workshop Server" \
  --sign-in-audience AzureADMyOrg

# Server App ID を記録
SERVER_APP_ID=$(az ad app list --display-name "MCP Workshop Server" \
  --query "[0].appId" -o tsv)
echo "Server App ID: $SERVER_APP_ID"
```

#### Step 2: パターンA — ユーザー代理実行の実装（15分）

Knowledge Search MCP Server にインバウンド認証ポリシーを追加します。

Azure Portal → API Management → APIs → MCP Servers → `knowledge-search-mcp` → Policies

```xml
<policies>
    <inbound>
        <base />

        <!-- Entra ID トークンの検証 -->
        <validate-azure-ad-token
            tenant-id="{your-tenant-id}"
            header-name="Authorization"
            failed-validation-httpcode="401"
            failed-validation-error-message="Unauthorized: Invalid or missing token">
            <client-application-ids>
                <application-id>{CLIENT_APP_ID}</application-id>
            </client-application-ids>
            <audiences>
                <audience>{SERVER_APP_ID}</audience>
            </audiences>
        </validate-azure-ad-token>

        <!-- ユーザー情報をカスタムヘッダーに抽出（監査用） -->
        <set-header name="X-User-Id" exists-action="override">
            <value>@(context.Request.Headers
                .GetValueOrDefault("Authorization","")
                .AsJwt()?.Claims
                .GetValueOrDefault("oid","unknown"))</value>
        </set-header>

    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
</policies>
```

**動作確認:**

```bash
# トークンを取得（Azure CLI）
TOKEN=$(az account get-access-token \
  --resource "api://$SERVER_APP_ID" \
  --query "accessToken" -o tsv)

# MCP Inspector で認証付きアクセス
# Headers に Authorization: Bearer $TOKEN を追加
```

- ✅ トークンなし → 401 Unauthorized
- ✅ トークンあり → ツール呼び出し成功

#### Step 3: パターンB — サービスID実行の実装（15分）

On-call Schedule MCP Server に Managed Identity ベースのアウトバウンド認証を設定します。

```xml
<policies>
    <inbound>
        <base />
        <!-- インバウンドはサブスクリプションキーで認証 -->
    </inbound>
    <backend>
        <!-- Managed Identity でバックエンド認証 -->
        <authentication-managed-identity
            resource="api://{ONCALL_BACKEND_APP_ID}" />
    </backend>
    <outbound>
        <base />
    </outbound>
</policies>
```

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

    <!-- MCP セッション単位でレート制限（1分あたり30リクエスト） -->
    <rate-limit-by-key
        calls="30"
        renewal-period="60"
        counter-key="@(context.Request.Headers
            .GetValueOrDefault("Mcp-Session-Id","anonymous"))"
        increment-condition="@(context.Response.StatusCode >= 200)" />

</inbound>
```

**動作確認:**
- MCP Inspector から連続でツールを呼び出し
- 31 回目で `429 Too Many Requests` が返ることを確認

#### Step 2: 相関IDの注入（10分）

```xml
<inbound>
    <base />

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

#### Step 3: 診断設定の構成（10分）

```bash
# APIM の診断設定を構成
az monitor diagnostic-settings create \
  --resource $(az apim show -n apim-mcp-workshop -g rg-mcp-workshop --query id -o tsv) \
  --name "mcp-diagnostics" \
  --workspace $(az monitor log-analytics workspace show \
    -n law-mcp-workshop -g rg-mcp-workshop --query id -o tsv) \
  --logs '[
    {"category": "GatewayLogs", "enabled": true},
    {"category": "GatewayMCPLogs", "enabled": true}
  ]'
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

```bash
# 5xx エラーが5分間に10回以上発生したらアラート
az monitor metrics alert create \
  --name "mcp-5xx-alert" \
  --resource-group rg-mcp-workshop \
  --scopes $(az apim show -n apim-mcp-workshop -g rg-mcp-workshop --query id -o tsv) \
  --condition "total Requests > 10 where ResponseCode includes 5xx" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --description "MCP Server 5xx errors exceeded threshold"
```

### ✅ 確認ポイント

- [ ] レート制限で 429 が返ることを確認
- [ ] Application Insights で相関IDによるトレースが確認できる
- [ ] KQL クエリでツール呼び出し状況が可視化される
- [ ] Payload bytes to log = 0 を設定した

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

```bash
# API Center に APIM をリンク
az apic integration create \
  --resource-group rg-mcp-workshop \
  --service-name apic-mcp-workshop \
  --integration-name apim-link \
  --integration-type apim \
  --target-resource-id $(az apim show -n apim-mcp-workshop \
    -g rg-mcp-workshop --query id -o tsv)
```

> **💡 ポイント**: 同期は一方向（APIM → API Center）で、通常数分以内に反映されます（最大24時間の場合あり）。MCP Servers と A2A Agent APIs も同期対象です。

数分待ってから同期結果を確認:

```bash
# 登録された API 一覧を確認
az apic api list \
  --resource-group rg-mcp-workshop \
  --service-name apic-mcp-workshop \
  --output table
```

#### Step 2: カスタムメタデータの定義（10分）

組織独自のガバナンス項目をメタデータとして定義します。

```bash
# データ分類メタデータ
az apic metadata create \
  --resource-group rg-mcp-workshop \
  --service-name apic-mcp-workshop \
  --metadata-name "dataClassification" \
  --title "Data Classification" \
  --schema '{"type":"string","enum":["public","internal","confidential","restricted"]}' \
  --assignments '[{"entity":"api","required":true}]'

# 認証方式メタデータ
az apic metadata create \
  --resource-group rg-mcp-workshop \
  --service-name apic-mcp-workshop \
  --metadata-name "authMode" \
  --title "Authentication Mode" \
  --schema '{"type":"string","enum":["user-delegated","service-identity","mixed"]}' \
  --assignments '[{"entity":"api","required":true}]'

# SLA ターゲットメタデータ
az apic metadata create \
  --resource-group rg-mcp-workshop \
  --service-name apic-mcp-workshop \
  --metadata-name "slaTarget" \
  --title "SLA Target (%)" \
  --schema '{"type":"string","enum":["99.9","99.5","99.0","best-effort"]}' \
  --assignments '[{"entity":"api","required":false}]'

# オーナーチームメタデータ
az apic metadata create \
  --resource-group rg-mcp-workshop \
  --service-name apic-mcp-workshop \
  --metadata-name "ownerTeam" \
  --title "Owner Team" \
  --schema '{"type":"string"}' \
  --assignments '[{"entity":"api","required":true}]'
```

#### Step 3: MCP Server のメタデータを付与（10分）

```bash
# Knowledge Search MCP Server にメタデータを設定
az apic api update \
  --resource-group rg-mcp-workshop \
  --service-name apic-mcp-workshop \
  --api-id knowledge-search-mcp \
  --custom-properties '{
    "dataClassification": "internal",
    "authMode": "user-delegated",
    "slaTarget": "99.5",
    "ownerTeam": "ナレッジ管理チーム"
  }'

# Incident MCP Server にメタデータを設定
az apic api update \
  --resource-group rg-mcp-workshop \
  --service-name apic-mcp-workshop \
  --api-id incident-mcp \
  --custom-properties '{
    "dataClassification": "confidential",
    "authMode": "user-delegated",
    "slaTarget": "99.9",
    "ownerTeam": "ITサービスデスクチーム"
  }'
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
      "url": "https://apim-mcp-workshop.azure-api.net/knowledge-mcp/mcp",
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
