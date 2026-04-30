const { McpServer } = require("@modelcontextprotocol/sdk/server/mcp.js");
const {
  StreamableHTTPServerTransport,
} = require("@modelcontextprotocol/sdk/server/streamableHttp.js");
const express = require("express");
const { z } = require("zod");

// --- サンプルデータ ---
let incidents = [
  {
    id: "INC-001",
    title: "本番環境 DB 接続エラー",
    severity: "critical",
    status: "open",
    assignee: "田中太郎",
    createdAt: "2026-04-29T10:00:00Z",
    description:
      "本番環境のデータベースへの接続がタイムアウトしています。アプリケーション全体に影響。",
  },
  {
    id: "INC-002",
    title: "VPN 接続不安定",
    severity: "high",
    status: "investigating",
    assignee: "鈴木花子",
    createdAt: "2026-04-29T14:30:00Z",
    description:
      "一部のユーザーで VPN 接続が頻繁に切断される現象が発生しています。",
  },
  {
    id: "INC-003",
    title: "メール配信遅延",
    severity: "medium",
    status: "resolved",
    assignee: "佐藤次郎",
    createdAt: "2026-04-28T09:00:00Z",
    description:
      "Exchange Online でメール配信に最大30分の遅延が発生していましたが、解消済みです。",
  },
];

let nextId = 4;

// --- MCP Server factory (stateless: new instance per request) ---
function createServer() {
  const srv = new McpServer({
    name: "incident-mcp-server",
    version: "1.0.0",
    description: "障害チケット管理用MCP Server。チケットの参照・起票が可能。",
  });

  // Tool: listIncidents
  srv.tool(
    "listIncidents",
    "障害チケットの一覧を取得します。オプションでステータスや重要度でフィルタリングできます。",
    {
      status: z.string().optional().describe(
        "フィルタするステータス (open / investigating / resolved / closed)"
      ),
      severity: z.string().optional().describe(
        "フィルタする重要度 (critical / high / medium / low)"
      ),
    },
    async ({ status, severity }) => {
      let results = [...incidents];
      if (status) results = results.filter((i) => i.status === status);
      if (severity) results = results.filter((i) => i.severity === severity);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              { count: results.length, incidents: results },
              null,
              2
            ),
          },
        ],
      };
    }
  );

  // Tool: getIncident
  srv.tool(
    "getIncident",
    "指定されたIDの障害チケットの詳細を取得します。",
    {
      id: z.string().describe("障害チケットID (例: INC-001)"),
    },
    async ({ id }) => {
      const incident = incidents.find((i) => i.id === id);
      if (!incident) {
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify({ error: `Incident ${id} not found` }),
            },
          ],
          isError: true,
        };
      }
      return {
        content: [{ type: "text", text: JSON.stringify(incident, null, 2) }],
      };
    }
  );

  // Tool: createIncident (副作用あり)
  srv.tool(
    "createIncident",
    "新しい障害チケットを起票します。タイトル、重要度、説明が必要です。",
    {
      title: z.string().describe("チケットタイトル"),
      severity: z.string().optional().describe(
        "重要度 (critical / high / medium / low)"
      ),
      description: z.string().optional().describe("障害の詳細説明"),
      assignee: z.string().optional().describe("担当者名（省略時は未アサイン）"),
    },
    async ({ title, severity, description, assignee }) => {
      const newIncident = {
        id: `INC-${String(nextId++).padStart(3, "0")}`,
        title,
        severity: severity || "medium",
        status: "open",
        assignee: assignee || "未アサイン",
        createdAt: new Date().toISOString(),
        description: description || "",
      };
      incidents.push(newIncident);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              { message: "Incident created successfully", incident: newIncident },
              null,
              2
            ),
          },
        ],
      };
    }
  );

  return srv;
}

// --- Streamable HTTP Transport ---
const app = express();
app.use(express.json());

app.post("/mcp", async (req, res) => {
  const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
  const srv = createServer();
  await srv.connect(transport);
  await transport.handleRequest(req, res, req.body);
});

app.get("/mcp", async (req, res) => {
  res.writeHead(405).end("Method Not Allowed. Use POST for MCP requests.");
});

app.delete("/mcp", async (req, res) => {
  res.writeHead(200).end("Session closed");
});

app.get("/health", (req, res) => res.json({ status: "ok" }));

const PORT = process.env.PORT || 3001;
app.listen(PORT, () =>
  console.log(`Incident MCP Server running on port ${PORT}`)
);
