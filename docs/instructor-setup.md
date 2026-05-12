# 講師用 事前準備ガイド — 複数人ハンズオンの実施

このドキュメントは **同一サブスクリプション内で複数人（〜5 名）の参加者がハンズオンを並行実施する**ためのセットアップ手順です。
**参加者ではなく、講師（テナント管理者）が事前に 1 回だけ実施**してください。

参加者向け本編は [hands-on.md](./hands-on.md) です。

---

## 1. 全体方針

| 項目 | 方針 |
|---|---|
| **Entra ID アプリ** | **講師が事前に 1 セット作成して全員で共有**（Approach C） |
| **Azure リソース** | **参加者ごとに専用 RG + リソースを分離**（リソース名に `userId` を付与） |
| **API Center Free SKU** | **同一サブスクリプション/リージョンで Free SKU は事実上 1 個のみ** → 参加者ごとに **リージョンを分散**して回避 |
| **APIM Developer SKU** | プロビジョニングに 15〜20 分かかるため、Lab 0 開始時に全員で一斉に `az deployment group create` を実行 |

---

## 2. 講師が事前に作成するもの

### 2.1 Entra ID 共有アプリ 2 つ

テナントに以下の 2 アプリを 1 セットだけ作成します。参加者は全員このアプリを共有して使います。

| アプリ | 表示名 | 用途 |
|---|---|---|
| Client | `MCP Workshop Client` | MCP Inspector / Azure CLI からトークン取得する側 |
| Server | `MCP Workshop Server` | APIM の `validate-azure-ad-token` ポリシーが検証する audience |

> **🔐 必要な権限**: アプリの作成・編集は作成者本人で可能ですが、**管理者の同意付与には Application Administrator 以上**が必要です。

#### 手順 A: MCP Client 用アプリ登録

> **📌 役割**: MCP Inspector や Azure CLI (`az account get-access-token`) など「**ツールを呼び出す側**」を表す Entra ID アプリ。
> OAuth 2.0 フローで「ユーザーの代わりに MCP Server へのアクセストークンを取得」する。
> APIM は「この Client から発行されたトークン」であることを検証する。

1. [Azure Portal](https://portal.azure.com) → **Microsoft Entra ID** → **アプリの登録** → 「**+ 新規登録**」
2. 以下を入力して「**登録**」:

   | 項目 | 値 |
   |---|---|
   | 名前 | `MCP Workshop Client` |
   | サポートされているアカウントの種類 | **シングル テナントのみ**（`この組織ディレクトリのみ` と同義） |
   | リダイレクト URI | Web / `http://localhost:3000/callback` |

3. 登録後、「**概要**」→「**アプリケーション (クライアント) ID**」を記録しておく（後で `$CLIENT_APP_ID` として配布）

#### 手順 B: MCP Server 用アプリ登録

> **📌 役割**: APIM の `validate-azure-ad-token` ポリシーが検証する「**トークンの宛先**」を表す Entra ID アプリ。
> `api://<SERVER_APP_ID>` が JWT の `aud`（audience）クレームと一致するか検証される。
> ユーザーは自らログインすることはなく、Client アプリがトークンを代理取得する。

1. 「**+ 新規登録**」
2. 以下を入力して「**登録**」:

   | 項目 | 値 |
   |---|---|
   | 名前 | `MCP Workshop Server` |
   | サポートされているアカウントの種類 | **シングル テナントのみ**（`この組織ディレクトリのみ` と同義） |
   | リダイレクト URI | （空のまま） |

3. 登録後、「**概要**」→「**アプリケーション (クライアント) ID**」を記録しておく（後で `$SERVER_APP_ID` として配布）

#### 手順 C: Application ID URI の設定

1. `MCP Workshop Server` の左メニュー「**API の公開**」→ 画面上部「**追加**」（Application ID URI）
2. 既定値 `api://<appId>` のまま「**保存**」

#### 手順 D: スコープ（access_as_user）の追加

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

#### 手順 E: Client アプリに Server スコープの利用許可を追加し、管理者の同意を付与

Server アプリ自身は何も API を呼ばないため、Server の「API のアクセス許可」は**空で正常**です。
同意はアクセス許可を**使う側（Client アプリ）** から行います。

1. **Microsoft Entra ID** → **アプリの登録** → `MCP Workshop Client` を開く
2. 左メニュー「**API のアクセス許可**」→「**+ アクセス許可の追加**」
3. 右側パネルで「**所属する組織で使用している API**」タブをクリック
4. 検索ボックスに `MCP Workshop Server` と入力 → 候補に表示されたらクリック
5. 「**委任されたアクセス許可**」→ `access_as_user` にチェック → 「**アクセス許可の追加**」
6. 「**<テナント名> に管理者の同意を与えます**」ボタンをクリック → 「**はい**」

> **⚠️ 権限要件**: 管理者の同意付与には Entra ID で **アプリケーション管理者**（Application Administrator）以上のロールが必要です。ボタンがグレーアウトしている場合はロールが不足しています。テナント管理者に依頼してください。

> **⚠️ 注意**: 手順 3 のタブ名は「自分の組織で使用している API」ではなく「**所属する組織で使用している API**」です（Portal の表記に注意）。

> **💡 ここで管理者の同意を付与しておくことで、参加者は自分のアカウントでサインインした際に同意画面を経由せずに `MCP Workshop Server` のスコープを利用できます。**

#### 手順 F: Azure CLI を承認済みクライアントに追加（`az account get-access-token` でのテスト用）

1. `MCP Workshop Server` → 「**API の公開**」
2. 「**承認済みのクライアント アプリケーション**」→「**+ クライアント アプリケーションの追加**」
3. 右パネルの「クライアント ID」欄（プレースホルダーに例の GUID が薄く表示されているが入力欄は空）に以下を入力:
   ```
   04b07795-8ddb-461a-bbee-02f9e1bf7b46
   ```
   > **💡 この GUID は Microsoft Azure CLI の固定 App ID**（すべてのテナント共通）。自分のアプリの ID ではありません。
4. 「承認済みのスコープ」の `api://.../access_as_user` にチェックが入っていることを確認 → 「**アプリケーションの追加**」

> **💡 この手順により、参加者は `az login` 後に `az account get-access-token --resource "api://$env:SERVER_APP_ID"` を実行するだけで Bearer トークンを取得できるようになります。参加者にアプリ登録権限は不要です。**

#### 手順 G: 動作確認（任意・推奨）

講師アカウントで Bearer トークンが取れることを確認します。

> **🔑 前提**: `az account get-access-token` は Azure CLI のサインインセッションを使うため、未ログインなら先に `az login` してください（既にログイン済みなら不要）。
>
> ```powershell
> az login
> az account set --subscription "<your-subscription-id>"   # 複数サブスクリプションがある場合
> ```

```powershell
$SERVER_APP_ID = az ad app list --display-name "MCP Workshop Server" --query "[0].appId" -o tsv
$TOKEN = az account get-access-token --resource "api://$SERVER_APP_ID" --query "accessToken" -o tsv
Write-Host "Token length: $($TOKEN.Length)"  # 1500 文字前後が返れば成功
```

エラーが出た場合は手順 C〜F を見直してください。

### 2.2 参加者への配布値

作成後、以下の 3 値を参加者全員に配布します。

```powershell
# 講師環境で値を取得
$TENANT_ID     = az account show --query "tenantId" -o tsv
$CLIENT_APP_ID = az ad app list --display-name "MCP Workshop Client" --query "[0].appId" -o tsv
$SERVER_APP_ID = az ad app list --display-name "MCP Workshop Server" --query "[0].appId" -o tsv

Write-Host "===== 参加者へ配布する値 ====="
Write-Host "TENANT_ID:     $TENANT_ID"
Write-Host "CLIENT_APP_ID: $CLIENT_APP_ID"
Write-Host "SERVER_APP_ID: $SERVER_APP_ID"
```

### 2.3 共有バックエンドのデプロイ（CAE 上限回避）

> **⚠️ なぜ共有するのか**: Azure Container App Environment（CAE）は **サブスクリプションあたり既定 1 個まで**の制限があります。参加者ごとに CAE を作ると 2 人目以降が `MaxNumberOfGlobalEnvironmentsInSubExceeded` で失敗するため、**講師が 1 セットだけバックエンド（Container Apps × 3 + ACR + CAE）をデプロイし、参加者全員でそれを共有**します。
>
> このハンズオンの主役は APIM / API Center なので、バックエンドの個別所有は重要ではありません。

**手順:**

1. **講師用 RG にバックエンドをデプロイ**（`deployBackend=true` がデフォルトの `infra/parameters.json` を使用）

   ```powershell
   # 講師用の固有 USER_ID を設定（参加者と衝突しない値）
   $env:USER_ID  = "instructor"
   $env:LOCATION = "eastus"   # API Center 対応リージョンならどれでも可
   $RG = "rg-mcp-$env:USER_ID"

   az group create --name $RG --location $env:LOCATION

   # parameters.json は deployBackend を持たない → 既定値 true でフルセット作成
   az deployment group create `
     --resource-group $RG `
     --name main `
     --template-file infra/main.bicep `
     --parameters infra/parameters.json `
     --parameters userId=$env:USER_ID location=$env:LOCATION
   ```

   > **📌 補足**: 講師は **APIM や API Center も使う**ので、参加者と同じく `parameters.json` でフルセット作成して問題ありません。バックエンドが含まれている点だけが参加者用テンプレートとの違いです。

2. **コンテナイメージをビルド & Container Apps を更新**

   ```powershell
   function Get-McpOutput($name) {
     az deployment group show -g $RG -n main --query "properties.outputs.$name.value" -o tsv
   }
   $ACR_NAME       = Get-McpOutput "acrName"
   $ACR_SERVER     = Get-McpOutput "acrLoginServer"
   $CA_KNOWLEDGE   = Get-McpOutput "knowledgeApiContainerAppName"
   $CA_INCIDENT    = Get-McpOutput "incidentMcpContainerAppName"
   $CA_ONCALL      = Get-McpOutput "oncallApiContainerAppName"

   # ACR でサーバーサイドビルド（ローカルに Docker 不要）
   az acr build --registry $ACR_NAME --image "knowledge-api:latest" src/knowledge-api/
   az acr build --registry $ACR_NAME --image "incident-mcp:latest" src/incident-mcp-server/
   az acr build --registry $ACR_NAME --image "oncall-api:latest" src/oncall-api/

   $ACR_USERNAME = az acr credential show --name $ACR_NAME --query "username" -o tsv
   $ACR_PASSWORD = az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv

   # 1. 各 Container App に ACR 認証情報を登録（registry set）
   az containerapp registry set --name $CA_KNOWLEDGE -g $RG `
     --server $ACR_SERVER --username $ACR_USERNAME --password $ACR_PASSWORD
   az containerapp registry set --name $CA_INCIDENT -g $RG `
     --server $ACR_SERVER --username $ACR_USERNAME --password $ACR_PASSWORD
   az containerapp registry set --name $CA_ONCALL -g $RG `
     --server $ACR_SERVER --username $ACR_USERNAME --password $ACR_PASSWORD

   # 2. イメージを更新
   az containerapp update --name $CA_KNOWLEDGE -g $RG --image "$ACR_SERVER/knowledge-api:latest"
   az containerapp update --name $CA_INCIDENT  -g $RG --image "$ACR_SERVER/incident-mcp:latest"
   az containerapp update --name $CA_ONCALL    -g $RG --image "$ACR_SERVER/oncall-api:latest"
   ```

   > **⚠️ `az acr build` で `TasksOperationsNotAllowed` エラーが出る場合**: サブスクリプションで ACR Tasks が制限されています。Docker Desktop を起動し、ローカルでビルド・push してください:
   >
   > ```powershell
   > az acr login --name $ACR_NAME
   > docker build -t "$ACR_SERVER/knowledge-api:latest" .\src\knowledge-api\        ; docker push "$ACR_SERVER/knowledge-api:latest"
   > docker build -t "$ACR_SERVER/incident-mcp:latest"  .\src\incident-mcp-server\  ; docker push "$ACR_SERVER/incident-mcp:latest"
   > docker build -t "$ACR_SERVER/oncall-api:latest"    .\src\oncall-api\           ; docker push "$ACR_SERVER/oncall-api:latest"
   > ```
   >
   > その後、上記の `containerapp registry set` + `containerapp update` ブロックを実行してください。

3. **3 つの FQDN を取得して参加者へ配布**

   ```powershell
   $KNOWLEDGE_API_URL = Get-McpOutput "knowledgeApiUrl"
   $INCIDENT_MCP_URL  = Get-McpOutput "incidentMcpUrl"
   $ONCALL_API_URL    = Get-McpOutput "oncallApiUrl"

   Write-Host "===== 参加者へ配布する共有バックエンド URL ====="
   Write-Host "KNOWLEDGE_API_URL: $KNOWLEDGE_API_URL"
   Write-Host "INCIDENT_MCP_URL:  $INCIDENT_MCP_URL"
   Write-Host "ONCALL_API_URL:    $ONCALL_API_URL"
   ```

4. **動作確認**

   ```powershell
   curl "https://$KNOWLEDGE_API_URL/health"
   curl "https://$INCIDENT_MCP_URL/health"
   curl "https://$ONCALL_API_URL/health"
   ```

   3 つとも `{"status":"ok"}` が返れば OK です。

> **💡 リージョン制約**: 共有バックエンドの **リージョンは固定**（例: `eastus`）です。参加者の APIM はそれぞれ別リージョン（API Center 対応リージョンに分散）にあるため、APIM → 共有バックエンドの通信は **クロスリージョン**になります。レイテンシは +50〜150 ms 程度で、ハンズオン体験には支障ありません。

> **💡 Incident MCP の書き込みデータ**: `createIncident` で起票したチケットは共有バックエンド側でインメモリ保持されるため、**他参加者が起票したチケットも見えます**。教材の趣旨上問題ない想定ですが、Container Apps を再起動するとデータは消えます。

> **💡 Lab 4 の App Insights エンドツーエンドトレース**: バックエンド側のリクエストイベントは **講師の App Insights** に記録されます。参加者の Application Insights では APIM → バックエンドの Dependency までは見えますが、バックエンド側 Request イベントは見えません。トレースに「バックエンド側 Request」を含めたい場合は参加者用 Bicep で `deployBackend=true` に設定し、自分のバックエンドをデプロイしてください（CAE 上限の引き上げが必要）。

---

## 3. 参加者割り当て表

5 名想定。**`userId` と `location` を講師が事前に固定**し、各参加者へ通知します。

> **⚠️ API Center の利用可能リージョン**（2026年5月時点）: 
> `eastus` / `westeurope` / `uksouth` / `centralindia` / `australiaeast` / `francecentral` / `swedencentral` / `canadacentral` のみ。
> **`japaneast` / `japanwest` は未対応**のため、下記は全員を対応リージョンに分散しています。

| 参加者 | `USER_ID` | `LOCATION` | 備考 |
|---|---|---|---|
| 受講者 1 | `user01` | `westeurope` | API Center Free SKU を West Europe で確保 |
| 受講者 2 | `user02` | `australiaeast` | API Center Free SKU を Australia East で確保（アジアで近い） |
| 受講者 3 | `user06` | `centralindia` | API Center Free SKU を Central India で確保。**※ user03 は `apic-mcp-user03-*` のグローバル名前空間衝突により使用不可のため user06 に変更** |
| 受講者 4 | `user04` | `uksouth` | API Center Free SKU を UK South で確保 |
| 受講者 5 | `user05` | `swedencentral` | API Center Free SKU を Sweden Central で確保 |

> **⚠️ API Center Free SKU の制約**: 同一サブスクリプション内で API Center は同じリージョンに複数立てると `Quota exceeded` になります（2026年5月時点）。**参加者ごとにリージョンを変える**ことでこの制限を回避します。
>
> 5 名を超える場合、または全員を同一リージョンに揃えたい場合は、講師が事前に API Center を **Standard SKU** で 1 つだけ立てて全員で共有する構成を検討してください（本ハンズオンでは扱いません）。

> **💡 Container Apps と APIM も同じリージョンでデプロイされる**: 上記リージョンは API Center / Container Apps / APIM のいずれも利用可能です。アジアから近いリージョンがよければ `australiaeast` を選ぶのがレイテンシ上有利です。

### 3.1 参加者へのロール付与（必須）

参加者は自分の RG に対して **`Owner` ロール**が必要です（Lab 5 Step 1 の `az role assignment create` で `Microsoft.Authorization/roleAssignments/write` 権限を要求するため）。

#### 推奨: Portal で 1 人ずつ付与

1. [Azure Portal](https://portal.azure.com) で **リソースグループ** → `rg-mcp-user01` を開く（事前作成不要、`az group create` で先に作っておくと付与が楽）
2. 左メニュー **「アクセス制御 (IAM)」** → 上部 **「＋ 追加」** → **「ロールの割り当ての追加」**
3. **ロール**: 検索ボックスに `Owner` → **「所有者」** を選択 → **「次へ」**
4. **メンバー**: **「＋ メンバーの選択」** → 参加者の名前 or メールアドレスで検索 → 選択 → **「選択」**
5. **「確認と割り当て」** → 完了

各参加者（user01 / user02 / user06 / user04 / user05）について繰り返す。

#### CLI で一括付与（参加者が多い場合）

```powershell
# 参加者リスト（UPN は実在のものに置き換える。下記は aidemo2026outlook テナントの例）
$participants = @(
  @{ upn = "user01@aidemo2026outlook.onmicrosoft.com"; userId = "user01"; location = "westeurope" },
  @{ upn = "user02@aidemo2026outlook.onmicrosoft.com"; userId = "user02"; location = "australiaeast" },
  @{ upn = "user06@aidemo2026outlook.onmicrosoft.com"; userId = "user06"; location = "centralindia" },  # ※ user03 はグローバル名前空間衝突により使用不可のため user06 に変更
  @{ upn = "user04@aidemo2026outlook.onmicrosoft.com"; userId = "user04"; location = "uksouth" },
  @{ upn = "user05@aidemo2026outlook.onmicrosoft.com"; userId = "user05"; location = "swedencentral" }
)

$sub = az account show --query id -o tsv
Write-Host "Subscription: $sub"

foreach ($p in $participants) {
  $rg = "rg-mcp-$($p.userId)"
  Write-Host ""
  Write-Host "===== $($p.userId) ($($p.upn)) -> $rg in $($p.location) ====="

  # 1. RG を作成（既存ならスキップ）
  az group create --name $rg --location $p.location | Out-Null

  # 2. UPN から Object ID を解決
  $oid = az ad user show --id $p.upn --query "id" -o tsv 2>$null
  if (-not $oid) {
    Write-Warning "  User not found: $($p.upn). Skipping."
    continue
  }

  # 3. Owner ロールを RG スコープで付与
  az role assignment create `
    --assignee-object-id $oid `
    --assignee-principal-type User `
    --role "Owner" `
    --scope "/subscriptions/$sub/resourceGroups/$rg" `
    --output none

  Write-Host "  Owner assigned to $($p.upn) on $rg"
}
```

**確認:**

```powershell
# RG が 5 つ作られているか
az group list --query "[?starts_with(name, 'rg-mcp-user')].{name:name, location:location}" -o table

# 各 RG のロール割り当てを確認
foreach ($p in $participants) {
  $rg = "rg-mcp-$($p.userId)"
  Write-Host "===== $rg ====="
  az role assignment list --resource-group $rg `
    --query "[].{principal:principalName, role:roleDefinitionName}" -o table
}
```

> **💡 なぜ Owner なのか**: Lab 5 Step 1 で `az role assignment create --role "API Management Service Reader Role" ...` を実行するため。
>
> セキュリティ重視なら `Contributor` + `User Access Administrator` の 2 ロールに分けることも可能ですが、Portal 操作なら 1 ロールの方が運用が楽です。

> **⚠️ 外部ゲストユーザーの場合**: UPN は `tanaka.taro_gmail.com#EXT#@yourtenant.onmicrosoft.com` のような形式になります。先にゲスト招待を済ませてから上記スクリプトを実行してください。

---

## 4. 参加者への案内テンプレート（コピペ用）

各参加者に以下のような形で連絡してください。

```
こんにちは、{参加者名} さん。

ハンズオンの事前準備値を共有します。
PowerShell で以下を最初に実行してから、hands-on.md の Lab 0 に進んでください。

# あなた専用の参加者ID と リージョン
$env:USER_ID  = "user01"            # ← 各参加者で異なる
$env:LOCATION = "westeurope"        # ← 各参加者で異なる

# サブスクリプション ID
$env:SUBSCRIPTION_ID = "33333333-3333-3333-3333-333333333333"

# Entra ID（全員共通・講師から配布）
$env:TENANT_ID     = "00000000-0000-0000-0000-000000000000"
$env:CLIENT_APP_ID = "11111111-1111-1111-1111-111111111111"
$env:SERVER_APP_ID = "22222222-2222-2222-2222-222222222222"

# 共有バックエンド URL（全員共通・講師から配布）
$env:KNOWLEDGE_API_URL = "ca-knowledge-api-instructor.xxxxx.eastus.azurecontainerapps.io"
$env:INCIDENT_MCP_URL  = "ca-incident-mcp-instructor.xxxxx.eastus.azurecontainerapps.io"
$env:ONCALL_API_URL    = "ca-oncall-api-instructor.xxxxx.eastus.azurecontainerapps.io"

リソースグループ名: rg-mcp-$env:USER_ID
（例: user01 なら rg-mcp-user01）
```

---

## 5. 講師による事後クリーンアップ

ハンズオン終了後、全参加者の RG を一括削除します。

```powershell
# rg-mcp-user* に一致する RG を全件削除
az group list --query "[?starts_with(name, 'rg-mcp-user')].name" -o tsv | ForEach-Object {
  Write-Host "Deleting $_"
  az group delete -n $_ --yes --no-wait
}

# Entra ID 共有アプリの削除（次回もハンズオンを実施するなら残す）
az ad app delete --id $(az ad app list --display-name "MCP Workshop Client" --query "[0].appId" -o tsv)
az ad app delete --id $(az ad app list --display-name "MCP Workshop Server" --query "[0].appId" -o tsv)
```

---

## 6. トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| 参加者の `az deployment group create` で `Quota exceeded` (API Center) | 同一リージョンに既存の Free SKU がある | 別のリージョンを割り当て直す |
| 参加者の APIM 名が他人と衝突 | `userId` が重複している | `parameters.json` の `userId` を一意な値に変更 |
| Lab 3 で 401 が返り続ける | 管理者の同意が未付与 | 講師が Client アプリで「管理者の同意を与えます」を再実行 |
| `az ad app list --display-name "MCP Workshop Client"` が複数件返る | 過去のハンズオンの残骸 | 不要なアプリを削除して 1 件に整理 |

---

## 7. 参考: 参加者を増やす場合の検討事項

| 規模 | 対応方針 |
|---|---|
| 〜5 名 | 本ガイドの通り（リージョン分散） |
| 6〜10 名 | 利用可能リージョンを追加（例: `southeastasia`, `australiaeast`, `northeurope`, `westeurope`, `centralus`）。リージョン間の APIM レイテンシ差は無視できる |
| 10 名超 | API Center を Standard SKU に変更し、講師環境に 1 つだけ立てて全員で共有。参加者個別の APIM は維持。または APIM クォータが足りなくなる可能性があるため、サブスクリプションを分けることを推奨 |
