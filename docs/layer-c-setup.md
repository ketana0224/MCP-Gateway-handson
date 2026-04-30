# Layer C セットアップガイド — GitHub Actions + Azure OIDC

このガイドでは、`.github/workflows/layer-c.yml` を動作させるために必要な **ワンタイムセットアップ** を説明します。

## 前提条件

- Azure CLI 2.60+ がインストール済み (`az --version`)
- GitHub CLI がインストール済み (`gh --version`)
- 対象 Azure サブスクリプションへの **Contributor** 権限
- 対象 GitHub リポジトリへの **Admin** 権限（Variables 登録に必要）

---

## 1. Azure AD アプリ登録 + Federated Credentials 設定

以下のコマンドを **ローカルターミナル** または **Azure Cloud Shell** で実行します。

```bash
# Azure にログイン（未ログインの場合）
az login

# 1. App Registration 作成
APP_ID=$(az ad app create --display-name mcp-handson-gh-oidc --query appId -o tsv)
echo "APP_ID: $APP_ID"

# 2. Service Principal 作成
az ad sp create --id $APP_ID

# 3. Federated Credential — main ブランチ用
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "gh-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:ketana0224/MCP-Gateway-handson:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

# 4. Federated Credential — Pull Request 用
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "gh-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:ketana0224/MCP-Gateway-handson:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

# 5. Contributor ロール付与（サブスクリプションレベル）
SUB_ID=$(az account show --query id -o tsv)
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/$SUB_ID

echo "Setup complete."
echo "APP_ID:  $APP_ID"
echo "SUB_ID:  $SUB_ID"
echo "TENANT:  $(az account show --query tenantId -o tsv)"
```

---

## 2. GitHub Variables 登録

```bash
# GitHub CLI でリポジトリに Variables を登録
gh variable set AZURE_CLIENT_ID \
  --body "$APP_ID" \
  --repo ketana0224/MCP-Gateway-handson

gh variable set AZURE_TENANT_ID \
  --body "$(az account show --query tenantId -o tsv)" \
  --repo ketana0224/MCP-Gateway-handson

gh variable set AZURE_SUBSCRIPTION_ID \
  --body "$SUB_ID" \
  --repo ketana0224/MCP-Gateway-handson
```

> **Note:** Variables は Settings > Secrets and variables > Actions > Variables に保存されます。  
> Secrets と異なり、ワークフローログに値が表示されることがありますが、  
> Client ID / Tenant ID / Subscription ID はシークレットではないため Variables 扱いが適切です。

---

## 3. GitHub ラベル作成

ワークフローは PR に **`run-layer-c`** ラベルが付いた場合のみ実行されます（APIM Developer SKU の誤爆防止）。

```bash
# run-layer-c ラベル作成
gh label create run-layer-c \
  --description "Trigger Layer C: Azure deploy + MCP verification" \
  --color "0075ca" \
  --repo ketana0224/MCP-Gateway-handson

# run-layer-c-destroy ラベル作成（検証後にリソースグループを自動削除）
gh label create run-layer-c-destroy \
  --description "Auto-delete resource group after Layer C verification" \
  --color "e4e669" \
  --repo ketana0224/MCP-Gateway-handson
```

---

## 4. ワークフロー実行方法

### 方法 A: PR にラベルを付けて自動実行

1. `infra/**` / `policies/**` / `.github/workflows/layer-c.yml` を変更した PR を作成
2. PR に **`run-layer-c`** ラベルを付ける
3. ワークフローが自動起動し、約 30〜45 分後に PR にコメントが投稿されます

**検証後にリソースを自動削除したい場合:**  
PR に **`run-layer-c-destroy`** ラベルを追加してください。

### 方法 B: 手動実行 (workflow_dispatch)

1. GitHub リポジトリの **Actions** タブを開く
2. **Layer C — Azure Deploy + MCP tools/list Verification** を選択
3. **Run workflow** ボタンをクリック
4. パラメータを入力して実行:
   - `resourceGroup`: リソースグループ名（デフォルト: `rg-mcp-workshop`）
   - `location`: Azureリージョン（デフォルト: `japaneast`）
   - `destroy`: 完了後にリソースグループを削除するか（`true`/`false`）

---

## 5. 実行確認ポイント

ワークフロー完了後、以下を確認してください:

| # | 確認事項 | 場所 |
|---|---|---|
| C1 | デプロイ outputs に `apimGatewayUrl` が含まれる | Actions ログ `Get deployment outputs` ステップ |
| C2 | `knowledge-mcp/mcp` への HTTP ステータス | PR コメント or Actions ログ |
| C3 | `incident-mcp/mcp` への HTTP ステータス | PR コメント or Actions ログ |
| C4 | `oncall-mcp/mcp` への HTTP ステータス | PR コメント or Actions ログ |

---

## 6. コスト注意

> ⚠️ **APIM Developer SKU は起動するだけで課金されます（約 ¥7,000/月）。**  
> PR ごとにリソースグループを作成し、確認後は必ず削除してください。

- **推奨:** `run-layer-c-destroy` ラベルを常に併用し、自動削除を有効にする
- **手動削除:**
  ```bash
  az group delete -n rg-mcp-workshop --yes --no-wait
  ```
- **確認:**
  ```bash
  az group show -n rg-mcp-workshop
  # "provisioningState": "Deleting" or error (deleted) が正常
  ```

---

## 7. トラブルシューティング

### OIDC 認証エラー (`AADSTS70021`)

Federated Credential の `subject` が一致していない可能性があります。  
PR からの実行には `pull_request` subject が必要です（手順 1 の Step 4 参照）。

### デプロイタイムアウト

APIM Developer SKU のプロビジョニングには **15〜20 分** かかります。  
ワークフローの `timeout-minutes: 60` 内に収まるはずですが、Azure の混雑状況によっては延びることがあります。

### `apimGatewayUrl` が空

`infra/main.bicep` の outputs に `apimGatewayUrl` が定義されていることを確認してください:

```bash
az deployment group show \
  -g rg-mcp-workshop \
  -n main \
  --query "properties.outputs" \
  -o json
```

### tools/list が空 / エラー

§6（AGENTS.md）の通り、コンテナイメージはプレースホルダです。  
実際の MCP ツール動作確認には `src/*` のコンテナ化・push・image 差し替えが必要です。  
HTTP ステータスの確認（200/4xx = OK、5xx/0 = NG）が現時点での検証範囲です。
