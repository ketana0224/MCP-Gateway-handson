# 前提ツール インストール手順書

本ハンズオンを実施するにあたり、各自の端末に以下のツールをインストールしてください。
所要時間: **20〜30 分**。

---

## 0. インストール対象一覧

| ツール | 最低バージョン | 用途 | 必須/任意 |
|---|---|---|---|
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | 2.60 以上 | Azure リソース操作・デプロイ | 必須 |
| [Node.js](https://nodejs.org/) | 20 以上 | バックエンド API / MCP Server / MCP Inspector の実行 | **必須**（Python と二択ではない。MCP Inspector が npx 必須なので Node.js は事実上必須） |
| [Python](https://www.python.org/downloads/) | 3.11 以上 | 任意。一部スクリプト・SDK 検証で利用 | 任意 |
| [Visual Studio Code](https://code.visualstudio.com/) | 最新 | エディタ。MCP クライアントとしても利用 | 必須 |
| [GitHub Copilot 拡張](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot) | 最新 | VS Code 上で AI エージェント／MCP クライアント | 必須 |
| MCP Inspector | 最新 | MCP Server のデバッグ（`npx` で都度起動）| 必須（事前 install 不要） |
| [Git](https://git-scm.com/downloads) | 2.40 以上 | リポジトリの clone | 必須 |

---

## 1. OS 別 一括インストール

自分の OS のセクションだけ実行してください。

### 1-A. Windows（winget 推奨）

PowerShell（管理者でなくても可、winget が利用可能であること）を開き、1 行ずつ実行：

```powershell
# Git
winget install --id Git.Git -e

# Azure CLI
winget install --id Microsoft.AzureCLI -e

# Node.js LTS（20 以上が入る）
winget install --id OpenJS.NodeJS.LTS -e

# Python 3.12（任意）
winget install --id Python.Python.3.12 -e

# Visual Studio Code
winget install --id Microsoft.VisualStudioCode -e
```

> **💡 winget が無い場合**: Windows 11 / Windows 10（21H2 以降）には標準搭載。古い環境は [App Installer](https://aka.ms/getwinget) を Microsoft Store からインストール。

**インストール後、PowerShell を一度閉じて開き直す**（`PATH` を反映させるため）。

### 1-B. macOS（Homebrew 推奨）

[Homebrew](https://brew.sh/) が未インストールなら先に入れる：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

その後：

```bash
# Git は最新版を入れ替え（macOS 同梱は古い）
brew install git

# Azure CLI
brew install azure-cli

# Node.js（LTS）
brew install node@20
brew link --overwrite node@20

# Python 3.12（任意）
brew install python@3.12

# Visual Studio Code（GUI アプリ）
brew install --cask visual-studio-code
```

### 1-C. Linux（Ubuntu/Debian 系）

```bash
# 1. 基本パッケージ
sudo apt update
sudo apt install -y git curl apt-transport-https lsb-release gnupg

# 2. Azure CLI（公式ワンライナー）
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# 3. Node.js 20（NodeSource）
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 4. Python 3.11+ （Ubuntu 22.04 以降は標準で 3.10+。3.11 が無い場合）
sudo apt install -y python3 python3-pip python3-venv

# 5. VS Code
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/keyrings/
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
rm microsoft.gpg
sudo apt update
sudo apt install -y code
```

> **💡 Linux GUI が無い場合（WSL / リモート開発）**: VS Code は手元の Windows/Mac に入れ、Remote-SSH や WSL 拡張で接続する構成でも OK。

---

## 2. ツール別の追加セットアップ

### 2-1. Azure CLI ログイン

```powershell
# バージョン確認（2.60 以上であること）
az version

# ログイン（ブラウザが開く）
az login

# 使用するサブスクリプションを既定にセット（講師から SUBSCRIPTION_ID が配布される）
az account set --subscription "<SUBSCRIPTION_ID>"

# 現在のアカウントを確認
az account show --query "{name:name, id:id, user:user.name}" -o table
```

#### Bicep CLI を有効化

```powershell
az bicep install
az bicep version   # 0.30 以上ならOK
```

### 2-2. Node.js / npm

```powershell
node -v    # v20.x.x 以上
npm -v     # 10.x.x 以上
```

> **💡 バージョン管理ツール（任意）**: 既存プロジェクトと衝突する場合は [nvm-windows](https://github.com/coreybutler/nvm-windows)（Win）/ [nvm](https://github.com/nvm-sh/nvm)（Mac/Linux）で複数バージョンを切り替えてください。

### 2-3. VS Code 拡張機能

VS Code を起動して、以下の拡張機能をインストール：

| 拡張機能 ID | 用途 |
|---|---|
| `GitHub.copilot` | GitHub Copilot 本体 |
| `GitHub.copilot-chat` | Copilot Chat / Agent モード |
| `ms-azuretools.vscode-bicep` | Bicep 構文サポート |
| `ms-vscode.azure-account` | Azure サインイン統合（任意） |

PowerShell から一括インストール：

```powershell
code --install-extension GitHub.copilot
code --install-extension GitHub.copilot-chat
code --install-extension ms-azuretools.vscode-bicep
```

インストール後、VS Code 右下の **Copilot アイコン** から **GitHub アカウントでサインイン** してください。

### 2-4. MCP Inspector（事前インストール不要）

[MCP Inspector](https://github.com/modelcontextprotocol/inspector) は MCP Server のデバッグツール。`npx` で都度起動するため、事前インストールは **不要** です。

動作確認だけ事前にしておくと安心：

```powershell
# 一度だけ ダウンロード→起動するとブラウザが開く
npx -y @modelcontextprotocol/inspector
```

ブラウザに Inspector の UI が表示されたら OK。ターミナルで `Ctrl+C` で停止。

> **⚠️ APIM の MCP エンドポイントに Inspector で接続する場合は、Transport を必ず `Streamable HTTP` にする**（SSE では接続不可）。

### 2-5. Git の初期設定

```powershell
git --version    # 2.40 以上

git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```

---

## 3. リポジトリの clone

```powershell
git clone https://github.com/<your-org>/MCP-Gateway-handson.git
cd MCP-Gateway-handson
```

> **💡 講師から配布された URL を使ってください**。

---

## 4. 動作確認 ワンライナー

すべて入った後、以下を実行してバージョンを一括表示：

### Windows / macOS / Linux 共通（PowerShell）

```powershell
Write-Host "=== Git ==="          ; git --version
Write-Host "=== Azure CLI ==="    ; az version --output table
Write-Host "=== Bicep CLI ==="    ; az bicep version
Write-Host "=== Node.js ==="      ; node -v
Write-Host "=== npm ==="          ; npm -v
Write-Host "=== Python ==="       ; python --version 2>$null; python3 --version 2>$null
Write-Host "=== VS Code ==="      ; code --version
Write-Host "=== Copilot ext ==="  ; code --list-extensions | Select-String "GitHub.copilot"
```

### 期待される最低バージョン

| ツール | 期待出力例 |
|---|---|
| Git | `git version 2.43.0` 以上 |
| Azure CLI | `azure-cli 2.60.0` 以上 |
| Bicep | `Bicep CLI version 0.30.0` 以上 |
| Node.js | `v20.10.0` 以上 |
| npm | `10.2.4` 以上 |
| Python（任意） | `Python 3.11.x` 以上 |
| VS Code | `1.90.0` 以上 |
| Copilot 拡張 | `GitHub.copilot` と `GitHub.copilot-chat` の 2 行が表示 |

---

## 5. トラブルシューティング

### Q1. `az` コマンドが見つからない（Windows）

PowerShell を **完全に閉じて開き直す**。それでもダメなら端末を再起動。`PATH` 環境変数に `C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin` が含まれているか確認。

### Q2. `node -v` が古いバージョンを返す（macOS / Linux）

複数の Node.js が共存している可能性。`which -a node` でパスを確認し、`/usr/local/bin/node` などが優先されているか見る。nvm 利用時は `nvm alias default 20`。

### Q3. `az login` でブラウザが開かない（WSL / リモート SSH）

デバイスコードフローを使う：

```bash
az login --use-device-code
```

表示された URL とコードを別端末のブラウザで開く。

### Q4. GitHub Copilot がアクティベートできない

- GitHub アカウントが **Copilot サブスクリプション**（個人 / Business / Enterprise）を持っているか確認
- VS Code 右下のアカウントアイコン → **「サインアウト」→「サインイン」** で再認証
- 企業のプロキシ環境では HTTPS_PROXY 環境変数の設定が必要

### Q5. `npx @modelcontextprotocol/inspector` がエラーになる

- Node.js が 18 以下だと動かない → 20 以上に上げる
- 社内プロキシ環境では `npm config set proxy http://...` を設定
- 一度だけキャッシュをクリア：`npm cache clean --force`

### Q6. `code` コマンドが見つからない（macOS）

VS Code を起動 → **コマンドパレット（⌘⇧P）** → `Shell Command: Install 'code' command in PATH` を実行。

---

## 6. 次のステップ

ここまで完了したら、[hands-on.md](./hands-on.md) の **「前提条件 → 参加者環境変数の設定 ①」** に進んでください。
