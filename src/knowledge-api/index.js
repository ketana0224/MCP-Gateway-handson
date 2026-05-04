const express = require("express");
const app = express();
app.use(express.json());

// --- サンプルデータ ---
const categories = [
  { id: "infra", name: "インフラストラクチャ" },
  { id: "security", name: "セキュリティ" },
  { id: "network", name: "ネットワーク" },
  { id: "application", name: "アプリケーション" },
];

const articles = [
  {
    id: "KB001",
    title: "VPN接続エラーの対処法",
    category: "network",
    content:
      "VPN接続で「認証失敗」が発生する場合、まずパスワードリセットを試みてください。次にVPNクライアントの再インストールを行います。それでも解消しない場合はネットワークチームにエスカレーションしてください。",
    tags: ["VPN", "接続エラー", "認証"],
  },
  {
    id: "KB002",
    title: "多要素認証(MFA)の設定手順",
    category: "security",
    content:
      "Microsoft Authenticatorアプリをインストールし、Entra IDポータルからMFAを有効化します。QRコードをスキャンして登録を完了してください。",
    tags: ["MFA", "認証", "セキュリティ"],
  },
  {
    id: "KB003",
    title: "仮想マシンのディスク拡張手順",
    category: "infra",
    content:
      "Azure Portalから仮想マシンを停止し、ディスク設定からサイズを変更します。変更後、OS内部でパーティションを拡張してください。",
    tags: ["VM", "ディスク", "Azure"],
  },
  {
    id: "KB004",
    title: "SSL証明書の更新手順",
    category: "security",
    content:
      "Key Vaultに新しい証明書をアップロードし、Application Gatewayのリスナー設定を更新します。更新後、HTTPSアクセスの動作確認を行ってください。",
    tags: ["SSL", "証明書", "Key Vault"],
  },
  {
    id: "KB005",
    title: "ExpressRoute回線のトラブルシューティング",
    category: "network",
    content:
      "BGPセッションの状態を確認し、ルートテーブルのアドバタイズ状況を点検します。回線プロバイダーの障害情報も並行して確認してください。",
    tags: ["ExpressRoute", "BGP", "ネットワーク"],
  },
];

// --- OpenAPI 定義 ---
const openApiSpec = {
  openapi: "3.0.3",
  info: {
    title: "Knowledge Search API",
    description: "社内ナレッジベースの検索API",
    version: "1.0.0",
  },
  servers: [{ url: "/" }],
  paths: {
    "/api/categories": {
      get: {
        operationId: "listCategories",
        summary: "ナレッジカテゴリの一覧を取得します",
        description: "社内ナレッジベースのカテゴリ一覧を取得します。カテゴリIDと表示名を返します。",
        responses: { 200: { description: "カテゴリ一覧" } },
      },
    },
    "/api/articles/search": {
      post: {
        operationId: "searchArticles",
        summary: "キーワードでナレッジ記事を全文検索します",
        description: "キーワードで社内ナレッジ記事を全文検索します。タイトル・本文・タグを横断検索し、関連度順に記事リストを返します。",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  query: { type: "string", description: "検索キーワード" },
                },
                required: ["query"],
              },
            },
          },
        },
        responses: { 200: { description: "検索結果" } },
      },
    },
    "/api/articles/{id}": {
      get: {
        operationId: "getArticleById",
        summary: "記事IDを指定してナレッジ記事の詳細を取得します",
        description: "記事IDを指定して社内ナレッジ記事の詳細（タイトル・本文・カテゴリ・更新日時）を取得します。",
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string" },
          },
        ],
        responses: {
          200: { description: "記事詳細" },
          404: { description: "記事が見つかりません" },
        },
      },
    },
  },
};

// --- エンドポイント ---
app.get("/api/openapi.json", (req, res) => res.json(openApiSpec));

app.get("/api/categories", (req, res) => res.json(categories));

app.post("/api/articles/search", (req, res) => {
  const { query } = req.body;
  if (!query) return res.status(400).json({ error: "query is required" });

  const q = query.toLowerCase();
  const results = articles.filter(
    (a) =>
      a.title.toLowerCase().includes(q) ||
      a.content.toLowerCase().includes(q) ||
      a.tags.some((t) => t.toLowerCase().includes(q))
  );
  res.json({ query, count: results.length, results });
});

app.get("/api/articles/:id", (req, res) => {
  const article = articles.find((a) => a.id === req.params.id);
  if (!article) return res.status(404).json({ error: "Article not found" });
  res.json(article);
});

app.get("/health", (req, res) => res.json({ status: "ok" }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () =>
  console.log(`Knowledge Search API running on port ${PORT}`)
);
