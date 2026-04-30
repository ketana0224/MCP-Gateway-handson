# AGENTS.md — MCP-Gateway-handson

このファイルは、AIコーディングエージェント（GitHub Copilot Coding Agent 等）および
講師・受講者が、このハンズオン教材の **動作確認** を再現可能に行うための指示書です。

---

## 1. リポジトリ概要

Azure API Management を **MCP Gateway**、API Center を **MCP Server Registry** として
活用する教材リポジトリ。Lab 0〜7 で構成され、本体ドキュメントは
[`docs/hands-on.md`](./docs/hands-on.md)。

- インフラ: `infra/main.bicep`(+ `infra/modules/*`)
- バックエンド (Node.js / Express):
  - `src/knowledge-api/`        … REST API（port 3000）— Lab 1
  - `src/incident-mcp-server/`  … MCP Server / Streamable HTTP（port 3001）— Lab 2
  - `src/oncall-api/`           … REST API（port 3002）— Lab 1
- APIM ポリシー: `policies/*.xml`
- 監査クエリ: `queries/dashboard.kql`
- VS Code MCP 設定: `.vscode/mcp.json`

---

## 2. 動作確認の3レイヤー

### Layer A — ローカル単体（Azureなしで実行可能）
受講者が手早く挙動を見るため、および AI エージェントが PR で破壊変更していないかを
確かめるための最小チェック。

### Layer B — インフラ検証（Bicep）
Azure へデプロイせず、テンプレートが論理的に正しいかだけを確認。

### Layer C — E2E（Azure 実デプロイ）
Bicep デプロイ後、APIM 経由で MCP の `tools/list` まで通ることを確認。
**所要 30〜45 分（APIM Developer SKU プロビジョニング含む）**。

---

## 3. 必須環境

- Node.js 20+
- Azure CLI 2.60+（Layer B/C で使用）
- Bicep CLI（`az bicep install` 済みであれば OK）
- npx（MCP Inspector 起動用）

---

## 4. コマンド一覧（エージェントはここから実行）

### 4.1 依存インストール
```bash
( cd src/knowledge-api       && npm install )
( cd src/incident-mcp-server && npm install )
( cd src/oncall-api          && npm install )
```

### 4.2 ローカル起動（別ターミナルで個別に）
```bash
( cd src/knowledge-api       && npm start )   # http://localhost:3000
( cd src/incident-mcp-server && npm start )   # http://localhost:3001
( cd src/oncall-api          && npm start )   # http://localhost:3002
```

### 4.3 Bicep 検証（デプロイなし）
```bash
az bicep build --file infra/main.bicep
az deployment group what-if \
  --resource-group <existing-rg> \
  --template-file infra/main.bicep \
  --parameters infra/parameters.json
```

### 4.4 E2E デプロイ（Layer C）
```bash
# 新規サブスクリプションの場合は先にプロバイダーを登録
az provider register -n Microsoft.App --wait
az provider register -n Microsoft.ApiManagement --wait
az provider register -n Microsoft.ApiCenter --wait
az provider register -n Microsoft.KeyVault --wait
az provider register -n Microsoft.Insights --wait
az provider register -n Microsoft.OperationalInsights --wait

az group create -n rg-mcp-workshop -l japaneast
az deployment group create \
  -g rg-mcp-workshop \
  -f infra/main.bicep \
  -p infra/parameters.json
```

### 4.5 後片付け
```bash
az group delete -n rg-mcp-workshop --yes --no-wait
```

---

## 5. Acceptance Criteria（合格条件）

### Layer A — ローカル単体
| # | チェック | コマンド | 期待 |
|---|---|---|---|
| A1 | Knowledge API 起動 | `curl http://localhost:3000/health` | `{"status":"ok"}` |
| A2 | カテゴリ取得 | `curl http://localhost:3000/api/categories` | 4件のJSON配列 |
| A3 | 検索 | `curl -X POST http://localhost:3000/api/articles/search -H "Content-Type: application/json" -d '{"query":"VPN"}'` | `count >= 1` |
| A4 | OpenAPI | `curl http://localhost:3000/api/openapi.json` | OpenAPI 3.0.3 JSON |
| A5 | Oncall API | `curl http://localhost:3002/api/oncall/2026-04-30` | 当番情報JSON |
| A6 | Incident MCP 起動 | `curl http://localhost:3001/health` | `{"status":"ok"}` |
| A7 | MCP Inspector で `tools/list` が `listIncidents` / `getIncident` / `createIncident` の3件返す | `npx @modelcontextprotocol/inspector` で `http://localhost:3001/mcp` に接続 | 3 tools |

### Layer B — Bicep
| # | チェック | 期待 |
|---|---|---|
| B1 | `az bicep build` がエラーなく完了 | exit 0 |
| B2 | `what-if` で APIM / API Center / Container Apps / Log Analytics / App Insights / Key Vault の作成が出力される | 全リソース表示 |
| B3 | `policies/*.xml` がXMLとして整形済み | `xmllint --noout policies/*.xml`（任意） |
| B4 | `queries/dashboard.kql` が空でない | `test -s queries/dashboard.kql` |

### Layer C — E2E
| # | チェック | 期待 |
|---|---|---|
| C1 | デプロイ outputs に `apimGatewayUrl` 等が含まれる | `az deployment group show` で確認 |
| C2 | APIM 経由で `https://<apim>.azure-api.net/knowledge-mcp/mcp` が `tools/list` を返す | MCP Inspector で 200 + tools 配列 |
| C3 | APIM 経由で `https://<apim>.azure-api.net/incident-mcp/mcp` が `tools/list` を返す | 同上 |
| C4 | APIM 経由で `https://<apim>.azure-api.net/oncall-mcp/mcp` が `tools/list` を返す | 同上 |
| C5 | Log Analytics の `ApiManagementGatewayMCPLog` に直近10分のレコード | `queries/dashboard.kql` 流用 |

**自動化:** `.github/workflows/layer-c.yml` 参照（Azure OIDC セットアップは `docs/layer-c-setup.md`）

---

## 6. 既知の制約 / 注意

- `infra/modules/container-apps.bicep` の `image:` は **プレースホルダ**（`mcr.microsoft.com/azuredocs/containerapps-helloworld:latest`）。
  Layer C で実 API 動作を確認するには、**`src/*` のコンテナ化と push、image 差し替えが必要**。
  → Layer A（ローカル）か、image 差し替え後の Layer C で確認すること。
- `infra/parameters.json` の `apimPublisherEmail` は `<your-email@example.com>` のまま。
  デプロイ前に必ず実在メールへ書き換える。
- APIM Developer SKU は **15〜20分** のプロビジョニング時間がかかる。

---

## 7. エージェントが守るべきルール

- **書き換えてよい**: `src/**`, `infra/**`, `policies/**`, `queries/**`, `docs/**`, `.vscode/**`
- **書き換え時は必ず Layer A まで通すこと**
- **書き換えてはいけない**:
  - `src/knowledge-api/index.js` のサンプルKBデータ（教材で参照される）
  - `src/incident-mcp-server/index.js` のツール名 (`listIncidents` / `getIncident` / `createIncident`) — `docs/hands-on.md` から参照される契約
  - `src/oncall-api/index.js` のサンプル日付（2026-04-28〜2026-05-02）— ハンズオン手順の前提
- **PR 説明には**「Layer A の A1〜A7 をどう確認したか」を記載する

---

## 8. 参考リンク

- ハンズオン本体: [`docs/hands-on.md`](./docs/hands-on.md)
- APIM MCP: <https://learn.microsoft.com/azure/api-management/mcp-server-overview>
- API Center MCP Registry: <https://learn.microsoft.com/azure/api-center/register-discover-mcp-server>
- MCP Spec: <https://modelcontextprotocol.io/specification/2025-06-18>
