# 在 VS Code 里用 Cline 的 cline-free（免费）/ DeepSeek 模型

一份可复现的操作手册：讲清楚 Cline 的免费模型池（`cline-free/*`）到底是什么、
**为什么现在免费池里没有 DeepSeek**、以及在 VS Code 里用 DeepSeek 的 4 条可行路线。

👉 **完整指南：[`docs/cline-free-deepseek-vscode.md`](docs/cline-free-deepseek-vscode.md)**

## 30 秒结论

| 你想要的 | 怎么做 |
|---|---|
| 白嫖 Cline 免费池 | VS Code 装 Cline 扩展 → `API Provider = Cline` → **Sign In** → 模型选择器 **Free** 标签页 |
| **现在就用 DeepSeek**（推荐） | `API Provider = DeepSeek` + 自己的 DeepSeek 官方 API key（按量付费，很便宜） |
| 高额度稳定用 | ClinePass 订阅（`cline-pass/deepseek-v4.1-flash`、`cline-pass/deepseek-v4-pro`） |
| 完全离线 | Ollama / LM Studio 本地跑 DeepSeek 蒸馏模型 |

`cline-free/xxx` 不是模型本身，而是 Cline **限时免费推广**的模型 ID 前缀，内容由服务端轮换下发。
**2026-10-12 实测免费池 = `step-5-preview` / `mimo-v2.6-flash` / `muse-spark-1.3-contributor` / `solar-mini4`，里面没有 DeepSeek。**

## 随时自检"今天有没有免费 DeepSeek"

```bash
./scripts/check-cline-free-models.sh          # 列出 free / clinePass / clineCloud 三桶并判断
./scripts/check-cline-free-models.sh --quiet  # 只输出结论；退出码 0 = 免费池里有 DeepSeek
```

脚本直接读 Cline 的公开接口 `https://api.cline.bot/api/v1/ai/cline/recommended-models`（无需登录），
也就是 VS Code 插件渲染 Free 标签页时用的同一份数据。

## 目录

- `docs/cline-free-deepseek-vscode.md` —— 主指南（概念、4 条路线、排障表、源码构建、证据索引）
- `scripts/check-cline-free-models.sh` —— 免费池自检脚本

> 时效性提醒：免费推广是限时轮换的，先跑脚本再按指南操作。
