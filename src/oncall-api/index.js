const express = require("express");
const app = express();

// --- サンプルデータ ---
const schedule = [
  { date: "2026-04-28", primary: "田中太郎", secondary: "佐藤次郎", team: "インフラチーム" },
  { date: "2026-04-29", primary: "鈴木花子", secondary: "田中太郎", team: "インフラチーム" },
  { date: "2026-04-30", primary: "佐藤次郎", secondary: "鈴木花子", team: "インフラチーム" },
  { date: "2026-05-01", primary: "高橋三郎", secondary: "佐藤次郎", team: "ネットワークチーム" },
  { date: "2026-05-02", primary: "田中太郎", secondary: "高橋三郎", team: "インフラチーム" },
];

// --- OpenAPI 定義 ---
const openApiSpec = {
  openapi: "3.0.3",
  info: {
    title: "On-call Schedule API",
    description: "オンコール当番表の参照API",
    version: "1.0.0",
  },
  servers: [{ url: "/" }],
  paths: {
    "/api/oncall/current": {
      get: {
        operationId: "getCurrentOncall",
        summary: "現在のオンコール担当者を取得",
        responses: { 200: { description: "現在の当番情報" } },
      },
    },
    "/api/oncall/{date}": {
      get: {
        operationId: "getScheduleByDate",
        summary: "指定日のオンコール担当者を取得",
        parameters: [
          { name: "date", in: "path", required: true, schema: { type: "string" }, description: "日付 (YYYY-MM-DD)" },
        ],
        responses: {
          200: { description: "当番情報" },
          404: { description: "スケジュール未登録" },
        },
      },
    },
  },
};

// --- エンドポイント ---
app.get("/api/openapi.json", (req, res) => res.json(openApiSpec));

app.get("/api/oncall/current", (req, res) => {
  const today = new Date().toISOString().split("T")[0];
  const entry = schedule.find((s) => s.date === today);
  if (!entry) {
    return res.json({
      date: today,
      primary: "未登録",
      secondary: "未登録",
      team: "未登録",
      message: "本日のオンコールスケジュールは未登録です",
    });
  }
  res.json(entry);
});

app.get("/api/oncall/:date", (req, res) => {
  const entry = schedule.find((s) => s.date === req.params.date);
  if (!entry) {
    return res.status(404).json({
      error: `Schedule not found for ${req.params.date}`,
    });
  }
  res.json(entry);
});

app.get("/health", (req, res) => res.json({ status: "ok" }));

const PORT = process.env.PORT || 3002;
app.listen(PORT, () =>
  console.log(`On-call Schedule API running on port ${PORT}`)
);
